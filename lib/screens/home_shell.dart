import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'call_hub_screen.dart';
import 'dossier_medical_screen.dart';
import 'encaisser_screen.dart';
import 'home_screen.dart';

// ─── Constantes de la barre ───────────────────────────────────────────────────

/// Hauteur de la barre proprement dite (hors safe area et zone de survol).
const double _kNavBarHeight = 62.0;

/// Rayon du bouton Accueil circulaire.
const double _kHomeButtonRadius = 28.0;

/// Nombre de pixels dont le dôme dépasse AU-DESSUS du bord haut de la barre.
const double _kButtonRise = 18.0;

/// Marge à gauche du bouton Accueil (espace de sécurité avec le bord de l'écran).
const double _kButtonLeftMargin = 24.0;

/// Largeur réservée au dôme dans le Row des onglets.
const double _kNotchReservedWidth = 98.0;

// ── Coquille principale : en-tête + 4 onglets + overlays d'appel. ───────────
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.app});

  final AppState app;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final bp = MediaQuery.of(context).padding.bottom;

    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        // Hauteur totale occupée par la barre dans le layout
        final navTotalHeight = _kNavBarHeight + bp;

        return Scaffold(
          backgroundColor: YamColors.pageBg,
          // Pas de bottomNavigationBar → le Stack body gère tout.
          body: SafeArea(
            bottom: false,
            child: Stack(
              // Clip.none : permet au bouton vert de dépasser vers le haut.
              clipBehavior: Clip.none,
              children: [
                // ── Contenu principal ──────────────────────────────────────
                Column(
                  children: [
                    _Header(app: app),
                    Expanded(
                      child: IndexedStack(
                        index: _tab,
                        children: [
                          HomeScreen(app: app),
                          DossierMedicalScreen(app: app, showAppBar: false),
                          EncaisserScreen(showAppBar: false, app: app),
                          ProfilScreen(app: app),
                        ],
                      ),
                    ),
                    // Réserve la place pour la barre (le contenu ne se cache pas derrière)
                    SizedBox(height: navTotalHeight),
                  ],
                ),

                // ── Barre de navigation (intégrée dans le Stack) ───────────
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _CustomBottomNav(
                    currentIndex: _tab,
                    onTap: (i) => setState(() => _tab = i),
                  ),
                ),

                // ── FAB Appels (au-dessus de la barre) ────────────────────
                Positioned(
                  right: 16,
                  bottom: navTotalHeight + 12,
                  child: FloatingActionButton(
                    backgroundColor: YamColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shape: const CircleBorder(),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => CallHubScreen(app: app)),
                      );
                    },
                    child: Badge(
                      isLabelVisible: app.missedCount > 0,
                      offset: const Offset(10, -8),
                      backgroundColor: YamColors.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      label: Text('${app.missedCount}'),
                      child: Image.asset(
                        'assets/images/appel.png',
                        width: 26,
                        height: 26,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── En-tête ──────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: YamColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: YamColors.primarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.local_hospital_rounded,
              color: YamColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Yam',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: YamColors.text,
            ),
          ),
          const Spacer(),
          CircleAvatar(
            radius: 16,
            backgroundColor: YamColors.primarySoft,
            child: Text(
              app.userName.isNotEmpty ? app.userName[0].toUpperCase() : 'U',
              style: const TextStyle(
                color: YamColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Barre de navigation incurvée ─────────────────────────────────────────────
class _CustomBottomNav extends StatelessWidget {
  const _CustomBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bp = MediaQuery.of(context).padding.bottom;
    final totalHeight = _kNavBarHeight + bp + _kButtonRise;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Fond de la barre (commence à y = _kButtonRise) ────────────────
          Positioned(
            top: _kButtonRise,
            left: 0,
            right: 0,
            bottom: 0,
            child: CustomPaint(
              painter: _CurvedNavPainter(),
            ),
          ),

          // ── Rangée de contenu : espace réservé encoche + onglets ──────────
          Positioned(
            top: _kButtonRise,
            left: 0,
            right: 0,
            height: _kNavBarHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Espace réservé à l'encoche (pour ne pas chevaucher les onglets)
                const SizedBox(width: _kNotchReservedWidth),

                // Onglets plats : Patients, Finances, Profil
                Expanded(
                  child: Row(
                    children: [
                      _FlatTab(
                        index: 1,
                        label: 'Patients',
                        icon: Icons.people_alt_outlined,
                        activeIcon: Icons.people_alt_rounded,
                        currentIndex: currentIndex,
                        onTap: onTap,
                      ),
                      _FlatTab(
                        index: 2,
                        label: 'Finances',
                        icon: Icons.account_balance_wallet_outlined,
                        activeIcon: Icons.account_balance_wallet_rounded,
                        currentIndex: currentIndex,
                        onTap: onTap,
                      ),
                      _FlatTab(
                        index: 3,
                        label: 'Profil',
                        icon: Icons.person_outline_rounded,
                        activeIcon: Icons.person_rounded,
                        currentIndex: currentIndex,
                        onTap: onTap,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Remplissage safe area en bas ──────────────────────────────────
          if (bp > 0)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: bp,
              child: const ColoredBox(color: YamColors.surface),
            ),

          // ── Bouton Accueil : remonté à top: 2.0 px ────────────────────────
          Positioned(
            top: 2.0,
            left: _kButtonLeftMargin,
            child: _HomeButton(
              isActive: currentIndex == 0,
              onTap: () => onTap(0),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── CustomPainter : dôme épousant le bouton circulaire d'Accueil ─────────────
class _CurvedNavPainter extends CustomPainter {
  static const double _cx = _kButtonLeftMargin + _kHomeButtonRadius; // 52.0
  static const double _domeSpan = 38.0; // Vague de x=14 à x=90
  static const double _domeHeight = 20.0; // Dôme montant au-dessus du bouton (y = -20)

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);

    // Ombre portée douce sous la barre et sa bosse
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.10), 8, false);

    // Fond surface (blanc)
    canvas.drawPath(
      path,
      Paint()
        ..color = YamColors.surface
        ..style = PaintingStyle.fill,
    );

    // Bordure supérieure fine tracée le long de la ligne et du dôme
    canvas.drawPath(
      path,
      Paint()
        ..color = YamColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  Path _buildPath(Size size) {
    final path = Path();

    final xStart = _cx - _domeSpan; // 14.0
    final xEnd = _cx + _domeSpan;   // 90.0

    // Départ coin supérieur gauche
    path.moveTo(0, 0);

    // Ligne plate jusqu'au début de la bosse (x = 14.0)
    path.lineTo(xStart, 0);

    // Bosse / Vague arrondie montant au-dessus du bouton (y = -_domeHeight)
    path.cubicTo(
      _cx - _domeSpan * 0.5, 0,
      _cx - _domeSpan * 0.5, -_domeHeight,
      _cx, -_domeHeight,
    );

    // Vague redescendant vers la ligne plate de la barre (y = 0)
    path.cubicTo(
      _cx + _domeSpan * 0.5, -_domeHeight,
      _cx + _domeSpan * 0.5, 0,
      xEnd, 0,
    );

    // Ligne vers le coin droit
    path.lineTo(size.width, 0);

    // Rectangle bas et retour au départ
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Bouton Accueil circulaire ─────────────────────────────────────────────────
class _HomeButton extends StatelessWidget {
  const _HomeButton({required this.isActive, required this.onTap});

  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: _kHomeButtonRadius * 2,
        height: _kHomeButtonRadius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: YamColors.primary,
          boxShadow: [
            BoxShadow(
              color: YamColors.primary.withValues(alpha: isActive ? 0.40 : 0.20),
              blurRadius: 14,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: Icon(
              isActive ? Icons.home_rounded : Icons.home_outlined,
              key: ValueKey(isActive),
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Onglet plat (Patients / Finances / Profil) ────────────────────────────────
class _FlatTab extends StatelessWidget {
  const _FlatTab({
    required this.index,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.currentIndex,
    required this.onTap,
  });

  final int index;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = currentIndex == index;
    final color = isActive ? YamColors.primary : YamColors.muted;

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: color,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Écran Profil ──────────────────────────────────────────────────────────────
class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key, required this.app});

  final AppState app;

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  /// Profil médecin renvoyé par `GET /api/medecin.php` (famille réelle).
  Map<String, dynamic>? _medecin;

  /// Solde KondjiPay — route argent centralisée dans [ApiConfig] (démo tant
  /// que `moneyDemo` est vrai).
  int? _solde;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    Map<String, dynamic>? medecin;
    int? solde;
    String? error;

    // 1. Profil médecin (API médicale — réelle) + solde embarqué.
    try {
      final res = await widget.app.kpro.medecinProfil();
      final m = res['medecin'];
      if (m is Map) medecin = m.cast<String, dynamic>();
      final embedded = res['solde'];
      if (embedded != null) solde = int.tryParse('$embedded');
    } catch (e) {
      error = '$e';
    }

    // 2. Solde via la route argent centralisée (point de bascule démo/réel).
    try {
      solde = await widget.app.kproSolde();
    } catch (e) {
      error ??= '$e';
    }

    if (!mounted) return;
    setState(() {
      _medecin = medecin;
      _solde = solde;
      _error = error;
      _loading = false;
    });
  }

  String get _specialite {
    final s = (_medecin?['specialite'] ?? '').toString();
    return s.isNotEmpty ? s : '';
  }

  String get _medecinNom {
    final prenom = (_medecin?['prenom'] ?? '').toString();
    final nom = (_medecin?['nom'] ?? '').toString();
    final full = '$prenom $nom'.trim();
    return full.isNotEmpty ? full : '';
  }

  Widget _buildSoldeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: YamColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: YamColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: YamColors.accentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: YamColors.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Solde KondjiPay',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: YamColors.muted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (ApiConfig.moneyDemo)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: YamColors.accentSoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'DÉMO',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: YamColors.accent,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (_loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: YamColors.primary),
                  )
                else
                  Text(
                    _solde != null ? '${_solde!} FCFA' : '— indisponible',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: YamColors.text,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Recharger',
            icon: const Icon(Icons.refresh_rounded,
                size: 20, color: YamColors.muted),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final initial = app.userName.isNotEmpty ? app.userName[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: YamColors.pageBg,
      appBar: AppBar(
        title: const Text(
          'Mon Profil',
          style: TextStyle(color: YamColors.text, fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: YamColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Card En-tête Utilisateur ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: YamColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: YamColors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: YamColors.primarySoft,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: YamColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.userName.isNotEmpty ? app.userName : 'Utilisateur Yam',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: YamColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (app.userPhone.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.phone_outlined, size: 14, color: YamColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              app.userPhone,
                              style: const TextStyle(
                                color: YamColors.text,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 2),
                      if (app.userId.isNotEmpty)
                        Text(
                          'ID Compte : #${app.userId}',
                          style: mono(size: 12, color: YamColors.muted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Carte Solde KondjiPay (route argent — démo/réel) ──
          _buildSoldeCard(),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: YamColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: YamColors.danger.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: YamColors.danger, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(fontSize: 12, color: YamColors.text),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // ── Card Informations détaillées ──
          Container(
            decoration: BoxDecoration(
              color: YamColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: YamColors.border),
            ),
            child: Column(
              children: [
                _buildInfoTile(
                  icon: Icons.person_outline_rounded,
                  label: 'Nom & Prénom',
                  value: app.userName.isNotEmpty ? app.userName : 'Non renseigné',
                ),
                if (_medecinNom.isNotEmpty || _specialite.isNotEmpty) ...[
                  const Divider(height: 1, indent: 52, color: YamColors.border),
                  _buildInfoTile(
                    icon: Icons.medical_services_outlined,
                    label: 'Profil médical',
                    value: [
                      if (_medecinNom.isNotEmpty) _medecinNom,
                      if (_specialite.isNotEmpty) _specialite,
                    ].join(' — '),
                  ),
                ],
                const Divider(height: 1, indent: 52, color: YamColors.border),
                _buildInfoTile(
                  icon: Icons.phone_android_rounded,
                  label: 'Numéro de téléphone',
                  value: app.userPhone.isNotEmpty ? app.userPhone : 'Non renseigné',
                ),
                const Divider(height: 1, indent: 52, color: YamColors.border),
                _buildInfoTile(
                  icon: Icons.badge_outlined,
                  label: 'Identifiant utilisateur',
                  value: app.userId.isNotEmpty ? '#${app.userId}' : 'Non connecté',
                ),
                const Divider(height: 1, indent: 52, color: YamColors.border),
                _buildInfoTile(
                  icon: Icons.smartphone_rounded,
                  label: 'Identifiant de l’appareil',
                  value: app.deviceId,
                  isMono: true,
                ),
                const Divider(height: 1, indent: 52, color: YamColors.border),
                _buildInfoTile(
                  icon: Icons.dns_outlined,
                  label: 'Serveur principal',
                  value: app.serverUrl,
                  isMono: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Bouton Déconnexion ──
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: YamColors.danger.withValues(alpha: 0.1),
              foregroundColor: YamColors.danger,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: YamColors.danger, width: 1),
              ),
            ),
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: const Text(
              'Se déconnecter',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    bool isMono = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: YamColors.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: YamColors.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: isMono
                      ? mono(size: 13, color: YamColors.text)
                      : const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: YamColors.text,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter de votre compte ?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: YamColors.muted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: YamColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              widget.app.logout();
            },
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
  }
}
