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

/// Liste des ordonnances. Point d'entrée vers la création d'une ordonnance.
class OrdonnanceListeScreen extends StatelessWidget {
  const OrdonnanceListeScreen({super.key, this.app});

  /// Contexte applicatif transmis à l'écran de création (API médicale).
  final AppState? app;

  static const _ordonnances = <_Ordonnance>[
    _Ordonnance(
      numero: 'ORD-2026-112',
      patient: 'Amina ABALO',
      date: '18/09/2026',
      medicaments: 'Paracétamol 500 mg, Ibuprofène 400 mg',
      praticien: 'Dr KOFFI',
    ),
    _Ordonnance(
      numero: 'ORD-2026-111',
      patient: 'Jean KOFFI',
      date: '17/09/2026',
      medicaments: 'Amoxicilline 500 mg',
      praticien: 'Dr KOFFI',
    ),
    _Ordonnance(
      numero: 'ORD-2026-110',
      patient: 'Essi MENSAH',
      date: '15/09/2026',
      medicaments: 'Metformine 850 mg, Sertraline 50 mg',
      praticien: 'Dr AGBEKO',
    ),
    _Ordonnance(
      numero: 'ORD-2026-109',
      patient: 'Kofi AGBEKO',
      date: '12/09/2026',
      medicaments: 'Amlodipine 5 mg, Hydrochlorothiazide 25 mg',
      praticien: 'Dr AGBEKO',
    ),
    _Ordonnance(
      numero: 'ORD-2026-108',
      patient: 'Amina ABALO',
      date: '10/09/2026',
      medicaments: 'Oméprazole 20 mg, Vitamine D',
      praticien: 'Dr MENSAH',
    ),
  ];

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
                    MaterialPageRoute(builder: (_) => OrdonnanceScreen(app: app)),
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
  const _OrdonnanceCard({required this.ordonnance, required this.onTap});

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
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(ordonnance.numero, style: mono(size: 11)),
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
          ),
        ),
      ),
    );
  }
}
