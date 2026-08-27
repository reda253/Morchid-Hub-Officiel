import 'package:flutter/material.dart';

/// Palette canonique unique de Morchid Hub — tokens du design Google Stitch
/// (Atlantic Blue / Sahara Sand / Moroccan Mint).
///
/// Les noms historiques (`primary`, `secondary`, `background`, `textDark`,
/// `textLight`, `error`, `success`, `surface`, `accent`) sont conservés pour que
/// tous les écrans existants adoptent la nouvelle identité sans réécriture, et de
/// nouveaux tokens Stitch sont ajoutés (`sand`, `mint`, `ink`, `outline`, …).
class AppColors {
  // ── Marque ────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF004B87);   // Atlantic Blue
  static const Color secondary = Color(0xFF00325C); // Deep Atlantic (rôle "foncé")
  static const Color accent = Color(0xFF00A86B);    // Moroccan Mint
  static const Color sand = Color(0xFFE8C18C);      // Sahara Sand
  static const Color mint = Color(0xFF00A86B);      // Moroccan Mint (alias explicite)

  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFD3E4FF);
  static const Color onPrimaryContainer = Color(0xFF001C38);

  // ── Surfaces ──────────────────────────────────────────────────────────
  static const Color background = Color(0xFFF9F9FC); // surface Stitch
  static const Color surface = Color(0xFFFFFFFF);    // surface-container-lowest
  static const Color surfaceAlt = Color(0xFFF1F4F9); // léger contraste
  static const Color cardBorder = Color(0xFFE1E8EF); // bordure bleu-tint des cartes

  // ── Texte ─────────────────────────────────────────────────────────────
  static const Color ink = Color(0xFF1A1C1E);       // on-surface
  static const Color textDark = Color(0xFF1A1C1E);
  static const Color textLight = Color(0xFF6B7280);  // texte secondaire lisible
  static const Color onSurfaceVariant = Color(0xFF424750);

  // ── Contours ──────────────────────────────────────────────────────────
  static const Color outline = Color(0xFFC2C6D1);
  static const Color outlineStrong = Color(0xFF727781);

  // ── États ─────────────────────────────────────────────────────────────
  static const Color error = Color(0xFFBA1A1A);
  static const Color success = Color(0xFF00A86B);
  static const Color warning = Color(0xFFB25E00);

  // ── Rôles sémantiques ─────────────────────────────────────────────────
  /// Jaune des étoiles de notation. Était codé en dur à l'identique dans
  /// review_screen, guide_profile_screen et available_routes_screen.
  static const Color star = Color(0xFFFFC107);

  /// Vert de marque WhatsApp. Imposé par WhatsApp, ne pas remplacer par
  /// `success` même si les deux sont verts.
  static const Color whatsapp = Color(0xFF25D366);

  /// Ombre portée standard des cartes (noir à 10 %).
  static const Color shadow = Color(0x1A000000);

  /// Texte et icônes posés sur une PHOTO ou un dégradé arbitraire.
  /// Même valeur que [onPrimary] aujourd'hui, mais rôle différent :
  /// [onPrimary] = « sur un aplat primary », [onImage] = « sur une image ».
  /// Ne pas fusionner : un futur passage contraste/dark-mode déplacera l'un
  /// sans l'autre.
  static const Color onImage = Color(0xFFFFFFFF);
}
