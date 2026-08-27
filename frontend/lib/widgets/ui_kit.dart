import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../utils/app_colors.dart';

/// Bibliothèque de composants partagés du design system Stitch.
/// Importer via `import '../widgets/ui_kit.dart';`.

// ── Logo Morchid Hub (étoile zellij 8 branches + wordmark) ──────────────────
class AppLogo extends StatelessWidget {
  final double size;
  final bool showWordmark;
  final Color? color;
  const AppLogo({Key? key, this.size = 26, this.showWordmark = true, this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(size: Size(size, size), painter: _ZellijStarPainter(c)),
        if (showWordmark) ...[
          const SizedBox(width: 8),
          Text(
            'Morchid Hub',
            style: AppTextStyles.headlineMd.copyWith(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.ink),
          ),
        ],
      ],
    );
  }
}

/// Étoile à 8 branches (khatim) = deux carrés superposés à 45°.
class _ZellijStarPainter extends CustomPainter {
  final Color color;
  _ZellijStarPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color..style = PaintingStyle.fill;
    final cx = size.width / 2, cy = size.height / 2;
    final side = size.width * 0.74;
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: side, height: side);

    // Carré 1 (axe aligné)
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(1.5)), fill);
    // Carré 2 (pivoté 45°)
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(0.785398); // 45°
    canvas.translate(-cx, -cy);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(1.5)), fill);
    canvas.restore();

    // Trou central (contraste) — petit carré surface
    final hole = Paint()..color = AppColors.surface;
    final hr = side * 0.30;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy), width: hr, height: hr), const Radius.circular(1)),
      hole,
    );
  }

  @override
  bool shouldRepaint(covariant _ZellijStarPainter old) => old.color != color;
}

/// En-tête d'app standard : logo à gauche, action à droite, fond blanc + filet.
class AppHeaderBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget> actions;
  final bool showWordmark;
  const AppHeaderBar({Key? key, this.actions = const [], this.showWordmark = true}) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                AppLogo(showWordmark: showWordmark),
                const Spacer(),
                ...actions,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Carte expérience (image + scrim + pastille note) ────────────────────────
class ExperienceCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final String? priceLabel;
  final String? byline;
  final double? rating;
  final double height;
  final VoidCallback? onTap;

  const ExperienceCard({
    Key? key,
    required this.title,
    this.imageUrl,
    this.priceLabel,
    this.byline,
    this.rating,
    this.height = 220,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            BrandImage(url: imageUrl, height: height, radius: 0),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.62)],
                    stops: const [0.45, 1.0],
                  ),
                ),
              ),
            ),
            if (rating != null)
              Positioned(
                top: 12, left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, size: 15, color: AppColors.star),
                      const SizedBox(width: 3),
                      Text(rating!.toStringAsFixed(1),
                          style: AppTextStyles.labelCaps.copyWith(color: AppColors.ink, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            Positioned(
              left: 16, right: 16, bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: AppTextStyles.titleMd.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (priceLabel != null)
                        Text(priceLabel!,
                            style: AppTextStyles.titleMd.copyWith(color: Colors.white)),
                      const Spacer(),
                      if (byline != null)
                        Flexible(
                          child: Text(byline!,
                              style: AppTextStyles.bodySm.copyWith(color: Colors.white70),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Carte expert local (avatar + badge vérifié + note + citation) ───────────
class ExpertCard extends StatelessWidget {
  final String name;
  final String region;
  final String? avatarUrl;
  final bool verified;
  final double? rating;
  final int reviews;
  final String? quote;
  final VoidCallback? onTap;

  const ExpertCard({
    Key? key,
    required this.name,
    required this.region,
    this.avatarUrl,
    this.verified = false,
    this.rating,
    this.reviews = 0,
    this.quote,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.cardBorder, width: 2),
                  ),
                  child: ClipOval(
                    child: (avatarUrl != null && avatarUrl!.isNotEmpty)
                        ? Image.network(avatarUrl!, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _initial())
                        : _initial(),
                  ),
                ),
                if (verified)
                  Positioned(
                    right: -2, bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                      child: const Icon(Icons.verified, size: 18, color: AppColors.mint),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(name, style: AppTextStyles.titleMd, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(region, style: AppTextStyles.bodySm, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.star_rounded, size: 15, color: AppColors.star),
                const SizedBox(width: 3),
                Text(rating != null ? '${rating!.toStringAsFixed(1)} ($reviews)' : 'Nouveau',
                    style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink)),
              ],
            ),
            if (quote != null && quote!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('« $quote »',
                  style: AppTextStyles.bodySm.copyWith(fontStyle: FontStyle.italic),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }

  Widget _initial() => Container(
        color: AppColors.primary,
        alignment: Alignment.center,
        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: AppTextStyles.numberLg.copyWith(color: AppColors.onPrimary, fontSize: 24)),
      );
}

// ── Image de marque (photo réseau + repli dégradé zellij) ───────────────────
/// Affiche une image réseau ; en absence/erreur, un repli dégradé Atlantic Blue
/// → Sahara Sand avec une icône centrée — pour des cartes « image-rich » même
/// sans photo de trajet en base.
class BrandImage extends StatelessWidget {
  final String? url;
  final double height;
  final double radius;
  final IconData icon;

  const BrandImage({
    Key? key,
    this.url,
    this.height = 180,
    this.radius = 12,
    this.icon = Icons.landscape_outlined,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final child = (url != null && url!.isNotEmpty)
        ? Image.network(
            url!,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder(),
            loadingBuilder: (ctx, w, prog) => prog == null ? w : _placeholder(),
          )
        : _placeholder();
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: child);
  }

  Widget _placeholder() {
    return Container(
      height: height,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 40),
      ),
    );
  }
}

// ── Badge « VERIFIED » ──────────────────────────────────────────────────────
class VerifiedBadge extends StatelessWidget {
  final String label;
  const VerifiedBadge({Key? key, this.label = 'VERIFIED'}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.mint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.mint),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified, size: 13, color: AppColors.mint),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.labelCaps.copyWith(color: AppColors.mint, fontSize: 10)),
        ],
      ),
    );
  }
}

// ── En-tête de section (titre + action optionnelle) ─────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionHeader({Key? key, required this.title, this.actionLabel, this.onAction}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTextStyles.titleMd.copyWith(fontWeight: FontWeight.w700)),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(actionLabel!, style: AppTextStyles.bodySm.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

// ── Carte générique (bordure bleu-tint, radius 12) ──────────────────────────
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const AppCard({Key? key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: card);
  }
}

// ── Chip de filtre ──────────────────────────────────────────────────────────
class AppFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback? onTap;
  const AppFilterChip({Key? key, required this.label, this.selected = false, this.icon, this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : AppColors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: selected ? AppColors.onPrimary : AppColors.textLight),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTextStyles.bodySm.copyWith(
                color: selected ? AppColors.onPrimary : AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rangée horizontale scrollable de chips de filtre.
class FilterChipBar extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String>? onSelected;
  const FilterChipBar({Key? key, required this.options, this.selected, this.onSelected}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => AppFilterChip(
          label: options[i],
          selected: options[i] == selected,
          onTap: () => onSelected?.call(options[i]),
        ),
      ),
    );
  }
}

// ── Carte de tarif (Free / Pro / Agency) ────────────────────────────────────
class PricingTierCard extends StatelessWidget {
  final String name;
  final String price;        // ex: "399" ou "Gratuit"
  final String? period;      // ex: "DH / mois"
  final List<String> features;
  final bool highlighted;    // Pro mis en avant
  final String ctaLabel;
  final VoidCallback? onTap;

  const PricingTierCard({
    Key? key,
    required this.name,
    required this.price,
    this.period,
    required this.features,
    this.highlighted = false,
    this.ctaLabel = 'Choisir',
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final borderColor = highlighted ? AppColors.primary : AppColors.cardBorder;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.primary.withValues(alpha: 0.04) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: highlighted ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(name, style: AppTextStyles.titleMd.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              if (highlighted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.sand, borderRadius: BorderRadius.circular(6)),
                  child: Text('POPULAIRE', style: AppTextStyles.labelCaps.copyWith(color: AppColors.secondary, fontSize: 9)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(price, style: AppTextStyles.displayLg.copyWith(fontSize: 34, color: AppColors.primary)),
              if (period != null) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(period!, style: AppTextStyles.bodySm),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle, size: 18, color: AppColors.mint),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f, style: AppTextStyles.bodyLg.copyWith(fontSize: 14))),
                  ],
                ),
              )),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: highlighted
                ? ElevatedButton(onPressed: onTap, child: Text(ctaLabel))
                : OutlinedButton(onPressed: onTap, child: Text(ctaLabel)),
          ),
        ],
      ),
    );
  }
}

// ── Zone d'upload de document ───────────────────────────────────────────────
class DocumentUploader extends StatelessWidget {
  final String title;
  final String hint;
  final bool filled;        // document sélectionné
  final String? fileName;
  final VoidCallback? onTap;

  const DocumentUploader({
    Key? key,
    required this.title,
    this.hint = 'PNG, JPG • Max 10MB',
    this.filled = false,
    this.fileName,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final borderColor = filled ? AppColors.mint : AppColors.outline;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: DottedBorderBox(
        color: borderColor,
        filled: filled,
        child: Column(
          children: [
            Icon(
              filled ? Icons.check_circle : Icons.cloud_upload_outlined,
              size: 28, color: filled ? AppColors.mint : AppColors.primary,
            ),
            const SizedBox(height: 8),
            Text(title, style: AppTextStyles.bodyLg.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              filled ? (fileName ?? 'Document ajouté') : hint,
              style: AppTextStyles.bodySm,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Conteneur à bordure en pointillés (peint via CustomPaint).
class DottedBorderBox extends StatelessWidget {
  final Widget child;
  final Color color;
  final bool filled;
  const DottedBorderBox({Key? key, required this.child, required this.color, this.filled = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(color: color, solid: filled),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: filled ? AppColors.mint.withValues(alpha: 0.06) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  final Color color;
  final bool solid;
  _DashedRectPainter({required this.color, this.solid = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size, const Radius.circular(12),
    );
    if (solid) {
      canvas.drawRRect(rrect, paint);
      return;
    }
    // Bordure en tirets le long du contour arrondi.
    final path = Path()..addRRect(rrect);
    const dash = 6.0, gap = 5.0;
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final next = dist + dash;
        canvas.drawPath(metric.extractPath(dist, next.clamp(0, metric.length)), paint);
        dist = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter old) => old.color != color || old.solid != solid;
}

// ── Badge de statut (Pending / Approved / Rejected) ─────────────────────────
class StatusBadge extends StatelessWidget {
  final String status; // pending, approved, rejected
  const StatusBadge({Key? key, required this.status}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    late Color c;
    late String label;
    switch (status) {
      case 'approved':
        c = AppColors.mint; label = 'APPROUVÉ'; break;
      case 'rejected':
        c = AppColors.error; label = 'REJETÉ'; break;
      default:
        c = AppColors.warning; label = 'EN ATTENTE';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: AppTextStyles.labelCaps.copyWith(color: c, fontSize: 10)),
    );
  }
}

// ── Carte d'informations (profil, détails guide) ────────────────────────────
class InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const InfoCard({Key? key, required this.title, required this.children}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.titleMd),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

// ── Ligne label / valeur avec icône ─────────────────────────────────────────
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const InfoRow({
    Key? key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textLight),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.labelCaps.copyWith(letterSpacing: 0)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.bodyLg.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Avatar de repli : initiales sur pastille bleue ──────────────────────────
class DefaultAvatar extends StatelessWidget {
  final String fullName;
  final double radius;
  final double? fontSize;
  const DefaultAvatar({
    Key? key,
    required this.fullName,
    this.radius = 24,
    this.fontSize,
  }) : super(key: key);

  String get _initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryContainer,
      child: Text(
        _initials,
        style: AppTextStyles.titleMd.copyWith(
          fontSize: fontSize ?? radius * 0.7,
          color: AppColors.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Bouton d'action carré (dashboard guide, profil) ─────────────────────────
class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const ActionButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: c),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ligne d'action pleine largeur (dashboard guide) ─────────────────────────
///
/// [enabled] est une règle métier, pas une décoration : une action indisponible
/// doit être *visiblement* indisponible. Ne pas remplacer par un `onTap` inerte.
class ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  const ActionRow({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled ? AppColors.cardBorder : AppColors.outline,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: enabled
                      ? AppColors.primaryContainer
                      : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: enabled ? AppColors.primary : AppColors.textLight,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.titleMd.copyWith(
                        fontSize: 16,
                        color: enabled ? AppColors.ink : AppColors.textLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: enabled ? AppColors.primary : AppColors.textLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
