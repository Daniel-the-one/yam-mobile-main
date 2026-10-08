import 'dart:convert';

import 'package:flutter/foundation.dart';

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
  /// En mode démo, la recharge crée une transaction EN ATTENTE : le solde
  /// n'est crédité que par `/wallet/recharge/notify` (webhook Mobile Money
  /// simulé). Pour que le crédit arrive immédiatement, ce client enchaîne
  /// automatiquement la confirmation (`code=200`) — l'utilisateur n'a rien
  /// à faire dans Postman. En mode réel, le webhook est externe : aucune
  /// confirmation n'est envoyée ici.
  ///
  /// Si un [idempotencyKey] est fourni, il est transmis via l'en-tête
  /// `Idempotency-Key`.
  Future<Map<String, dynamic>> rechargeWallet({
    required int montant,
    String? phoneNumber,
    String? idempotencyKey,
  }) async {
    final idemHeaders = idempotencyKey != null && idempotencyKey.isNotEmpty
        ? {'Idempotency-Key': idempotencyKey}
        : null;
    final res = await _http.postRaw(
      ApiConfig.walletRecharge,
      {
        'montant': montant,
        if (phoneNumber != null && phoneNumber.isNotEmpty)
          'phone_number': phoneNumber,
      },
      authenticated: true,
      demo: ApiConfig.moneyDemo,
      extraHeaders: idemHeaders,
    );

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
    final rechargeResponse = decoded as Map<String, dynamic>;

    // Démo : confirmation automatique (webhook Mobile Money simulé).
    final notifyPath = ApiConfig.walletRechargeNotify;
    if (notifyPath.isNotEmpty) {
      final reference = _rechargeReference(rechargeResponse);
      if (reference != null && reference.isNotEmpty) {
        try {
          final notifyRes = await _http.postRaw(
            notifyPath,
            {'transaction_id': reference, 'code': 200},
            authenticated: true,
            demo: true,
          );
          final notifyDecoded = jsonDecode(notifyRes.body);
          if (notifyRes.statusCode >= 200 && notifyRes.statusCode < 300) {
            return notifyDecoded is Map<String, dynamic>
                ? notifyDecoded
                : rechargeResponse;
          }
          debugPrint(
            '[YAM][WALLET] confirmation recharge refusée '
            '(HTTP ${notifyRes.statusCode}) : $notifyDecoded',
          );
        } catch (e) {
          // La recharge reste en attente côté serveur ; on ne fait pas
          // échouer l'opération pour un échec de confirmation.
          debugPrint('[YAM][WALLET] confirmation recharge impossible : $e');
        }
      }
    }

    return rechargeResponse;
  }

  /// Extrait la référence de transaction d'une réponse de recharge.
  /// Format démo : `information.reference` ; fallback : `reference` direct.
  static String? _rechargeReference(Map<String, dynamic> response) {
    final info = response['information'];
    if (info is Map<String, dynamic>) {
      final ref = info['reference']?.toString();
      if (ref != null && ref.isNotEmpty) return ref;
    }
    final direct = response['reference']?.toString();
    return (direct != null && direct.isNotEmpty) ? direct : null;
  }

  /// Transfert d'argent vers un autre utilisateur
  /// (`POST /api/demo/v1/wallet/transfert` ou `/api/v1/wallet/transfert`).
  Future<Map<String, dynamic>> transferWallet({
    required int montant,
    required String recipient,
    String? idempotencyKey,
  }) async {
    final idemHeaders = idempotencyKey != null && idempotencyKey.isNotEmpty
        ? {'Idempotency-Key': idempotencyKey}
        : null;
    final res = await _http.postRaw(
      ApiConfig.walletTransfer,
      {'montant': montant, 'recipient': recipient},
      authenticated: true,
      demo: ApiConfig.moneyDemo,
      extraHeaders: idemHeaders,
    );

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
    final idemHeaders = idempotencyKey != null && idempotencyKey.isNotEmpty
        ? {'Idempotency-Key': idempotencyKey}
        : null;
    final res = await _http.postRaw(
      ApiConfig.walletWithdraw,
      {
        'montant': montant,
        if (phoneNumber != null && phoneNumber.isNotEmpty)
          'phone_number': phoneNumber,
      },
      authenticated: true,
      demo: ApiConfig.moneyDemo,
      extraHeaders: idemHeaders,
    );

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
