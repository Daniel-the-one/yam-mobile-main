import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'runtime_config.dart';

/// Client REST de l'API Yam. Routes : config, ring, signal.
class ApiClient {
  ApiClient(
    this.baseUrlProvider, {
    this._tokenProvider,
    this._demoTokenProvider,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Fournit l'URL courante (modifiable dans les réglages de l'app).
  final String Function() baseUrlProvider;
  final String? Function()? _tokenProvider;

  /// Fournit le jeton de la session de DÉMONSTRATION (famille argent).
  ///
  /// Les endpoints `/api/demo/v1/*` exigent leur propre jeton (`demo_…`),
  /// distinct du jeton Yam réel : le middleware `demo.auth` rejette un jeton
  /// Yam classique (401). Sans ce jeton, les opérations d'argent en mode démo
  /// échoueraient systématiquement.
  final String? Function()? _demoTokenProvider;

  /// Client HTTP utilisé pour les requêtes. Injectable pour les tests
  /// (MockClient de package:http/testing) ; par défaut un vrai client.
  final http.Client _client;

  Uri _uri(String path) {
    final base = baseUrlProvider().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base$path');
  }

  /// Récupère la configuration runtime (Pusher + TURN) depuis le backend.
  /// Retourne null si l'endpoint est injoignable ou illisible (l'app garde
  /// alors ses valeurs par défaut locales).
  Future<RuntimeConfig?> fetchConfig() async {
    try {
      final res = await _client
          .get(_uri('/api/v1/config'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body);
      if (json is! Map<String, dynamic>) return null;
      return RuntimeConfig.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Map<String, String> _headers({bool authenticated = false, bool demo = false}) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = demo ? _demoTokenProvider?.call() : _tokenProvider?.call();
    if (authenticated && token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static dynamic _decodeSafe(http.Response res, String path) {
    try {
      return jsonDecode(res.body);
    } catch (_) {
      if (res.statusCode >= 500) {
        throw Exception('Serveur temporairement indisponible (HTTP ${res.statusCode}).');
      }
      throw Exception('Réponse illisible du serveur (HTTP ${res.statusCode}).');
    }
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    bool authenticated = false,
    bool demo = false,
    Map<String, String>? headers,
  }) async {
    final reqHeaders = _headers(authenticated: authenticated, demo: demo);
    if (headers != null) reqHeaders.addAll(headers);

    final res = await _client
        .get(_uri(path), headers: reqHeaders)
        .timeout(const Duration(seconds: 10));

    final decoded = _decodeSafe(res, path);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final map = decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
      final errors = map['errors'];
      final message = errors is Map && errors.isNotEmpty
          ? (errors.values.first is List && (errors.values.first as List).isNotEmpty
              ? (errors.values.first as List).first
              : null)
          : map['message'] ?? map['error']?['message'];
      throw Exception(message ?? 'API $path → HTTP ${res.statusCode}');
    }
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{'data': decoded};
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    bool authenticated = false,
    bool demo = false,
  }) async {
    final res = await _client
        .post(
          _uri(path),
          headers: _headers(authenticated: authenticated, demo: demo),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    final decoded = _decodeSafe(res, path);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final map = decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
      final errors = map['errors'];
      final message = errors is Map && errors.isNotEmpty
          ? (errors.values.first is List && (errors.values.first as List).isNotEmpty
              ? (errors.values.first as List).first
              : null)
          : map['message'] ?? map['error']?['message'];
      throw Exception(message ?? 'API $path → HTTP ${res.statusCode}');
    }
    return decoded as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login({
    required String phoneNumber,
    required String password,
    required String deviceId,
    required String platform,
    String? label,
  }) => _post('/api/v1/auth/login', {
        'phone_number': phoneNumber,
        'password': password,
        'device_id': deviceId,
        'platform': platform,
        if (label != null && label.isNotEmpty) 'label': label,
      });

  Future<Map<String, dynamic>> register({
    required String name,
    required String phoneNumber,
    required String password,
    required String deviceId,
    required String platform,
    String? username,
  }) => _post('/api/v1/auth/register', {
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
  }) =>
      _post(ApiConfig.demoAuthLogin, {
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
  }) =>
      _post(ApiConfig.demoAuthRegister, {
        'name': name,
        'phone_number': phoneNumber,
        'password': password,
        if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
      });

  Future<void> logout() async {
    await _post('/api/v1/auth/logout', const {}, authenticated: true);
  }

  /// Fait sonner l'appareil cible. Retourne le call_id si fourni.
  ///
  /// [type] : `'audio'` (défaut) ou `'video'` — détermine le type d'appel.
  Future<String?> ring({
    required String toUserId,
    required String fromDeviceId,
    required String fromUsername,
    String type = 'audio',
  }) async {
    final targetId = int.tryParse(toUserId.trim());
    if (targetId == null) {
      throw Exception('to_user_id doit être un entier (reçu : "$toUserId")');
    }
    final data = await _post('/api/v1/call/ring', {
      'to_user_id': targetId,
      'from_device_id': fromDeviceId,
      'from_username': fromUsername,
      'type': type,
    }, authenticated: true);
    return (data['data'] as Map?)?['call_id'] as String? ?? data['call_id'] as String?;
  }

  /// Envoie un signal WebRTC (offer / answer / candidate / bye).
  ///
  /// [callId] : identifiant de l'appel, requis pour le stockage différé de
  /// l'offre côté serveur (type=offer) et l'invalidation au raccrochage
  /// (type=bye).
  ///
  /// Pour le type `bye`, effectue jusqu'à 3 tentatives avec backoff (500ms × tentative)
  /// pour garantir la livraison même si le serveur est temporairement injoignable.
  Future<void> signal({
    String? toDeviceId,
    String? toUserId,
    required String fromDeviceId,
    required String type,
    required Map<String, dynamic> payload,
    String? callId,
  }) async {
    if ((toDeviceId == null || toDeviceId.isEmpty) &&
        (toUserId == null || toUserId.isEmpty)) {
      return;
    }

    // Retry pour les signaux 'bye' (aligné sur le client web : 3 tentatives max)
    final isBye = type == 'bye';
    int attempt = 0;
    const maxAttempts = 3;
    const retryDelay = Duration(milliseconds: 500);

    while (true) {
      try {
        final toUserIdInt = toUserId != null && toUserId.isNotEmpty
            ? int.tryParse(toUserId)
            : null;
        // Si toUserId est fourni mais non parseable en int, on lève une erreur explicite
        // plutôt que d'envoyer une chaîne que le backend rejettera.
        if (toUserId != null && toUserId.isNotEmpty && toUserIdInt == null) {
          throw Exception('to_user_id doit être un entier (reçu : "$toUserId")');
        }
        await _post('/api/v1/call/signal', {
          if (toDeviceId != null && toDeviceId.isNotEmpty) 'to_device_id': toDeviceId,
          // ignore: use_null_aware_elements
          if (toUserIdInt != null) 'to_user_id': toUserIdInt,
          'from_device_id': fromDeviceId,
          'type': type,
          'payload': payload,
          if (callId != null && callId.isNotEmpty) 'call_id': callId,
        }, authenticated: true);
        return; // Succès
      } catch (e) {
        if (!isBye || attempt >= maxAttempts - 1) {
          // Pas de retry pour les non-bye, ou dernière tentative échouée
          rethrow;
        }
        attempt++;
        debugPrint('[YAM][API] signal(bye) tentative $attempt échouée, retry dans ${retryDelay.inMilliseconds}ms : $e');
        await Future.delayed(retryDelay * attempt); // backoff: 500ms, 1000ms, 1500ms
      }
    }
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final res = await _client.get(
      _uri('/api/v1/users/search?q=${Uri.encodeQueryComponent(query)}&limit=8'),
      headers: _headers(authenticated: true),
    ).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return [];
    final json = jsonDecode(res.body);
    final data = json is Map ? (json['data'] ?? json['users']) : null;
    if (data is! List) return [];
    return data.whereType<Map>().map((u) => u.cast<String, dynamic>()).toList();
  }

  /// Récupère l'offre SDP différée stockée par le serveur pour un appel.
  ///
  /// Retourne le payload de l'offre (`{sdp, type}`) ou null si l'offre est
  /// introuvable, expirée ou interdite (l'appelant a raccroché, timeout...).
  Future<Map<String, dynamic>?> fetchDeferredOffer({
    required String callId,
    required String deviceId,
  }) async {
    try {
      final uri = _uri(
          '/api/v1/call/${Uri.encodeComponent(callId)}/offer'
          '?device_id=${Uri.encodeComponent(deviceId)}');
      final res = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body);
      if (json is! Map<String, dynamic>) return null;
      return (json['payload'] as Map?)?.cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _delete(
    String path, {
    bool authenticated = false,
    bool demo = false,
  }) async {
    final res = await _client
        .delete(_uri(path),
            headers: _headers(authenticated: authenticated, demo: demo))
        .timeout(const Duration(seconds: 10));

    final decoded = jsonDecode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final map = decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
      final message = map['message'] ?? map['error']?['message'];
      throw Exception(message ?? 'API $path → HTTP ${res.statusCode}');
    }
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{'ok': true};
  }

  /// Sonde de santé de l'API Laravel (`GET /up`).
  Future<bool> healthCheck() async {
    try {
      final res = await _client
          .get(_uri(ApiConfig.healthCheck))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Récupère le profil de l'utilisateur connecté (`GET /api/v1/users/me`).
  Future<Map<String, dynamic>> getMe() =>
      _get(ApiConfig.usersMe, authenticated: true);

  /// Récupère la liste des contacts enregistrés (`GET /api/v1/contacts`).
  Future<Map<String, dynamic>> fetchContacts() =>
      _get(ApiConfig.contacts, authenticated: true);

  /// Enregistre un contact (`POST /api/v1/contacts`).
  ///
  /// [contactUserId] est l'identifiant ENTIER de l'utilisateur cible
  /// (`users.id`) — le backend le valide (`exists:users,id`).
  Future<Map<String, dynamic>> addContact(int contactUserId) => _post(
        ApiConfig.contacts,
        {'contact_user_id': contactUserId},
        authenticated: true,
      );

  /// Supprime un contact (`DELETE /api/v1/contacts/{contactUserId}`).
  Future<Map<String, dynamic>> removeContact(int contactUserId) =>
      _delete('${ApiConfig.contacts}/$contactUserId', authenticated: true);

  /// Récupère la liste des appareils enregistrés (`GET /api/v1/devices`).
  Future<Map<String, dynamic>> fetchDevices() =>
      _get(ApiConfig.devices, authenticated: true);

  /// Enregistre un appareil auprès du serveur (`POST /api/v1/devices/register`).
  Future<Map<String, dynamic>> registerDevice({
    required String label,
    required String deviceId,
    required String platform,
  }) =>
      _post(
        ApiConfig.deviceRegister,
        {
          'label': label,
          'device_id': deviceId,
          'platform': platform,
        },
        authenticated: true,
      );

  /// Supprime un appareil enregistré (`DELETE /api/v1/devices/{deviceId}`).
  Future<Map<String, dynamic>> deleteDevice(String deviceId) =>
      _delete(ApiConfig.deviceDelete(deviceId), authenticated: true);

  /// Récupère les informations du portefeuille (`GET /api/demo/v1/wallet` ou `/api/v1/wallet`).
  Future<Map<String, dynamic>> getWallet() =>
      _get(ApiConfig.wallet, authenticated: true, demo: ApiConfig.moneyDemo);

  /// Effectue une recharge de portefeuille (`POST /api/demo/v1/wallet/recharge` ou `/api/v1/wallet/recharge`).
  /// Si un [idempotencyKey] est fourni, il est transmis via l'en-tête `Idempotency-Key`.
  Future<Map<String, dynamic>> rechargeWallet({
    required int montant,
    String? phoneNumber,
    String? idempotencyKey,
  }) async {
    final headers =
        _headers(authenticated: true, demo: ApiConfig.moneyDemo);
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    final res = await _client
        .post(
          _uri(ApiConfig.walletRecharge),
          headers: headers,
          body: jsonEncode({
            'montant': montant,
            if (phoneNumber != null && phoneNumber.isNotEmpty)
              'phone_number': phoneNumber,
          }),
        )
        .timeout(const Duration(seconds: 10));

    final decoded = jsonDecode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final map = decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
      final message = map['message'] ?? map['error']?['message'];
      throw Exception(
          message ?? 'API ${ApiConfig.walletRecharge} → HTTP ${res.statusCode}');
    }
    return decoded as Map<String, dynamic>;
  }

  /// Effectue un transfert d'argent vers un autre utilisateur (`POST /api/demo/v1/wallet/transfert` ou `/api/v1/wallet/transfert`).
  Future<Map<String, dynamic>> transferWallet({
    required int montant,
    required String recipient,
    String? idempotencyKey,
  }) async {
    final headers =
        _headers(authenticated: true, demo: ApiConfig.moneyDemo);
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    final res = await _client
        .post(
          _uri(ApiConfig.walletTransfer),
          headers: headers,
          body: jsonEncode({
            'montant': montant,
            'recipient': recipient,
          }),
        )
        .timeout(const Duration(seconds: 10));

    final decoded = _decodeSafe(res, ApiConfig.walletTransfer);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final map = decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
      final message = map['message'] ?? map['error']?['message'];
      throw Exception(
          message ?? 'API ${ApiConfig.walletTransfer} → HTTP ${res.statusCode}');
    }
    return decoded as Map<String, dynamic>;
  }

  /// Effectue un retrait de portefeuille (`POST /api/demo/v1/wallet/withdraw` ou `/api/v1/wallet/withdraw`).
  Future<Map<String, dynamic>> withdrawWallet({
    required int montant,
    String? phoneNumber,
    String? idempotencyKey,
  }) async {
    final headers =
        _headers(authenticated: true, demo: ApiConfig.moneyDemo);
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    final res = await _client
        .post(
          _uri(ApiConfig.walletWithdraw),
          headers: headers,
          body: jsonEncode({
            'montant': montant,
            if (phoneNumber != null && phoneNumber.isNotEmpty)
              'phone_number': phoneNumber,
          }),
        )
        .timeout(const Duration(seconds: 10));

    final decoded = _decodeSafe(res, ApiConfig.walletWithdraw);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final map = decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
      final message = map['message'] ?? map['error']?['message'];
      throw Exception(
          message ?? 'API ${ApiConfig.walletWithdraw} → HTTP ${res.statusCode}');
    }
    return decoded as Map<String, dynamic>;
  }
}
