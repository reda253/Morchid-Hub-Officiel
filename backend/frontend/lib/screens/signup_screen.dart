import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/auth_widgets.dart';
import '../services/api_service.dart';
import '../models/user_models.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with SingleTickerProviderStateMixin {
  // ============================================
  // 📝 CONTROLLERS & FORM KEY
  // ============================================
  final _formKey = GlobalKey<FormState>();
  
  // Champs communs (tous les utilisateurs)
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
  // ✅ VALIDATION - CHAMPS COMMUNS
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
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer votre numéro de téléphone';
    }
    // Validation pour format marocain: +212 6XX XX XX XX
    final phoneRegex = RegExp(r'^\+212\s?[5-7]\d{8}$|^0[5-7]\d{8}$');
    if (!phoneRegex.hasMatch(value.replaceAll(' ', ''))) {
      return 'Format: +212 6XX XX XX XX ou 06XX XX XX XX';
    }
    return null;
  }

  String? _validateBirthYear(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer votre année de naissance';
    }
    final year = int.tryParse(value);
    if (year == null) {
      return 'Année invalide';
    }
    final currentYear = DateTime.now().year;
    if (year < 1924 || year > currentYear - 18) {
      return 'Vous devez avoir au moins 18 ans';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer un mot de passe';
    }
    if (value.length < 6) {
      return 'Au moins 6 caractères';
    }
    if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)').hasMatch(value)) {
      return 'Doit contenir des lettres et des chiffres';
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
    if (value == null || value.isEmpty) {
      return 'Veuillez rédiger une courte biographie';
    }
    if (value.length < 50) {
      return 'La biographie doit contenir au moins 50 caractères';
    }
    return null;
  }

  // ============================================
  // 🚀 SUBMIT SIGNUP
  // ============================================
  Future<void> _handleSignup() async {
    // Valider le formulaire
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Veuillez remplir tous les champs obligatoires'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
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

    try {
      // ============================================
      // PRÉPARER LES DONNÉES
      // ============================================
      final personalInfo = PersonalInfo(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        dateOfBirth: "${_birthYearController.text.trim()}-01-01",
      );

      GuideDetails? guideDetails;
      if (_selectedRole == 'guide') {
        guideDetails = GuideDetails(
          languages: _languagesController.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
          specialties: _selectedSpecialties,
          citiesCovered: _citiesController.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
          yearsOfExperience: int.tryParse(_experienceController.text) ?? 0,
          bio: _bioController.text.trim(),
        );
      }

      final registrationData = UserRegistrationRequest(
        personalInfo: personalInfo,
        role: _selectedRole!,
        password: _passwordController.text,
        guideDetails: guideDetails,
      );

      // ============================================
      // APPEL API D'INSCRIPTION
      // ============================================
      final response = await ApiService.register(
        registrationData: registrationData,
      );

      // Cacher l'indicateur de chargement
      setState(() {
        _isLoading = false;
      });

      // Afficher un message de succès
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${response.message}'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );

      // Naviguer vers l'écran de vérification email
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/email-verification',
            arguments: {
              'email': _emailController.text.trim(),
              'fullName': _fullNameController.text.trim(),
            },
          );
        }
      }
    } catch (e) {
      // Cacher l'indicateur de chargement
      setState(() {
        _isLoading = false;
      });

      // Afficher l'erreur
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
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
                // 🎭 HEADER
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
                // 🔽 DROPDOWN RÔLE
                // ============================================
                RoleDropdown(
                  selectedRole: _selectedRole,
                  onChanged: (value) {
                    setState(() {
                      _selectedRole = value;
                      // Animer l'apparition des champs guides
                      if (value == 'guide') {
                        _animationController.forward();
                      } else {
                        _animationController.reverse();
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
                // 🔒 CHAMP CONFIRMATION
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
                // ✅ CHECKBOX CONDITIONS
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
                // 🔀 DIVIDER
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
                    onTap: () => Navigator.pop(context),
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