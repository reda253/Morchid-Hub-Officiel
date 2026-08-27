import 'package:flutter/material.dart';

import '../models/admin_models.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_colors.dart';

/// Graphe en barres du revenu mensuel — rendu par CustomPainter (aucune
/// dépendance externe). Consomme les données réelles de /admin/analytics/revenue.
class RevenueBarChart extends StatelessWidget {
  final List<RevenuePoint> points;
  final String currency;
  final double height;

  const RevenueBarChart({
    Key? key,
    required this.points,
    this.currency = 'MAD',
    this.height = 200,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('Aucune donnée de revenu', style: AppTextStyles.bodySm),
        ),
      );
    }
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _BarChartPainter(points: points, currency: currency),
        size: Size.infinite,
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<RevenuePoint> points;
  final String currency;

  _BarChartPainter({required this.points, required this.currency});

  @override
  void paint(Canvas canvas, Size size) {
    const double labelH = 22;
    const double topPad = 18;
    final chartH = size.height - labelH - topPad;
    final maxVal = points.map((p) => p.revenue).fold<double>(0, (a, b) => a > b ? a : b);
    final denom = maxVal <= 0 ? 1.0 : maxVal;

    final n = points.length;
    final slot = size.width / n;
    final barW = slot * 0.5;

    final barPaint = Paint()..color = AppColors.primary;
    final barPaintZero = Paint()..color = AppColors.cardBorder;
    final gridPaint = Paint()
      ..color = AppColors.cardBorder
      ..strokeWidth = 1;

    // Ligne de base.
    final baseY = topPad + chartH;
    canvas.drawLine(Offset(0, baseY), Offset(size.width, baseY), gridPaint);

    for (var i = 0; i < n; i++) {
      final p = points[i];
      final ratio = p.revenue / denom;
      final barH = (ratio * chartH).clamp(2.0, chartH);
      final left = slot * i + (slot - barW) / 2;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(left, baseY - barH, barW, barH),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );
      canvas.drawRRect(rect, p.revenue > 0 ? barPaint : barPaintZero);

      // Valeur au-dessus de la barre (si non nulle).
      if (p.revenue > 0) {
        _text(
          canvas,
          _short(p.revenue),
          Offset(slot * i + slot / 2, baseY - barH - 14),
          AppTextStyles.labelCaps.copyWith(color: AppColors.primary, fontSize: 10),
          center: true,
        );
      }

      // Label du mois.
      _text(
        canvas,
        p.label,
        Offset(slot * i + slot / 2, baseY + 6),
        AppTextStyles.bodySm.copyWith(fontSize: 11),
        center: true,
      );
    }
  }

  String _short(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k';
    return v.toStringAsFixed(0);
  }

  void _text(Canvas canvas, String s, Offset pos, TextStyle style, {bool center = false}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = center ? pos.dx - tp.width / 2 : pos.dx;
    tp.paint(canvas, Offset(dx, pos.dy));
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) =>
      old.points != points || old.currency != currency;
}
