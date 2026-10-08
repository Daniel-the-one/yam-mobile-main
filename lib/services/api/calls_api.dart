import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../utils/api_errors.dart';
import 'yam_http.dart';

/// Endpoints des appels (`/api/v1/call/*`).
class CallsApi {
  CallsApi(this._http);

  final YamHttpClient _http;

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
      throw ApiException('to_user_id doit être un entier (reçu : "$toUserId")');
    }
    final data = await _http.post('/api/v1/call/ring', {
      'to_user_id': targetId,
      'from_device_id': fromDeviceId,
      'from_username': fromUsername,
      'type': type,
    }, authenticated: true);
    return (data['data'] as Map?)?['call_id'] as String? ??
        data['call_id'] as String?;
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

    // Validation déterministe : hors de la boucle de retry — inutile de
    // retenter une entrée invalide (un 'bye' avec un id malformé ne doit
    // pas déclencher 3 tentatives).
    final toUserIdInt = toUserId != null && toUserId.isNotEmpty
        ? int.tryParse(toUserId)
        : null;
    if (toUserId != null && toUserId.isNotEmpty && toUserIdInt == null) {
      throw ApiException('to_user_id doit être un entier (reçu : "$toUserId")');
    }

    // Retry pour les signaux 'bye' (aligné sur le client web : 3 tentatives max)
    final isBye = type == 'bye';
    int attempt = 0;
    const maxAttempts = 3;
    const retryDelay = Duration(milliseconds: 500);

    while (true) {
      try {
        await _http.post('/api/v1/call/signal', {
          if (toDeviceId != null && toDeviceId.isNotEmpty)
            'to_device_id': toDeviceId,
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
        debugPrint(
          '[YAM][API] signal(bye) tentative $attempt échouée, retry dans ${retryDelay.inMilliseconds}ms : $e',
        );
        await Future.delayed(
          retryDelay * attempt,
        ); // backoff: 500ms, 1000ms, 1500ms
      }
    }
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
      final res = await _http.rawGet(
        '/api/v1/call/${Uri.encodeComponent(callId)}/offer'
        '?device_id=${Uri.encodeComponent(deviceId)}',
        timeout: const Duration(seconds: 8),
      );
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body);
      if (json is! Map<String, dynamic>) return null;
      return (json['payload'] as Map?)?.cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }
}
