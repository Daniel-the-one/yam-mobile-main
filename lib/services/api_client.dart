import 'package:http/http.dart' as http;

import 'api/auth_api.dart';
import 'api/calls_api.dart';
import 'api/config_api.dart';
import 'api/contacts_api.dart';
import 'api/devices_api.dart';
import 'api/users_api.dart';
import 'api/wallet_api.dart';
import 'api/yam_http.dart';
import 'runtime_config.dart';

/// Façade des APIs Yam (Laravel).
///
/// L'interface publique est inchangée pour les écrans et les tests, mais
/// chaque famille d'endpoints est désormais délèguée à son fichier dédié
/// dans `services/api/` : pour déboguer un domaine, ouvrir directement
/// `auth_api.dart`, `wallet_api.dart`, `contacts_api.dart`, `devices_api.dart`,
/// `calls_api.dart`, `users_api.dart` ou `config_api.dart`.
class ApiClient {
  ApiClient(
    this.baseUrlProvider, {
    this.tokenProvider,
    this.demoTokenProvider,
    http.Client? client,
  }) : _http = YamHttpClient(
         baseUrlProvider,
         tokenProvider: tokenProvider,
         demoTokenProvider: demoTokenProvider,
         client: client,
       );

  /// Fournit l'URL courante (modifiable dans les réglages de l'app).
  final String Function() baseUrlProvider;

  /// Fournit le jeton Yam réel (`Authorization: Bearer`).
  final String? Function()? tokenProvider;

  /// Fournit le jeton de la session de DÉMONSTRATION (famille argent).
  final String? Function()? demoTokenProvider;

  /// Socle HTTP partagé (URI, en-têtes, GET/POST/DELETE, erreurs).
  final YamHttpClient _http;

  // ── Familles exposées ──────────────────────────────────────────────
  late final AuthApi auth = AuthApi(_http);
  late final WalletApi wallet = WalletApi(_http);
  late final ContactsApi contacts = ContactsApi(_http);
  late final DevicesApi devices = DevicesApi(_http);
  late final CallsApi calls = CallsApi(_http);
  late final UsersApi users = UsersApi(_http);
  late final ConfigApi config = ConfigApi(_http);

  // ── Délégations (interface historique inchangée) ───────────────────

  /// Récupère la configuration runtime (Pusher + TURN) depuis le backend.
  Future<RuntimeConfig?> fetchConfig() => config.fetchConfig();

  Future<Map<String, dynamic>> login({
    required String phoneNumber,
    required String password,
    required String deviceId,
    required String platform,
    String? label,
  }) => auth.login(
    phoneNumber: phoneNumber,
    password: password,
    deviceId: deviceId,
    platform: platform,
    label: label,
  );

  Future<Map<String, dynamic>> register({
    required String name,
    required String phoneNumber,
    required String password,
    required String deviceId,
    required String platform,
    String? username,
  }) => auth.register(
    name: name,
    phoneNumber: phoneNumber,
    password: password,
    deviceId: deviceId,
    platform: platform,
    username: username,
  );

  /// Ouvre une session de DÉMONSTRATION (`POST /api/demo/v1/auth/login`).
  Future<Map<String, dynamic>> demoLogin({
    String? phoneNumber,
    String? password,
    String? deviceId,
  }) => auth.demoLogin(
    phoneNumber: phoneNumber,
    password: password,
    deviceId: deviceId,
  );

  /// Crée un compte de DÉMONSTRATION (`POST /api/demo/v1/auth/register`).
  Future<Map<String, dynamic>> demoRegister({
    required String name,
    required String phoneNumber,
    required String password,
    String? deviceId,
  }) => auth.demoRegister(
    name: name,
    phoneNumber: phoneNumber,
    password: password,
    deviceId: deviceId,
  );

  Future<void> logout() => auth.logout();

  /// Fait sonner l'appareil cible. Retourne le call_id si fourni.
  Future<String?> ring({
    required String toUserId,
    required String fromDeviceId,
    required String fromUsername,
    String type = 'audio',
  }) => calls.ring(
    toUserId: toUserId,
    fromDeviceId: fromDeviceId,
    fromUsername: fromUsername,
    type: type,
  );

  /// Envoie un signal WebRTC (offer / answer / candidate / bye).
  Future<void> signal({
    String? toDeviceId,
    String? toUserId,
    required String fromDeviceId,
    required String type,
    required Map<String, dynamic> payload,
    String? callId,
  }) => calls.signal(
    toDeviceId: toDeviceId,
    toUserId: toUserId,
    fromDeviceId: fromDeviceId,
    type: type,
    payload: payload,
    callId: callId,
  );

  /// Recherche d'utilisateurs (`GET /api/v1/users/search`).
  Future<List<Map<String, dynamic>>> searchUsers(String query) =>
      users.searchUsers(query);

  /// Récupère l'offre SDP différée stockée par le serveur pour un appel.
  Future<Map<String, dynamic>?> fetchDeferredOffer({
    required String callId,
    required String deviceId,
  }) => calls.fetchDeferredOffer(callId: callId, deviceId: deviceId);

  /// Sonde de santé de l'API Laravel (`GET /up`).
  Future<bool> healthCheck() => config.healthCheck();

  /// Profil de l'utilisateur connecté (`GET /api/v1/users/me`).
  Future<Map<String, dynamic>> getMe() => users.getMe();

  /// Liste des contacts enregistrés (`GET /api/v1/contacts`).
  Future<Map<String, dynamic>> fetchContacts() => contacts.fetchContacts();

  /// Enregistre un contact (`POST /api/v1/contacts`).
  Future<Map<String, dynamic>> addContact(int contactUserId) =>
      contacts.addContact(contactUserId);

  /// Supprime un contact (`DELETE /api/v1/contacts/{id}`).
  Future<Map<String, dynamic>> removeContact(int contactUserId) =>
      contacts.removeContact(contactUserId);

  /// Liste des appareils enregistrés (`GET /api/v1/devices`).
  Future<Map<String, dynamic>> fetchDevices() => devices.fetchDevices();

  /// Enregistre un appareil (`POST /api/v1/devices/register`).
  Future<Map<String, dynamic>> registerDevice({
    required String label,
    required String deviceId,
    required String platform,
  }) => devices.registerDevice(
    label: label,
    deviceId: deviceId,
    platform: platform,
  );

  /// Supprime un appareil enregistré (`DELETE /api/v1/devices/{id}`).
  Future<Map<String, dynamic>> deleteDevice(String deviceId) =>
      devices.deleteDevice(deviceId);

  /// Solde et informations du portefeuille (démo ou réel).
  Future<Map<String, dynamic>> getWallet() => wallet.getWallet();

  /// Recharge de portefeuille (démo ou réel).
  Future<Map<String, dynamic>> rechargeWallet({
    required int montant,
    String? phoneNumber,
    String? idempotencyKey,
  }) => wallet.rechargeWallet(
    montant: montant,
    phoneNumber: phoneNumber,
    idempotencyKey: idempotencyKey,
  );

  /// Transfert d'argent (démo ou réel).
  Future<Map<String, dynamic>> transferWallet({
    required int montant,
    required String recipient,
    String? idempotencyKey,
  }) => wallet.transferWallet(
    montant: montant,
    recipient: recipient,
    idempotencyKey: idempotencyKey,
  );

  /// Retrait de portefeuille (démo ou réel).
  Future<Map<String, dynamic>> withdrawWallet({
    required int montant,
    String? phoneNumber,
    String? idempotencyKey,
  }) => wallet.withdrawWallet(
    montant: montant,
    phoneNumber: phoneNumber,
    idempotencyKey: idempotencyKey,
  );
}
