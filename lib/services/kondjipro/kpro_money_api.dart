import '../../config/api_config.dart';
import 'kpro_http.dart';

/// Endpoints « argent » KondjiPro (solde, encaissement) — démo tant que
/// [ApiConfig.moneyDemo] vaut `true`, réel sinon.
class KproMoneyApi {
  KproMoneyApi(this._http);

  final KproHttpClient _http;

  /// Solde KondjiPay — route ARGENT (démo si [ApiConfig.moneyDemo]).
  /// Réponse {ok, solde} dans les deux modes.
  Future<int> solde() async {
    final res = await _http.get(ApiConfig.solde);
    return int.tryParse('${res['solde'] ?? 0}') ?? 0;
  }

  /// Demande d'encaissement — route ARGENT (démo si [ApiConfig.moneyDemo]).
  /// Retourne la transaction (référence, statut) + `qr_data`.
  Future<Map<String, dynamic>> encaisser({
    required int patientId,
    required int montant,
    String motif = '',
  }) => _http.postForm(ApiConfig.encaissement, {
    'patient_id': '$patientId',
    'montant': '$montant',
    'motif': motif,
  });
}
