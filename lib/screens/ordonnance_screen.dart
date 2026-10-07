import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../models/patient.dart';
import '../state/app_state.dart';
import '../theme.dart';

class _MedicamentItem {
  _MedicamentItem({
    String name = '',
    String quantity = '10',
    this.unit = 'Comprimés',
    this.frequency = '2 fois/jour',
  })  : nameController = TextEditingController(text: name),
        quantityController = TextEditingController(text: quantity);

  final TextEditingController nameController;
  final TextEditingController quantityController;
  String unit;
  String frequency;

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
  }
}

class OrdonnanceScreen extends StatefulWidget {
  const OrdonnanceScreen({super.key, this.app, this.patient});

  /// Contexte applicatif — si fourni, l'ordonnance est enregistrée via
  /// l'API médicale KondjiPro (`POST /api/ordonnance_save.php`) ; sinon
  /// l'écran reste en mode démonstration.
  final AppState? app;

  /// Patient présélectionné (depuis le dossier médical).
  final Patient? patient;

  @override
  State<OrdonnanceScreen> createState() => _OrdonnanceScreenState();
}

class _OrdonnanceScreenState extends State<OrdonnanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();

  final List<String> _unitOptions = [
    'Comprimés',
    'Gélules',
    'Sirops',
    'Ampoules',
    'Sachets',
    'Flacons',
    'Gouttes',
    'Pommade',
  ];

  final List<String> _frequencyOptions = [
    '1 fois/jour',
    '2 fois/jour',
    '3 fois/jour',
    '4 fois/jour',
    'Matin et Soir',
    'Si besoin',
    'Toutes les 8h',
  ];

  final List<_MedicamentItem> _medicaments = [
    _MedicamentItem(
      name: 'Paracétamol 500 mg',
      quantity: '10',
      unit: 'Comprimés',
      frequency: '2 fois/jour',
    ),
  ];

  @override
  void initState() {
    super.initState();
    final patient = widget.patient;
    if (patient != null && patient.telephone.isNotEmpty) {
      _phoneController.text = patient.telephone;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    for (final item in _medicaments) {
      item.dispose();
    }
    super.dispose();
  }

  bool _saving = false;

  void _snack(String message, {Color color = YamColors.primary}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _addMedicament() {
    setState(() {
      _medicaments.add(_MedicamentItem());
    });
  }

  void _removeMedicament(int index) {
    if (_medicaments.length > 1) {
      setState(() {
        final item = _medicaments.removeAt(index);
        item.dispose();
      });
    }
  }

  Future<void> _validerOrdonnance() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    final count = _medicaments.length;
    final app = widget.app;

    // ── Mode démo (aucun AppState) : comportement historique ──
    if (app == null) {
      debugPrint('Ordonnance validée pour $phone avec $count médicament(s)');
      _snack('Ordonnance enregistrée ($count médicament(s))');
      return;
    }

    // ── Mode réel : POST ordonnance_save.php (med[i][…]) ──
    setState(() => _saving = true);
    try {
      final patientId = await app.kpro.resolvePatientId(
        phone: phone,
        knownId: widget.patient?.id,
      );
      if (patientId == null) {
        _snack('Aucun patient trouvé pour le numéro $phone.',
            color: YamColors.danger);
        return;
      }

      await app.kpro.saveOrdonnance(
        patientId: patientId,
        notes: '',
        meds: _medicaments
            .map((m) => {
                  'nom': m.nameController.text.trim(),
                  'quantite': m.quantityController.text.trim(),
                  'unite': m.unit,
                  'frequence': m.frequency,
                })
            .toList(),
      );

      _snack('Ordonnance enregistrée ($count médicament(s))');
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _snack('$e', color: YamColors.danger);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          'Nouvelle Ordonnance',
          style: TextStyle(
            color: YamColors.text,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: YamColors.border,
            height: 1,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section Numéro du patient
                      const Text(
                        'Numéro du patient',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: YamColors.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: IntlPhoneField(
                              controller: _phoneController,
                              initialCountryCode: 'TG',
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
                                color: YamColors.text,
                              ),
                              invalidNumberMessage:
                                  'Numéro de téléphone invalide',
                              decoration: InputDecoration(
                                hintText: 'Ex: 90 12 34 56',
                                filled: true,
                                fillColor: YamColors.surface,
                                contentPadding: const EdgeInsets.all(16),
                                border: OutlineInputBorder(
                                  borderRadius: kFieldRadius,
                                  borderSide:
                                      const BorderSide(color: YamColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: kFieldRadius,
                                  borderSide:
                                      const BorderSide(color: YamColors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: kFieldRadius,
                                  borderSide: const BorderSide(
                                    color: YamColors.primary,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Material(
                            color: YamColors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: kFieldRadius,
                              side: const BorderSide(color: YamColors.border),
                            ),
                            child: InkWell(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Accès aux contacts'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                              borderRadius: kFieldRadius,
                              child: Container(
                                width: 52,
                                height: 52,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.contact_phone_outlined,
                                  color: YamColors.primary,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Section Médicaments
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Prescription médicale',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: YamColors.text,
                            ),
                          ),
                          Text(
                            '${_medicaments.length} médicament(s)',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: YamColors.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Liste des blocs médicaments
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _medicaments.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = _medicaments[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: YamColors.surface,
                              borderRadius: kCardRadius,
                              border: Border.all(
                                color: YamColors.border,
                                width: 1,
                              ),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // En-tête du bloc médicament
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 26,
                                          height: 26,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: YamColors.primarySoft,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: YamColors.primary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Médicament ${index + 1}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: YamColors.text,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_medicaments.length > 1)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: YamColors.danger,
                                          size: 20,
                                        ),
                                        onPressed: () =>
                                            _removeMedicament(index),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        tooltip: 'Supprimer ce médicament',
                                      ),
                                  ],
                                ),
                                const Divider(
                                  height: 20,
                                  color: YamColors.border,
                                ),

                                // Champ Nom du médicament
                                const Text(
                                  'Dénomination & Dosage',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: YamColors.text,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: item.nameController,
                                  decoration: InputDecoration(
                                    hintText: 'Ex: Paracétamol 500 mg',
                                    hintStyle: const TextStyle(
                                      color: YamColors.muted,
                                      fontSize: 14,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.medication_outlined,
                                      size: 20,
                                      color: YamColors.muted,
                                    ),
                                    filled: true,
                                    fillColor: YamColors.surfaceSubtle,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: YamColors.border,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: YamColors.border,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: YamColors.primary,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Veuillez saisir le médicament';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),

                                // Ligne des 3 sélecteurs : Quantité, Unité, Fréquence
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 1. Quantité
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Qté',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: YamColors.text,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          TextFormField(
                                            controller: item.quantityController,
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly
                                            ],
                                            textAlign: TextAlign.center,
                                            decoration: InputDecoration(
                                              hintText: '10',
                                              filled: true,
                                              fillColor: YamColors.surfaceSubtle,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 12,
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: const BorderSide(
                                                  color: YamColors.border,
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: const BorderSide(
                                                  color: YamColors.border,
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: const BorderSide(
                                                  color: YamColors.primary,
                                                  width: 1.5,
                                                ),
                                              ),
                                            ),
                                            validator: (val) {
                                              if (val == null ||
                                                  val.trim().isEmpty) {
                                                return 'Requis';
                                              }
                                              return null;
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // 2. Unité
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Unité',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: YamColors.text,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          DropdownButtonFormField<String>(
                                            initialValue: item.unit,
                                            isExpanded: true,
                                            decoration: InputDecoration(
                                              filled: true,
                                              fillColor: YamColors.surfaceSubtle,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 12,
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: const BorderSide(
                                                  color: YamColors.border,
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: const BorderSide(
                                                  color: YamColors.border,
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: const BorderSide(
                                                  color: YamColors.primary,
                                                  width: 1.5,
                                                ),
                                              ),
                                            ),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: YamColors.text,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            items: _unitOptions
                                                .map(
                                                  (u) =>
                                                      DropdownMenuItem<String>(
                                                    value: u,
                                                    child: Text(
                                                      u,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: (val) {
                                              if (val != null) {
                                                setState(() {
                                                  item.unit = val;
                                                });
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // 3. Fréquence
                                    Expanded(
                                      flex: 4,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Fréquence',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: YamColors.text,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          DropdownButtonFormField<String>(
                                            initialValue: item.frequency,
                                            isExpanded: true,
                                            decoration: InputDecoration(
                                              filled: true,
                                              fillColor: YamColors.surfaceSubtle,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 12,
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: const BorderSide(
                                                  color: YamColors.border,
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: const BorderSide(
                                                  color: YamColors.border,
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: const BorderSide(
                                                  color: YamColors.primary,
                                                  width: 1.5,
                                                ),
                                              ),
                                            ),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: YamColors.text,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            items: _frequencyOptions
                                                .map(
                                                  (f) =>
                                                      DropdownMenuItem<String>(
                                                    value: f,
                                                    child: Text(
                                                      f,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: (val) {
                                              if (val != null) {
                                                setState(() {
                                                  item.frequency = val;
                                                });
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // Bouton d'ajout : "+ Ajouter un médicament"
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _addMedicament,
                          icon: const Icon(
                            Icons.add_circle_outline_rounded,
                            size: 20,
                            color: YamColors.primary,
                          ),
                          label: const Text(
                            '+ Ajouter un médicament',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: YamColors.primary,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: YamColors.surface,
                            side: const BorderSide(
                              color: YamColors.primary,
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            // Pied de page : Bouton d'action principal
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: YamColors.surface,
                border: Border(
                  top: BorderSide(
                    color: YamColors.border,
                    width: 1,
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _validerOrdonnance,
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
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Valider l'ordonnance"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
