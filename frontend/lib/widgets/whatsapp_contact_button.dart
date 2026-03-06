import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Bouton WhatsApp affiché après confirmation de paiement.
/// Redirige directement vers une conversation WhatsApp avec le guide.
///
/// Usage :
///   WhatsAppContactButton(phone: '+212612345678', guideName: 'Youssef')
class WhatsAppContactButton extends StatelessWidget {
  /// Numéro du guide au format international (ex: +212612345678)
  final String phone;

  /// Nom du guide (utilisé dans le message pré-rempli)
  final String guideName;

  const WhatsAppContactButton({
    Key? key,
    required this.phone,
    required this.guideName,
  }) : super(key: key);

  // ── Couleurs ──────────────────────────────────────────────────────────────
  static const Color _whatsappGreen = Color(0xFF25D366);
  static const Color _whatsappDark  = Color(0xFF128C7E);

  // ── Nettoyage du numéro ───────────────────────────────────────────────────
  /// Supprime espaces, tirets et parenthèses pour l'URL WhatsApp.
  String _cleanPhone(String raw) =>
      raw.replaceAll(RegExp(r'[\s\-\(\)]'), '');

  // ── Construction de l'URL WhatsApp ────────────────────────────────────────
  Uri _buildWhatsAppUri() {
    final cleaned = _cleanPhone(phone);
    final message = Uri.encodeComponent(
      'Bonjour $guideName ! Je viens de réserver votre circuit sur Morchid Hub. '
      'Pouvons-nous convenir des détails ?',
    );
    return Uri.parse('https://wa.me/$cleaned?text=$message');
  }

  // ── Lancement de WhatsApp ─────────────────────────────────────────────────
  Future<void> _openWhatsApp(BuildContext context) async {
    final uri = _buildWhatsAppUri();

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // WhatsApp non installé → fallback web WhatsApp
      final webUri = Uri.parse(
        'https://web.whatsapp.com/send?phone=${_cleanPhone(phone)}',
      );
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir WhatsApp'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openWhatsApp(context),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [_whatsappGreen, _whatsappDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: _whatsappGreen.withOpacity(0.45),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: _WhatsAppIcon(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Icône WhatsApp dessinée en Flutter (CustomPaint) — aucune dépendance image
// ─────────────────────────────────────────────────────────────────────────────
class _WhatsAppIcon extends StatelessWidget {
  const _WhatsAppIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(30, 30),
      painter: _WhatsAppPainter(),
    );
  }
}

class _WhatsAppPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Corps de la bulle (cercle blanc)
    canvas.drawCircle(center, radius * 0.82, paint);

    // Téléphone (icône simplifiée en vert par-dessus)
    final phonePaint = Paint()
      ..color = const Color(0xFF25D366)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round;

    // Combiné : on dessine un téléphone stylisé
    final path = Path();
    final s = size.width;

    // Corps du combiné
    path.moveTo(s * 0.28, s * 0.22);
    path.cubicTo(
      s * 0.28, s * 0.16,
      s * 0.36, s * 0.14,
      s * 0.40, s * 0.18,
    );
    path.lineTo(s * 0.46, s * 0.28);
    path.cubicTo(
      s * 0.49, s * 0.33,
      s * 0.47, s * 0.37,
      s * 0.44, s * 0.39,
    );
    path.cubicTo(
      s * 0.56, s * 0.52,
      s * 0.60, s * 0.56,
      s * 0.61, s * 0.56,
    );
    path.cubicTo(
      s * 0.63, s * 0.53,
      s * 0.67, s * 0.51,
      s * 0.72, s * 0.54,
    );
    path.lineTo(s * 0.82, s * 0.60);
    path.cubicTo(
      s * 0.86, s * 0.64,
      s * 0.84, s * 0.72,
      s * 0.78, s * 0.72,
    );
    path.cubicTo(
      s * 0.46, s * 0.80,
      s * 0.20, s * 0.54,
      s * 0.28, s * 0.22,
    );

    canvas.drawPath(path, phonePaint);

    // Petite queue de bulle en bas à gauche
    final tailPaint = Paint()
      ..color = const Color(0xFF25D366)
      ..style = PaintingStyle.fill;

    final tail = Path();
    tail.moveTo(s * 0.12, s * 0.88);
    tail.lineTo(s * 0.24, s * 0.72);
    tail.lineTo(s * 0.32, s * 0.82);
    tail.close();
    canvas.drawPath(tail, tailPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
