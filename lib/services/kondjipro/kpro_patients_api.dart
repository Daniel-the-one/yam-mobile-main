import '../../config/api_config.dart';
import '../../utils/json_utils.dart';
import 'kpro_http.dart';

/// Endpoints des patients KondjiPro (`/api/patients.php`).
class KproPatientsApi {
  KproPatientsApi(this._http);

  final KproHttpClient _http;

  /// Recherche de patients (`?q=`) — vide = les 20 premiers.
  Future<List<Map<String, dynamic>>> searchPatients(String query) async {
    final q = query.trim();
    final res = await _http.get(
      '${ApiConfig.patients}${q.isEmpty ? '' : '?q=${Uri.encodeQueryComponent(q)}'}',
    );
    return listOf(res['results']);
  }

  /// Résout l'identifiant numérique d'un patient.
  ///
  /// 1. `knownId` fourni (depuis le dossier médical) → conversion directe ;
  /// 2. sinon recherche par téléphone (`?q=` sur les 8 derniers chiffres) avec
  ///    appariement EXACT des chiffres du numéro — jamais de correspondance
  ///    approximative, pour ne pas facturer/prescrire au mauvais patient ;
  /// 3. `null` si aucun patient ne correspond exactement.
  Future<int?> resolvePatientId({String? phone, String? knownId}) async {
    if (knownId != null && knownId.isNotEmpty) {
      final id = int.tryParse(knownId);
      if (id != null) return id;
    }
    final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8) return null;
    final tail = digits.substring(digits.length - 8);

    final rows = await searchPatients(tail);
    for (final row in rows) {
      final rowDigits = (row['telephone'] ?? '').toString().replaceAll(
        RegExp(r'\D'),
        '',
      );
      if (rowDigits.endsWith(tail)) {
        final id = int.tryParse('${row['id']}');
        if (id != null) return id;
      }
    }
    return null;
  }

  /// Détail patient + historique (`?id=`).
  Future<(Map<String, dynamic>?, List<Map<String, dynamic>>)> patientDetail(
    String id,
  ) async {
    final res = await _http.get(
      '${ApiConfig.patients}?id=${Uri.encodeQueryComponent(id)}',
    );
    final patient = res['patient'];
    return (
      patient is Map ? patient.cast<String, dynamic>() : null,
      listOf(res['historique']),
    );
  }
}
