import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../utils/api_errors.dart';
import '../../utils/json_utils.dart';
import '../storage_service.dart';

/// Client HTTP des APIs PHP KondjiPro (famille « médicale »).
///
/// Porte le socle commun : session (cookie `kondjipro_session` + CSRF),
/// re-login silencieux, envoi GET/POST urlencodé avec gestion des erreurs.
/// Les familles métier (patients, médical, argent) s'appuient dessus via les
/// fichiers dédiés de `services/kondjipro/`.
///
/// Mécanisme d'authentification (identique au portail web) :
///  1. `POST /api/auth/login.php` → le serveur renvoie un cookie de session
///     `kondjipro_session` (capturé depuis l'en-tête `Set-Cookie`) et un
///     `csrf_token` ;
///  2. cookie + CSRF sont persistés localement ([StorageService]) et
///     envoyés sur chaque requête (`Cookie` + `X-CSRF-Token`) ;
///  3. sur un 401 (session expirée côté serveur), le client tente UN
///     re-login silencieux avec les identifiants conservés en mémoire puis
///     rejoue la requête ; à défaut, [KondjiproAuthException] est levée.
class KproHttpClient {
  KproHttpClient({
    required this.baseUrlProvider,
    required this.storage,
    this.demoTokenProvider,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  /// Fournit l'URL courante du serveur (partagée avec Yam).
  final String Function() baseUrlProvider;

  final StorageService storage;

  /// Fournit le jeton de session de DÉMONSTRATION (famille argent).
  ///
  /// Les endpoints `/api/demo/v1/*` (encaissement, solde) exigent leur propre
  /// jeton `demo_…` en `Authorization: Bearer`, PAS le cookie PHP KondjiPro.
  final String? Function()? demoTokenProvider;

  final http.Client _http;

  String? _sessionCookie;
  String? _csrfToken;

  // Identifiants conservés EN MÉMOIRE UNIQUEMENT (jamais persistés) pour
  // permettre un re-login silencieux pendant la durée de vie de l'app.
  String? _identifier;
  String? _password;

  /// Vrai si un cookie de session est disponible (potentiellement expiré).
  bool get hasSession => _sessionCookie != null && _sessionCookie!.isNotEmpty;

  /// Restaure la session persistée (cookie + CSRF) au démarrage de l'app.
  Future<void> restore() async {
    _sessionCookie = await storage.loadKproSession();
    _csrfToken = await storage.loadKproCsrf();
  }

  Uri _uri(String path) {
    final base = baseUrlProvider().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base$path');
  }

  /// Connecte la session KondjiPro (famille médicale).
  ///
  /// Réussite = cookie `kondjipro_session` + `csrf_token` reçus et persistés.
  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    final res = await _http
        .post(
          _uri(ApiConfig.kproLogin),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'identifier': identifier, 'password': password}),
        )
        .timeout(const Duration(seconds: 12));

    final decoded = decodeJsonMap(res.body);
    if (res.statusCode != 200) {
      throw ApiException(
        messageOf(decoded) ??
            'Connexion médicale refusée (HTTP ${res.statusCode}).',
      );
    }

    final setCookie = res.headers['set-cookie'] ?? '';
    final match = RegExp(r'kondjipro_session=([^;,\s]+)').firstMatch(setCookie);
    if (match == null) {
      throw ApiException(
        'Réponse de connexion médicale invalide (pas de session).',
      );
    }

    _sessionCookie = match.group(1);
    _csrfToken = decoded?['csrf_token']?.toString() ?? _csrfToken;
    _identifier = identifier;
    _password = password;

    await storage.saveKproSession(_sessionCookie!);
    if (_csrfToken != null && _csrfToken!.isNotEmpty) {
      await storage.saveKproCsrf(_csrfToken!);
    }
    debugPrint(
      '[YAM][KPRO] session médicale établie (csrf=${_csrfToken != null})',
    );
  }

  /// Détruit la session côté serveur puis purge tout localement.
  Future<void> logout() async {
    try {
      if (hasSession) {
        await _http
            .post(_uri(ApiConfig.kproLogout), headers: _headers())
            .timeout(const Duration(seconds: 8));
      }
    } catch (_) {
      // Le nettoyage local doit avoir lieu même si le serveur est injoignable.
    }
    await _clearLocal();
  }

  /// Purge locale sans appel réseau (session Yam expirée, etc.).
  Future<void> _clearLocal() async {
    _sessionCookie = null;
    _csrfToken = null;
    _identifier = null;
    _password = null;
    await storage.clearKproSession();
  }

  // ────────────────────── Requêtes authentifiées ──────────────────────

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);

  /// POST au format `application/x-www-form-urlencoded` (PHP lit `$_POST`).
  Future<Map<String, dynamic>> postForm(
    String path,
    Map<String, String> fields,
  ) => _send('POST', path, form: fields);

  /// POST urlencodé à partir d'une chaîne déjà encodée — nécessaire pour les
  /// clés répétées du type `actes[]` qu'une Map ne peut pas exprimer.
  Future<Map<String, dynamic>> postFormRaw(String path, String body) =>
      _send('POST', path, formRaw: body);

  Map<String, String> _headers({bool withCsrf = false}) {
    return <String, String>{
      if (hasSession) 'Cookie': 'kondjipro_session=$_sessionCookie',
      if (withCsrf && _csrfToken != null && _csrfToken!.isNotEmpty)
        'X-CSRF-Token': _csrfToken!,
    };
  }

  /// Vrai si le chemin cible un endpoint de DÉMONSTRATION Laravel
  /// (`/api/demo/v1/…`) : authentifié par jeton Bearer démo, pas par cookie.
  static bool _isDemoEndpoint(String path) => path.startsWith('/api/demo/');

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? form,
    String? formRaw,
    bool isRetry = false,
  }) async {
    final isDemo = _isDemoEndpoint(path);

    final headers = <String, String>{};
    if (isDemo) {
      // Famille argent en démo : jeton Bearer dédié (session /api/demo/v1).
      final token = demoTokenProvider?.call() ?? '';
      if (token.isEmpty) {
        throw KondjiproAuthException(
          'Session de démonstration absente — reconnectez-vous.',
        );
      }
      headers['Authorization'] = 'Bearer $token';
    } else {
      if (!hasSession) {
        throw KondjiproAuthException(
          'Session médicale absente — reconnectez-vous (Profil → déconnexion).',
        );
      }
      headers.addAll(_headers(withCsrf: method != 'GET'));
    }
    if (formRaw != null) {
      headers['Content-Type'] = 'application/x-www-form-urlencoded';
    }

    final http.Response res;
    try {
      if (method == 'GET') {
        res = await _http
            .get(_uri(path), headers: headers)
            .timeout(const Duration(seconds: 12));
      } else {
        res = await _http
            .post(_uri(path), headers: headers, body: formRaw ?? form ?? '')
            .timeout(const Duration(seconds: 12));
      }
    } on TimeoutException {
      throw ApiException('Serveur médical injoignable (délai dépassé).');
    } on Exception catch (e) {
      // Erreur réseau (connexion refusée, DNS, TLS…) : message orienté action,
      // sans jargon technique. Le détail reste en log de debug.
      debugPrint('[YAM][KPRO] erreur réseau sur $path : $e');
      throw ApiException(
        'Serveur médical injoignable — vérifiez votre connexion.',
      );
    }

    // Session expirée côté serveur → 1 re-login silencieux puis nouvel essai.
    // (Uniquement pour la famille médicale : la démo n'a pas d'identifiants
    // en mémoire pour un re-login silencieux.)
    if (res.statusCode == 401 && !isRetry && !isDemo) {
      final reconnected = await _tryReconnect();
      if (reconnected) {
        return _send(method, path, form: form, formRaw: formRaw, isRetry: true);
      }
      throw KondjiproAuthException(
        'Session médicale expirée — reconnectez-vous (Profil → déconnexion).',
      );
    }

    final decoded = decodeJsonMap(res.body);

    if (res.statusCode == 403) {
      // csrf_invalid ou refus d'accès : on expose le message serveur.
      throw ApiException(messageOf(decoded) ?? 'Accès refusé (HTTP 403).');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(
        messageOf(decoded) ?? 'Erreur API médicale (HTTP ${res.statusCode}).',
      );
    }
    if (decoded == null) {
      throw ApiException('Réponse illisible du serveur médical.');
    }
    // Les endpoints PHP métier répondent {ok:false, message} en HTTP 200
    // pour certaines validations : on les convertit en exception.
    if (decoded['ok'] == false) {
      throw ApiException(
        messageOf(decoded) ?? 'Opération refusée par le serveur.',
      );
    }
    return decoded;
  }

  /// Re-login silencieux (identifiants en mémoire uniquement).
  Future<bool> _tryReconnect() async {
    final id = _identifier;
    final pwd = _password;
    if (id == null || pwd == null) return false;
    try {
      await login(identifier: id, password: pwd);
      return true;
    } catch (e) {
      debugPrint('[YAM][KPRO] re-login impossible : $e');
      return false;
    }
  }
}
