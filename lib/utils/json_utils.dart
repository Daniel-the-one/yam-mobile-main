/// Helpers de parsing JSON défensif, partagés par tous les clients API.
///
/// Regroupe les petits utilitaires qui étaient dupliqués dans les anciens
/// clients monolithiques : décodage tolérant, extraction de message d'erreur,
/// conversion de listes.
library;

import 'dart:convert';

/// Décode un corps de réponse en Map, ou null si illisible / non-objet.
Map<String, dynamic>? decodeJsonMap(String body) {
  try {
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}

/// Message d'erreur `message` d'une réponse API (si présent et non vide).
String? messageOf(Map<String, dynamic>? json) {
  if (json == null) return null;
  final message = json['message'];
  if (message is String && message.isNotEmpty) return message;
  return null;
}

/// Message d'erreur prioritaire d'une réponse Laravel : champ `errors`
/// (première valeur), sinon `message`, sinon `error.message`.
///
/// Retourne `dynamic` pour préserver le comportement historique : le champ
/// `message` peut être de n'importe quel type dans une réponse malformée.
dynamic apiErrorMessage(Map<String, dynamic> json) {
  final errors = json['errors'];
  if (errors is Map && errors.isNotEmpty) {
    final first = errors.values.first;
    if (first is List && first.isNotEmpty) return first.first;
    return null;
  }
  return json['message'] ?? json['error']?['message'];
}

/// Convertit une valeur en liste de Maps (parsing défensif des listes API).
///
/// Retourne une liste vide pour toute valeur qui n'est pas une liste de Maps
/// (champ absent, null, type inattendu…).
List<Map<String, dynamic>> listOf(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
}
