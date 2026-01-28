import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/auth_widgets.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with SingleTickerProviderStateMixin{
  // ============================================
  // 📝 CONTROLLERS & FORM KEY
  // ============================================
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthYearController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

   // Champs spécifiques aux guides
  final _languagesController = TextEditingController();
  final _citiesController = TextEditingController();
  final _experienceController = TextEditingController();
  final _bioController = TextEditingController();
  final List<String> _selectedSpecialties = [];
  String? _selectedRole;
  bool _isLoading = false;
  bool _acceptTerms = false;

  // Animation pour l'apparition des champs guides
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _birthYearController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _languagesController.dispose();
    _citiesController.dispose();
    _experienceController.dispose();
    _bioController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ============================================
  // ✅ VALIDATION
  // ============================================
  String? _validateFullName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer votre nom complet';
    }
    if (value.length < 3) {
      return 'Le nom doit contenir au moins 3 caractères';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer votre email';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Email invalide';
    }
    return null;
  }
  String? _validatePhone(String? value) {
  if (value == null || value.isEmpty) return 'Veuillez entrer votre numéro';
  
  // REGEX : +212 6XX XX XX XX ou 06XX XX XX XX
  final phoneRegex = RegExp(r'^\+212\s?[5-7]\d{8}$|^0[5-7]\d{8}$');
  if (!phoneRegex.hasMatch(value.replaceAll(' ', ''))) {
    return 'Format invalide (ex: 0612345678)';
  }
  return null;
}
  String? _validateBirthYear(String? value) {
  if (value == null || value.isEmpty) return 'Année requise';
  final year = int.tryParse(value);
  final currentYear = DateTime.now().year;
  
  // Vérification de l'âge (18 ans min)
  if (year == null || year < 1924 || year > currentYear - 18) {
    return 'Vous devez avoir au moins 18 ans';
  }
  return null;
}

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer un mot de passe';
    }
    if (value.length < 6) {
      return 'Le mot de passe doit contenir au moins 6 caractères';
    }
    // Vérifier qu'il contient au moins une lettre et un chiffre
    if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)').hasMatch(value)) {
      return 'Le mot de passe doit contenir des lettres et des chiffres';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez confirmer votre mot de passe';
    }
    if (value != _passwordController.text) {
      return 'Les mots de passe ne correspondent pas';
    }
    return null;
  }

  String? _validateRole(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez sélectionner votre rôle';
    }
    return null;
  }
    // ============================================
  // ✅ VALIDATION - CHAMPS GUIDES
  // ============================================
  String? _validateLanguages(String? value) {
    if (_selectedRole != 'guide') return null;
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer au moins une langue';
    }
    return null;
  }

  String? _validateSpecialties(List<String>? value) {
    if (_selectedRole != 'guide') return null;
    if (value == null || value.isEmpty) {
      return 'Veuillez sélectionner au moins une spécialité';
    }
    return null;
  }

  String? _validateCities(String? value) {
    if (_selectedRole != 'guide') return null;
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer au moins une ville';
    }
    return null;
  }

  String? _validateExperience(String? value) {
    if (_selectedRole != 'guide') return null;
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer vos années d\'expérience';
    }
    final years = int.tryParse(value);
    if (years == null || years < 0) {
      return 'Nombre invalide';
    }
    return null;
  }

  String? _validateBio(String? value) {
  if (_selectedRole != 'guide') return null;
  if (value == null || value.isEmpty) return 'La biographie est requise';
  
  // Minimum 50 caractères
  if (value.length < 50) {
    return 'La biographie doit contenir au moins 50 caractères';
  }
  return null;
}

  // ============================================
  // 🚀 SUBMIT SIGNUP
  // ============================================
 Future<void> _handleSignup() async {
  if (!_formKey.currentState!.validate()) return;

  // Validation des spécialités pour les guides
  if (_selectedRole == 'guide' && _selectedSpecialties.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sélectionnez au moins une spécialité')),
    );
    return;
  }

    // Vérifier la validation des spécialités pour les guides
    if (_selectedRole == 'guide' && _selectedSpecialties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Veuillez sélectionner au moins une spécialité'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Vérifier que les conditions sont acceptées
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Vous devez accepter les conditions d\'utilisation'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Afficher l'indicateur de chargement
    setState(() {
      _isLoading = true;
    });
    // Préparer les données à envoyer
    final Map<String, dynamic> userData = {
      'personal_info': {
        'full_name': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'date_of_birth': '${_birthYearController.text}-01-01',
      },
      'role': _selectedRole,
      'password': _passwordController.text,
    };

    // Ajouter les champs spécifiques aux guides
    if (_selectedRole == 'guide') {
      userData['guide_details'] = {
        'languages': _languagesController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        'specialties': _selectedSpecialties,
        'cities_covered': _citiesController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        'years_of_experience': int.parse(_experienceController.text),
        'bio': _bioController.text.trim(),
      };
    }

    // TODO: Appeler l'API d'inscription ici
    // Exemple:
    // final userData = {
    //   'full_name': _fullNameController.text,
    //   'email': _emailController.text,
    //   'password': _passwordController.text,
    //   'role': _selectedRole,
    // };
    // await AuthService.register(userData);
    
    // Simulation d'un délai réseau (À RETIRER EN PRODUCTION)
    await Future.delayed(const Duration(seconds: 2));
    // Debug: Afficher les données collectées
    print('=== DONNÉES D\'INSCRIPTION ===');
    print(userData);

    // Cacher l'indicateur de chargement
    setState(() {
      _isLoading = false;
    });

    // Afficher un message de succès
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selectedRole == 'guide'
                ? '✅ Inscription réussie ! Vérifiez votre email pour activer votre compte.'
                : '✅ Bienvenue sur Morchid Hub !',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );

      // Retourner à l'écran de login après 1 seconde
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  // ============================================
  // 🎨 BUILD UI
  // ============================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // Bouton retour personnalisé
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textDark,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ============================================
                // 🎭 HEADER (Logo + Titre)
                // ============================================
                const AuthHeader(
                  title: 'Créer un compte',
                  subtitle: 'Rejoignez notre communauté de\nvoyageurs responsables',
                ),
                
                const SizedBox(height: 40),
                
                // ============================================
                // 👤 CHAMP NOM COMPLET
                // ============================================
                CustomTextField(
                  controller: _fullNameController,
                  label: 'Nom complet',
                  hint: 'Mohammed Alami',
                  prefixIcon: Icons.person_outline,
                  validator: _validateFullName,
                ),
                
                const SizedBox(height: 20),
                
                // ============================================
                // 📧 CHAMP EMAIL
                // ============================================
                CustomTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'exemple@email.com',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                
                const SizedBox(height: 20),

                // ============================================
                // 📱 CHAMP TÉLÉPHONE (NOUVEAU)
                // ============================================
                CustomTextField(
                  controller: _phoneController,
                  label: 'Numéro de téléphone',
                  hint: '+212 6XX XX XX XX',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: _validatePhone,
                ),
                
                const SizedBox(height: 20),
                
                // ============================================
                // 🎂 ANNÉE DE NAISSANCE (NOUVEAU)
                // ============================================
                CustomTextField(
                  controller: _birthYearController,
                  label: 'Année de naissance',
                  hint: 'AAAA (ex: 1995)',
                  prefixIcon: Icons.cake_outlined,
                  keyboardType: TextInputType.number,
                  validator: _validateBirthYear,
                ),
                
                const SizedBox(height: 20),
                
                // ============================================
                // 🔽 DROPDOWN RÔLE (Touriste ou Guide)
                // ============================================
                RoleDropdown(
                    selectedRole: _selectedRole,
                    onChanged: (value) {
                      setState(() {
                        _selectedRole = value;
                        // LOGIQUE D'ANIMATION ICI
                        if (value == 'guide') {
                          _animationController.forward(); // Affiche les champs avec animation
                        } else {
                          _animationController.reverse(); // Cache les champs
                        }
                      });
                    },
                    validator: _validateRole,
                  ),
                
                // ============================================
                // 🎯 CHAMPS DYNAMIQUES POUR LES GUIDES
                // ============================================
                if (_selectedRole == 'guide') ...[
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.1),
                        end: Offset.zero,
                      ).animate(_fadeAnimation),
                      child: Column(
                        children: [
                          const SizedBox(height: 30),
                          
                          // Divider avec texte
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: AppColors.primary.withOpacity(0.3),
                                  thickness: 1.5,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'INFORMATIONS GUIDE',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: AppColors.primary.withOpacity(0.3),
                                  thickness: 1.5,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 30),
                          
                          // 🌍 Langues parlées
                          LanguagesInput(
                            controller: _languagesController,
                            validator: _validateLanguages,
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // 🏷️ Spécialités (chips interactifs)
                          SpecialtiesSelector(
                            selectedSpecialties: _selectedSpecialties,
                            onChanged: (value) {
                              setState(() {
                                // Force la mise à jour
                              });
                            },
                            validator: _validateSpecialties,
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // 🏙️ Villes couvertes
                          CustomTextField(
                            controller: _citiesController,
                            label: 'Villes couvertes',
                            hint: 'Ex: Marrakech, Fès, Tanger...',
                            prefixIcon: Icons.location_city,
                            validator: _validateCities,
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // 📅 Années d'expérience
                          CustomTextField(
                            controller: _experienceController,
                            label: 'Années d\'expérience',
                            hint: 'Nombre d\'années (ex: 5)',
                            prefixIcon: Icons.work_outline,
                            keyboardType: TextInputType.number,
                            validator: _validateExperience,
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // 📝 Biographie
                          CustomTextField(
                            controller: _bioController,
                            label: 'Biographie',
                            hint: 'Décrivez votre parcours et vos passions en quelques mots...',
                            prefixIcon: Icons.description_outlined,
                            maxLines: 5,
                            validator: _validateBio,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 30),
                
                // ============================================
                // 🔒 CHAMP MOT DE PASSE
                // ============================================
                CustomTextField(
                  controller: _passwordController,
                  label: 'Mot de passe',
                  hint: '••••••••',
                  prefixIcon: Icons.lock_outline,
                  isPassword: true,
                  validator: _validatePassword,
                ),
                
                const SizedBox(height: 20),
                
                // ============================================
                // 🔒 CHAMP CONFIRMATION MOT DE PASSE
                // ============================================
                CustomTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirmer le mot de passe',
                  hint: '••••••••',
                  prefixIcon: Icons.lock_outline,
                  isPassword: true,
                  validator: _validateConfirmPassword,
                ),
                
                const SizedBox(height: 24),
                
                // ============================================
                // ✅ CHECKBOX CONDITIONS D'UTILISATION
                // ============================================
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _acceptTerms,
                        onChanged: (value) {
                          setState(() {
                            _acceptTerms = value ?? false;
                          });
                        },
                        activeColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _acceptTerms = !_acceptTerms;
                          });
                        },
                        child: RichText(
                          text: TextSpan(
                            text: 'J\'accepte les ',
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontSize: 13,
                            ),
                            children: [
                              TextSpan(
                                text: 'Conditions d\'utilisation',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const TextSpan(text: ' et la '),
                              TextSpan(
                                text: 'Politique de confidentialité',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 30),
                
                // ============================================
                // 🎯 BOUTON D'INSCRIPTION
                // ============================================
                PrimaryButton(
                  text: 'S\'inscrire',
                  icon: Icons.how_to_reg,
                  onPressed: _handleSignup,
                  isLoading: _isLoading,
                ),
                
                const SizedBox(height: 30),
                
                // ============================================
                // 🔀 DIVIDER "OU"
                // ============================================
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: AppColors.textLight.withOpacity(0.3),
                        thickness: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OU',
                        style: TextStyle(
                          color: AppColors.textLight.withOpacity(0.6),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: AppColors.textLight.withOpacity(0.3),
                        thickness: 1,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 30),
                
                // ============================================
                // 🔗 LIEN VERS LOGIN
                // ============================================
                Center(
                  child: TextLink(
                    normalText: 'Vous avez déjà un compte ? ',
                    linkText: 'Se connecter',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}