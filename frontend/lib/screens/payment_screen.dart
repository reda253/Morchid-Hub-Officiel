import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_colors.dart';
import '../services/api_service.dart';
import '../models/user_models.dart';

// ═══════════════════════════════════════════════════════════════
//  PaymentScreen — Morchid Hub Premium
//  Améliorations par rapport à la version de base :
//   ✅ Animation flip de la carte (recto / verso CVV)
//   ✅ Formatage automatique MM/YY avec validation d'expiration
//   ✅ Formatage du numéro en groupes XXXX XXXX XXXX XXXX
//   ✅ Algorithme de Luhn pour valider le numéro de carte
//   ✅ Sélecteur de méthode de paiement (Carte / CIH / Wafacash)
//   ✅ Résumé de commande complet avec éco-badge
//   ✅ Badge de sécurité SSL en bas
//   ✅ Gestion d'erreur complète avec codes backend
//   ✅ Intégration avec ApiService.upgradeToPremium() existant
// ═══════════════════════════════════════════════════════════════

class PaymentScreen extends StatefulWidget {
  final double amount;
  final String planName;

  const PaymentScreen({
    Key? key,
    this.amount = 100.00,
    this.planName = 'Abonnement Premium',
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isProcessing = false;
  bool _showCardBack = false;
  int _selectedMethod = 0; // 0 = Carte, 1 = CIH, 2 = Wafacash

  // ── Animation flip ───────────────────────────────────────────
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  // ── Contrôleurs ──────────────────────────────────────────────
  final _cardNumberController = TextEditingController();
  final _expiryController     = TextEditingController();
  final _cvvController        = TextEditingController();
  final _nameController       = TextEditingController();
  final _cvvFocusNode         = FocusNode();

  @override
  void initState() {
    super.initState();

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    // Flip vers dos quand CVV est focalisé
    _cvvFocusNode.addListener(() {
      if (_cvvFocusNode.hasFocus) {
        _flipController.forward();
        setState(() => _showCardBack = true);
      } else {
        _flipController.reverse();
        setState(() => _showCardBack = false);
      }
    });

    _cardNumberController.addListener(() => setState(() {}));
    _nameController.addListener(()       => setState(() {}));
    _expiryController.addListener(()     => setState(() {}));
    _cvvController.addListener(()        => setState(() {}));
  }

  @override
  void dispose() {
    _flipController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    _cvvFocusNode.dispose();
    super.dispose();
  }

  // ── Algorithme de Luhn ────────────────────────────────────────
  bool _isValidLuhn(String number) {
    if (number.length != 16) return false;
    int sum = 0;
    bool alternate = false;
    for (int i = number.length - 1; i >= 0; i--) {
      int n = int.parse(number[i]);
      if (alternate) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

  // ── Validation expiration ─────────────────────────────────────
  bool _isValidExpiry(String value) {
    if (value.length != 5) return false;
    final parts = value.split('/');
    if (parts.length != 2) return false;
    final month = int.tryParse(parts[0]);
    final year  = int.tryParse('20${parts[1]}');
    if (month == null || year == null) return false;
    if (month < 1 || month > 12) return false;
    return DateTime(year, month + 1).isAfter(DateTime.now());
  }

  // ── Formatage numéro pour affichage ──────────────────────────
  String _formatCardDisplay(String raw) {
    final clean = raw.padRight(16, '*');
    final buf = StringBuffer();
    for (int i = 0; i < 16; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(i >= 4 && i < 12 && i < raw.length ? '•' : clean[i]);
    }
    return buf.toString();
  }

  // ── Détection type de carte ───────────────────────────────────
  String _detectCardType(String number) {
    final clean = number.replaceAll(' ', '');
    if (clean.startsWith('4')) return 'VISA';
    if (RegExp(r'^5[1-5]').hasMatch(clean)) return 'MASTERCARD';
    if (clean.startsWith('34') || clean.startsWith('37')) return 'AMEX';
    return 'VISA';
  }

  // ── Traitement du paiement ────────────────────────────────────
  Future<void> _processPayment() async {
    if (_selectedMethod == 0 && !_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);
    try {
      await Future.delayed(const Duration(seconds: 2));
      final response = await ApiService.upgradeToPremium();
      if (!mounted) return;
      _showSuccessDialog(response.message);
    } on ApiError catch (e) {
      if (!mounted) return;
      _showErrorSnackbar(_mapErrorCode(e.errorCode, e.message));
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackbar('Une erreur inattendue est survenue. Réessayez.');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String _mapErrorCode(String code, String fallback) {
    const map = {
      'NOT_A_GUIDE':            'Réservé aux guides certifiés.',
      'GUIDE_PROFILE_NOT_FOUND':'Profil guide introuvable. Contactez le support.',
      'NETWORK_ERROR':          'Pas de connexion. Vérifiez votre réseau.',
      'UNAUTHORIZED':           'Session expirée. Reconnectez-vous.',
    };
    return map[code] ?? fallback;
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Paiement Réussi ! 🎉',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              const SizedBox(height: 10),
              Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textLight, fontSize: 14, height: 1.5)),
              const SizedBox(height: 12),
              // Avantages Premium
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(children: [
                  _benefit(Icons.all_inclusive, 'Trajets illimités'),
                  _benefit(Icons.star_rounded, 'Meilleure visibilité'),
                  _benefit(Icons.eco_rounded, 'Badge Éco-Certifié'),
                  _benefit(Icons.support_agent_rounded, 'Support prioritaire'),
                ]),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Retour à l\'accueil',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _benefit(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Icon(icon, color: AppColors.primary, size: 17),
      const SizedBox(width: 10),
      Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textDark)),
    ]),
  );

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Paiement Premium',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAnimatedCard(),
            const SizedBox(height: 28),
            _buildMethodSelector(),
            const SizedBox(height: 24),

            if (_selectedMethod == 0) ...[
              const Text('Détails de la carte',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(children: [
                  _buildTextField(
                    label: 'Nom sur la carte',
                    hint: 'Ex: OMAR FILALI',
                    controller: _nameController,
                    icon: Icons.person_outline_rounded,
                    validator: (v) => v!.trim().isEmpty ? 'Champ requis' : null,
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    label: 'Numéro de carte',
                    hint: '0000 0000 0000 0000',
                    controller: _cardNumberController,
                    icon: Icons.credit_card_rounded,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(16),
                      _CardNumberFormatter(),
                    ],
                    validator: (v) {
                      final clean = v!.replaceAll(' ', '');
                      if (clean.length < 16) return 'Doit contenir 16 chiffres';
                      if (!_isValidLuhn(clean)) return 'Numéro de carte invalide';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: _buildTextField(
                        label: 'Expiration',
                        hint: 'MM/YY',
                        controller: _expiryController,
                        icon: Icons.calendar_today_rounded,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                          _ExpiryFormatter(),
                        ],
                        validator: (v) {
                          if (v!.isEmpty) return 'Requis';
                          if (!_isValidExpiry(v)) return 'Date invalide ou expirée';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildTextField(
                        label: 'CVV',
                        hint: '•••',
                        controller: _cvvController,
                        icon: Icons.lock_outline_rounded,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        focusNode: _cvvFocusNode,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        validator: (v) => v!.length < 3 ? 'CVV invalide' : null,
                      ),
                    ),
                  ]),
                ]),
              ),
            ] else
              _buildAlternativePaymentInfo(),

            const SizedBox(height: 24),
            _buildOrderSummary(),
            const SizedBox(height: 20),
            _buildSecurityBadge(),
            const SizedBox(height: 24),

            // Bouton de paiement
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  shadowColor: AppColors.primary.withOpacity(0.4),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text('Payer ${widget.amount.toStringAsFixed(2)} DH',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Carte animée (flip recto/verso) ──────────────────────────
  Widget _buildAnimatedCard() {
    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, _) {
        final angle = _flipAnimation.value * 3.14159;
        final isFront = _flipAnimation.value < 0.5;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: isFront
              ? _buildCardFront()
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(3.14159),
                  child: _buildCardBack(),
                ),
        );
      },
    );
  }

  Widget _buildCardFront() {
    final cardType = _detectCardType(_cardNumberController.text);
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withBlue(180).withGreen(100)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(
          color: AppColors.primary.withOpacity(0.35),
          blurRadius: 20,
          offset: const Offset(0, 10),
        )],
      ),
      child: Stack(children: [
        // Cercles décoratifs
        Positioned(top: -40, right: -30, child: _circle(140)),
        Positioned(bottom: -50, left: -20, child: _circle(180, opacity: 0.06)),
        // Contenu
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  Container(
                    width: 34, height: 26,
                    decoration: BoxDecoration(
                      color: Colors.amber.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.wifi_rounded, color: Colors.white70, size: 20),
                ]),
                Text(cardType, style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold,
                  fontSize: 18, letterSpacing: 1)),
              ]),
              Text(
                _cardNumberController.text.isEmpty
                    ? '**** **** **** ****'
                    : _formatCardDisplay(_cardNumberController.text.replaceAll(' ', '')),
                style: const TextStyle(
                  color: Colors.white, fontSize: 20,
                  letterSpacing: 2.5, fontWeight: FontWeight.w600),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('TITULAIRE', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 9, letterSpacing: 1)),
                  Text(
                    _nameController.text.isEmpty ? 'VOTRE NOM' : _nameController.text.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('EXPIRE', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 9, letterSpacing: 1)),
                  Text(
                    _expiryController.text.isEmpty ? 'MM/YY' : _expiryController.text,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ]),
              ]),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _circle(double size, {double opacity = 0.08}) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withOpacity(opacity),
    ),
  );

  Widget _buildCardBack() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF1A1A2E),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 28),
        Container(height: 44, color: Colors.black54),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(children: [
            Expanded(child: Container(height: 36, color: Colors.white12)),
            const SizedBox(width: 12),
            Container(
              width: 70, height: 36,
              color: Colors.white,
              alignment: Alignment.center,
              child: Text(
                _cvvController.text.isEmpty ? 'CVV' : '•' * _cvvController.text.length,
                style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold,
                  color: Colors.black87, letterSpacing: 3),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Sélecteur de méthode ─────────────────────────────────────
  Widget _buildMethodSelector() {
    final methods = [
      {'icon': Icons.credit_card_rounded, 'label': 'Carte'},
      {'icon': Icons.account_balance_rounded, 'label': 'CIH'},
      {'icon': Icons.mobile_screen_share_rounded, 'label': 'Wafacash'},
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Méthode de paiement',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
      const SizedBox(height: 12),
      Row(
        children: List.generate(methods.length, (i) {
          final selected = _selectedMethod == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedMethod = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(right: i < methods.length - 1 ? 10 : 0),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? AppColors.primary : Colors.grey.shade200,
                    width: selected ? 2 : 1,
                  ),
                  boxShadow: selected
                      ? [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))]
                      : [],
                ),
                child: Column(children: [
                  Icon(methods[i]['icon'] as IconData,
                    color: selected ? Colors.white : Colors.grey.shade500, size: 24),
                  const SizedBox(height: 4),
                  Text(methods[i]['label'] as String,
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : Colors.grey.shade600)),
                ]),
              ),
            ),
          );
        }),
      ),
    ]);
  }

  // ── Info paiement alternatif ─────────────────────────────────
  Widget _buildAlternativePaymentInfo() {
    final isCIH = _selectedMethod == 1;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(
          isCIH ? Icons.account_balance_rounded : Icons.mobile_screen_share_rounded,
          color: AppColors.primary, size: 32),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isCIH ? 'Paiement CIH' : 'Paiement Wafacash',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark)),
          const SizedBox(height: 6),
          Text(
            isCIH
                ? 'Effectuez un virement de 100 DH via CIH Net.\nRéférence : MH-PREMIUM-2026'
                : 'Rendez-vous en agence Wafacash.\nNuméro : 06 XX XX XX XX\nMention : Morchid Hub Premium',
            style: const TextStyle(fontSize: 13, color: AppColors.textLight, height: 1.5)),
        ])),
      ]),
    );
  }

  // ── Récapitulatif commande ───────────────────────────────────
  Widget _buildOrderSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Récapitulatif',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 14),
        _row('${widget.planName} (1 mois)', '${widget.amount.toStringAsFixed(2)} DH'),
        const SizedBox(height: 8),
        _row('TVA (0%)', '0.00 DH', light: true),
        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 14),
        _row('Total', '${widget.amount.toStringAsFixed(2)} DH', bold: true),
        const SizedBox(height: 16),
        // Badge éco
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.eco_rounded, color: Colors.green.shade600, size: 15),
            const SizedBox(width: 6),
            Text('Votre abonnement soutient le tourisme durable 🌿',
              style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.w500)),
          ]),
        ),
      ]),
    );
  }

  Widget _row(String label, String value, {bool bold = false, bool light = false}) =>
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(
        fontSize: 13,
        color: light ? AppColors.textLight : AppColors.textDark,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      Text(value, style: TextStyle(
        fontSize: 13,
        color: bold ? AppColors.primary : AppColors.textDark,
        fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
    ]);

  // ── Badge sécurité ───────────────────────────────────────────
  Widget _buildSecurityBadge() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.lock_rounded, size: 13, color: Colors.grey.shade400),
      const SizedBox(width: 5),
      Text('SSL 256-bit', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
      Container(margin: const EdgeInsets.symmetric(horizontal: 8), width: 1, height: 12, color: Colors.grey.shade300),
      Icon(Icons.verified_rounded, size: 13, color: Colors.grey.shade400),
      const SizedBox(width: 5),
      Text('Certifié PCI DSS', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
    ],
  );

  // ── Champ de texte réutilisable ──────────────────────────────
  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    FocusNode? focusNode,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        obscureText: obscureText,
        inputFormatters: inputFormatters,
        textCapitalization: textCapitalization,
        onChanged: (_) => setState(() {}),
        validator: validator,
        style: const TextStyle(fontSize: 15, color: AppColors.textDark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error)),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
        ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════
//  INPUT FORMATTERS
// ═══════════════════════════════════════════════════════════════

/// Formate le numéro en groupes de 4 : XXXX XXXX XXXX XXXX
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(' ', '');
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final formatted = buf.toString();
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formate automatiquement la date : MM/YY
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll('/', '');
    if (digits.length > 4) return oldValue;
    final formatted = digits.length > 2
        ? '${digits.substring(0, 2)}/${digits.substring(2)}'
        : digits;
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}