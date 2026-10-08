import 'dart:convert';

import '../../config/api_config.dart';
import '../runtime_config.dart';
import 'yam_http.dart';

/// Endpoints de configuration et de diagnostic (`/api/v1/config`, `/up`).
class ConfigApi {
  ConfigApi(this._http);

  final YamHttpClient _http;

  /// Récupère la configuration runtime (Pusher + TURN) depuis le backend.
  ///
  /// Retourne null si l'endpoint est injoignable ou illisible (l'app garde
  /// alors ses valeurs par défaut locales).
  Future<RuntimeConfig?> fetchConfig() async {
    try {
      final res = await _http.rawGet(
        '/api/v1/config',
        timeout: const Duration(seconds: 8),
      );
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body);
      if (json is! Map<String, dynamic>) return null;
      return RuntimeConfig.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Sonde de santé de l'API Laravel (`GET /up`).
  Future<bool> healthCheck() async {
    try {
      final res = await _http.rawGet(
        ApiConfig.healthCheck,
        timeout: const Duration(seconds: 5),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
