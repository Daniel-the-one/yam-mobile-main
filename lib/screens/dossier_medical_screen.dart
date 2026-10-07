import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/patient.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'card_scanner_screen.dart';
import 'patient_details_screen.dart';

class DossierMedicalScreen extends StatefulWidget {
  const DossierMedicalScreen({super.key, this.showAppBar = true, this.app});

  final bool showAppBar;
  final AppState? app;

  @override
  State<DossierMedicalScreen> createState() => _DossierMedicalScreenState();
}

class _DossierMedicalScreenState extends State<DossierMedicalScreen> {
  int _tabIndex = 0; // 0 = Rechercher, 1 = Scanner carte
  final _searchController = TextEditingController();

  // Liste patients — alimentée par l'API médicale KondjiPro
  // (GET /api/patients.php). Vide tant que le chargement n'a pas réussi ;
  // sans AppState (widget isolé / test), la liste reste vide.
  List<Patient> _allPatients = const [];
  bool _loading = true;
  String? _error;

  List<Patient> get _filteredPatients {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _allPatients;
    return _allPatients.where((p) {
      return p.nom.toLowerCase().contains(query) ||
          p.telephone.replaceAll(' ', '').contains(query.replaceAll(' ', ''));
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadPatients();
  }

  /// Charge la liste des patients depuis l'API médicale (famille réelle).
  ///
  /// Échec → message d'erreur affiché sous la barre de recherche + bouton
  /// réessayer (pas de fausses données présentées comme réelles).
  Future<void> _loadPatients() async {
    final app = widget.app;
    if (app == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await app.kpro.searchPatients('');
      if (!mounted) return;
      setState(() {
        _allPatients = rows.map(Patient.fromApi).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.showAppBar) ...[
            const SizedBox(height: 8),
            const Text(
              'Dossier médical',
              style: TextStyle(
                color: YamColors.text,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            const SizedBox(height: 8),
          ],

          // ── Sélecteur d'onglets ──
          _buildTabSelector(),

          const SizedBox(height: 16),

          // ── Contenu selon l'onglet ──
          if (_tabIndex == 0) ...[
            // Barre de recherche
            _buildSearchBar(),
            const SizedBox(height: 20),

            // Titre de section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Patients récents',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: YamColors.text,
                  ),
                ),
                Text(
                  '${_filteredPatients.length} patient(s)',
                  style: const TextStyle(
                    fontSize: 13,
                    color: YamColors.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Bandeau d'erreur API (jamais de fausses données réelles).
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: YamColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: YamColors.danger.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: YamColors.danger, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(fontSize: 12.5, color: YamColors.text),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadPatients,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Liste des patients
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: YamColors.primary),
                    )
                  : _filteredPatients.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 44,
                            color: YamColors.muted.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Aucun patient trouvé',
                            style: TextStyle(
                              color: YamColors.muted,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: YamColors.primary,
                      onRefresh: _loadPatients,
                      child: ListView.separated(
                        itemCount: _filteredPatients.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          return _PatientCard(
                            patient: _filteredPatients[index],
                            app: widget.app,
                          );
                        },
                      ),
                    ),
            ),
          ] else ...[
            // Scanner carte
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: YamColors.primarySoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 56,
                          color: YamColors.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Scanner une carte patient',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: YamColors.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Positionnez la carte QR du patient devant la caméra pour ouvrir son dossier médical.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: YamColors.muted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _openCameraScanner,
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: const Text('Ouvrir la caméra'),
                        style: FilledButton.styleFrom(
                          backgroundColor: YamColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 14,
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: kButtonRadius,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showAppBar) {
      return _buildContent();
    }

    return Scaffold(
      backgroundColor: YamColors.pageBg,
      appBar: AppBar(
        backgroundColor: YamColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          'Dossier médical',
          style: TextStyle(
            color: YamColors.text,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: YamColors.border, height: 1),
        ),
      ),
      body: SafeArea(
        child: _buildContent(),
      ),
    );
  }

  /// Demande la permission caméra puis ouvre l'écran de scan.
  Future<void> _openCameraScanner() async {
    final messenger = ScaffoldMessenger.of(context);
    final permission = await Permission.camera.request();
    if (!mounted) return;

    if (permission.isPermanentlyDenied) {
      _showCameraBlockedDialog(canOpenSettings: true);
      return;
    }
    if (!permission.isGranted) {
      _showCameraBlockedDialog(canOpenSettings: false);
      return;
    }

    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const CardScannerScreen()),
    );
    if (scanned == null || !mounted) return;

    final patient = _findPatientById(scanned);
    if (patient == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Aucun patient trouvé pour ce code : $scanned'),
          backgroundColor: YamColors.danger,
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PatientDetailsScreen(patient: patient, app: widget.app),
      ),
    );
  }

  /// Retrouve le patient dont l'identifiant de carte correspond au code scanné.
  ///
  /// Compare à la fois `id` (ex : `PAT-2024-00123`) et `uuid` (contenu du QR
  /// côté KondjiPro), en ignorant casse et espaces.
  Patient? _findPatientById(String code) {
    final needle = Patient.normalizeId(code);
    if (needle.isEmpty) return null;

    for (final patient in _allPatients) {
      if (Patient.normalizeId(patient.id) == needle ||
          Patient.normalizeId(patient.uuid) == needle) {
        return patient;
      }
    }
    return null;
  }

  void _showCameraBlockedDialog({required bool canOpenSettings}) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: YamColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: kCardRadius),
        title: const Text(
          'Permission caméra requise',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: YamColors.text),
        ),
        content: Text(
          canOpenSettings
              ? "L'accès à la caméra a été refusé définitivement. Activez-le dans les paramètres du téléphone pour scanner une carte."
              : "L'accès à la caméra a été refusé. Autorisez-le pour scanner une carte patient.",
          style: const TextStyle(fontSize: 14, color: YamColors.muted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          if (canOpenSettings)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                openAppSettings();
              },
              child: const Text('Ouvrir les paramètres'),
            ),
        ],
      ),
    );
  }

  /// Sélecteur d'onglets arrondi
  Widget _buildTabSelector() {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: YamColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: YamColors.border),
      ),
      child: Row(
        children: [
          _buildTabButton('Rechercher', Icons.search_rounded, 0),
          const SizedBox(width: 6),
          _buildTabButton('Scanner carte', Icons.qr_code_scanner_rounded, 1),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, IconData icon, int index) {
    final isActive = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
          decoration: BoxDecoration(
            color: isActive ? YamColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
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
                size: 19,
                color: isActive ? YamColors.primary : YamColors.muted,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? YamColors.primary : YamColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Barre de recherche
  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded, color: YamColors.muted),
        hintText: 'Rechercher par nom ou téléphone...',
        filled: true,
        fillColor: YamColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: kFieldRadius,
          borderSide: const BorderSide(color: YamColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: kFieldRadius,
          borderSide: const BorderSide(color: YamColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: kFieldRadius,
          borderSide: const BorderSide(color: YamColors.primary, width: 2),
        ),
      ),
    );
  }
}

/// Carte patient
class _PatientCard extends StatelessWidget {
  const _PatientCard({required this.patient, this.app});

  final Patient patient;
  final AppState? app;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: YamColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: kCardRadius,
        side: BorderSide(color: YamColors.border),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PatientDetailsScreen(patient: patient, app: app),
            ),
          );
        },
        borderRadius: kCardRadius,
        child: Container(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar initiales
              CircleAvatar(
                radius: 22,
                backgroundColor: YamColors.primarySoft,
                child: Text(
                  patient.initials,
                  style: const TextStyle(
                    color: YamColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Infos patient
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.nom,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: YamColors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      patient.telephone,
                      style: const TextStyle(
                        fontSize: 13,
                        color: YamColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Né le ${patient.dateNaissance}',
                      style: TextStyle(
                        fontSize: 12,
                        color: YamColors.muted.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),

              // Chevron
              const Icon(
                Icons.chevron_right_rounded,
                color: YamColors.muted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
