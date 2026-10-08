import '../../config/api_config.dart';
import '../../utils/json_utils.dart';
import 'kpro_http.dart';

/// Endpoints médicaux KondjiPro (consultations, ordonnances, factures,
/// profil médecin) — famille réelle, cookie de session PHP.
class KproMedicalApi {
  KproMedicalApi(this._http);

  final KproHttpClient _http;

  /// Enregistre une consultation (`POST /api/consultation_save.php`).
  Future<void> saveConsultation({
    required int patientId,
    required String motif,
    String diagnostic = '',
    String notes = '',
  }) => _http
      .postForm(ApiConfig.consultationSave, {
        'patient': '$patientId',
        'motif': motif,
        'diagnostic': diagnostic,
        'notes': notes,
      })
      .then((_) {});

  /// Enregistre une ordonnance (`POST /api/ordonnance_save.php`).
  Future<void> saveOrdonnance({
    required int patientId,
    required String notes,
    required List<Map<String, String>> meds,
  }) => _http
      .postForm(ApiConfig.ordonnanceSave, {
        'patient': '$patientId',
        'notes': notes,
        for (var i = 0; i < meds.length; i++) ...{
          'med[$i][nom]': meds[i]['nom'] ?? '',
          'med[$i][quantite]': meds[i]['quantite'] ?? '1',
          'med[$i][unite]': meds[i]['unite'] ?? '',
          'med[$i][frequence]': meds[i]['frequence'] ?? '',
        },
      })
      .then((_) {});

  /// Enregistre une facture à partir des codes d'actes (C001…C006).
  ///
  /// `actes[]` est une clé répétée (`actes[]=C001&actes[]=C002`) : le corps
  /// est construit à la main car une Map ne peut pas porter de clés doublons.
  Future<void> saveFacture({
    required int patientId,
    required List<String> codes,
  }) => _http
      .postFormRaw(
        ApiConfig.factureSave,
        'patient=${Uri.encodeQueryComponent('$patientId')}'
        '&${codes.map((c) => 'actes[]=${Uri.encodeQueryComponent(c)}').join('&')}',
      )
      .then((_) {});

  /// Profil du médecin connecté (`GET /api/medecin.php`).
  Future<Map<String, dynamic>> medecinProfil() => _http.get(ApiConfig.medecin);

  /// Liste des factures (`GET /api/factures.php`).
  Future<List<Map<String, dynamic>>> factures() async {
    final res = await _http.get(ApiConfig.factures);
    return listOf(res['factures']);
  }

  /// Liste des ordonnances (`GET /api/ordonnances.php`).
  Future<List<Map<String, dynamic>>> ordonnances() async {
    final res = await _http.get(ApiConfig.ordonnances);
    return listOf(res['ordonnances']);
  }
}
