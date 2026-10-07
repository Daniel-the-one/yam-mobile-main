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

/// Liste des factures. Point d'entrée vers la création d'une facture.
class FactureListeScreen extends StatelessWidget {
  const FactureListeScreen({super.key, this.app});

  /// Contexte applicatif transmis à l'écran de création (API médicale).
  final AppState? app;

  static const _factures = <_Facture>[
    _Facture(
      numero: 'FAC-2026-089',
      patient: 'Jean KOFFI',
      montant: 15000,
      date: '18/09/2026',
      statut: _StatutFacture.payee,
    ),
    _Facture(
      numero: 'FAC-2026-088',
      patient: 'Amina ABALO',
      montant: 7500,
      date: '17/09/2026',
      statut: _StatutFacture.payee,
    ),
    _Facture(
      numero: 'FAC-2026-087',
      patient: 'Kofi AGBEKO',
      montant: 22500,
      date: '16/09/2026',
      statut: _StatutFacture.enAttente,
    ),
    _Facture(
      numero: 'FAC-2026-086',
      patient: 'Essi MENSAH',
      montant: 5000,
      date: '15/09/2026',
      statut: _StatutFacture.payee,
    ),
    _Facture(
      numero: 'FAC-2026-085',
      patient: 'Jean KOFFI',
      montant: 10000,
      date: '12/09/2026',
      statut: _StatutFacture.enAttente,
    ),
    _Facture(
      numero: 'FAC-2026-084',
      patient: 'Amina ABALO',
      montant: 32500,
      date: '10/09/2026',
      statut: _StatutFacture.payee,
    ),
  ];

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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: YamColors.border, height: 1),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                itemCount: _factures.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final facture = _factures[index];
                  return _FactureCard(
                    facture: facture,
                    montant: _formatMontant(facture.montant),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('Détail facture à venir (${facture.numero})'),
                          backgroundColor: YamColors.primary,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => FacturerScreen(app: app)),
                  ),
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
    required this.montant,
    required this.onTap,
  });

  final _Facture facture;
  final String montant;
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
                          montant,
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
