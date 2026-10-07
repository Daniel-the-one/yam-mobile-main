import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'facturer_screen.dart';

enum _StatutFacture { payee, enAttente }

class _Facture {
  const _Facture({
    required this.numero,
    required this.patient,
    required this.montant,
    required this.date,
    required this.statut,
  });

  final String numero;
  final String patient;
  final int montant;
  final String date;
  final _StatutFacture statut;

  bool get estPayee => statut == _StatutFacture.payee;
}

/// Liste des factures (chargée depuis l'API médicale).
/// Point d'entrée vers la création d'une facture.
class FactureListeScreen extends StatefulWidget {
  const FactureListeScreen({super.key, this.app});

  /// Contexte applicatif transmis à l'écran de création (API médicale).
  final AppState? app;

  @override
  State<FactureListeScreen> createState() => _FactureListeScreenState();
}

class _FactureListeScreenState extends State<FactureListeScreen> {
  List<_Facture> _factures = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Charge la liste depuis l'API médicale (`GET /api/factures.php`).
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
      final rows = await app.kpro.factures();
      final list = rows
          .map((r) => _Facture(
                numero: r['numero']?.toString() ?? '—',
                patient: r['patient']?.toString() ?? 'Patient inconnu',
                montant: int.tryParse('${r['montant']}') ?? 0,
                date: r['date']?.toString() ?? '',
                statut: r['statut'] == 'payee'
                    ? _StatutFacture.payee
                    : _StatutFacture.enAttente,
              ))
          .toList();
      if (mounted) {
        setState(() {
          _factures = list;
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

  /// Retire le préfixe technique `Exception: ` des messages d'erreur.
  static String _friendlyError(Object e) {
    final s = e.toString();
    return s.startsWith('Exception: ') ? s.substring(11) : s;
  }

  Future<void> _openCreate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FacturerScreen(app: widget.app)),
    );
    // Une facture vient peut-être d'être créée : on rafraîchit la liste.
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
    if (_factures.isEmpty) {
      return const Center(
        child: Text(
          'Aucune facture enregistrée',
          style: TextStyle(color: YamColors.muted),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemCount: _factures.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final facture = _factures[index];
        return _FactureCard(
          facture: facture,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Détail facture à venir (${facture.numero})'),
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
          'Factures',
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
                  child: const Text('+ Nouvelle facture'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FactureCard extends StatelessWidget {
  const _FactureCard({
    required this.facture,
    required this.onTap,
  });

  final _Facture facture;
  final VoidCallback onTap;

  String _formatMontant(int value) {
    final str = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(str[i]);
    }
    return '${buffer.toString()} FCFA';
  }

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
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: facture.estPayee
                      ? YamColors.primarySoft
                      : YamColors.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  size: 20,
                  color: facture.estPayee ? YamColors.primary : YamColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            facture.patient,
                            style: const TextStyle(
                              color: YamColors.text,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatMontant(facture.montant),
                          style: const TextStyle(
                            color: YamColors.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          facture.numero,
                          style: mono(size: 11),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          facture.date,
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
              const SizedBox(width: 8),
              _StatutChip(facture: facture),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatutChip extends StatelessWidget {
  const _StatutChip({required this.facture});

  final _Facture facture;

  @override
  Widget build(BuildContext context) {
    final label = facture.estPayee ? 'Payée' : 'En attente';
    final textColor = facture.estPayee ? YamColors.primary : YamColors.accent;
    final bgColor = facture.estPayee ? YamColors.primarySoft : YamColors.accentSoft;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
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
}