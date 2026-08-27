import 'package:flutter/material.dart';
import 'dart:async';
import '../widgets/auth_widgets.dart';
import '../widgets/inline_error.dart';
import '../theme/app_text_styles.dart';
import '../services/api_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String fullName;

  const EmailVerificationScreen({
    Key? key,
    required this.email,
    required this.fullName,
  }) : super(key: key);

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with SingleTickerProviderStateMixin {
  bool _isResending = false;
  bool _canResend = true;
  int _countdown = 0;
  String? _resendError;
  Timer? _timer;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      _canResend = false;
      _countdown = 60; // 60 secondes
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _handleResendEmail() async {
    if (!_canResend) return;

    setState(() {
      _isResending = true;
      _resendError = null;
    });

    try {
      final response = await ApiService.resendVerification(
        email: widget.email,
      );

      setState(() {
        _isResending = false;
      });

      _startCountdown();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${response.message}'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isResending = false;
        _resendError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              // Icône animée
              Center(
                child: ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.2),
                          AppColors.secondary.withOpacity(0.2),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mark_email_unread,
                      size: 60,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
          
              const SizedBox(height: 40),

              // Titre
              Text(
                'Vérifiez votre email',
                textAlign: TextAlign.center,
                style: AppTextStyles.displayMd,
              ),

              const SizedBox(height: 16),

              // Message de bienvenue
              Text(
                'Bienvenue ${widget.fullName} ! 🎉',
                textAlign: TextAlign.center,
                style: AppTextStyles.titleMd.copyWith(color: AppColors.primary),
              ),

              const SizedBox(height: 24),

              // Description
              Text(
                'Nous avons envoyé un lien de vérification à',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyLg.copyWith(color: AppColors.textLight),
              ),

              const SizedBox(height: 8),

              // Email
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.email,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyLg.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Instructions
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildInstructionStep(
                      icon: Icons.email,
                      title: 'Ouvrez votre boîte mail',
                      description: 'Cherchez un email de Morchid Hub',
                    ),
                    const SizedBox(height: 16),
                    _buildInstructionStep(
                      icon: Icons.touch_app,
                      title: 'Cliquez sur le lien',
                      description: 'Activez votre compte en un clic',
                    ),
                    const SizedBox(height: 16),
                    _buildInstructionStep(
                      icon: Icons.check_circle,
                      title: 'C\'est fait !',
                      description: 'Vous pourrez vous connecter',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40), // Utilise une marge fixe à la place

              // Bouton Renvoyer
              if (_canResend)
                OutlinedButton.icon(
                  onPressed: _isResending ? null : _handleResendEmail,
                  icon: _isResending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(_isResending
                      ? 'Envoi en cours...'
                      : 'Renvoyer l\'email'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppColors.primary, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    foregroundColor: AppColors.primary,
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.textLight.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Renvoyer dans $_countdown secondes',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyLg.copyWith(
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              InlineError(message: _resendError),

              const SizedBox(height: 16),

              // Retour à la connexion
              TextButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: Text(
                  'Retour à la connexion',
                  style: AppTextStyles.bodySm.copyWith(
                    decoration: TextDecoration.underline,
                  ),
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

  Widget _buildInstructionStep({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.bodyLg.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTextStyles.bodyXs,
              ),
            ],
          ),
        ),
      ],
    );
  }
}