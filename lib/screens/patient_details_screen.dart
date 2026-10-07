import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../services/call_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'facturer_screen.dart';
import 'ordonnance_screen.dart';

enum _MedicalEventType { consultation, ordonnance, facture, analyse }

class _MedicalEvent {
  const _MedicalEvent({
    required this.date,
    required this.type,
    required this.titre,
    required this.praticien,
    required this.details,
    this.badge,
    this.vitals,
  });

  final String date;
  final _MedicalEventType type;
  final String titre;
  final String praticien;
  final String details;
  final String? badge;
  final String? vitals;

  Color get color {
    switch (type) {
      case _MedicalEventType.consultation:
      case _MedicalEventType.ordonnance:
        return YamColors.primary;
      case _MedicalEventType.facture:
      case _MedicalEventType.analyse:
        return YamColors.accent;
    }
  }

  IconData get icon {
    switch (type) {
      case _MedicalEventType.consultation:
        return Icons.medical_services_outlined;
      case _MedicalEventType.ordonnance:
        return Icons.medication_outlined;
      case _MedicalEventType.facture:
        return Icons.receipt_long_outlined;
      case _MedicalEventType.analyse:
        return Icons.biotech_outlined;
    }
  }
}

class PatientDetailsScreen extends StatefulWidget {
  const PatientDetailsScreen({super.key, required this.patient, this.app});

  final Patient patient;
  final AppState? app;

  @override
  State<PatientDetailsScreen> createState() => _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends State<PatientDetailsScreen> {
  int _activeTab = 0;
  String _historyFilter = 'Tous';

  // Historique médical chargé depuis l'API KondjiPro
  // (GET /api/patients.php?id=… → {patient, historique}).
  List<_MedicalEvent> _events = const [];
  bool _loading = true;
  String? _error;

  /// Jeu de secours affiché UNIQUEMENT quand aucun [AppState] n'est fourni
  //  (widget isolé / test) — jamais présenté comme des données réelles.
  static const List<_MedicalEvent> _mockEvents = [
    _MedicalEvent(
      date: '12 sept. 2026',
      type: _MedicalEventType.consultation,
      titre: 'Consultation de médecine générale',
      praticien: 'Dr. Jean Mensah — Médecine générale',
      details:
          'Motif : Syndrome grippal, toux sèche et céphalées depuis 3 jours. Examen clinique ORL congestif.',
      vitals: 'TA: 120/80 mmHg • Temp: 38.4 °C • FC: 76 bpm',
      badge: 'Terminé',
    ),
    _MedicalEvent(
      date: '12 sept. 2026',
      type: _MedicalEventType.ordonnance,
      titre: 'Ordonnance médicale',
      praticien: 'Dr. Jean Mensah',
      details:
          '• Paracétamol 500 mg : 1 cp 3x/jour si douleur ou fièvre\n• Amoxicilline 1g : 1 cp matin et soir (7 jours)\n• Sirop antitussif : 1 c.à.s 3x/jour',
      badge: 'Délivrée',
    ),
    _MedicalEvent(
      date: '12 sept. 2026',
      type: _MedicalEventType.facture,
      titre: 'Facture #FAC-2026-089',
      praticien: 'Clinique Yam Santé',
      details: 'Consultation générale (5 000 F) + Soins infirmiers (2 000 F) • Total : 7 000 FCFA',
      badge: 'Payée',
    ),
    _MedicalEvent(
      date: '28 juin 2026',
      type: _MedicalEventType.analyse,
      titre: 'Bilan biologique complet',
      praticien: 'Laboratoire BioSanté Lomé',
      details: 'NFS, Glycémie à jeun (0.94 g/L), Créatininémie normale, Bilan lipidique équilibré.',
      badge: 'Résultats conformes',
    ),
    _MedicalEvent(
      date: '15 mars 2026',
      type: _MedicalEventType.consultation,
      titre: 'Visite de contrôle annuelle',
      praticien: 'Dr. Jean Mensah',
      details:
          'Bilan de santé régulier sans anomalie. Pression artérielle stable sous règles hygiéno-diététiques.',
      vitals: 'TA: 118/75 mmHg • Poids: 74 kg • FC: 70 bpm',
      badge: 'Terminé',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  /// Charge l'historique du patient depuis l'API médicale (famille réelle).
  ///
  /// Les lignes renvoyées ont la forme
  /// `{type, titre, desc, date}` ; elles sont converties en [_MedicalEvent].
  /// Échec → bandeau d'erreur + réessayer (pas de fausses données).
  Future<void> _loadHistory() async {
    final app = widget.app;
    if (app == null) {
      setState(() {
        _events = _mockEvents;
        _loading = false;
      });
      return;
    }
    final patientId = widget.patient.id;
    if (patientId.isEmpty) {
      setState(() {
        _events = [];
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (patient, historique) = await app.kpro.patientDetail(patientId);
      if (!mounted) return;
      setState(() {
        _events = historique.map(_eventFromApi).toList();
        // Le détail confirme aussi les champs du patient (allergies…) —
        // on n'en profite pas pour ne pas écraser l'objet affiché en cours.
        if (patient == null) _error = 'Patient introuvable côté serveur.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  _MedicalEvent _eventFromApi(Map<String, dynamic> row) {
    final typeStr = (row['type'] ?? '').toString();
    final type = switch (typeStr) {
      'ord' => _MedicalEventType.ordonnance,
      'facture' => _MedicalEventType.facture,
      'analyse' => _MedicalEventType.analyse,
      _ => _MedicalEventType.consultation,
    };
    final badge = switch (type) {
      _MedicalEventType.consultation => 'Terminé',
      _MedicalEventType.ordonnance => 'Délivrée',
      _MedicalEventType.facture => 'Facturée',
      _MedicalEventType.analyse => 'Résultats',
    };
    final praticien =
        (widget.app?.userName ?? '').trim().isNotEmpty
            ? widget.app!.userName
            : 'Médecin traitant';

    return _MedicalEvent(
      date: (row['date'] ?? '').toString(),
      type: type,
      titre: (row['titre'] ?? 'Événement médical').toString(),
      praticien: praticien,
      details: (row['desc'] ?? '').toString(),
      badge: badge,
    );
  }

  List<_MedicalEvent> get _filteredEvents {
    if (_historyFilter == 'Tous') return _events;
    if (_historyFilter == 'Consultations') {
      return _events.where((e) => e.type == _MedicalEventType.consultation).toList();
    }
    if (_historyFilter == 'Ordonnances') {
      return _events.where((e) => e.type == _MedicalEventType.ordonnance).toList();
    }
    if (_historyFilter == 'Factures') {
      return _events.where((e) => e.type == _MedicalEventType.facture).toList();
    }
    if (_historyFilter == 'Analyses') {
      return _events.where((e) => e.type == _MedicalEventType.analyse).toList();
    }
    return _events;
  }

  Future<void> _startCall({String? targetName, String? targetPhone, bool video = false}) async {
    final app = widget.app;
    final patient = widget.patient;
    final name = targetName ?? patient.nom;
    final phone = targetPhone ?? patient.telephone;

    if (app == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appel vers $name ($phone)...'),
          backgroundColor: YamColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    String? resolvedUserId;

    for (final c in app.contacts) {
      final cPhone = (c.phoneNumber ?? '').replaceAll(RegExp(r'\D'), '');
      if ((c.name.toLowerCase() == name.toLowerCase()) ||
          (cPhone.isNotEmpty && cleanPhone.isNotEmpty && (cPhone.contains(cleanPhone) || cleanPhone.contains(cPhone)))) {
        if (int.tryParse(c.userId) != null) {
          resolvedUserId = c.userId;
          break;
        }
      }
    }

    if (resolvedUserId == null) {
      try {
        final query = name.isNotEmpty ? name : cleanPhone;
        final users = await app.searchUsers(query);
        if (users.isNotEmpty) {
          final first = users.first;
          final idStr = first['id']?.toString();
          if (idStr != null && int.tryParse(idStr) != null) {
            resolvedUserId = idStr;
          }
        }
      } catch (_) {}
    }

    if (resolvedUserId == null || int.tryParse(resolvedUserId) == null) {
      if (cleanPhone.isNotEmpty && int.tryParse(cleanPhone) != null) {
        resolvedUserId = cleanPhone;
      } else {
        resolvedUserId = '2';
      }
    }

    if (!mounted) return;

    if (app.call.phase != CallPhase.idle) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Un appel est déjà en cours.'),
          backgroundColor: YamColors.accent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lancement de l\'appel vers $name...'),
        backgroundColor: YamColors.primary,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      await app.call.startOutgoing(
        resolvedUserId,
        targetName: name,
        video: video,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Échec de l\'appel : $e'),
            backgroundColor: YamColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final patient = widget.patient;

    return Scaffold(
      backgroundColor: YamColors.pageBg,
      appBar: AppBar(
        backgroundColor: YamColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: YamColors.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          patient.nom,
          style: const TextStyle(
            color: YamColors.text,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Appel audio',
            icon: const Icon(Icons.phone_outlined, color: YamColors.primary),
            onPressed: () => _startCall(video: false),
          ),
          IconButton(
            tooltip: 'Appel vidéo',
            icon: const Icon(Icons.videocam_outlined, color: YamColors.primary),
            onPressed: () => _startCall(video: true),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: YamColors.muted),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Action : $value'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'modifier',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18, color: YamColors.text),
                    SizedBox(width: 10),
                    Text('Modifier le dossier', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'exporter',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_outlined, size: 18, color: YamColors.text),
                    SizedBox(width: 10),
                    Text('Exporter le dossier (PDF)', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'partager',
                child: Row(
                  children: [
                    Icon(Icons.share_outlined, size: 18, color: YamColors.text),
                    SizedBox(width: 10),
                    Text('Partager la fiche médicale', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: YamColors.border, height: 1),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPatientHeaderCard(patient),
                    const SizedBox(height: 14),
                    _buildTabsNav(),
                    const SizedBox(height: 16),
                    if (_activeTab == 0)
                      _buildHistoryTab()
                    else if (_activeTab == 1)
                      _buildHealthProfileTab(patient)
                    else if (_activeTab == 2)
                      _buildTreatmentsTab()
                    else
                      _buildDocumentsTab(),
                  ],
                ),
              ),
            ),
            _buildStickyActionBar(context),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  En-tête patient
  // ─────────────────────────────────────────────────────────
  Widget _buildPatientHeaderCard(Patient patient) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: YamColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: YamColors.border, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Ligne avatar + infos ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: YamColors.primaryLight,
                    child: Text(
                      patient.initials,
                      style: const TextStyle(
                        color: YamColors.primaryDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 1,
                    right: 1,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: YamColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: YamColors.surface, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Infos textuelles
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.nom,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: YamColors.text,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${patient.sexe} • ${patient.age} ans (né le ${patient.dateNaissance})',
                      style: const TextStyle(
                        fontSize: 12,
                        color: YamColors.muted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.phone_rounded, size: 13, color: YamColors.muted),
                        const SizedBox(width: 4),
                        Text(
                          patient.telephone,
                          style: const TextStyle(
                            fontSize: 12,
                            color: YamColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: YamColors.border),
          const SizedBox(height: 12),

          // ── Badges clés ──
          Row(
            children: [
              _buildInfoBadge(
                icon: Icons.water_drop_outlined,
                label: 'Groupe ${patient.groupeSanguin}',
                textColor: YamColors.primary,
                bgColor: YamColors.primaryLight,
              ),
              if (patient.allergies.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInfoBadge(
                    icon: Icons.warning_amber_rounded,
                    label: 'Allergies : ${patient.allergies.join(", ")}',
                    textColor: YamColors.accent,
                    bgColor: YamColors.accentLight,
                    overflow: true,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // ── Actions rapides ──
          Row(
            children: [
              _buildQuickActionButton(
                context,
                label: 'Prescrire',
                icon: Icons.medication_rounded,
                color: YamColors.primary,
                bgColor: YamColors.primarySoft,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrdonnanceScreen(
                      app: widget.app,
                      patient: patient,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildQuickActionButton(
                context,
                label: 'Facturer',
                icon: Icons.receipt_long_rounded,
                color: YamColors.accent,
                bgColor: YamColors.accentSoft,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FacturerScreen(
                      app: widget.app,
                      patient: patient,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildQuickActionButton(
                context,
                label: 'Message',
                icon: Icons.chat_bubble_outline_rounded,
                color: YamColors.muted,
                bgColor: YamColors.surfaceSubtle,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ouverture de la messagerie...'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Badge de statut : fond plat, pas de transparence, icône fine.
  Widget _buildInfoBadge({
    required IconData icon,
    required String label,
    required Color textColor,
    required Color bgColor,
    bool overflow = false,
  }) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: textColor),
        const SizedBox(width: 5),
        overflow
            ? Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                  overflow: TextOverflow.ellipsis,
                ),
              )
            : Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
              ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: overflow ? Row(children: [content.children.first, content.children[1], content.children.last]) : content,
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Onglets de navigation
  // ─────────────────────────────────────────────────────────
  Widget _buildTabsNav() {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: YamColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: YamColors.border),
      ),
      child: Row(
        children: [
          _buildTabItem(0, 'Historique', Icons.history_rounded),
          const SizedBox(width: 2),
          _buildTabItem(1, 'Profil Santé', Icons.health_and_safety_outlined),
          const SizedBox(width: 2),
          _buildTabItem(2, 'Traitements', Icons.medication_liquid_outlined),
          const SizedBox(width: 2),
          _buildTabItem(3, 'Documents', Icons.folder_outlined),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label, IconData icon) {
    final isActive = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isActive ? YamColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isActive
                ? Border.all(color: YamColors.border.withValues(alpha: 0.5), width: 1)
                : null,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? YamColors.primary : YamColors.muted,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? YamColors.primary : YamColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Onglet 0 : Historique
  // ─────────────────────────────────────────────────────────
  Widget _buildHistoryTab() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: CircularProgressIndicator(color: YamColors.primary),
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: YamColors.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: YamColors.danger.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: YamColors.danger, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _error!,
                    style:
                        const TextStyle(fontSize: 12.5, color: YamColors.text),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _loadHistory,
                child: const Text('Réessayer'),
              ),
            ),
          ],
        ),
      );
    }

    if (_events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Text(
            'Aucun événement médical enregistré pour ce patient.',
            textAlign: TextAlign.center,
            style: TextStyle(color: YamColors.muted, fontSize: 13.5),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filtres
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['Tous', 'Consultations', 'Ordonnances', 'Factures', 'Analyses']
                .map(
                  (filter) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildFilterChip(filter),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 14),

        // Événements
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filteredEvents.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _buildEventCard(_filteredEvents[index]),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String filter) {
    final isSelected = _historyFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _historyFilter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? YamColors.primaryLight : YamColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? YamColors.primary : YamColors.border,
            width: 1,
          ),
        ),
        child: Text(
          filter,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? YamColors.primary : YamColors.muted,
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(_MedicalEvent event) {
    final isAccent =
        event.type == _MedicalEventType.facture || event.type == _MedicalEventType.analyse;

    return Container(
      decoration: BoxDecoration(
        color: YamColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: YamColors.border, width: 1),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icône type
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isAccent ? YamColors.accentSoft : YamColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(event.icon, size: 18, color: event.color),
              ),
              const SizedBox(width: 10),

              // Titre + praticien
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.titre,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: YamColors.text,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      event.praticien,
                      style: const TextStyle(fontSize: 11, color: YamColors.muted),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Badge statut
              if (event.badge != null)
                _buildStatusChip(
                  label: event.badge!,
                  textColor: isAccent ? YamColors.accent : YamColors.primary,
                  bgColor: isAccent ? YamColors.accentSoft : YamColors.primarySoft,
                ),
            ],
          ),

          // ── Constantes vitales ──
          if (event.vitals != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: YamColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                event.vitals!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: YamColors.muted,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),
          Text(
            event.details,
            style: const TextStyle(
              fontSize: 13,
              color: YamColors.text,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: YamColors.border),
          const SizedBox(height: 8),

          // ── Pied de carte ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                event.date,
                style: const TextStyle(
                  fontSize: 11,
                  color: YamColors.muted,
                ),
              ),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Détails de "${event.titre}"'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                child: const Row(
                  children: [
                    Text(
                      'Consulter',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: YamColors.primary,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 16, color: YamColors.primary),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Onglet 1 : Profil Santé
  // ─────────────────────────────────────────────────────────
  Widget _buildHealthProfileTab(Patient patient) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Constantes vitales
        const _SectionLabel(label: 'Dernières constantes vitales'),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildVitalCard('Tension', '120/80', 'mmHg', Icons.speed_rounded, YamColors.primary),
            const SizedBox(width: 8),
            _buildVitalCard('Température', '37.2', '°C', Icons.thermostat_rounded, YamColors.accent),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildVitalCard('Fréquence C.', '72', 'bpm', Icons.favorite_border_rounded, YamColors.danger),
            const SizedBox(width: 8),
            _buildVitalCard('Poids / IMC', '74 kg', 'IMC 23.4', Icons.monitor_weight_outlined, YamColors.text),
          ],
        ),

        const SizedBox(height: 18),

        _buildSectionCard(
          title: 'Antécédents & Terrain',
          icon: Icons.medical_information_outlined,
          children: [
            _buildInfoRow('Groupe Sanguin', patient.groupeSanguin, isBold: true),
            _buildInfoRow(
              'Allergies connues',
              patient.allergies.join(', '),
              textColor: YamColors.accent,
              isBold: true,
            ),
            _buildInfoRow('Antécédents', patient.antecedents.join('\n')),
            _buildInfoRow('Régime / Habitudes', 'Non-fumeur, activité physique régulière'),
          ],
        ),

        const SizedBox(height: 12),

        _buildSectionCard(
          title: 'Coordonnées & Urgence',
          icon: Icons.contact_emergency_outlined,
          children: [
            _buildInfoRow('Adresse', patient.adresse),
            _buildInfoRow('Téléphone principal', patient.telephone),
            _buildInfoRow(
              'Contact d\'urgence',
              patient.contactUrgence,
              isBold: true,
              trailing: IconButton(
                icon: const Icon(Icons.phone_in_talk_rounded, color: YamColors.primary, size: 18),
                onPressed: () => _startCall(
                  targetName: patient.contactUrgence,
                  targetPhone: patient.contactUrgence,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVitalCard(String label, String value, String unit, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: YamColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: YamColors.border, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color == YamColors.text
                    ? YamColors.surfaceSubtle
                    : color == YamColors.primary
                        ? YamColors.primarySoft
                        : color == YamColors.accent
                            ? YamColors.accentSoft
                            : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: YamColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: YamColors.text,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        unit,
                        style: const TextStyle(fontSize: 10, color: YamColors.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Onglet 2 : Traitements
  // ─────────────────────────────────────────────────────────
  Widget _buildTreatmentsTab() {
    final treatments = [
      {
        'nom': 'Amoxicilline 1g',
        'forme': 'Comprimé',
        'posologie': '1 comprimé matin et soir au cours du repas',
        'duree': 'Reste 4 jours sur 7',
        'prescripteur': 'Dr. Jean Mensah (12/09/2026)',
        'progress': 0.45,
      },
      {
        'nom': 'Paracétamol 500 mg',
        'forme': 'Comprimé',
        'posologie': '1 comprimé toutes les 6h si fièvre ou douleur',
        'duree': 'Si besoin',
        'prescripteur': 'Dr. Jean Mensah (12/09/2026)',
        'progress': 1.0,
      },
      {
        'nom': 'Sirop Antitussif',
        'forme': 'Flacon / Sirop',
        'posologie': '1 cuillère à soupe 3 fois par jour',
        'duree': 'Reste 3 jours',
        'prescripteur': 'Dr. Jean Mensah (12/09/2026)',
        'progress': 0.6,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionLabel(label: 'Prescriptions actives'),
            Text(
              '${treatments.length} traitement(s)',
              style: const TextStyle(fontSize: 12, color: YamColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: treatments.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = treatments[index];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: YamColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: YamColors.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: YamColors.primarySoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.medication_liquid_rounded,
                          color: YamColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['nom'] as String,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: YamColors.text,
                              ),
                            ),
                            Text(
                              item['forme'] as String,
                              style: const TextStyle(fontSize: 12, color: YamColors.muted),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusChip(
                        label: item['duree'] as String,
                        textColor: YamColors.primary,
                        bgColor: YamColors.primarySoft,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Posologie : ${item['posologie']}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: YamColors.text,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Prescrit par ${item['prescripteur']}',
                    style: const TextStyle(fontSize: 11, color: YamColors.muted),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: item['progress'] as double,
                      backgroundColor: YamColors.surfaceSubtle,
                      valueColor: const AlwaysStoppedAnimation<Color>(YamColors.primary),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Onglet 3 : Documents
  // ─────────────────────────────────────────────────────────
  Widget _buildDocumentsTab() {
    final docs = [
      {
        'nom': 'Ordonnance_Septembre_2026.pdf',
        'type': 'Ordonnance',
        'date': '12/09/2026',
        'taille': '245 Ko',
        'icon': Icons.picture_as_pdf_rounded,
        'color': YamColors.primary,
      },
      {
        'nom': 'Bilan_Sanguin_BioSante.pdf',
        'type': 'Laboratoire',
        'date': '28/06/2026',
        'taille': '1.2 Mo',
        'icon': Icons.biotech_rounded,
        'color': YamColors.accent,
      },
      {
        'nom': 'Radiographie_Thoracique_Face.jpg',
        'type': 'Imagerie',
        'date': '15/03/2026',
        'taille': '3.4 Mo',
        'icon': Icons.image_rounded,
        'color': YamColors.text,
      },
      {
        'nom': 'Compte_Rendu_Consultation_Mensah.pdf',
        'type': 'Compte-rendu',
        'date': '15/03/2026',
        'taille': '180 Ko',
        'icon': Icons.description_rounded,
        'color': YamColors.primary,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionLabel(label: 'Documents & Imageries'),
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ajout d\'un document en cours...'),
                    backgroundColor: YamColors.primary,
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded, size: 15),
              label: const Text('Ajouter'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(70, 30),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final color = doc['color'] as Color;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: YamColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: YamColors.border, width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color == YamColors.primary
                          ? YamColors.primarySoft
                          : color == YamColors.accent
                              ? YamColors.accentSoft
                              : YamColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      doc['icon'] as IconData,
                      color: color,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc['nom'] as String,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: YamColors.text,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${doc['type']} • ${doc['date']} • ${doc['taille']}',
                          style: const TextStyle(fontSize: 11, color: YamColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Télécharger',
                    icon: const Icon(Icons.download_rounded, color: YamColors.muted, size: 18),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Téléchargement de ${doc['nom']}...'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Widgets communs
  // ─────────────────────────────────────────────────────────

  /// Chip de statut : fond plat, texte court, pas d'effets.
  Widget _buildStatusChip({
    required String label,
    required Color textColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: YamColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: YamColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: YamColors.primary),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: YamColors.text,
                ),
              ),
            ],
          ),
          const Divider(height: 18, thickness: 1, color: YamColors.border),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    Color? textColor,
    bool isBold = false,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: YamColors.muted,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
                color: textColor ?? YamColors.text,
                height: 1.4,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Barre d'action bas
  // ─────────────────────────────────────────────────────────
  Widget _buildStickyActionBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: YamColors.surface,
        border: Border(top: BorderSide(color: YamColors.border, width: 1)),
      ),
      child: SizedBox(
        height: 48,
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ouverture d\'une nouvelle consultation...'),
                backgroundColor: YamColors.primary,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
          label: const Text(
            'Nouvelle consultation',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: YamColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Widget utilitaire : titre de section
// ─────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: YamColors.text,
      ),
    );
  }
}
