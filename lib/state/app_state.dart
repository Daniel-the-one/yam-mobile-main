import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/contact.dart';
import '../models/missed_call.dart';
import '../config/api_config.dart';
import '../services/api_client.dart';
import '../services/battery_optimization_service.dart';
import '../services/call_service.dart';
import '../services/kondjipro_client.dart';
import '../services/push_service.dart';
import '../services/runtime_config.dart';
import '../services/signaling_service.dart';
import '../services/storage_service.dart';

/// État global de l'application : identité, connexion, contacts, historique.
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  final storage = StorageService();
  late final ApiClient api = ApiClient(
    () => serverUrl,
    tokenProvider: () => authToken,
    demoTokenProvider: () => demoToken,
  );

  /// Client des APIs médicales KondjiPro (cookie de session PHP + CSRF).
  /// Les endpoints sont déclarés dans [ApiConfig] — famille médicale réelle,
  /// famille argent en démo tant que `ApiConfig.moneyDemo` est vrai.
  late final KondjiproClient kpro = KondjiproClient(
    baseUrlProvider: () => serverUrl,
    storage: storage,
    demoTokenProvider: () => demoToken,
  );
  final signaling = SignalingService();
  late final CallService call = CallService(api);
  final push = PushService();
  final batteryOptimization = BatteryOptimizationService();

  String serverUrl = StorageService.defaultServerUrl;
  String deviceId = '';
  String userName = '';
  String userPhone = '';
  String userId = '';
  String authToken = '';
  String demoToken = '';
  ConnStatus status = ConnStatus.disconnected;
  RuntimeConfig? runtimeConfig;
  List<Contact> contacts = [];
  List<CallRecord> calls = [];
  Timer? _autoReconnectTimer;
  bool _isReconnecting = false;

  int get missedCount => calls.where((c) => c.missed).length;
  bool get isAuthenticated => authToken.isNotEmpty && userId.isNotEmpty;

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    unawaited(Permission.notification.request().catchError((_) => PermissionStatus.denied));

    deviceId = await storage.ensureDeviceId();
    userName = await storage.loadUserName();
    userPhone = await storage.loadUserPhone();
    userId = await storage.loadUserId();
    authToken = await storage.loadAuthToken();
    demoToken = await storage.loadDemoToken();
    if (userName.isEmpty) {
      final suffix = deviceId.length > 4 ? deviceId.substring(deviceId.length - 4) : deviceId;
      userName = 'Appareil $suffix';
      await storage.saveUserName(userName);
    }
    serverUrl = await storage.loadServerUrl();
    contacts = await storage.loadContacts();
    calls = await storage.loadCalls();
    // Restaure la session médicale KondjiPro (cookie PHP) éventuellement
    // conservée par une session précédente. Le re-login silencieux reste
    // possible pendant l'usage courant (identifiants en mémoire).
    await kpro.restore();
    call.myDeviceId = deviceId;
    call.myName = userName;

    signaling.onStatus = (s) {
      status = s;
      notifyListeners();
    };
    signaling.onIncomingCall = call.handleIncomingCall;
    signaling.onSignal = call.handleSignal;
    call.onCallEnded = (peerId, peerName, missed) {
      logCall(peerId: peerId, peerName: peerName, missed: missed);
      // Termine l'écran d'appel natif (CallKit) si affiché.
      if (call.currentCallId != null) {
        unawaited(push.endCall(call.currentCallId!));
      }
    };
    call.addListener(notifyListeners);

    if (isAuthenticated) unawaited(_startAuthenticatedSession());
    // Redémarrage de l'app : la session démo persistée peut avoir expiré ou
    // manquer → on en (re)crée une (visiteur si les identifiants ne sont pas
    // disponibles).
    if (isAuthenticated && ApiConfig.moneyDemo && demoToken.isEmpty) {
      unawaited(_ensureDemoSession());
    }

    // Reconnexion automatique périodique si l'appareil est déconnecté
    // (ex: changement de Wi-Fi, bascule 4G, perte temporaire de signal).
    _autoReconnectTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (isAuthenticated && status == ConnStatus.disconnected && !_isReconnecting && call.phase == CallPhase.idle) {
        debugPrint('[YAM][AUTO-RECONNECT] Tentative de reconnexion au serveur...');
        reconnect();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[YAM][LIFECYCLE] App au premier plan → vérification connexion');
      if (isAuthenticated && status == ConnStatus.disconnected && call.phase == CallPhase.idle) {
        reconnect();
      }
    }
  }

  /// Charge la config runtime (Pusher + TURN) depuis le backend et la
  /// partage avec la signalisation et le service d'appel.
  Future<void> refreshRuntimeConfig() async {
    final cfg = await api.fetchConfig();
    if (cfg != null) {
      runtimeConfig = cfg;
      call.config = cfg;
      debugPrint('[YAM][CONFIG] TURN=${cfg.turnUrl.isNotEmpty ? "oui" : "non"} '
          'Pusher=cluster ${cfg.pusherCluster} (clé ${cfg.pusherKey})');
    }
  }

  Future<void> reconnect() async {
    if (!isAuthenticated) return;
    if (_isReconnecting) return;
    _isReconnecting = true;
    status = ConnStatus.connecting;
    notifyListeners();
    try {
      await refreshRuntimeConfig();
      await signaling.connect(
        serverUrl: serverUrl,
        deviceId: deviceId,
        config: runtimeConfig,
      );
    } catch (e) {
      debugPrint('[YAM][RECONNECT] Erreur de reconnexion : $e');
    } finally {
      _isReconnecting = false;
    }
  }

  Future<void> updateServerUrl(String url) async {
    serverUrl = url.trim();
    await storage.saveServerUrl(serverUrl);
    notifyListeners();
    // Ré-enregistre le device FCM auprès du nouveau serveur : sans cela, les
    // appels entrants en arrière-plan/app fermée continueraient de pointer
    // vers l'ancien serveur jusqu'au redémarrage de l'app.
    await push.updateServerUrl(serverUrl);
    await reconnect();
  }

  Future<void> updateUserName(String name) async {
    userName = name.trim();
    if (userName.isEmpty) {
      userName = 'Appareil ${deviceId.length > 4 ? deviceId.substring(deviceId.length - 4) : deviceId}';
    }
    call.myName = userName;
    await storage.saveUserName(userName);
    notifyListeners();
  }

  Future<void> login({
    required String phoneNumber,
    required String password,
  }) async {
    final cleanPhone = phoneNumber.trim();
    final result = await api.login(
      phoneNumber: cleanPhone,
      password: password,
      deviceId: deviceId,
      platform: 'android',
      label: userName,
    );
    await _storeAuthenticatedSession(result, fallbackPhone: cleanPhone);
    // Même identifiant/mot de passe que Yam (table users partagée) :
    // ouvre aussi la session médicale KondjiPro (cookie + CSRF).
    unawaited(_kproLogin(identifier: cleanPhone, password: password));
    // Famille argent : ouvre la session de démonstration dédiée.
    unawaited(_ensureDemoSession(
        phone: cleanPhone, password: password, name: userName));
  }

  Future<void> register({
    required String name,
    required String phoneNumber,
    required String password,
    String? username,
  }) async {
    final cleanName = name.trim();
    final cleanPhone = phoneNumber.trim();
    final result = await api.register(
      name: cleanName,
      phoneNumber: cleanPhone,
      password: password,
      deviceId: deviceId,
      platform: 'android',
      username: username?.trim(),
    );
    await _storeAuthenticatedSession(result,
        fallbackName: cleanName, fallbackPhone: cleanPhone);
    unawaited(_kproLogin(identifier: cleanPhone, password: password));
    unawaited(_ensureDemoSession(
        phone: cleanPhone, password: password, name: cleanName));
  }

  /// Ouvre la session médicale KondjiPro après le login Yam.
  ///
  /// Non bloquant : un échec (API médicale injoignable) n'empêche pas
  /// l'appel ni la navigation — les écrans médicaux afficheront alors
  /// leur message d'erreur au premier usage.
  Future<void> _kproLogin({
    required String identifier,
    required String password,
  }) async {
    try {
      await kpro.login(identifier: identifier, password: password);
    } catch (e) {
      debugPrint('[YAM][KPRO] session médicale non ouverte : $e');
    }
  }

  /// Ouvre la session de DÉMONSTRATION (famille argent) si nécessaire.
  ///
  /// Les endpoints `/api/demo/v1/*` exigent leur propre jeton (`demo_…`),
  /// distinct du jeton Yam : sans lui, recharge/transfert/retrait/encaissement
  /// échoueraient en 401. Stratégie, dans l'ordre :
  ///  1. `register` (nouveau compte démo lié au téléphone) ;
  ///  2. `login` (compte démo déjà créé lors d'une session précédente) ;
  ///  3. session visiteur (corps vide) — dernier recours si les identifiants
  ///     ne sont pas disponibles (redémarrage de l'app).
  /// Non bloquant : un échec n'empêche pas l'appel ni la navigation.
  Future<void> _ensureDemoSession({
    String? phone,
    String? password,
    String? name,
  }) async {
    if (!ApiConfig.moneyDemo) return;
    if (demoToken.isNotEmpty) return;

    final p = phone ?? userPhone;
    final pwd = password ?? '';
    final displayName = name ?? userName;

    // 1. register (nouveau compte démo lié au téléphone).
    try {
      final res = await api.demoRegister(
        name: displayName.isNotEmpty ? displayName : 'Utilisateur mobile',
        phoneNumber: p.isNotEmpty
            ? p
            : 'mobile-${deviceId.substring(deviceId.length > 4 ? deviceId.length - 4 : 0)}',
        password: pwd.isNotEmpty ? pwd : 'yam-demo-2026',
        deviceId: deviceId,
      );
      demoToken = (res['data'] as Map?)?['token']?.toString() ?? '';
    } catch (e) {
      debugPrint('[YAM][DEMO] register démo refusé ($e)');
    }

    // 2. login (compte démo déjà créé lors d'une session précédente).
    if (demoToken.isEmpty) {
      try {
        final res = await api.demoLogin(
          phoneNumber: p.isNotEmpty ? p : null,
          password: pwd.isNotEmpty ? pwd : null,
          deviceId: deviceId,
        );
        demoToken = (res['data'] as Map?)?['token']?.toString() ?? '';
      } catch (e) {
        debugPrint('[YAM][DEMO] login démo refusé ($e)');
      }
    }

    // 3. session visiteur (dernier recours — identifiants indisponibles).
    if (demoToken.isEmpty) {
      try {
        final res = await api.demoLogin(deviceId: deviceId);
        demoToken = (res['data'] as Map?)?['token']?.toString() ?? '';
      } catch (e) {
        debugPrint('[YAM][DEMO] session visiteur impossible : $e');
      }
    }

    if (demoToken.isNotEmpty) {
      await storage.saveDemoToken(demoToken);
      debugPrint('[YAM][DEMO] session de démonstration établie');
    }
  }

  Future<void> logout() async {
    try {
      await api.logout();
    } catch (_) {
      // Le nettoyage local reste nécessaire même si le serveur est injoignable.
    }
    try {
      await kpro.logout();
    } catch (_) {
      // Idem pour la session médicale.
    }
    await signaling.disconnect();
    await storage.clearSession();
    authToken = '';
    userId = '';
    userPhone = '';
    status = ConnStatus.disconnected;
    notifyListeners();
  }

  Future<void> _storeAuthenticatedSession(
    Map<String, dynamic> response, {
    String? fallbackName,
    String? fallbackPhone,
  }) async {
    final data = (response['data'] as Map?)?.cast<String, dynamic>() ?? response;
    final user = (data['user'] as Map?)?.cast<String, dynamic>() ?? const {};
    final token = data['token']?.toString() ?? '';
    final id = user['id']?.toString() ?? '';
    if (token.isEmpty || id.isEmpty) throw Exception('Réponse d’authentification invalide.');
    authToken = token;
    userId = id;
    final nameFromApi = user['name']?.toString() ?? user['username']?.toString() ?? '';
    if (nameFromApi.isNotEmpty) {
      userName = nameFromApi;
    } else if (fallbackName != null && fallbackName.isNotEmpty) {
      userName = fallbackName;
    }

    final phoneFromApi = user['phone_number']?.toString() ?? user['phone']?.toString() ?? '';
    if (phoneFromApi.isNotEmpty) {
      userPhone = phoneFromApi;
    } else if (fallbackPhone != null && fallbackPhone.isNotEmpty) {
      userPhone = fallbackPhone;
    }

    call.myName = userName;
    await storage.saveSession(
      token: token,
      userId: id,
      userName: userName,
      phoneNumber: userPhone,
    );
    await _startAuthenticatedSession();
    notifyListeners();
  }

  Future<void> _startAuthenticatedSession() async {
    unawaited(push.init(
      serverUrl: serverUrl,
      deviceId: deviceId,
      userName: userName,
      authToken: authToken,
      onIncomingCall: call.handleIncomingCall,
      onAcceptCall: call.accept,
    ));
    await refreshRuntimeConfig();
    await reconnect();
    // Les OEM (TECNO/Infinix/Xiaomi) tuent les apps en arrière-plan : sans
    // exemption batterie, les notifications FCM d'appel entrant peuvent être
    // retardées ou bloquées. On demande l'exemption une fois par session.
    unawaited(_requestBatteryExemptionIfNeeded());
  }

  /// Demande l'exemption d'optimisation batterie si l'app n'est pas déjà
  /// exemptée et que l'utilisateur ne l'a pas déjà refusée. Non bloquant :
  /// en cas d'échec, l'utilisateur peut toujours l'activer manuellement.
  Future<void> _requestBatteryExemptionIfNeeded() async {
    try {
      // Ne pas re-proposer si l'utilisateur a déjà fermé/refusé le dialog.
      if (await storage.loadBatteryExemptionDismissed()) return;
      final exempted = await batteryOptimization.isIgnoringBatteryOptimizations();
      if (!exempted) {
        debugPrint('[YAM][BATTERY] App non exemptée → demande d\'exemption');
        await batteryOptimization.requestIgnoreBatteryOptimizations();
        // On considère la demande faite (acceptée ou non) : on ne la
        // re-propose pas à chaque session.
        await storage.saveBatteryExemptionDismissed(true);
      }
    } catch (e) {
      debugPrint('[YAM][BATTERY] Demande d\'exemption impossible : $e');
    }
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (!isAuthenticated || query.trim().isEmpty) return [];
    return api.searchUsers(query.trim());
  }

  // ─────────────────────────── Appareils & Portefeuille ────────────────

  Future<Map<String, dynamic>?> fetchUserProfile() async {
    if (!isAuthenticated) return null;
    return api.getMe();
  }

  Future<Map<String, dynamic>?> fetchDevices() async {
    if (!isAuthenticated) return null;
    return api.fetchDevices();
  }

  Future<Map<String, dynamic>> registerDevice({
    required String label,
    required String deviceId,
    required String platform,
  }) async {
    return api.registerDevice(label: label, deviceId: deviceId, platform: platform);
  }

  Future<Map<String, dynamic>> deleteDevice(String deviceId) async {
    return api.deleteDevice(deviceId);
  }

  Future<Map<String, dynamic>?> fetchWallet() async {
    if (!isAuthenticated) return null;
    await _ensureDemoSession();
    return api.getWallet();
  }

  Future<Map<String, dynamic>> rechargeWallet({
    required int montant,
    String? phoneNumber,
    String? idempotencyKey,
  }) async {
    await _ensureDemoSession();
    return api.rechargeWallet(
      montant: montant,
      phoneNumber: phoneNumber,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<Map<String, dynamic>> transferWallet({
    required int montant,
    required String recipient,
    String? idempotencyKey,
  }) async {
    await _ensureDemoSession();
    return api.transferWallet(
      montant: montant,
      recipient: recipient,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<Map<String, dynamic>> withdrawWallet({
    required int montant,
    String? phoneNumber,
    String? idempotencyKey,
  }) async {
    await _ensureDemoSession();
    return api.withdrawWallet(
      montant: montant,
      phoneNumber: phoneNumber,
      idempotencyKey: idempotencyKey,
    );
  }

  /// Solde KondjiPay — garantit la session démo avant l'appel.
  Future<int> kproSolde() async {
    await _ensureDemoSession();
    return kpro.solde();
  }

  /// Demande d'encaissement — garantit la session démo avant l'appel.
  Future<Map<String, dynamic>> kproEncaisser({
    required int patientId,
    required int montant,
    String motif = '',
  }) async {
    await _ensureDemoSession();
    return kpro.encaisser(patientId: patientId, montant: montant, motif: motif);
  }

  // ─────────────────────────── Contacts ────────────────────────────────

  /// Charge les contacts depuis le serveur (`GET /api/v1/contacts`) et les
  /// fusionne avec la liste locale (dédoublonnage par `userId`, le serveur
  /// fait foi). Silencieux en cas d'échec réseau : la liste locale reste
  /// utilisable hors-ligne.
  Future<void> fetchContacts() async {
    if (!isAuthenticated) return;
    try {
      final res = await api.fetchContacts();
      final list = res['contacts'];
      if (list is! List) return;
      final byUserId = <String, Contact>{
        for (final c in contacts)
          if (c.userId.isNotEmpty) c.userId: c,
      };
      for (final e in list.whereType<Map>()) {
        final m = e.cast<String, dynamic>();
        final uid = '${m['user_id'] ?? ''}';
        if (uid.isEmpty) continue;
        byUserId[uid] = Contact(
          id: 'srv-$uid',
          name: m['name']?.toString() ?? 'Inconnu',
          userId: uid,
          phoneNumber: m['phone_number']?.toString(),
        );
      }
      contacts = byUserId.values.toList();
      await storage.saveContacts(contacts);
      notifyListeners();
    } catch (e) {
      debugPrint('[YAM][CONTACTS] chargement serveur impossible : $e');
    }
  }

  /// Ajoute un contact : d'abord côté serveur (`POST /api/v1/contacts`), puis
  /// localement. Lève une exception si le serveur refuse (contact inexistant,
  /// réseau…) — l'écran affiche alors l'erreur.
  Future<void> addContact(String name, String targetUserId,
      {String? phoneNumber}) async {
    final n = name.trim();
    final id = targetUserId.trim();
    if (n.isEmpty || id.isEmpty) return;
    final userIdInt = int.tryParse(id);
    if (userIdInt == null) {
      throw Exception('Identifiant de contact invalide.');
    }
    await api.addContact(userIdInt);
    contacts.add(Contact(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: n,
      userId: id,
      phoneNumber: phoneNumber,
    ));
    await storage.saveContacts(contacts);
    notifyListeners();
  }

  /// Supprime un contact : d'abord côté serveur (`DELETE /api/v1/contacts/{id}`),
  /// puis localement. Les contacts historiques sans identifiant numérique ne
  /// sont supprimés que localement (le serveur n'a rien à supprimer).
  Future<void> removeContact(Contact c) async {
    final userIdInt = int.tryParse(c.userId);
    if (userIdInt != null) {
      await api.removeContact(userIdInt);
    }
    contacts.removeWhere((x) => x.id == c.id);
    await storage.saveContacts(contacts);
    notifyListeners();
  }

  // ────────────────────────── Historique ───────────────────────────────

  Future<void> logCall({
    required String peerId,
    required String peerName,
    required bool missed,
  }) async {
    calls.insert(
      0,
      CallRecord(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        peerId: peerId,
        peerName: peerName,
        at: DateTime.now(),
        missed: missed,
      ),
    );
    if (calls.length > 50) calls.removeRange(50, calls.length);
    await storage.saveCalls(calls);
    notifyListeners();
  }

  Future<void> removeCall(CallRecord r) async {
    calls.removeWhere((x) => x.id == r.id);
    await storage.saveCalls(calls);
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoReconnectTimer?.cancel();
    super.dispose();
  }
}
