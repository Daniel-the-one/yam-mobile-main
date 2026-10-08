import '../../config/api_config.dart';
import 'yam_http.dart';

/// Endpoints d'authentification Yam (`/api/v1/auth/*`) et session de
/// démonstration (`/api/demo/v1/auth/*`, famille argent).
class AuthApi {
  AuthApi(this._http);

  final YamHttpClient _http;

  /// Connexion (`POST /api/v1/auth/login`).
  Future<Map<String, dynamic>> login({
    required String phoneNumber,
    required String password,
    required String deviceId,
    required String platform,
    String? label,
  }) => _http.post('/api/v1/auth/login', {
    'phone_number': phoneNumber,
    'password': password,
    'device_id': deviceId,
    'platform': platform,
    if (label != null && label.isNotEmpty) 'label': label,
  });

  /// Création de compte (`POST /api/v1/auth/register`).
  Future<Map<String, dynamic>> register({
    required String name,
    required String phoneNumber,
    required String password,
    required String deviceId,
    required String platform,
    String? username,
  }) => _http.post('/api/v1/auth/register', {
    'name': name,
    'phone_number': phoneNumber,
    'password': password,
    'device_id': deviceId,
    'platform': platform,
    if (username != null && username.isNotEmpty) 'username': username,
  });

  /// Ouvre une session de DÉMONSTRATION (`POST /api/demo/v1/auth/login`).
  ///
  /// Corps vide = compte visiteur (portefeuille virtuel neuf) ; avec
  /// [phoneNumber] + [password] = connexion à un compte démo existant.
  Future<Map<String, dynamic>> demoLogin({
    String? phoneNumber,
    String? password,
    String? deviceId,
  }) => _http.post(ApiConfig.demoAuthLogin, {
    if (phoneNumber != null && phoneNumber.isNotEmpty)
      'phone_number': phoneNumber,
    if (password != null && password.isNotEmpty) 'password': password,
    if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
  });

  /// Crée un compte de DÉMONSTRATION (`POST /api/demo/v1/auth/register`).
  Future<Map<String, dynamic>> demoRegister({
    required String name,
    required String phoneNumber,
    required String password,
    String? deviceId,
  }) => _http.post(ApiConfig.demoAuthRegister, {
    'name': name,
    'phone_number': phoneNumber,
    'password': password,
    if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
  });

  /// Déconnexion (`POST /api/v1/auth/logout`).
  Future<void> logout() async {
    await _http.post('/api/v1/auth/logout', const {}, authenticated: true);
  }
}
