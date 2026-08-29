import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../utils/app_colors.dart';

/// Chiffres alignés en colonne : sans chasse fixe, « 4.8 » et « 1.1 » n'ont pas
/// la même largeur et les valeurs tremblent quand elles se rafraîchissent.
final TextStyle _figureStyle = AppTextStyles.numberXl.copyWith(
  fontSize: 26,
  height: 1.0,
  fontFeatures: const [FontFeature.tabularFigures()],
);

/// Tuile KPI autonome : label en capitales, grand chiffre, delta optionnel.
///
/// Pour un *groupe* de KPI, préférer [StatGroup] : quatre tuiles bordées côte à
/// côte donnent quatre boîtes qui se disputent l'attention.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? delta;        // ex: "+50%"
  final bool positive;
  final IconData? icon;

  const StatTile({
    Key? key,
    required this.label,
    required this.value,
    this.delta,
    this.positive = true,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final deltaColor = positive ? AppColors.mint : AppColors.error;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: AppColors.primary),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: AppTextStyles.labelCaps.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: _figureStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (delta != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  positive ? Icons.trending_up : Icons.trending_down,
                  size: 14, color: deltaColor,
                ),
                const SizedBox(width: 4),
                Text(
                  delta!,
                  style: AppTextStyles.bodySm.copyWith(
                    color: deltaColor, fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Une cellule de [StatGroup].
///
/// [unit] se compose en petit à côté du chiffre (« 4.8 /5 », « 320 DH ») :
/// l'unité appartient à la valeur, pas au label, et la sortir du grand corps
/// laisse le chiffre seul porter la lecture.
class StatCell {
  final String label;
  final String value;
  final String? unit;

  const StatCell({required this.label, required this.value, this.unit});
}

/// Panneau de KPI groupés : **une** carte, cellules séparées par des filets.
///
/// Quatre `StatTile` dans une grille, c'est quatre bordures, quatre ombres
/// potentielles et quatre icônes qui se répètent — l'écran ressemble à un
/// gabarit d'administration générique. Groupées, les mêmes données se lisent
/// comme un seul instrument, et la hiérarchie revient à la typographie : petit
/// label en capitales, grand chiffre.
///
/// La hauteur de rangée est fixe et non dérivée d'un `childAspectRatio` : un
/// ratio dépend de la largeur de l'écran, donc creuse du vide sur les grands
/// écrans et rogne le texte sur les petits.
class StatGroup extends StatelessWidget {
  static const double _rowHeight = 84;

  final List<StatCell> cells;
  final int columns;

  const StatGroup({Key? key, required this.cells, this.columns = 2})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    for (var start = 0; start < cells.length; start += columns) {
      if (rows.isNotEmpty) {
        rows.add(const Divider(
          height: 1, thickness: 1, color: AppColors.cardBorder,
        ));
      }

      final children = <Widget>[];
      for (var col = 0; col < columns; col++) {
        if (col > 0) {
          children.add(const VerticalDivider(
            width: 1, thickness: 1, color: AppColors.cardBorder,
          ));
        }
        final index = start + col;
        children.add(Expanded(
          child: index < cells.length ? _buildCell(cells[index]) : const SizedBox(),
        ));
      }

      rows.add(SizedBox(height: _rowHeight, child: Row(children: children)));
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      // Les filets doivent s'arrêter au rayon, pas dépasser dans les coins.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Column(mainAxisSize: MainAxisSize.min, children: rows),
      ),
    );
  }

  Widget _buildCell(StatCell cell) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            cell.label.toUpperCase(),
            style: AppTextStyles.labelCaps.copyWith(fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  cell.value,
                  style: _figureStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (cell.unit != null) ...[
                const SizedBox(width: 4),
                Text(
                  cell.unit!,
                  style: AppTextStyles.bodySm.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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
