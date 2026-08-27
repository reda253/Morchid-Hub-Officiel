/// Validateurs de formulaire partagés.
/// Chaque fonction retourne `null` si la valeur est valide, sinon le message
/// d'erreur à afficher — signature compatible `FormFieldValidator<String>`.
class Validators {
  Validators._();

  static final RegExp _email = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  static final RegExp _phone = RegExp(r'^\+212[5-7]\d{8}$|^0[5-7]\d{8}$');
  static final RegExp _letterAndDigit = RegExp(r'^(?=.*[A-Za-z])(?=.*\d)');

  static String? fullName(String? value) {
    if (value == null || value.isEmpty) return 'Veuillez entrer votre nom complet';
    if (value.length < 3) return 'Le nom doit contenir au moins 3 caractères';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.isEmpty) return 'Veuillez entrer votre email';
    if (!_email.hasMatch(value)) return 'Email invalide';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer votre numéro de téléphone';
    }
    if (!_phone.hasMatch(value.replaceAll(' ', ''))) {
      return 'Format: +212 6XX XX XX XX ou 06XX XX XX XX';
    }
    return null;
  }

  static String? birthYear(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer votre année de naissance';
    }
    final year = int.tryParse(value);
    if (year == null) return 'Année invalide';
    final currentYear = DateTime.now().year;
    if (year < 1924 || year > currentYear - 18) {
      return 'Vous devez avoir au moins 18 ans';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Veuillez entrer un mot de passe';
    if (value.length < 6) return 'Au moins 6 caractères';
    if (!_letterAndDigit.hasMatch(value)) {
      return 'Doit contenir des lettres et des chiffres';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) {
      return 'Veuillez confirmer votre mot de passe';
    }
    if (value != original) return 'Les mots de passe ne correspondent pas';
    return null;
  }

  static String? required(String? value, String fieldLabel) {
    if (value == null || value.isEmpty) return 'Veuillez entrer $fieldLabel';
    return null;
  }
}
