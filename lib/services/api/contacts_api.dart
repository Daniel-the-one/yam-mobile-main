import '../../config/api_config.dart';
import 'yam_http.dart';

/// Endpoints des contacts (`/api/v1/contacts`).
class ContactsApi {
  ContactsApi(this._http);

  final YamHttpClient _http;

  /// Liste des contacts enregistrés (`GET /api/v1/contacts`).
  Future<Map<String, dynamic>> fetchContacts() =>
      _http.get(ApiConfig.contacts, authenticated: true);

  /// Enregistre un contact (`POST /api/v1/contacts`).
  ///
  /// [contactUserId] est l'identifiant ENTIER de l'utilisateur cible
  /// (`users.id`) — le backend le valide (`exists:users,id`).
  Future<Map<String, dynamic>> addContact(int contactUserId) => _http.post(
    ApiConfig.contacts,
    {'contact_user_id': contactUserId},
    authenticated: true,
  );

  /// Supprime un contact (`DELETE /api/v1/contacts/{contactUserId}`).
  Future<Map<String, dynamic>> removeContact(int contactUserId) =>
      _http.delete('${ApiConfig.contacts}/$contactUserId', authenticated: true);
}
