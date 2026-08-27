import 'package:flutter_test/flutter_test.dart';
import 'package:morchid_hub/utils/validators.dart';

void main() {
  group('fullName', () {
    test('rejects empty', () {
      expect(Validators.fullName(''), 'Veuillez entrer votre nom complet');
    });
    test('rejects under 3 characters', () {
      expect(Validators.fullName('Ab'), 'Le nom doit contenir au moins 3 caractères');
    });
    test('accepts a real name', () {
      expect(Validators.fullName('Reda El Arroud'), isNull);
    });
  });

  group('email', () {
    test('rejects empty', () {
      expect(Validators.email(null), 'Veuillez entrer votre email');
    });
    test('rejects malformed', () {
      expect(Validators.email('nope@'), 'Email invalide');
    });
    test('accepts valid', () {
      expect(Validators.email('a@b.co'), isNull);
    });
  });

  group('phone', () {
    test('accepts +212 form with spaces', () {
      expect(Validators.phone('+212 612345678'), isNull);
    });
    test('accepts 0-prefixed form', () {
      expect(Validators.phone('0612345678'), isNull);
    });
    test('rejects a non-Moroccan number', () {
      expect(Validators.phone('+33612345678'),
          'Format: +212 6XX XX XX XX ou 06XX XX XX XX');
    });
  });

  group('birthYear', () {
    test('rejects under 18', () {
      final tooYoung = DateTime.now().year - 10;
      expect(Validators.birthYear('$tooYoung'), 'Vous devez avoir au moins 18 ans');
    });
    test('accepts an adult', () {
      expect(Validators.birthYear('1995'), isNull);
    });
  });

  group('password', () {
    test('rejects short', () {
      expect(Validators.password('a1'), 'Au moins 6 caractères');
    });
    test('rejects letters only', () {
      expect(Validators.password('abcdef'), 'Doit contenir des lettres et des chiffres');
    });
    test('accepts letters and digits', () {
      expect(Validators.password('abc123'), isNull);
    });
  });

  group('confirmPassword', () {
    test('rejects mismatch', () {
      expect(Validators.confirmPassword('abc123', 'xyz789'),
          'Les mots de passe ne correspondent pas');
    });
    test('accepts match', () {
      expect(Validators.confirmPassword('abc123', 'abc123'), isNull);
    });
  });

  group('required', () {
    test('uses the supplied label', () {
      expect(Validators.required('', 'une ville'), 'Veuillez entrer une ville');
    });
  });
}
