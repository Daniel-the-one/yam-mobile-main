import 'package:flutter/material.dart';

import '../models/contact.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Contacts : formulaire d'ajout + liste avec appeler / supprimer.
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key, required this.app});

  final AppState app;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _queryCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    // Synchronise la liste locale avec les contacts enregistrés côté serveur.
    widget.app.fetchContacts();
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$e'),
        backgroundColor: YamColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _addContact(Map<String, dynamic> u) async {
    final rawId = u['id'];
    final userId = int.tryParse(rawId?.toString() ?? '');
    if (userId == null) return;
    try {
      await widget.app.addContact(
        u['name']?.toString() ?? 'Inconnu',
        userId.toString(),
        phoneNumber: u['phone_number']?.toString(),
      );
      if (mounted) setState(() => _results = []);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _removeContact(Contact c) async {
    try {
      await widget.app.removeContact(c);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _search() async {
    final query = _queryCtrl.text.trim();
    if (query.isEmpty) return;
    setState(() => _searching = true);
    try {
      _results = await widget.app.searchUsers(query);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
    if (mounted) {
      FocusScope.of(context).unfocus();
    }
  }

  InputDecoration _deco(String hint, {bool monoStyle = false}) => InputDecoration(
        hintText: hint,
        hintStyle: monoStyle ? mono(size: 14) : null,
        filled: true,
        fillColor: YamColors.surface,
        border: const OutlineInputBorder(
          borderRadius: kFieldRadius,
          borderSide: BorderSide(color: YamColors.border),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: kFieldRadius,
          borderSide: BorderSide(color: YamColors.border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: kFieldRadius,
          borderSide: BorderSide(color: YamColors.primary, width: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _queryCtrl,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: _deco('Téléphone, nom ou nom d’utilisateur'),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: YamColors.primary,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(borderRadius: kFieldRadius),
            ),
            onPressed: _searching ? null : _search,
            icon: const Icon(Icons.search_rounded, size: 18),
            label: Text(
              _searching ? 'Recherche…' : 'Rechercher un utilisateur',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ),
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 16),
          ..._results.map((u) {
            // Le backend exige un identifiant entier pour to_user_id.
            final rawId = u['id'];
            final userId = int.tryParse(rawId?.toString() ?? '');
            final hasValidId = userId != null;
            return _SearchUserTile(
              user: u,
              onAdd: hasValidId
                  ? () => _addContact(u)
                  : null,
              onCall: hasValidId
                  ? () => widget.app.call.startOutgoing(
                        userId.toString(),
                        targetName: u['name']?.toString(),
                      )
                  : null,
            );
          }),
        ],
        const SizedBox(height: 20),
        if (app.contacts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'Aucun contact enregistré',
                style: TextStyle(color: YamColors.muted),
              ),
            ),
          )
        else
          ...app.contacts.map((c) => _ContactTile(
                app,
                c,
                key: ValueKey(c.id),
                onRemove: () => _removeContact(c),
              )),
      ],
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile(this.app, this.contact, {super.key, required this.onRemove});

  final AppState app;
  final Contact contact;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: YamColors.surface,
        borderRadius: kCardRadius,
        border: Border.all(color: YamColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: YamColors.primarySoft,
            child: Text(
              contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: YamColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: YamColors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  contact.phoneNumber ?? 'Utilisateur #${contact.userId}',
                  style: mono(size: 12, color: YamColors.muted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Appeler',
            onPressed: () => app.call.startOutgoing(contact.userId, targetName: contact.name),
            icon: const Icon(Icons.call_rounded, color: YamColors.primary),
          ),
          IconButton(
            tooltip: 'Appel vidéo',
            onPressed: () =>
                app.call.startOutgoing(contact.userId, targetName: contact.name, video: true),
            icon: const Icon(Icons.videocam_rounded, color: YamColors.primary),
          ),
          IconButton(
            tooltip: 'Supprimer',
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded, color: YamColors.muted),
          ),
        ],
      ),
    );
  }
}

class _SearchUserTile extends StatelessWidget {
  const _SearchUserTile({required this.user, required this.onAdd, required this.onCall});

  final Map<String, dynamic> user;
  final VoidCallback? onAdd;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: YamColors.surface,
          borderRadius: kCardRadius,
          border: Border.all(color: YamColors.border),
        ),
        child: ListTile(
          title: Text(
            user['name']?.toString() ?? 'Inconnu',
            style: const TextStyle(fontWeight: FontWeight.w700, color: YamColors.text),
          ),
          subtitle: Text(
            user['phone_number']?.toString() ?? user['username']?.toString() ?? '',
            style: const TextStyle(color: YamColors.muted, fontSize: 13),
          ),
          trailing: Wrap(
            spacing: 4,
            children: [
              IconButton(
                onPressed: onAdd,
                icon: Icon(
                  Icons.person_add_alt_1_rounded,
                  color: onAdd != null ? YamColors.primary : YamColors.muted,
                ),
              ),
              IconButton(
                onPressed: onCall,
                icon: Icon(
                  Icons.call_rounded,
                  color: onCall != null ? YamColors.primary : YamColors.muted,
                ),
              ),
            ],
          ),
        ),
      );
}
