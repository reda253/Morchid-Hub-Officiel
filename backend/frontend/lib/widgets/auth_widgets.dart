import 'package:flutter/material.dart';

// ============================================
// 🎨 DESIGN SYSTEM - MORCHID HUB
// ============================================
class AppColors {
  static const Color primary = Color(0xFF2D6A4F); // Vert Émeraude
  static const Color secondary = Color(0xFF1B4332); // Bleu Marine Foncé
  static const Color background = Color(0xFFF8F9FA); // Blanc Cassé
  static const Color textDark = Color(0xFF2B2D42);
  static const Color textLight = Color(0xFF8D99AE);
  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF16A34A);
}

// ============================================
// 📝 CUSTOM TEXT FIELD
// ============================================
class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final bool isPassword;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;

  const CustomTextField({
    Key? key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.maxLines = 1,
  }) : super(key: key);

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscureText = true;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label du champ
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        
        // Champ de texte avec animation
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(51),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Focus(
            onFocusChange: (hasFocus) {
              setState(() {
                _isFocused = hasFocus;
              });
            },
            child: TextFormField(
              controller: widget.controller,
              obscureText: widget.isPassword ? _obscureText : false,
              keyboardType: widget.keyboardType,
              maxLines: widget.maxLines,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textDark,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: TextStyle(
                  color: AppColors.textLight.withAlpha(153),
                  fontSize: 15,
                ),
                prefixIcon: Icon(
                  widget.prefixIcon,
                  color: _isFocused ? AppColors.primary : AppColors.textLight,
                  size: 22,
                ),
                
                // Bouton pour afficher/masquer le mot de passe
                suffixIcon: widget.isPassword
                    ? IconButton(
                        icon: Icon(
                          _obscureText ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.textLight,
                          size: 22,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureText = !_obscureText;
                          });
                        },
                      )
                    : null,
                
                // Bordures et remplissage
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                
                // Style des bordures
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: AppColors.textLight.withAlpha(51),
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                    color: AppColors.error,
                    width: 1.5,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                    color: AppColors.error,
                    width: 2.5,
                  ),
                ),
              ),
              validator: widget.validator,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================
// 🎯 PRIMARY BUTTON (Bouton Principal)
// ============================================
class PrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final IconData? icon;

  const PrimaryButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  }) : super(key: key);

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withAlpha(102),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.isLoading ? null : widget.onPressed,
              borderRadius: BorderRadius.circular(20),
              child: Center(
                child: widget.isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(
                              widget.icon,
                              color: Colors.white,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                          ],
                          Text(
                            widget.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================
// 🔽 CUSTOM DROPDOWN (Sélecteur de Rôle)
// ============================================
class RoleDropdown extends StatelessWidget {
  final String? selectedRole;
  final Function(String?) onChanged;
  final String? Function(String?)? validator;

  const RoleDropdown({
    Key? key,
    required this.selectedRole,
    required this.onChanged,
    this.validator,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Je suis',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
            border: Border.all(
              color: AppColors.textLight.withAlpha(51),
              width: 1.5,
            ),
          ),
          child: DropdownButtonFormField<String>(
            value: selectedRole,
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.person_outline,
                color: AppColors.primary,
                size: 22,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              border: InputBorder.none,
              hintText: 'Sélectionnez votre rôle',
              hintStyle: TextStyle(
                color: AppColors.textLight.withOpacity(0.6),
                fontSize: 15,
              ),
            ),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(20),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.primary,
            ),
            items: [
              DropdownMenuItem(
                value: 'tourist',
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(26),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.luggage,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Touriste',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'guide',
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withAlpha(26),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.hiking,
                        color: AppColors.secondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Guide Touristique',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            onChanged: onChanged,
            validator: validator,
          ),
        ),
      ],
    );
  }
}

// ============================================
// 🔗 TEXT LINK (Lien cliquable)
// ============================================
class TextLink extends StatelessWidget {
  final String normalText;
  final String linkText;
  final VoidCallback onTap;

  const TextLink({
    Key? key,
    required this.normalText,
    required this.linkText,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: RichText(
        text: TextSpan(
          text: normalText,
          style: const TextStyle(
            color: AppColors.textLight,
            fontSize: 14,
          ),
          children: [
            TextSpan(
              text: linkText,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// 🏷️ MULTI-SELECT CHIPS (Pour les spécialités)
// ============================================
class SpecialtiesSelector extends StatefulWidget {
  final List<String> selectedSpecialties;
  final Function(List<String>) onChanged;
  final String? Function(List<String>?)? validator;

  const SpecialtiesSelector({
    Key? key,
    required this.selectedSpecialties,
    required this.onChanged,
    this.validator,
  }) : super(key: key);

  @override
  State<SpecialtiesSelector> createState() => _SpecialtiesSelectorState();
}
class _SpecialtiesSelectorState extends State<SpecialtiesSelector> {
  final List<Map<String, dynamic>> _specialties = [
    {'name': 'Nature', 'icon': Icons.landscape, 'value': 'nature'},
    {'name': 'Culture', 'icon': Icons.museum, 'value': 'culture'},
    {'name': 'Aventure', 'icon': Icons.hiking, 'value': 'adventure'},
    {'name': 'Gastronomie', 'icon': Icons.restaurant, 'value': 'gastronomy'},
    {'name': 'Histoire', 'icon': Icons.history_edu, 'value': 'history'},
  ];

  void _toggleSpecialty(String value) {
    setState(() {
      if (widget.selectedSpecialties.contains(value)) {
        widget.selectedSpecialties.remove(value);
      } else {
        widget.selectedSpecialties.add(value);
      }
      widget.onChanged(widget.selectedSpecialties);
    });
  }
   @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Spécialités',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _specialties.map((specialty) {
            final isSelected = widget.selectedSpecialties.contains(specialty['value']);
            return GestureDetector(
              onTap: () => _toggleSpecialty(specialty['value']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.textLight.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      specialty['icon'],
                      size: 18,
                      color: isSelected ? Colors.white : AppColors.textDark,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      specialty['name'],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (widget.validator != null)
          Builder(
            builder: (context) {
              final error = widget.validator!(widget.selectedSpecialties);
              if (error != null) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Text(
                    error,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.error,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
      ],
    );
  }
}
// ============================================
// 🌍 LANGUAGES INPUT (Champ pour les langues)
// ============================================
class LanguagesInput extends StatelessWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;

  const LanguagesInput({
    Key? key,
    required this.controller,
    this.validator,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: controller,
      label: 'Langues parlées',
      hint: 'Ex: Arabe, Français, Anglais...',
      prefixIcon: Icons.language,
      validator: validator,
    );
  }
}

// ============================================
// 🎭 AUTH HEADER (En-tête avec logo et titre)
// ============================================
class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const AuthHeader({
    Key? key,
    required this.title,
    required this.subtitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Logo avec Hero animation pour transition fluide
        Hero(
          tag: 'app_logo',
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withAlpha(77),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.eco,
              size: 50,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        // Titre
        Text(
          title,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        
        // Sous-titre
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textLight.withAlpha(204),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}