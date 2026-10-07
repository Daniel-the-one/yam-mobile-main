import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../theme.dart';

/// Boîte de dialogue pour recharger le portefeuille.
class RechargeWalletDialog extends StatefulWidget {
  const RechargeWalletDialog({super.key, required this.app});

  final AppState app;

  @override
  State<RechargeWalletDialog> createState() => _RechargeWalletDialogState();
}

class _RechargeWalletDialogState extends State<RechargeWalletDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.app.userPhone.isNotEmpty) {
      _phoneController.text = widget.app.userPhone;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

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

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    final phone = _phoneController.text.trim();

    if (amount <= 0) {
      _snack('Veuillez entrer un montant valide.', color: YamColors.danger);
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await widget.app.rechargeWallet(
        montant: amount,
        phoneNumber: phone.isEmpty ? null : phone,
        idempotencyKey: 'recharge-${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      Navigator.pop(context);
      _snack('Recharge de $amount FCFA initiée avec succès !');
    } catch (e) {
      _snack('$e', color: YamColors.danger);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: YamColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: kCardRadius),
      title: const Text(
        'Recharger le portefeuille',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: YamColors.text),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Montant (FCFA)',
                hintText: 'Ex: 10000',
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Numéro de téléphone (Mobile Money)',
                hintText: 'Ex: +228 90 00 00 00',
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: YamColors.primary),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Valider'),
        ),
      ],
    );
  }
}

/// Boîte de dialogue pour envoyer (transférer) de l'argent.
class SendMoneyDialog extends StatefulWidget {
  const SendMoneyDialog({super.key, required this.app});

  final AppState app;

  @override
  State<SendMoneyDialog> createState() => _SendMoneyDialogState();
}

class _SendMoneyDialogState extends State<SendMoneyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    super.dispose();
  }

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

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    final recipient = _recipientController.text.trim();

    if (amount <= 0) {
      _snack('Veuillez entrer un montant valide.', color: YamColors.danger);
      return;
    }

    setState(() => _loading = true);
    try {
      await widget.app.transferWallet(
        montant: amount,
        recipient: recipient,
        idempotencyKey: 'transfer-${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      Navigator.pop(context);
      _snack('Transfert de $amount FCFA effectué avec succès !');
    } catch (e) {
      _snack('$e', color: YamColors.danger);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: YamColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: kCardRadius),
      title: const Text(
        'Envoyer de l\'argent',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: YamColors.text),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _recipientController,
              decoration: const InputDecoration(
                labelText: 'Destinataire (Téléphone ou ID)',
                hintText: 'Ex: +228 90 00 00 00',
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Montant (FCFA)',
                hintText: 'Ex: 5000',
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: YamColors.primary),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Envoyer'),
        ),
      ],
    );
  }
}

/// Boîte de dialogue pour retirer de l'argent.
class WithdrawMoneyDialog extends StatefulWidget {
  const WithdrawMoneyDialog({super.key, required this.app});

  final AppState app;

  @override
  State<WithdrawMoneyDialog> createState() => _WithdrawMoneyDialogState();
}

class _WithdrawMoneyDialogState extends State<WithdrawMoneyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.app.userPhone.isNotEmpty) {
      _phoneController.text = widget.app.userPhone;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

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

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    final phone = _phoneController.text.trim();

    if (amount <= 0) {
      _snack('Veuillez entrer un montant valide.', color: YamColors.danger);
      return;
    }

    setState(() => _loading = true);
    try {
      await widget.app.withdrawWallet(
        montant: amount,
        phoneNumber: phone.isEmpty ? null : phone,
        idempotencyKey: 'withdraw-${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      Navigator.pop(context);
      _snack('Retrait de $amount FCFA initié avec succès !');
    } catch (e) {
      _snack('$e', color: YamColors.danger);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: YamColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: kCardRadius),
      title: const Text(
        'Retirer des fonds',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: YamColors.text),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Montant (FCFA)',
                hintText: 'Ex: 10000',
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Numéro de réception (Mobile Money)',
                hintText: 'Ex: +228 90 00 00 00',
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: YamColors.primary),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Retirer'),
        ),
      ],
    );
  }
}
