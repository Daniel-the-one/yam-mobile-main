import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../utils/api_errors.dart';
import '../../utils/json_utils.dart';

/// Client HTTP de base des APIs Yam (Laravel).
///
/// Porte le socle commun à toutes les familles d'endpoints : construction
/// d'URI, en-têtes (Bearer Yam ou Bearer démo), GET/POST/DELETE avec délai
/// et extraction d'erreur. Les familles métier (auth, wallet, contacts…)
/// s'appuient dessus via les fichiers dédiés de `services/api/`.
class YamHttpClient {
  YamHttpClient(
    this.baseUrlProvider, {
    this.tokenProvider,
    this.demoTokenProvider,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Fournit l'URL courante (modifiable dans les réglages de l'app).
  final String Function() baseUrlProvider;

  /// Fournit le jeton Yam réel (`Authorization: Bearer`).
  final String? Function()? tokenProvider;

  /// Fournit le jeton de la session de DÉMONSTRATION (famille argent).
  ///
  /// Les endpoints `/api/demo/v1/*` exigent leur propre jeton (`demo_…`),
  /// distinct du jeton Yam réel : le middleware `demo.auth` rejette un jeton
  /// Yam classique (401). Sans ce jeton, les opérations d'argent en mode démo
  /// échoueraient systématiquement.
  final String? Function()? demoTokenProvider;

  /// Client HTTP utilisé pour les requêtes. Injectable pour les tests
  /// (MockClient de package:http/testing) ; par défaut un vrai client.
  final http.Client _client;

  /// Construit l'URI absolue d'un chemin d'API.
  Uri uri(String path) {
    final base = baseUrlProvider().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base$path');
  }

  /// En-têtes communs : `Content-Type` + `Authorization: Bearer` (jeton Yam
  /// réel ou jeton démo selon [demo]).
  Map<String, String> buildHeaders({
    bool authenticated = false,
    bool demo = false,
  }) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = demo ? demoTokenProvider?.call() : tokenProvider?.call();
    if (authenticated && token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Décode un corps de réponse ; lève [ApiException] si illisible.
  static dynamic decodeSafe(http.Response res, String path) {
    try {
      return jsonDecode(res.body);
    } catch (_) {
      if (res.statusCode >= 500) {
        throw ApiException(
          'Serveur temporairement indisponible (HTTP ${res.statusCode}).',
        );
      }
      throw ApiException(
        'Réponse illisible du serveur (HTTP ${res.statusCode}).',
      );
    }
  }

  /// GET avec décodage et extraction d'erreur standard.
  Future<Map<String, dynamic>> get(
    String path, {
    bool authenticated = false,
    bool demo = false,
    Map<String, String>? extraHeaders,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final reqHeaders = buildHeaders(authenticated: authenticated, demo: demo);
    if (extraHeaders != null) reqHeaders.addAll(extraHeaders);

    final res = await _client
        .get(uri(path), headers: reqHeaders)
        .timeout(timeout);

    final decoded = decodeSafe(res, path);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final map = decoded is Map<String, dynamic>
          ? decoded
          : const <String, dynamic>{};
      final message = apiErrorMessage(map);
      throw ApiException(message ?? 'API $path → HTTP ${res.statusCode}');
    }
    return decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'data': decoded};
  }

  /// POST avec décodage et extraction d'erreur standard.
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool authenticated = false,
    bool demo = false,
    Map<String, String>? extraHeaders,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final reqHeaders = buildHeaders(authenticated: authenticated, demo: demo);
    if (extraHeaders != null) reqHeaders.addAll(extraHeaders);

    final res = await _client
        .post(uri(path), headers: reqHeaders, body: jsonEncode(body))
        .timeout(timeout);

    final decoded = decodeSafe(res, path);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final map = decoded is Map<String, dynamic>
          ? decoded
          : const <String, dynamic>{};
      final message = apiErrorMessage(map);
      throw ApiException(message ?? 'API $path → HTTP ${res.statusCode}');
    }
    return decoded as Map<String, dynamic>;
  }

  /// DELETE avec décodage et extraction d'erreur standard.
  Future<Map<String, dynamic>> delete(
    String path, {
    bool authenticated = false,
    bool demo = false,
  }) async {
    final res = await _client
        .delete(
          uri(path),
          headers: buildHeaders(authenticated: authenticated, demo: demo),
        )
        .timeout(const Duration(seconds: 10));

    final decoded = jsonDecode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final map = decoded is Map<String, dynamic>
          ? decoded
          : const <String, dynamic>{};
      final message = map['message'] ?? map['error']?['message'];
      throw ApiException(message ?? 'API $path → HTTP ${res.statusCode}');
    }
    return decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'ok': true};
  }

  /// GET brut (statut + corps) pour les endpoints à comportement spécial
  /// (config, recherche, offre différée, sonde de santé) qui retournent
  /// null/[] au lieu de lever une exception.
  Future<http.Response> rawGet(
    String path, {
    bool authenticated = false,
    bool demo = false,
    Map<String, String>? extraHeaders,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final reqHeaders = buildHeaders(authenticated: authenticated, demo: demo);
    if (extraHeaders != null) reqHeaders.addAll(extraHeaders);
    return _client.get(uri(path), headers: reqHeaders).timeout(timeout);
  }

  /// POST brut (statut + corps) pour les endpoints qui gèrent eux-mêmes le
  /// décodage et l'extraction d'erreur (ex. wallet avec `Idempotency-Key`).
  Future<http.Response> postRaw(
    String path,
    Map<String, dynamic> body, {
    bool authenticated = false,
    bool demo = false,
    Map<String, String>? extraHeaders,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final reqHeaders = buildHeaders(authenticated: authenticated, demo: demo);
    if (extraHeaders != null) reqHeaders.addAll(extraHeaders);
    return _client
        .post(uri(path), headers: reqHeaders, body: jsonEncode(body))
        .timeout(timeout);
  }
}
