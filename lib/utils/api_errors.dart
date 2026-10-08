/// Exceptions partagées par tous les clients API.
///
/// Centralisées ici pour être réutilisables par les clients Yam (Laravel) et
/// KondjiPro (PHP) sans dépendance circulaire entre les fichiers de services.
library;

/// Erreur d'API générique avec message orienté utilisateur.
///
/// `toString()` renvoie directement le message (sans préfixe `Exception: `) :
/// les écrans peuvent l'afficher tel quel, sans nettoyage.
class ApiException implements Exception {
  ApiException(this.message);

  final dynamic message;

  @override
  String toString() => message?.toString() ?? '';
}

/// Erreur d'authentification KondjiPro (session absente ou expirée).
class KondjiproAuthException implements Exception {
  KondjiproAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
