import 'dart:convert';

import '../../config/api_config.dart';
import '../../utils/api_errors.dart';
import 'yam_http.dart';

/// Endpoints du portefeuille (wallet) — démo ou réel selon
/// [ApiConfig.moneyDemo] (le seul fichier à modifier pour basculer).
class WalletApi {
  WalletApi(this._http);

  final YamHttpClient _http;

  /// Solde et informations du portefeuille
  /// (`GET /api/demo/v1/wallet` ou `/api/v1/wallet`).
  Future<Map<String, dynamic>> getWallet() => _http.get(
    ApiConfig.wallet,
    authenticated: true,
    demo: ApiConfig.moneyDemo,
  );

  /// Recharge de portefeuille
  /// (`POST /api/demo/v1/wallet/recharge` ou `/api/v1/wallet/recharge`).
  ///
  /// Si un [idempotencyKey] est fourni, il est transmis via l'en-tête
  /// `Idempotency-Key`.
  Future<Map<String, dynamic>> rechargeWallet({
    required int montant,
    String? phoneNumber,
    String? idempotencyKey,
  }) async {
    final headers = _http.buildHeaders(
      authenticated: true,
      demo: ApiConfig.moneyDemo,
    );
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    final res = await _http.postRaw(ApiConfig.walletRecharge, {
      'montant': montant,
      if (phoneNumber != null && phoneNumber.isNotEmpty)
        'phone_number': phoneNumber,
    }, extraHeaders: headers);

    final decoded = jsonDecode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final map = decoded is Map<String, dynamic>
          ? decoded
          : const <String, dynamic>{};
      final message = map['message'] ?? map['error']?['message'];
      throw ApiException(
        message ?? 'API ${ApiConfig.walletRecharge} → HTTP ${res.statusCode}',
      );
    }
    return decoded as Map<String, dynamic>;
  }

  /// Transfert d'argent vers un autre utilisateur
  /// (`POST /api/demo/v1/wallet/transfert` ou `/api/v1/wallet/transfert`).
  Future<Map<String, dynamic>> transferWallet({
    required int montant,
    required String recipient,
    String? idempotencyKey,
  }) async {
    final headers = _http.buildHeaders(
      authenticated: true,
      demo: ApiConfig.moneyDemo,
    );
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    final res = await _http.postRaw(ApiConfig.walletTransfer, {
      'montant': montant,
      'recipient': recipient,
    }, extraHeaders: headers);

    final decoded = YamHttpClient.decodeSafe(res, ApiConfig.walletTransfer);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final map = decoded is Map<String, dynamic>
          ? decoded
          : const <String, dynamic>{};
      final message = map['message'] ?? map['error']?['message'];
      throw ApiException(
        message ?? 'API ${ApiConfig.walletTransfer} → HTTP ${res.statusCode}',
      );
    }
    return decoded as Map<String, dynamic>;
  }

  /// Retrait de portefeuille
  /// (`POST /api/demo/v1/wallet/withdraw` ou `/api/v1/wallet/withdraw`).
  Future<Map<String, dynamic>> withdrawWallet({
    required int montant,
    String? phoneNumber,
    String? idempotencyKey,
  }) async {
    final headers = _http.buildHeaders(
      authenticated: true,
      demo: ApiConfig.moneyDemo,
    );
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    final res = await _http.postRaw(ApiConfig.walletWithdraw, {
      'montant': montant,
      if (phoneNumber != null && phoneNumber.isNotEmpty)
        'phone_number': phoneNumber,
    }, extraHeaders: headers);

    final decoded = YamHttpClient.decodeSafe(res, ApiConfig.walletWithdraw);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final map = decoded is Map<String, dynamic>
          ? decoded
          : const <String, dynamic>{};
      final message = map['message'] ?? map['error']?['message'];
      throw ApiException(
        message ?? 'API ${ApiConfig.walletWithdraw} → HTTP ${res.statusCode}',
      );
    }
    return decoded as Map<String, dynamic>;
  }
}
