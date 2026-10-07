import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../models/patient.dart';
import '../state/app_state.dart';
import '../theme.dart';

class EncaisserScreen extends StatefulWidget {
  const EncaisserScreen({
    super.key,
    this.showAppBar = true,
    this.app,
    this.patient,
  });

  final bool showAppBar;

  /// Contexte applicatif — si fourni, la demande d'encaissement part vers la
  /// route argent ([ApiConfig.encaissement]) : démo tant que
  /// `ApiConfig.moneyDemo` est vrai (aucun argent réel ne circule).
  final AppState? app;

  /// Patient présélectionné (depuis le dossier médical).
  final Patient? patient;

  @override
  State<EncaisserScreen> createState() => _EncaisserScreenState();
}

class _EncaisserScreenState extends State<EncaisserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();

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
    _amountController.dispose();
    _reasonController.dispose();
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

  Future<void> _generateQrCode() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    final reason = _reasonController.text.trim();
    final app = widget.app;

    // Bornes imposées par l'API (100 – 1 000 000 FCFA).
    if (amount < 100 || amount > 1000000) {
      _snack('Le montant doit être compris entre 100 et 1 000 000 FCFA.',
          color: YamColors.danger);
      return;
    }

    // ── Mode démo (aucun AppState) : comportement historique ──
    if (app == null) {
      debugPrint('Génération QR : $phone, $amount FCFA, $reason');
      _snack('Génération du lien de paiement en cours...');
      return;
    }

    // ── Mode réel : route argent (démo si ApiConfig.moneyDemo) ──
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

      final result = await app.kproEncaisser(
        patientId: patientId,
        montant: amount,
        motif: reason,
      );

      if (!mounted) return;
      // Réponse démo : {ok, message, transaction:{reference, statut,…}, qr_data}
      final tx = result['transaction'];
      final map = tx is Map ? tx.cast<String, dynamic>() : result;
      final reference =
          (map['reference'] ?? result['reference'] ?? '—').toString();
      final statut =
          (map['statut'] ?? result['statut'] ?? 'en_attente').toString();
      final message = (result['message'] ?? '').toString();

      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: YamColors.surface,
          shape: const RoundedRectangleBorder(borderRadius: kCardRadius),
          title: const Text(
            'Demande d\'encaissement créée',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, color: YamColors.text),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dialogRow('Référence', reference),
              _dialogRow('Montant', '$amount FCFA'),
              _dialogRow('Statut', statut),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                      fontSize: 12.5, color: YamColors.muted, height: 1.4),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      _snack('$e', color: YamColors.danger);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _dialogRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: YamColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: YamColors.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.showAppBar) ...[
              const SizedBox(height: 4),
              const Text(
                'Encaisser',
                style: TextStyle(
                  color: YamColors.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 4),
            ],
            // Sous-titre
            const Text(
              'Générez un QR de paiement direct pour le patient.',
              style: TextStyle(
                fontSize: 14,
                color: YamColors.muted,
              ),
            ),
            const SizedBox(height: 20),

            // Champ: Numéro du patient
            const Text(
              'Numéro du patient',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: YamColors.text,
              ),
            ),
            const SizedBox(height: 8),
            IntlPhoneField(
              controller: _phoneController,
              initialCountryCode: 'TG',
              keyboardType: TextInputType.phone,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
                color: YamColors.text,
              ),
              invalidNumberMessage: 'Numéro de téléphone invalide',
              decoration: InputDecoration(
                hintText: 'Ex: 90 00 00 00',
                filled: true,
                fillColor: YamColors.surface,
                contentPadding: const EdgeInsets.all(16),
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
                  borderSide:
                      const BorderSide(color: YamColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Champ: Montant à encaisser
            const Text(
              'Montant à encaisser',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: YamColors.text,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: YamColors.primary,
              ),
              decoration: InputDecoration(
                suffixText: 'FCFA',
                suffixStyle: const TextStyle(
                  color: YamColors.muted,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                hintText: '0',
                filled: true,
                fillColor: YamColors.surface,
                contentPadding: const EdgeInsets.all(16),
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
                  borderSide:
                      const BorderSide(color: YamColors.primary, width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Veuillez entrer un montant';
                }
                if (double.tryParse(value) == null) {
                  return 'Montant invalide';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Champ: Motif (optionnel)
            const Text(
              'Motif (optionnel)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: YamColors.text,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _reasonController,
              keyboardType: TextInputType.multiline,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Ex: Consultation, bilan ou acte médical...',
                filled: true,
                fillColor: YamColors.surface,
                contentPadding: const EdgeInsets.all(16),
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
                  borderSide:
                      const BorderSide(color: YamColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Bouton générer
            FilledButton(
              onPressed: _saving ? null : _generateQrCode,
              style: FilledButton.styleFrom(
                backgroundColor: YamColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const RoundedRectangleBorder(
                  borderRadius: kButtonRadius,
                ),
                elevation: 0,
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
                  : const Text(
                      'Générer le QR de paiement',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showAppBar) {
      return _buildForm();
    }

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
          'Encaisser',
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
        child: _buildForm(),
      ),
    );
  }
}
