import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import 'dossier_medical_screen.dart';
import 'encaisser_screen.dart';
import 'facture_liste_screen.dart';
import 'ordonnance_liste_screen.dart';
import 'wallet_dialogs.dart';

/// Accueil : solde + grille d'accès rapide.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.app});

  final AppState app;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _WalletCard(app: widget.app),
        const SizedBox(height: 20),
        const Text(
          'Services rapides',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: YamColors.text,
          ),
        ),
        const SizedBox(height: 12),
        _QuickAccessGrid(app: widget.app),
      ],
    );
  }
}

class _WalletCard extends StatefulWidget {
  const _WalletCard({required this.app});

  final AppState app;

  @override
  State<_WalletCard> createState() => _WalletCardState();
}

class _WalletCardState extends State<_WalletCard> {
  bool _isHidden = false;
  String _balance = '—';
  bool _loadingBalance = true;

  @override
  void initState() {
    super.initState();
    _refreshBalance();
  }

  /// Charge le solde réel depuis l'API wallet (`GET /api/v1/wallet` ou
  /// `/api/demo/v1/wallet` selon [ApiConfig.moneyDemo]).
  Future<void> _refreshBalance() async {
    try {
      final res = await widget.app.fetchWallet();
      final wallet = res?['wallet'];
      final raw = wallet is Map ? wallet['solde_raw'] : null;
      final amount = int.tryParse('$raw') ?? 0;
      if (mounted) {
        setState(() {
          _balance = _formatAmount(amount);
          _loadingBalance = false;
        });
      }
    } catch (e) {
      debugPrint('[YAM][WALLET] solde indisponible : $e');
      if (mounted) {
        setState(() {
          _balance = '—';
          _loadingBalance = false;
        });
      }
    }
  }

  /// Formate un montant avec séparateur de milliers : `50000` → `50 000 F`.
  static String _formatAmount(int amount) {
    final digits = amount.toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    return '$buf F';
  }

  Future<void> _onRecharge(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => RechargeWalletDialog(app: widget.app),
    );
    _refreshBalance();
  }

  Future<void> _onSend(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => SendMoneyDialog(app: widget.app),
    );
    _refreshBalance();
  }

  Future<void> _onWithdraw(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => WithdrawMoneyDialog(app: widget.app),
    );
    _refreshBalance();
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: YamColors.primary,
        borderRadius: kCardRadius,
        boxShadow: [
          BoxShadow(
            color: YamColors.primary.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Solde disponible',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _isHidden
                    ? "•••••• F"
                    : (_loadingBalance ? '…' : _balance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => setState(() => _isHidden = !_isHidden),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isHidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _refreshBalance,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: Center(
                  child: _buildActionButton(
                    context: context,
                    icon: Icons.add_rounded,
                    label: 'Recharger',
                    onTap: () => _onRecharge(context),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: _buildActionButton(
                    context: context,
                    icon: Icons.send_rounded,
                    label: 'Envoyer',
                    onTap: () => _onSend(context),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: _buildActionButton(
                    context: context,
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Retirer',
                    onTap: () => _onWithdraw(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAccessGrid extends StatelessWidget {
  const _QuickAccessGrid({this.app});

  final AppState? app;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.25,
      children: [
        _GridCard(
          title: 'Dossier médical',
          subtitle: 'Patients et suivis',
          icon: Icons.folder_shared_rounded,
          iconColor: YamColors.primary,
          iconBgColor: YamColors.primarySoft,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DossierMedicalScreen(app: app)),
          ),
        ),
        _GridCard(
          title: 'Encaisser',
          subtitle: 'Lien QR de paiement',
          icon: Icons.qr_code_rounded,
          iconColor: YamColors.primary,
          iconBgColor: YamColors.primarySoft,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EncaisserScreen(app: app)),
          ),
        ),
        _GridCard(
          title: 'Facturer',
          subtitle: 'Créer une facture',
          icon: Icons.receipt_long_rounded,
          iconColor: YamColors.accent,
          iconBgColor: YamColors.accentSoft,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => FactureListeScreen(app: app)),
          ),
        ),
        _GridCard(
          title: 'Ordonnance',
          subtitle: 'Prescription rapide',
          icon: Icons.medication_rounded,
          iconColor: YamColors.primary,
          iconBgColor: YamColors.primarySoft,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => OrdonnanceListeScreen(app: app)),
          ),
        ),
      ],
    );
  }
}

class _GridCard extends StatelessWidget {
  const _GridCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  color: YamColors.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: YamColors.muted,
                  fontSize: 11,
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
