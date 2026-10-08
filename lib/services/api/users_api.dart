import 'dart:convert';

import '../../config/api_config.dart';
import 'yam_http.dart';

/// Endpoints des utilisateurs (`/api/v1/users/*`).
class UsersApi {
  UsersApi(this._http);

  final YamHttpClient _http;

  /// Recherche d'utilisateurs (`GET /api/v1/users/search?q=…&limit=8`).
  ///
  /// Retourne une liste vide si le serveur ne répond pas 200.
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final res = await _http.rawGet(
      '/api/v1/users/search?q=${Uri.encodeQueryComponent(query)}&limit=8',
      authenticated: true,
      timeout: const Duration(seconds: 8),
    );
    if (res.statusCode != 200) return [];
    final json = jsonDecode(res.body);
    final data = json is Map ? (json['data'] ?? json['users']) : null;
    if (data is! List) return [];
    return data.whereType<Map>().map((u) => u.cast<String, dynamic>()).toList();
  }

  /// Profil de l'utilisateur connecté (`GET /api/v1/users/me`).
  Future<Map<String, dynamic>> getMe() =>
      _http.get(ApiConfig.usersMe, authenticated: true);
}
