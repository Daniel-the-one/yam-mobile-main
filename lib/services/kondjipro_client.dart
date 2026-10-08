import 'package:http/http.dart' as http;

import 'kondjipro/kpro_http.dart';
import 'kondjipro/kpro_medical_api.dart';
import 'kondjipro/kpro_money_api.dart';
import 'kondjipro/kpro_patients_api.dart';
import 'storage_service.dart';

/// Erreur d'authentification KondjiPro (session absente ou expirée).
///
/// Ré-exportée depuis `utils/api_errors.dart` pour préserver l'import
/// historique `package:yam_mobile/services/kondjipro_client.dart`.
export '../utils/api_errors.dart' show KondjiproAuthException;

/// Façade des APIs médicales KondjiPro.
///
/// L'interface publique est inchangée pour les écrans et les tests, mais le
/// socle HTTP (session cookie + CSRF, re-login silencieux) vit désormais dans
/// `kondjipro/kpro_http.dart` et chaque famille métier dans son fichier dédié :
/// `kpro_patients_api.dart`, `kpro_medical_api.dart`, `kpro_money_api.dart`.
class KondjiproClient {
  KondjiproClient({
    required this.baseUrlProvider,
    required this.storage,
    this.demoTokenProvider,
    http.Client? httpClient,
  }) : _http = KproHttpClient(
         baseUrlProvider: baseUrlProvider,
         storage: storage,
         demoTokenProvider: demoTokenProvider,
         httpClient: httpClient,
       );

  /// Fournit l'URL courante du serveur (partagée avec Yam).
  final String Function() baseUrlProvider;
  final StorageService storage;

  /// Fournit le jeton de session de DÉMONSTRATION (famille argent).
  ///
  /// Les endpoints `/api/demo/v1/*` (encaissement, solde) exigent leur propre
  /// jeton `demo_…` en `Authorization: Bearer`, PAS le cookie PHP KondjiPro.
  final String? Function()? demoTokenProvider;

  /// Socle HTTP partagé (session, envoi, erreurs).
  final KproHttpClient _http;

  // ── Familles exposées ──────────────────────────────────────────────
  late final KproPatientsApi patients = KproPatientsApi(_http);
  late final KproMedicalApi medical = KproMedicalApi(_http);
  late final KproMoneyApi money = KproMoneyApi(_http);

  /// Vrai si un cookie de session est disponible (potentiellement expiré).
  bool get hasSession => _http.hasSession;

  /// Restaure la session persistée (cookie + CSRF) au démarrage de l'app.
  Future<void> restore() => _http.restore();

  /// Connecte la session KondjiPro (famille médicale).
  Future<void> login({required String identifier, required String password}) =>
      _http.login(identifier: identifier, password: password);

  /// Détruit la session côté serveur puis purge tout localement.
  Future<void> logout() => _http.logout();

  // ── Délégations HTTP brutes (utilisées par les tests) ──────────────

  Future<Map<String, dynamic>> get(String path) => _http.get(path);

  /// POST au format `application/x-www-form-urlencoded` (PHP lit `$_POST`).
  Future<Map<String, dynamic>> postForm(
    String path,
    Map<String, String> fields,
  ) => _http.postForm(path, fields);

  /// POST urlencodé à partir d'une chaîne déjà encodée — nécessaire pour les
  /// clés répétées du type `actes[]` qu'une Map ne peut pas exprimer.
  Future<Map<String, dynamic>> postFormRaw(String path, String body) =>
      _http.postFormRaw(path, body);

  // ── Délégations métier (interface historique inchangée) ────────────

  /// Recherche de patients (`?q=`) — vide = les 20 premiers.
  Future<List<Map<String, dynamic>>> searchPatients(String query) =>
      patients.searchPatients(query);

  /// Résout l'identifiant numérique d'un patient (appariement exact).
  Future<int?> resolvePatientId({String? phone, String? knownId}) =>
      patients.resolvePatientId(phone: phone, knownId: knownId);

  /// Détail patient + historique (`?id=`).
  Future<(Map<String, dynamic>?, List<Map<String, dynamic>>)> patientDetail(
    String id,
  ) => patients.patientDetail(id);

  /// Enregistre une consultation (famille médicale — réelle).
  Future<void> saveConsultation({
    required int patientId,
    required String motif,
    String diagnostic = '',
    String notes = '',
  }) => medical.saveConsultation(
    patientId: patientId,
    motif: motif,
    diagnostic: diagnostic,
    notes: notes,
  );

  /// Enregistre une ordonnance (famille médicale — réelle).
  Future<void> saveOrdonnance({
    required int patientId,
    required String notes,
    required List<Map<String, String>> meds,
  }) => medical.saveOrdonnance(patientId: patientId, notes: notes, meds: meds);

  /// Enregistre une facture à partir des codes d'actes (C001…C006).
  Future<void> saveFacture({
    required int patientId,
    required List<String> codes,
  }) => medical.saveFacture(patientId: patientId, codes: codes);

  /// Profil du médecin connecté (famille médicale — réelle).
  Future<Map<String, dynamic>> medecinProfil() => medical.medecinProfil();

  /// Liste des factures (`GET /api/factures.php`).
  Future<List<Map<String, dynamic>>> factures() => medical.factures();

  /// Liste des ordonnances (`GET /api/ordonnances.php`).
  Future<List<Map<String, dynamic>>> ordonnances() => medical.ordonnances();

  /// Solde KondjiPay — route ARGENT (démo si [ApiConfig.moneyDemo]).
  Future<int> solde() => money.solde();

  /// Demande d'encaissement — route ARGENT (démo si [ApiConfig.moneyDemo]).
  Future<Map<String, dynamic>> encaisser({
    required int patientId,
    required int montant,
    String motif = '',
  }) => money.encaisser(patientId: patientId, montant: montant, motif: motif);
}
