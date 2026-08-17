import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/api_service.dart';
import '../theme/app_text_styles.dart';
import '../widgets/ui_kit.dart';

class GuideVerificationScreen extends StatefulWidget {
  const GuideVerificationScreen({Key? key}) : super(key: key);

  @override
  State<GuideVerificationScreen> createState() =>
      _GuideVerificationScreenState();
}

class _GuideVerificationScreenState extends State<GuideVerificationScreen> {
  // Design system
  static const Color primaryColor = Color(0xFF004B87);
  static const Color backgroundColor = Color(0xFFF9F9FC);
  static const Color textDark = Color(0xFF1A1C1E);
  static const Color textLight = Color(0xFF6B7280);
  static const Color successColor = Color(0xFF00A86B);
  static const Color errorColor = Color(0xFFBA1A1A);

  final _formKey = GlobalKey<FormState>();
  final _cineController = TextEditingController();
  final _licenseController = TextEditingController();

  File? _profilePhoto;
  File? _licensePhoto;
  File? _cinePhoto;

  bool _isSubmitting = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _cineController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  // ── Sélection d'images ────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source, String type) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source, maxWidth: 1920, maxHeight: 1920, imageQuality: 85,
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
            const Text('Choisir une source',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
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

  // ── Validation ────────────────────────────────────────────────────────
  String? _validateCINE(String? value) {
    if (value == null || value.isEmpty) return 'Veuillez entrer votre numéro de CINE';
    if (!RegExp(r'^[A-Z]{1,2}\d{6,7}$').hasMatch(value.toUpperCase())) {
      return 'Format invalide (ex: AB123456)';
    }
    return null;
  }

  String? _validateLicense(String? value) {
    if (value == null || value.isEmpty) return 'Veuillez entrer votre numéro de licence';
    if (value.length < 5) return 'Numéro de licence trop court';
    return null;
  }

  bool _validatePhotos() {
    if (_profilePhoto == null) {
      _showErrorSnackbar('Veuillez ajouter une photo de profil');
      return false;
    }
    if (_cinePhoto == null) {
      _showErrorSnackbar('Veuillez prendre en photo votre CIN');
      return false;
    }
    if (_licensePhoto == null) {
      _showErrorSnackbar('Veuillez prendre en photo votre carte de guide');
      return false;
    }
    return true;
  }

  // ── Soumission ────────────────────────────────────────────────────────
  Future<void> _submitVerification() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_validatePhotos()) return;

    setState(() => _isSubmitting = true);
    try {
      final response = await ApiService.submitGuideVerification(
        cineNumber: _cineController.text.toUpperCase(),
        licenseNumber: _licenseController.text,
        profilePhoto: _profilePhoto!,
        licensePhoto: _licensePhoto!,
        cinePhoto: _cinePhoto!,
      );
      setState(() => _isSubmitting = false);
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildSuccessDialog(response.message),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) _showErrorSnackbar(e.toString());
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: errorColor,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    ));
  }

  String? _basename(File? f) => f?.path.split(RegExp(r'[\\/]')).last;

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(s, style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600, color: textDark)),
      );

  // ── Build (page unique style Stitch) ──────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(title: const Text('Devenir vérifié')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const VerifiedBadge(label: 'VÉRIFICATION'),
              const SizedBox(height: 14),
              Text('Devenez vérifié', style: AppTextStyles.headlineMd),
              const SizedBox(height: 6),
              Text(
                'Gagnez la confiance de milliers de voyageurs. Les guides vérifiés '
                'reçoivent 4× plus de réservations.',
                style: AppTextStyles.bodyLg,
              ),
              const SizedBox(height: 24),
              _label('Numéro CINE'),
              TextFormField(
                controller: _cineController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: 'AB123456'),
                validator: _validateCINE,
              ),
              const SizedBox(height: 16),
              _label('Numéro de licence guide'),
              TextFormField(
                controller: _licenseController,
                decoration: const InputDecoration(hintText: 'Ex : LIC-2024-XXXX'),
                validator: _validateLicense,
              ),
              const SizedBox(height: 24),
              Text('Documents', style: AppTextStyles.titleMd),
              const SizedBox(height: 12),
              DocumentUploader(
                title: '1. Photo de profil',
                hint: 'Photo claire, de face • Max 10MB',
                filled: _profilePhoto != null,
                fileName: _basename(_profilePhoto),
                onTap: () => _showImageSourceDialog('profile'),
              ),
              const SizedBox(height: 12),
              DocumentUploader(
                title: '2. CIN marocaine',
                hint: 'Scans nets recto/verso • Max 10MB',
                filled: _cinePhoto != null,
                fileName: _basename(_cinePhoto),
                onTap: () => _showImageSourceDialog('cine'),
              ),
              const SizedBox(height: 12),
              DocumentUploader(
                title: '3. Carte professionnelle de guide',
                hint: 'Licence du Ministère, année en cours • Max 10MB',
                filled: _licensePhoto != null,
                fileName: _basename(_licensePhoto),
                onTap: () => _showImageSourceDialog('license'),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: textLight),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('La vérification prend généralement 24 à 48 h ouvrées.',
                        style: AppTextStyles.bodySm),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitVerification,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Soumettre pour vérification'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessDialog(String message) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: successColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, size: 60, color: successColor),
            ),
            const SizedBox(height: 24),
            const Text('Documents envoyés !',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textDark)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: textLight, height: 1.5)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('Retour au profil'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
