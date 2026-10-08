import '../../config/api_config.dart';
import 'yam_http.dart';

/// Endpoints des appareils enregistrés (`/api/v1/devices`).
class DevicesApi {
  DevicesApi(this._http);

  final YamHttpClient _http;

  /// Liste des appareils de l'utilisateur (`GET /api/v1/devices`).
  Future<Map<String, dynamic>> fetchDevices() =>
      _http.get(ApiConfig.devices, authenticated: true);

  /// Enregistre un appareil (`POST /api/v1/devices/register`).
  Future<Map<String, dynamic>> registerDevice({
    required String label,
    required String deviceId,
    required String platform,
  }) => _http.post(ApiConfig.deviceRegister, {
    'label': label,
    'device_id': deviceId,
    'platform': platform,
  }, authenticated: true);

  /// Supprime un appareil enregistré (`DELETE /api/v1/devices/{deviceId}`).
  Future<Map<String, dynamic>> deleteDevice(String deviceId) =>
      _http.delete(ApiConfig.deviceDelete(deviceId), authenticated: true);
}
