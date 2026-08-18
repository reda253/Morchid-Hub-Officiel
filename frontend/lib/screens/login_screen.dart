import 'package:flutter/material.dart';
import '../widgets/auth_widgets.dart';
import '../services/api_service.dart';
import '../routes/app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ============================================
  // 📝 CONTROLLERS & FORM KEY
  // ============================================
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ============================================
  // ✅ VALIDATION
  // ============================================
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer votre email';
    }
    // Expression régulière pour valider le format de l'email
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Email invalide';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer votre mot de passe';
    }
    if (value.length < 6) {
      return 'Le mot de passe doit contenir au moins 6 caractères';
    }
    return null;
  }

  // ============================================
  // 🚀 SUBMIT LOGIN
  // ============================================
  Future<void> _handleLogin() async {
    // Valider le formulaire
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Afficher l'indicateur de chargement
    setState(() {
      _isLoading = true;
    });

    try {
      // ============================================
      // APPEL API DE CONNEXION
      // ============================================
      final response = await ApiService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Cacher l'indicateur de chargement
      setState(() {
        _isLoading = false;
      });

      // Afficher un message de succès
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Bienvenue ${response.user.fullName} !'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );

        // Pour l'instant, juste un print
        print('✅ Connexion réussie: ${response.user.email}');
        print('🔑 Token: ${response.accessToken.substring(0, 20)}...');
        // Naviguer vers le Dashboard
        Navigator.pushReplacementNamed(context, AppRoutes.shell);
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                
                // ============================================
                // 🎭 HEADER (Logo + Titre)
                // ============================================
                const AuthHeader(
                  title: 'Bon retour !',
                  subtitle: 'Connectez-vous pour découvrir le Maroc\nde manière durable',
                ),
                
                const SizedBox(height: 50),
                
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
                
                const SizedBox(height: 12),
                
                // ============================================
                // 🔗 LIEN "MOT DE PASSE OUBLIÉ"
                // ============================================
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // TODO: Naviguer vers l'écran de récupération
                      Navigator.pushNamed(context, AppRoutes.forgotPassword);
                    },
                    child: const Text(
                      'Mot de passe oublié ?',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // ============================================
                // 🎯 BOUTON DE CONNEXION
                // ============================================
                PrimaryButton(
                  text: 'Se connecter',
                  icon: Icons.login,
                  onPressed: _handleLogin,
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
                // 🔗 LIEN VERS SIGNUP
                // ============================================
                Center(
                  child: TextLink(
                    normalText: 'Pas encore de compte ? ',
                    linkText: 'S\'inscrire',
                    onTap: () {
                      // Navigation avec animation fluide
                      Navigator.pushNamed(context, AppRoutes.signup);
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