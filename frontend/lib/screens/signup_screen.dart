import 'package:flutter/material.dart';
import '../widgets/auth_widgets.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // ============================================
  // 📝 CONTROLLERS & FORM KEY
  // ============================================
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _selectedRole;
  bool _isLoading = false;
  bool _acceptTerms = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
  // 🚀 SUBMIT SIGNUP
  // ============================================
  Future<void> _handleSignup() async {
    // Valider le formulaire
    if (!_formKey.currentState!.validate()) {
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
                // 🔽 DROPDOWN RÔLE (Touriste ou Guide)
                // ============================================
                RoleDropdown(
                  selectedRole: _selectedRole,
                  onChanged: (value) {
                    setState(() {
                      _selectedRole = value;
                    });
                  },
                  validator: _validateRole,
                ),
                
                const SizedBox(height: 20),
                
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