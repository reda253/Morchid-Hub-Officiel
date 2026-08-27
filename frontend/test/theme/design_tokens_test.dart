import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morchid_hub/theme/app_text_styles.dart';
import 'package:morchid_hub/utils/app_colors.dart';

/// Every [AppTextStyles] token, read once.
///
/// The tokens are lazily-initialised `static` fields built with `GoogleFonts.*`,
/// so touching each one here runs its one-time initialiser — including the
/// background font download that initialiser kicks off.
List<TextStyle> _allTextStyles() => <TextStyle>[
      AppTextStyles.displayLg, AppTextStyles.displayMd,
      AppTextStyles.headlineLg, AppTextStyles.headlineMd,
      AppTextStyles.titleMd, AppTextStyles.titleSm,
      AppTextStyles.bodyLg, AppTextStyles.bodySm, AppTextStyles.bodyXs,
      AppTextStyles.labelCaps, AppTextStyles.numberXl, AppTextStyles.numberLg,
    ];

void main() {
  // GoogleFonts needs a binding to reach the asset bundle, and it starts a
  // background font download the first time a token is built. flutter_test
  // forces every HTTP request to 400, so that download always rejects — which
  // says nothing about a token's values but would otherwise surface as a
  // spurious failure in whichever test happened to be running.
  //
  // Because the tokens are lazily-initialised static fields, running every
  // initialiser here — inside a guarded zone that absorbs the rejection —
  // means the expectations below read plain, already-initialised fields and
  // trigger no font loading of their own. Assertions stay outside the guarded
  // zone, so a genuine expectation failure still fails its test.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    runZonedGuarded(_allTextStyles, (Object error, StackTrace stack) {});
  });

  group('AppTextStyles additions', () {
    test('titleSm is 14/w600', () {
      expect(AppTextStyles.titleSm.fontSize, 14);
      expect(AppTextStyles.titleSm.fontWeight, FontWeight.w600);
      expect(AppTextStyles.titleSm.color, AppColors.ink);
    });

    test('bodyXs is 13/w400 in the secondary text colour', () {
      expect(AppTextStyles.bodyXs.fontSize, 13);
      expect(AppTextStyles.bodyXs.fontWeight, FontWeight.w400);
      expect(AppTextStyles.bodyXs.color, AppColors.textLight);
    });

    test('displayMd is 32/w700', () {
      expect(AppTextStyles.displayMd.fontSize, 32);
      expect(AppTextStyles.displayMd.fontWeight, FontWeight.w700);
    });

    test('numberLg is 20/w700', () {
      expect(AppTextStyles.numberLg.fontSize, 20);
      expect(AppTextStyles.numberLg.fontWeight, FontWeight.w700);
    });

    test('every style carries an explicit colour', () {
      // A style with a null colour inherits from the ambient DefaultTextStyle,
      // which is what produced the scattered bare TextStyle() calls this plan
      // is removing. Every token must be self-contained.
      final styles = _allTextStyles();
      for (final s in styles) {
        expect(s.color, isNotNull);
      }
    });
  });

  group('AppColors additions', () {
    test('star is the amber used for ratings', () {
      expect(AppColors.star, const Color(0xFFFFC107));
    });

    test('whatsapp is the brand green', () {
      expect(AppColors.whatsapp, const Color(0xFF25D366));
    });

    test('shadow is a translucent black', () {
      // `.a` (0.0-1.0), pas `.alpha` (0-255) : ce dernier est déprécié.
      expect(AppColors.shadow.a, lessThan(1.0));
    });

    test('onImage and onPrimary are separate roles even at the same value', () {
      // Same hex today, different meaning. This test exists so that a future
      // change to one does not silently drag the other along.
      expect(AppColors.onImage, const Color(0xFFFFFFFF));
      expect(AppColors.onPrimary, const Color(0xFFFFFFFF));
    });
  });
}
