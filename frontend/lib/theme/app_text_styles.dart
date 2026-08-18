import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/app_colors.dart';

/// Échelle typographique Stitch : Epilogue (titres) + Manrope (corps).
class AppTextStyles {
  static TextStyle displayLg = GoogleFonts.epilogue(
    fontSize: 40, fontWeight: FontWeight.w700, height: 1.1, color: AppColors.ink,
  );
  static TextStyle headlineLg = GoogleFonts.epilogue(
    fontSize: 30, fontWeight: FontWeight.w600, height: 1.15, color: AppColors.ink,
  );
  static TextStyle headlineMd = GoogleFonts.epilogue(
    fontSize: 22, fontWeight: FontWeight.w600, height: 1.2, color: AppColors.ink,
  );
  static TextStyle titleMd = GoogleFonts.manrope(
    fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.ink,
  );
  static TextStyle bodyLg = GoogleFonts.manrope(
    fontSize: 16, fontWeight: FontWeight.w400, height: 1.4, color: AppColors.ink,
  );
  static TextStyle bodySm = GoogleFonts.manrope(
    fontSize: 14, fontWeight: FontWeight.w400, height: 1.4, color: AppColors.textLight,
  );
  static TextStyle labelCaps = GoogleFonts.manrope(
    fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6,
    color: AppColors.textLight,
  );
  static TextStyle numberXl = GoogleFonts.epilogue(
    fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.ink,
  );
  static TextStyle displayMd = GoogleFonts.epilogue(
    fontSize: 32, fontWeight: FontWeight.w700, height: 1.1, color: AppColors.ink,
  );
  static TextStyle titleSm = GoogleFonts.manrope(
    fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink,
  );
  static TextStyle bodyXs = GoogleFonts.manrope(
    fontSize: 13, fontWeight: FontWeight.w400, height: 1.4,
    color: AppColors.textLight,
  );
  static TextStyle numberLg = GoogleFonts.epilogue(
    fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink,
  );
}
