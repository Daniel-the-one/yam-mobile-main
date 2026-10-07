import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'ordonnance_screen.dart';

class _Ordonnance {
  const _Ordonnance({
    required this.numero,
    required this.patient,
    required this.date,
    required this.medicaments,
    required this.praticien,
  });

  final String numero;
  final String patient;
  final String date;
  final String medicaments;
  final String praticien;
}

/// Liste des ordonnances (chargée depuis l'API médicale).
/// Point d'entrée vers la création d'une ordonnance.
class OrdonnanceListeScreen extends StatefulWidget {
  const OrdonnanceListeScreen({super.key, this.app});

  /// Contexte applicatif transmis à l'écran de création (API médicale).
  final AppState? app;

  @override
  State<OrdonnanceListeScreen> createState() => _OrdonnanceListeScreenState();
}

class _OrdonnanceListeScreenState extends State<OrdonnanceListeScreen> {
  List<_Ordonnance> _ordonnances = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Charge la liste depuis l'API médicale (`GET /api/ordonnances.php`).
  Future<void> _load() async {
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
      final rows = await app.kpro.ordonnances();
      final list = rows.map((r) {
        final meds = r['medicaments'];
        final noms = meds is List
            ? meds
                .whereType<Map>()
                .map((m) => m['nom']?.toString() ?? '')
                .where((n) => n.isNotEmpty)
                .join(', ')
            : '';
        return _Ordonnance(
          numero: r['numero']?.toString() ?? '—',
          patient: r['patient']?.toString() ?? 'Patient inconnu',
          date: r['date']?.toString() ?? '',
          medicaments: noms.isNotEmpty ? noms : (r['notes']?.toString() ?? ''),
          praticien: '',
        );
      }).toList();
      if (mounted) {
        setState(() {
          _ordonnances = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _friendlyError(e);
          _loading = false;
        });
      }
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    return s.startsWith('Exception: ') ? s.substring(11) : s;
  }

  Future<void> _openCreate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OrdonnanceScreen(app: widget.app)),
    );
    // Une ordonnance vient peut-être d'être créée : on rafraîchit la liste.
    _load();
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 40, color: YamColors.muted),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: YamColors.muted),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }
    if (_ordonnances.isEmpty) {
      return const Center(
        child: Text(
          'Aucune ordonnance enregistrée',
          style: TextStyle(color: YamColors.muted),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemCount: _ordonnances.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final ordonnance = _ordonnances[index];
        return _OrdonnanceCard(
          ordonnance: ordonnance,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Détail ordonnance à venir (${ordonnance.numero})',
                ),
                backgroundColor: YamColors.primary,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: YamColors.pageBg,
      appBar: AppBar(
        backgroundColor: YamColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          'Ordonnances',
          style: TextStyle(
            color: YamColors.text,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, color: YamColors.text),
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
            Expanded(child: _buildBody()),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _openCreate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: YamColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const RoundedRectangleBorder(
                      borderRadius: kButtonRadius,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('+ Nouvelle ordonnance'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdonnanceCard extends StatelessWidget {
  const _OrdonnanceCard({
    required this.ordonnance,
    required this.onTap,
  });

  final _Ordonnance ordonnance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: YamColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: kCardRadius,
        side: BorderSide(color: YamColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: kCardRadius,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: YamColors.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.medication_rounded,
                      size: 20,
                      color: YamColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ordonnance.patient,
                          style: const TextStyle(
                            color: YamColors.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              ordonnance.numero,
                              style: mono(size: 11),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              ordonnance.date,
                              style: const TextStyle(
                                fontSize: 11,
                                color: YamColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: YamColors.muted,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                ordonnance.medicaments,
                style: const TextStyle(
                  fontSize: 13,
                  color: YamColors.muted,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (ordonnance.praticien.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  ordonnance.praticien,
                  style: const TextStyle(
                    fontSize: 11,
                    color: YamColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}