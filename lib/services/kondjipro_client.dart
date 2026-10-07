import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'storage_service.dart';

/// Erreur d'authentification KondjiPro (session absente ou expirée).
class KondjiproAuthException implements Exception {
  KondjiproAuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Client HTTP des APIs PHP KondjiPro (famille « médicale »).
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
///
/// Les endpoints sont fournis par [ApiConfig] — c'est le seul endroit où
/// ils se modifient.
class KondjiproClient {
  KondjiproClient({
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
          body: jsonEncode({
            'identifier': identifier,
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 12));

    final decoded = _decode(res.body);
    if (res.statusCode != 200) {
      throw Exception(_messageOf(decoded) ??
          'Connexion médicale refusée (HTTP ${res.statusCode}).');
    }

    final setCookie = res.headers['set-cookie'] ?? '';
    final match = RegExp(r'kondjipro_session=([^;,\s]+)').firstMatch(setCookie);
    if (match == null) {
      throw Exception('Réponse de connexion médicale invalide (pas de session).');
    }

    _sessionCookie = match.group(1);
    _csrfToken = decoded?['csrf_token']?.toString() ?? _csrfToken;
    _identifier = identifier;
    _password = password;

    await storage.saveKproSession(_sessionCookie!);
    if (_csrfToken != null && _csrfToken!.isNotEmpty) {
      await storage.saveKproCsrf(_csrfToken!);
    }
    debugPrint('[YAM][KPRO] session médicale établie (csrf=${_csrfToken != null})');
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
  ) =>
      _send('POST', path, form: fields);

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
            'Session de démonstration absente — reconnectez-vous.');
      }
      headers['Authorization'] = 'Bearer $token';
    } else {
      if (!hasSession) {
        throw KondjiproAuthException(
            'Session médicale absente — reconnectez-vous (Profil → déconnexion).');
      }
      headers.addAll(_headers(withCsrf: method != 'GET'));
    }
    if (formRaw != null) {
      headers['Content-Type'] = 'application/x-www-form-urlencoded';
    }

    final http.Response res;
    try {
      if (method == 'GET') {
        res = await _http.get(_uri(path), headers: headers)
            .timeout(const Duration(seconds: 12));
      } else {
        res = await _http
            .post(_uri(path), headers: headers, body: formRaw ?? form ?? '')
            .timeout(const Duration(seconds: 12));
      }
    } on TimeoutException {
      throw Exception('Serveur médical injoignable (délai dépassé).');
    } on Exception catch (e) {
      // Erreur réseau (connexion refusée, DNS, TLS…) : message orienté action,
      // sans jargon technique. Le détail reste en log de debug.
      debugPrint('[YAM][KPRO] erreur réseau sur $path : $e');
      throw Exception('Serveur médical injoignable — vérifiez votre connexion.');
    }

    // Session expirée côté serveur → 1 re-login silencieux puis nouvel essai.
    // (Uniquement pour la famille médicale : la démo n'a pas d'identifiants
    // en mémoire pour un re-login silencieux.)
    if (res.statusCode == 401 && !isRetry && !isDemo) {
      final reconnected = await _tryReconnect();
      if (reconnected) {
        return _send(method, path,
            form: form, formRaw: formRaw, isRetry: true);
      }
      throw KondjiproAuthException(
          'Session médicale expirée — reconnectez-vous (Profil → déconnexion).');
    }

    final decoded = _decode(res.body);

    if (res.statusCode == 403) {
      // csrf_invalid ou refus d'accès : on expose le message serveur.
      throw Exception(_messageOf(decoded) ?? 'Accès refusé (HTTP 403).');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_messageOf(decoded) ??
          'Erreur API médicale (HTTP ${res.statusCode}).');
    }
    if (decoded == null) {
      throw Exception('Réponse illisible du serveur médical.');
    }
    // Les endpoints PHP métier répondent {ok:false, message} en HTTP 200
    // pour certaines validations : on les convertit en exception.
    if (decoded['ok'] == false) {
      throw Exception(_messageOf(decoded) ?? 'Opération refusée par le serveur.');
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

  // ────────────────────────── Endpoints métier ──────────────────────────

  /// Recherche de patients (`?q=`) — vide = les 20 premiers.
  Future<List<Map<String, dynamic>>> searchPatients(String query) async {
    final q = query.trim();
    final res = await get(
        '${ApiConfig.patients}${q.isEmpty ? '' : '?q=${Uri.encodeQueryComponent(q)}'}');
    final results = res['results'];
    if (results is! List) return [];
    return results.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  /// Résout l'identifiant numérique d'un patient.
  ///
  /// 1. `knownId` fourni (depuis le dossier médical) → conversion directe ;
  /// 2. sinon recherche par téléphone (`?q=` sur les 8 derniers chiffres) avec
  ///    appariement EXACT des chiffres du numéro — jamais de correspondance
  ///    approximative, pour ne pas facturer/prescrire au mauvais patient ;
  /// 3. `null` si aucun patient ne correspond exactement.
  Future<int?> resolvePatientId({String? phone, String? knownId}) async {
    if (knownId != null && knownId.isNotEmpty) {
      final id = int.tryParse(knownId);
      if (id != null) return id;
    }
    final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8) return null;
    final tail = digits.substring(digits.length - 8);

    final rows = await searchPatients(tail);
    for (final row in rows) {
      final rowDigits =
          (row['telephone'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
      if (rowDigits.endsWith(tail)) {
        final id = int.tryParse('${row['id']}');
        if (id != null) return id;
      }
    }
    return null;
  }

  /// Détail patient + historique (`?id=`).
  Future<(Map<String, dynamic>?, List<Map<String, dynamic>>)>
      patientDetail(String id) async {
    final res =
        await get('${ApiConfig.patients}?id=${Uri.encodeQueryComponent(id)}');
    final patient = res['patient'];
    final historique = res['historique'];
    return (
      patient is Map ? patient.cast<String, dynamic>() : null,
      historique is List
          ? historique.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
          : <Map<String, dynamic>>[],
    );
  }

  /// Enregistre une consultation (famille médicale — réelle).
  Future<void> saveConsultation({
    required int patientId,
    required String motif,
    String diagnostic = '',
    String notes = '',
  }) =>
      postForm(ApiConfig.consultationSave, {
        'patient': '$patientId',
        'motif': motif,
        'diagnostic': diagnostic,
        'notes': notes,
      }).then((_) {});

  /// Enregistre une ordonnance (famille médicale — réelle).
  Future<void> saveOrdonnance({
    required int patientId,
    required String notes,
    required List<Map<String, String>> meds,
  }) =>
      postForm(ApiConfig.ordonnanceSave, {
        'patient': '$patientId',
        'notes': notes,
        for (var i = 0; i < meds.length; i++) ...{
          'med[$i][nom]': meds[i]['nom'] ?? '',
          'med[$i][quantite]': meds[i]['quantite'] ?? '1',
          'med[$i][unite]': meds[i]['unite'] ?? '',
          'med[$i][frequence]': meds[i]['frequence'] ?? '',
        },
      }).then((_) {});

  /// Enregistre une facture à partir des codes d'actes (C001…C006).
  ///
  /// `actes[]` est une clé répétée (`actes[]=C001&actes[]=C002`) : le corps
  /// est construit à la main car une Map ne peut pas porter de clés doublons.
  Future<void> saveFacture({
    required int patientId,
    required List<String> codes,
  }) =>
      postFormRaw(
        ApiConfig.factureSave,
        'patient=${Uri.encodeQueryComponent('$patientId')}'
        '&${codes.map((c) => 'actes[]=${Uri.encodeQueryComponent(c)}').join('&')}',
      ).then((_) {});

  /// Profil du médecin connecté (famille médicale — réelle).
  Future<Map<String, dynamic>> medecinProfil() => get(ApiConfig.medecin);

  /// Solde KondjiPay — route ARGENT (démo si [ApiConfig.moneyDemo]).
  /// Réponse {ok, solde} dans les deux modes.
  Future<int> solde() async {
    final res = await get(ApiConfig.solde);
    return int.tryParse('${res['solde'] ?? 0}') ?? 0;
  }

  /// Demande d'encaissement — route ARGENT (démo si [ApiConfig.moneyDemo]).
  /// Retourne la transaction (référence, statut) + `qr_data`.
  Future<Map<String, dynamic>> encaisser({
    required int patientId,
    required int montant,
    String motif = '',
  }) =>
      postForm(ApiConfig.encaissement, {
        'patient_id': '$patientId',
        'montant': '$montant',
        'motif': motif,
      });

  // ────────────────────────── Helpers JSON ──────────────────────────

  static Map<String, dynamic>? _decode(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static String? _messageOf(Map<String, dynamic>? json) {
    if (json == null) return null;
    final message = json['message'];
    if (message is String && message.isNotEmpty) return message;
    return null;
  }
}
