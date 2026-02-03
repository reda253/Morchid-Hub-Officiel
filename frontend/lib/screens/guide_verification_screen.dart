import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/api_service.dart';
import '../widgets/auth_widgets.dart';
import '../models/user_models.dart';

class GuideVerificationScreen extends StatefulWidget {
  const GuideVerificationScreen({Key? key}) : super(key: key);

  @override
  State<GuideVerificationScreen> createState() =>
      _GuideVerificationScreenState();
}

class _GuideVerificationScreenState extends State<GuideVerificationScreen> {
  // ============================================
  // 🎨 COULEURS DU DESIGN SYSTEM
  // ============================================
  static const Color primaryColor = Color(0xFF2D6A4F);
  static const Color secondaryColor = Color(0xFF1B4332);
  static const Color backgroundColor = Color(0xFFF8F9FA);
  static const Color textDark = Color(0xFF2B2D42);
  static const Color textLight = Color(0xFF8D99AE);
  static const Color successColor = Color(0xFF52B788);
  static const Color errorColor = Color(0xFFE63946);

  // ============================================
  // 📝 FORM STATE
  // ============================================
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  // Champs texte
  final _cineController = TextEditingController();
  final _licenseController = TextEditingController();

  // Images
  File? _profilePhoto;
  File? _licensePhoto;
  File? _cinePhoto;

  // Loading
  bool _isSubmitting = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _cineController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  // ============================================
  // 📸 SÉLECTION D'IMAGES
  // ============================================
  Future<void> _pickImage(ImageSource source, String type) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          switch (type) {
            case 'profile':
              _profilePhoto = File(image.path);
              break;
            case 'license':
              _licensePhoto = File(image.path);
              break;
            case 'cine':
              _cinePhoto = File(image.path);
              break;
          }
        });
      }
    } catch (e) {
      _showErrorSnackbar('Erreur lors de la sélection de l\'image: $e');
    }
  }

  void _showImageSourceDialog(String type) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choisir une source',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: primaryColor),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, type);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: primaryColor),
              title: const Text('Choisir dans la galerie'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, type);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // ✅ VALIDATION
  // ============================================
  String? _validateCINE(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer votre numéro de CINE';
    }
    // Format CINE marocain: 1-2 lettres + 6-7 chiffres
    if (!RegExp(r'^[A-Z]{1,2}\d{6,7}$').hasMatch(value.toUpperCase())) {
      return 'Format invalide (ex: AB123456)';
    }
    return null;
  }

  String? _validateLicense(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer votre numéro de licence';
    }
    if (value.length < 5) {
      return 'Numéro de licence trop court';
    }
    return null;
  }

  bool _validateStep(int step) {
    switch (step) {
      case 0:
        return _formKey.currentState?.validate() ?? false;
      case 1:
        if (_profilePhoto == null) {
          _showErrorSnackbar('Veuillez ajouter une photo de profil');
          return false;
        }
        return true;
      case 2:
        if (_licensePhoto == null) {
          _showErrorSnackbar('Veuillez prendre en photo votre licence');
          return false;
        }
        if (_cinePhoto == null) {
          _showErrorSnackbar('Veuillez prendre en photo votre CINE');
          return false;
        }
        return true;
      default:
        return false;
    }
  }

  // ============================================
  // 🚀 SOUMISSION
  // ============================================
  Future<void> _submitVerification() async {
    if (!_validateStep(2)) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await ApiService.submitGuideVerification(
        cineNumber: _cineController.text.toUpperCase(),
        licenseNumber: _licenseController.text,
        profilePhoto: _profilePhoto!,
        licensePhoto: _licensePhoto!,
        cinePhoto: _cinePhoto!,
      );

      setState(() {
        _isSubmitting = false;
      });

      if (mounted) {
        // Afficher le message de succès
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildSuccessDialog(response.message),
        );
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });

      if (mounted) {
        _showErrorSnackbar(e.toString());
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: errorColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ============================================
  // 🎨 BUILD UI
  // ============================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Vérification d\'identité',
          style: TextStyle(color: textDark),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Stepper Header
              _buildStepperHeader(),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: _buildCurrentStep(),
                ),
              ),

              // Navigation Buttons
              _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // 📊 STEPPER HEADER
  // ============================================
  Widget _buildStepperHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStepIndicator(0, 'Identité', Icons.badge),
          _buildStepLine(0),
          _buildStepIndicator(1, 'Visage', Icons.face),
          _buildStepLine(1),
          _buildStepIndicator(2, 'Documents', Icons.description),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, IconData icon) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isCompleted
                  ? primaryColor
                  : isActive
                      ? primaryColor
                      : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.check : icon,
              color: isCompleted || isActive ? Colors.white : textLight,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive ? primaryColor : textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepLine(int step) {
    final isCompleted = _currentStep > step;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 30),
        color: isCompleted ? primaryColor : Colors.grey.shade300,
      ),
    );
  }

  // ============================================
  // 📄 STEP CONTENT
  // ============================================
  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Identity();
      case 1:
        return _buildStep2ProfilePhoto();
      case 2:
        return _buildStep3Documents();
      default:
        return Container();
    }
  }

  // ÉTAPE 1: Identité
  Widget _buildStep1Identity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Informations d\'identité',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Entrez vos informations telles qu\'elles apparaissent sur vos documents officiels.',
          style: TextStyle(
            fontSize: 14,
            color: textLight,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        CustomTextField(
          controller: _cineController,
          label: 'Numéro de CINE',
          hint: 'AB123456',
          prefixIcon: Icons.credit_card,
          textCapitalization: TextCapitalization.characters,
          validator: _validateCINE,
        ),
        const SizedBox(height: 20),
        CustomTextField(
          controller: _licenseController,
          label: 'Numéro de Licence Guide',
          hint: 'LIC-2024-001',
          prefixIcon: Icons.verified_user,
          textCapitalization: TextCapitalization.characters,
          validator: _validateLicense,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: primaryColor.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ces informations doivent correspondre exactement aux documents que vous allez fournir.',
                  style: TextStyle(
                    fontSize: 13,
                    color: textDark,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ÉTAPE 2: Photo de Profil
  Widget _buildStep2ProfilePhoto() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Photo de profil',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Cette photo sera visible sur votre profil public. Choisissez une photo claire et professionnelle.',
          style: TextStyle(
            fontSize: 14,
            color: textLight,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 40),
        Center(
          child: GestureDetector(
            onTap: () => _showImageSourceDialog('profile'),
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: primaryColor,
                  width: 3,
                ),
                color: _profilePhoto == null
                    ? primaryColor.withOpacity(0.1)
                    : null,
              ),
              child: _profilePhoto == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.add_a_photo,
                          size: 50,
                          color: primaryColor,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Ajouter une photo',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    )
                  : ClipOval(
                      child: Image.file(
                        _profilePhoto!,
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (_profilePhoto != null)
          Center(
            child: TextButton.icon(
              onPressed: () => _showImageSourceDialog('profile'),
              icon: const Icon(Icons.refresh),
              label: const Text('Changer la photo'),
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
              ),
            ),
          ),
        const SizedBox(height: 32),
        _buildPhotoTips(),
      ],
    );
  }

  // ÉTAPE 3: Documents
  Widget _buildStep3Documents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Documents officiels',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Prenez des photos claires de vos documents. Assurez-vous que toutes les informations sont lisibles.',
          style: TextStyle(
            fontSize: 14,
            color: textLight,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        _buildDocumentCard(
          title: 'Licence de Guide Touristique',
          icon: Icons.badge,
          image: _licensePhoto,
          onTap: () => _showImageSourceDialog('license'),
        ),
        const SizedBox(height: 20),
        _buildDocumentCard(
          title: 'Carte d\'Identité Nationale (CINE)',
          icon: Icons.credit_card,
          image: _cinePhoto,
          onTap: () => _showImageSourceDialog('cine'),
        ),
        const SizedBox(height: 32),
        _buildSecurityNote(),
      ],
    );
  }

  Widget _buildDocumentCard({
    required String title,
    required IconData icon,
    required File? image,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: image == null
                ? Colors.grey.shade300
                : primaryColor,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: primaryColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textDark,
                    ),
                  ),
                ),
                Icon(
                  image == null ? Icons.add_circle : Icons.check_circle,
                  color: image == null ? textLight : successColor,
                  size: 28,
                ),
              ],
            ),
            if (image != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  image,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.refresh),
                label: const Text('Changer la photo'),
                style: TextButton.styleFrom(
                  foregroundColor: primaryColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoTips() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.tips_and_updates, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Conseils pour une bonne photo',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTip('Visage bien éclairé et centré'),
          _buildTip('Fond neutre de préférence'),
          _buildTip('Sourire naturel et professionnel'),
          _buildTip('Pas de lunettes de soleil'),
        ],
      ),
    );
  }

  Widget _buildSecurityNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.shade200,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.security, color: Colors.green, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Vos documents sont sécurisés et utilisés uniquement pour vérifier votre identité.',
              style: TextStyle(
                fontSize: 13,
                color: textDark,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            size: 16,
            color: Colors.blue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // 🎯 NAVIGATION BUTTONS
  // ============================================
  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _currentStep--;
                  });
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: primaryColor, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Précédent',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSubmitting
                  ? null
                  : () {
                      if (_currentStep < 2) {
                        if (_validateStep(_currentStep)) {
                          setState(() {
                            _currentStep++;
                          });
                        }
                      } else {
                        _submitVerification();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _currentStep < 2 ? 'Suivant' : 'Soumettre',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // ✅ SUCCESS DIALOG
  // ============================================
  Widget _buildSuccessDialog(String message) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: successColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                size: 60,
                color: successColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Documents envoyés !',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: textLight,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Return to previous screen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Retour au profil',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}