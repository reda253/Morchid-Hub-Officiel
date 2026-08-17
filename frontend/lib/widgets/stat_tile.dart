import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../utils/app_colors.dart';

/// Tuile KPI du tableau de bord admin (design Stitch) :
/// label en capitales, grand chiffre, delta coloré optionnel.
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
      padding: const EdgeInsets.all(16),
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
                Icon(icon, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: AppTextStyles.labelCaps,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: AppTextStyles.numberXl, maxLines: 1, overflow: TextOverflow.ellipsis),
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
