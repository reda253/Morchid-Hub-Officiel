import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../routes/app_routes.dart';
import '../services/storage_service.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_colors.dart';
import '../widgets/motion.dart';
import '../widgets/ui_kit.dart';

/// Présentation de première ouverture : accueil + trois pages de découverte.
///
/// **Un seul parcours, pas deux écrans.** Un écran d'accueil qui pousse ensuite
/// vers un carrousel demande un tap de plus pour arriver au même endroit. Ici
/// la première page *est* l'accueil — fond de marque, symbole, promesse — et
/// les trois suivantes expliquent, dans le même geste de balayage.
///
/// **Les illustrations sont le produit lui-même.** Chaque page montre un
/// fragment réel de l'interface (le badge vérifié tel qu'il apparaîtra dans la
/// recherche, un tracé d'itinéraire, l'éco-score) plutôt qu'un dessin
/// décoratif. On promet moins et on montre plus : l'utilisateur reconnaîtra
/// ces éléments dix minutes plus tard.
///
/// **Le fond glisse du bleu au clair** au fil du premier balayage, au lieu de
/// couper. Comme l'écran de démarrage est déjà Atlantic Blue, l'application
/// s'ouvre sur une seule couleur continue et éclaircit quand elle commence à
/// expliquer.
///
/// C'est un écran vu **une fois** : c'est la seule catégorie où un peu de soin
/// gratuit se justifie. Tout ce qui est vu tous les jours reste sobre.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  static const int _count = 4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Position continue dans le carrousel. `page` n'est lisible qu'une fois la
  /// première passe de layout faite, d'où la garde sur [ScrollPosition.haveDimensions].
  double get _offset =>
      (_controller.hasClients && _controller.position.haveDimensions)
          ? (_controller.page ?? 0)
          : 0;

  Future<void> _leaveFor(String route) async {
    await StorageService.markOnboardingSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(route);
  }

  void _next() {
    _controller.nextPage(duration: AppMotion.enter, curve: AppMotion.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    // Rebâti à chaque frame du balayage : le fond, le texte et les boutons
    // s'interpolent tous sur la même position, donc rien ne se désynchronise.
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final page = _offset;
        // 0 = page d'accueil (fond de marque), 1 et au-delà = fond clair.
        final t = page.clamp(0.0, 1.0);

        final ground = Color.lerp(AppColors.primary, AppColors.background, t)!;
        final onGround = Color.lerp(AppColors.onPrimary, AppColors.ink, t)!;
        final onGroundSoft = Color.lerp(
          AppColors.onPrimary.withValues(alpha: 0.74),
          AppColors.textLight,
          t,
        )!;
        final ctaBackground = Color.lerp(AppColors.sand, AppColors.primary, t)!;
        final ctaForeground = Color.lerp(AppColors.secondary, AppColors.onPrimary, t)!;
        final railOn = Color.lerp(AppColors.sand, AppColors.primary, t)!;
        final railOff = Color.lerp(
          AppColors.onPrimary.withValues(alpha: 0.32),
          AppColors.outline,
          t,
        )!;

        final isLast = page > _count - 1.5;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          // Les icônes de la barre système suivent le fond : claires sur le
          // bleu, sombres sur le clair.
          value: t < 0.5
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          child: Scaffold(
            backgroundColor: ground,
            body: SafeArea(
              child: Column(
                children: [
                  _buildSkip(page, onGroundSoft),
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: _count,
                      itemBuilder: (context, index) => _buildPage(
                        index: index,
                        page: page,
                        onGround: onGround,
                        onGroundSoft: onGroundSoft,
                      ),
                    ),
                  ),
                  _buildFooter(
                    page: page,
                    isLast: isLast,
                    railOn: railOn,
                    railOff: railOff,
                    ctaBackground: ctaBackground,
                    ctaForeground: ctaForeground,
                    onGroundSoft: onGroundSoft,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── « Passer » ────────────────────────────────────────────────────────────

  /// S'efface sur la dernière page, où il ferait doublon avec « J'ai déjà un
  /// compte » — et où il n'y a plus rien à passer.
  Widget _buildSkip(double page, Color color) {
    final visible = (1 - (page - (_count - 2))).clamp(0.0, 1.0);

    // Hauteur réservée mais enfant retiré une fois invisible : un bouton à
    // opacité nulle resterait dans l'arbre, donc atteignable au lecteur
    // d'écran et au parcours au clavier.
    return SizedBox(
      height: 48,
      child: Align(
        alignment: Alignment.centerRight,
        child: visible < 0.02
            ? const SizedBox.shrink()
            : Opacity(
                opacity: visible,
                child: TextButton(
                  onPressed: () => _leaveFor(AppRoutes.login),
                  style: TextButton.styleFrom(foregroundColor: color),
                  child: Text(
                    'Passer',
                    style: AppTextStyles.bodySm.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // ── Pages ─────────────────────────────────────────────────────────────────

  /// Le contenu se déplace moins vite que la page et s'estompe sur les côtés :
  /// la profondeur vient du geste de l'utilisateur, pas d'une animation jouée
  /// pour elle-même. Neutralisé quand le système demande moins de mouvement.
  Widget _buildPage({
    required int index,
    required double page,
    required Color onGround,
    required Color onGroundSoft,
  }) {
    final delta = index - page;
    final reduced = AppMotion.reduced(context);
    final opacity = (1 - delta.abs()).clamp(0.0, 1.0);

    final content = index == 0
        ? _buildWelcome(onGround, onGroundSoft)
        : _buildFeature(index, onGround, onGroundSoft);

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: reduced ? Offset.zero : Offset(delta * 56, 0),
        // Centré tant qu'il y a la place, défilable sinon. Sans cela un petit
        // écran — ou simplement une taille de texte système agrandie — coupe
        // le bas du paragraphe, ce qui est le pire endroit où le perdre.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  /// Page d'accueil : reprend exactement la composition de l'écran de
  /// démarrage — même symbole, même signature — et n'y ajoute qu'une phrase.
  /// L'application ne se présente pas deux fois différemment.
  Widget _buildWelcome(Color onGround, Color onGroundSoft) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppLogo(
          size: 76,
          showWordmark: false,
          color: AppColors.onPrimary,
          monochrome: true,
        ),
        const SizedBox(height: 32),
        Text(
          'Morchid Hub',
          style: AppTextStyles.displayMd.copyWith(
            color: onGround,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Le Maroc, guidé autrement',
          style: AppTextStyles.titleMd.copyWith(color: AppColors.sand),
        ),
        const SizedBox(height: 22),
        Text(
          'Des guides officiels vérifiés, des itinéraires que vous voyez '
          'avant de partir, et un tourisme qui laisse le pays intact.',
          style: AppTextStyles.bodyLg.copyWith(color: onGroundSoft, height: 1.55),
        ),
      ],
    );
  }

  Widget _buildFeature(int index, Color onGround, Color onGroundSoft) {
    late final Widget plate;
    late final String title;
    late final String body;

    switch (index) {
      case 1:
        plate = const _VerifiedGuidePlate();
        title = 'Des guides officiels,\nvérifiés un par un';
        // Décrit le processus réel : licence + pièce d'identité contrôlées, et
        // invisibilité dans la recherche tant que le compte n'est pas approuvé.
        body = 'Licence professionnelle et pièce d\'identité contrôlées par '
            'notre équipe. Un guide n\'apparaît dans la recherche qu\'une fois '
            'approuvé.';
        break;
      case 2:
        plate = const _RoutePlate();
        title = 'Des itinéraires tracés\nsur la carte';
        body = 'Chaque guide publie son parcours point par point. Vous voyez '
            'où vous allez avant de le contacter, pas après.';
        break;
      default:
        plate = const _EcoScorePlate();
        title = 'Un éco-score\nsur chaque guide';
        body = 'Transport, taille des groupes, sites visités : chaque guide '
            'porte une note publique. Vous savez ce que votre visite laisse '
            'derrière elle.';
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        plate,
        const SizedBox(height: 30),
        Text(
          title,
          style: AppTextStyles.headlineLg.copyWith(
            color: onGround,
            fontSize: 27,
            height: 1.2,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          body,
          style: AppTextStyles.bodyLg.copyWith(color: onGroundSoft, height: 1.55),
        ),
      ],
    );
  }

  // ── Pied : progression + actions ──────────────────────────────────────────

  Widget _buildFooter({
    required double page,
    required bool isLast,
    required Color railOn,
    required Color railOff,
    required Color ctaBackground,
    required Color ctaForeground,
    required Color onGroundSoft,
  }) {
    final secondaryVisible = ((page - (_count - 2)).clamp(0.0, 1.0));

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ProgressRail(page: page, count: _count, on: railOn, off: railOff),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLast ? () => _leaveFor(AppRoutes.signup) : _next,
              style: ElevatedButton.styleFrom(
                backgroundColor: ctaBackground,
                foregroundColor: ctaForeground,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              // Le libellé change de sens à la dernière page ; un fondu court
              // évite que le mot se substitue brutalement sous le doigt.
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: Text(
                  isLast ? 'Créer un compte' : 'Suivant',
                  key: ValueKey(isLast),
                  style: AppTextStyles.bodyLg.copyWith(
                    color: ctaForeground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          // Emplacement réservé en permanence : faire apparaître un bouton
          // ferait remonter toute la colonne au dernier balayage.
          SizedBox(
            height: 44,
            child: secondaryVisible < 0.02
                ? null
                : Opacity(
                    opacity: secondaryVisible,
                    child: Center(
                      child: TextButton(
                        onPressed: () => _leaveFor(AppRoutes.login),
                        child: Text(
                          'J\'ai déjà un compte',
                          style: AppTextStyles.bodySm.copyWith(
                            color: onGroundSoft,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Progression ─────────────────────────────────────────────────────────────

/// Rail segmenté plutôt que trois points : les points sont le réflexe par
/// défaut de tout carrousel d'introduction. Le segment actif s'allonge, ce qui
/// dit la position *et* l'avancement.
class _ProgressRail extends StatelessWidget {
  final double page;
  final int count;
  final Color on;
  final Color off;

  const _ProgressRail({
    required this.page,
    required this.count,
    required this.on,
    required this.off,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          // Suit la position continue : le segment s'allonge pendant le
          // balayage, il ne saute pas au relâchement.
          Builder(builder: (_) {
            final proximity = (1 - (page - i).abs()).clamp(0.0, 1.0);
            return Container(
              width: 7 + 17 * proximity,
              height: 4,
              decoration: BoxDecoration(
                color: Color.lerp(off, on, proximity),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ],
      ],
    );
  }
}

// ── Plaques : des fragments réels de l'interface ────────────────────────────

/// Fond commun des plaques. Volontairement neutre : c'est le fragment posé
/// dessus qui doit se voir, pas le cadre.
class _Plate extends StatelessWidget {
  final Widget child;
  const _Plate({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 178,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(child: child),
    );
  }
}

/// Le badge « VÉRIFIÉ » exactement tel qu'il apparaîtra dans les résultats de
/// recherche — même composant que la vraie carte guide.
class _VerifiedGuidePlate extends StatelessWidget {
  const _VerifiedGuidePlate();

  @override
  Widget build(BuildContext context) {
    return _Plate(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            const DefaultAvatar(fullName: 'Youssef Amrani', radius: 24, fontSize: 17),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Youssef Amrani',
                      style: AppTextStyles.titleSm,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('Marrakech · 8 ans',
                      style: AppTextStyles.bodyXs,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  const VerifiedBadge(label: 'VÉRIFIÉ'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un tracé d'itinéraire, dans la même langue graphique que l'écran de carte :
/// polyligne à segments droits (ce que renvoie le routage), pas une courbe
/// décorative.
class _RoutePlate extends StatelessWidget {
  const _RoutePlate();

  @override
  Widget build(BuildContext context) {
    return _Plate(
      child: CustomPaint(
        size: const Size(double.infinity, 148),
        painter: _RoutePainter(),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  // Repère unitaire : le tracé s'adapte à la largeur sans se déformer.
  static const List<Offset> _points = [
    Offset(0.07, 0.74),
    Offset(0.27, 0.38),
    Offset(0.46, 0.56),
    Offset(0.67, 0.22),
    Offset(0.93, 0.40),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    Offset at(Offset p) => Offset(p.dx * size.width, p.dy * size.height);

    // Trame de repère, très en retrait : elle situe le tracé sans se lire.
    final grid = Paint()..color = AppColors.cardBorder;
    for (double x = 10; x < size.width; x += 20) {
      for (double y = 8; y < size.height; y += 20) {
        canvas.drawCircle(Offset(x, y), 1, grid);
      }
    }

    final path = Path()..moveTo(at(_points.first).dx, at(_points.first).dy);
    for (final point in _points.skip(1)) {
      path.lineTo(at(point).dx, at(point).dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );

    // Départ en vert, arrivée en bleu, tous deux cerclés de blanc pour se
    // détacher du tracé qu'ils terminent.
    void marker(Offset position, Color color) {
      canvas.drawCircle(position, 7, Paint()..color = AppColors.surface);
      canvas.drawCircle(position, 4.5, Paint()..color = color);
    }

    marker(at(_points.first), AppColors.mint);
    marker(at(_points.last), AppColors.primary);
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) => false;
}

/// L'éco-score dans la typographie des chiffres de l'application, avec une
/// jauge segmentée — une barre pleine arrondie serait le repli générique.
class _EcoScorePlate extends StatelessWidget {
  const _EcoScorePlate();

  static const int _segments = 10;
  static const int _filled = 8;

  @override
  Widget build(BuildContext context) {
    return _Plate(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ÉCO-SCORE', style: AppTextStyles.labelCaps.copyWith(fontSize: 11)),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '84',
                style: AppTextStyles.numberXl.copyWith(
                  fontSize: 40,
                  height: 1.0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '/100',
                style: AppTextStyles.bodySm.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              for (var i = 0; i < _segments; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: i < _filled ? AppColors.mint : AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
