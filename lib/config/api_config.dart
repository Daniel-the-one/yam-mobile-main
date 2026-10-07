/// Registre central des endpoints KondjiPro / Yam.
///
/// ─── LE SEUL FICHIER À MODIFIER POUR BASCULER DU MODE DÉMO AU MODE RÉEL ───
///
/// Chaque famille d'API déclare ses chemins :
///   • `auth` / `calls`  → APIs Yam Laravel **réelles** (déjà câblées dans
///     [ApiClient], listées ici à titre documentaire) ;
///   • `medical`         → APIs PHP KondjiPro **réelles** (partielles : le
///     serveur retombe sur des données de démonstration sans BDD) ;
///   • `money`           → famille **démonstration** tant que [moneyDemo] vaut
///     `true`. Passer [moneyDemo] à `false` suffit à utiliser les endpoints
///     réels déclarés ci-dessous (aucune autre modification nécessaire).
class ApiConfig {
  ApiConfig._();

  // ══════════════════ BASCULE ARGENT ══════════════════
  // true  → l'argent (encaissement, solde) passe par les endpoints DÉMO
  //         Laravel (/api/demo/v1/…) : aucune donnée réelle touchée.
  // false → les endpoints RÉELS déclarés plus bas sont utilisés.
  static const bool moneyDemo = true;

  // ══════════════════ PRÉFIXES ══════════════════
  static const String _apiV1Prefix = '/api/v1';
  static const String _demoPrefix = '/api/demo/v1';
  static const String _kproPrefix = '/api'; // PHP legacy KondjiPro

  // ─────────────────────────────────────────────────────────────────────
  // Famille PRÉREQUIS & DIAGNOSTICS (Laravel)
  // ─────────────────────────────────────────────────────────────────────

  /// GET → sonde de santé Laravel.
  static const String healthCheck = '/up';

  // ─────────────────────────────────────────────────────────────────────
  // Famille AUTH DÉMO (Laravel /api/demo/v1) — session dédiée à l'argent
  // ─────────────────────────────────────────────────────────────────────

  /// POST → ouvre une session de démonstration ({phone_number, password}
  /// optionnels ; vide = compte visiteur).
  static const String demoAuthLogin = '$_demoPrefix/auth/login';

  /// POST → crée un compte de démonstration ({name, phone_number, password}).
  static const String demoAuthRegister = '$_demoPrefix/auth/register';

  /// GET → logs d'application (actif si APP_DEBUG=true).
  static const String debugLogs = '$_apiV1Prefix/debug/logs';

  // ─────────────────────────────────────────────────────────────────────
  // Famille USER & CONTACTS & DEVICES (Laravel)
  // ─────────────────────────────────────────────────────────────────────

  /// GET → profil de l'utilisateur connecté.
  static const String usersMe = '$_apiV1Prefix/users/me';

  /// GET → liste des contacts de l'utilisateur.
  static const String contacts = '$_apiV1Prefix/contacts';

  /// GET → liste des appareils de l'utilisateur.
  static const String devices = '$_apiV1Prefix/devices';

  /// POST → enregistrement d'un appareil ({label, device_id, platform}).
  static const String deviceRegister = '$_apiV1Prefix/devices/register';

  /// DELETE {deviceId} → suppression d'un appareil enregistré.
  static String deviceDelete(String deviceId) =>
      '$_apiV1Prefix/devices/${Uri.encodeComponent(deviceId)}';

  // ─────────────────────────────────────────────────────────────────────
  // Famille WALLET / PORTEFEUILLE (Laravel)
  // ─────────────────────────────────────────────────────────────────────

  /// GET → solde et informations du portefeuille (Démo).
  static const String walletDemo = '$_demoPrefix/wallet';

  /// GET → solde et informations du portefeuille (Réel).
  static const String walletReal = '$_apiV1Prefix/wallet';

  /// POST → recharge de portefeuille ({montant, phone_number}) (Démo).
  static const String walletRechargeDemo = '$_demoPrefix/wallet/recharge';

  /// POST → recharge de portefeuille ({montant, phone_number}) (Réel).
  static const String walletRechargeReal = '$_apiV1Prefix/wallet/recharge';

  /// POST → transfert d'argent ({montant, recipient}) (Démo).
  /// NOTE : la route s'écrit `/wallet/transfert` côté API (français).
  static const String walletTransferDemo = '$_demoPrefix/wallet/transfert';

  /// POST → transfert d'argent ({montant, recipient}) (Réel).
  static const String walletTransferReal = '$_apiV1Prefix/wallet/transfert';

  /// POST → retrait d'argent ({montant, phone_number}) (Démo).
  static const String walletWithdrawDemo = '$_demoPrefix/wallet/withdraw';

  /// POST → retrait d'argent ({montant, phone_number}) (Réel).
  static const String walletWithdrawReal = '$_apiV1Prefix/wallet/withdraw';

  /// Endpoint de consultation wallet effectivement utilisé.
  static String get wallet => moneyDemo ? walletDemo : walletReal;

  /// Endpoint de recharge wallet effectivement utilisé.
  static String get walletRecharge =>
      moneyDemo ? walletRechargeDemo : walletRechargeReal;

  /// Endpoint de transfert wallet effectivement utilisé.
  static String get walletTransfer =>
      moneyDemo ? walletTransferDemo : walletTransferReal;

  /// Endpoint de retrait wallet effectivement utilisé.
  static String get walletWithdraw =>
      moneyDemo ? walletWithdrawDemo : walletWithdrawReal;

  // ─────────────────────────────────────────────────────────────────────
  // Famille AUTH + CALLS — APIs Yam Laravel (RÉELLES, déjà en production)
  // Portées par lib/services/api_client.dart, listées pour complétude :
  //   POST /api/v1/auth/login      POST /api/v1/auth/register
  //   POST /api/v1/auth/logout     GET  /api/v1/users/me
  //   GET  /api/v1/config          POST /api/v1/call/ring
  //   POST /api/v1/call/signal     POST /api/v1/call/cancel
  // ─────────────────────────────────────────────────────────────────────

  // ─────────────────────────────────────────────────────────────────────
  // Famille MÉDICALE — PHP KondjiPro (RÉELLES, partielles)
  // Auth : cookie de session `kondjipro_session` + header X-CSRF-Token
  // pour les POST (voir KondjiproClient).
  // ─────────────────────────────────────────────────────────────────────

  /// POST {identifier, password} → cookie de session + `csrf_token`.
  static const String kproLogin = '$_kproPrefix/auth/login.php';

  /// POST → détruit la session.
  static const String kproLogout = '$_kproPrefix/auth/logout.php';

  /// GET ?q=… (recherche) | GET ?id=… (détail + historique).
  static const String patients = '$_kproPrefix/patients.php';

  /// POST patient, motif, diagnostic, notes → historique patient.
  static const String consultationSave = '$_kproPrefix/consultation_save.php';

  /// POST patient, notes, med[i][nom|quantite|unite|frequence].
  static const String ordonnanceSave = '$_kproPrefix/ordonnance_save.php';

  /// POST patient, actes[]=code (catalogue C001…C006).
  static const String factureSave = '$_kproPrefix/facture_save.php';

  /// GET → profil du médecin connecté + solde ; POST → mise à jour profil.
  static const String medecin = '$_kproPrefix/medecin.php';

  // ─────────────────────────────────────────────────────────────────────
  // Famille ARGENT — DÉMO tant que [moneyDemo] est true
  // ─────────────────────────────────────────────────────────────────────

  /// Démo Laravel : réponse statique, aucun paiement réel.
  static const String encaissementDemo =
      '$_demoPrefix/kondjipro/encaissement';

  /// Réel : demande d'encaissement en attente (transactions_encaissement).
  static const String encaissementReal = '$_kproPrefix/encaissement_create.php';

  /// Démo Laravel : solde statique 150 000 F.
  static const String soldeDemo = '$_demoPrefix/kondjipro/solde';

  /// Réel : `GET medecin.php` renvoie déjà le champ `solde`
  /// (le parsing lit `solde` dans les deux cas — forme identique).
  static const String soldeReal = '$_kproPrefix/medecin.php';

  /// Endpoint d'encaissement effectivement utilisé.
  static String get encaissement =>
      moneyDemo ? encaissementDemo : encaissementReal;

  /// Endpoint de solde effectivement utilisé.
  static String get solde => moneyDemo ? soldeDemo : soldeReal;
}
