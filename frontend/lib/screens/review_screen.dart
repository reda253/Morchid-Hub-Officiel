import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user_models.dart';
import '../services/storage_service.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_colors.dart';
import '../widgets/error_state.dart';
import '../widgets/inline_error.dart';
import '../widgets/ui_kit.dart';

class ReviewScreen extends StatefulWidget {
  final String guideId;
  final String guideName;
  final String? guidePhotoUrl;
  final String? routeId;
  final String? routeLabel; // Ex: "Médina → Jardin Majorelle"

  const ReviewScreen({
    Key? key,
    required this.guideId,
    required this.guideName,
    this.guidePhotoUrl,
    this.routeId,
    this.routeLabel,
  }) : super(key: key);

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen>
    with SingleTickerProviderStateMixin {
  // ── Onglets ───────────────────────────────────────────────────────────────
  late TabController _tabController;

  // ── Formulaire d'ajout d'avis ─────────────────────────────────────────────
  int _rating = 0;
  int _hoverRating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  String? _submitError;

  // ── Liste des avis existants ──────────────────────────────────────────────
  ReviewListResponse? _reviewsData;
  bool _isLoadingReviews = true;
  ApiError? _reviewsError;

  // ── Labels des notes ──────────────────────────────────────────────────────
  static const List<String> _ratingLabels = [
    '',
    'Très mauvais',
    'Mauvais',
    'Correct',
    'Bien',
    'Excellent',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadReviews();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  // ── Charger les avis existants ────────────────────────────────────────────
  Future<void> _loadReviews() async {
    setState(() {
      _isLoadingReviews = true;
      _reviewsError = null;
    });
    try {
      final data = await ApiService.fetchGuideReviews(widget.guideId);
      if (mounted) setState(() => _reviewsData = data);
    } on ApiError catch (e) {
      if (mounted) setState(() => _reviewsError = e);
    } catch (e) {
      if (mounted) {
        setState(() => _reviewsError = ApiError(
              errorCode: 'FETCH_REVIEWS_ERROR',
              message: e.toString(),
            ));
      }
    } finally {
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  // ── Soumettre un avis ─────────────────────────────────────────────────────
  Future<void> _submitReview() async {
    if (_rating == 0) {
      setState(() => _submitError = 'Veuillez sélectionner une note');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final request = ReviewCreateRequest(
        guideId: widget.guideId,
        rating:  _rating,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
        routeId: widget.routeId,
      );

      await ApiService.submitReview(request.toJson());
      // Save this guide as the last guide reviewed
      await StorageService.saveLastGuide({
        'id': widget.guideId,
        'name': widget.guideName,
        'photo': widget.guidePhotoUrl,
      });

      if (mounted) {
        _showSnackBar('Merci ! Votre avis a été enregistré.', isError: false);
        // Rafraîchir la liste des avis après soumission
        await _loadReviews();
        // Basculer sur l'onglet "Avis"
        _tabController.animateTo(1);
        // Réinitialiser le formulaire
        setState(() {
          _rating = 0;
          _hoverRating = 0;
        });
        _commentController.clear();

        // Remonter true pour indiquer au parent que les stats ont changé
        Navigator.pop(context, true);
      }
    } on ApiError catch (e) {
      if (mounted) setState(() => _submitError = e.message);
    } catch (e) {
      if (mounted) setState(() => _submitError = 'Erreur inattendue : $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeader(),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: AppColors.onImage),
              onPressed: () => Navigator.pop(context),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.onImage,
              indicatorWeight: 3,
              labelColor: AppColors.onImage,
              unselectedLabelColor: AppColors.onImage.withValues(alpha: 0.60),
              labelStyle: AppTextStyles.titleMd.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              tabs: [
                const Tab(text: 'Laisser un avis'),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Avis'),
                      if (_reviewsData != null &&
                          _reviewsData!.totalReviews > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.onImage.withValues(alpha: 0.24),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_reviewsData!.totalReviews}',
                            style: AppTextStyles.bodySm.copyWith(
                              fontSize: 12,
                              color: AppColors.onImage,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildFormTab(),
            _buildReviewsTab(),
          ],
        ),
      ),
    );
  }

  // ── Header avec info guide ────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(64, 16, 24, 56),
          child: Row(
            children: [
              // Avatar du guide
              _buildGuideAvatar(),
              const SizedBox(width: 16),
              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.guideName,
                      style: AppTextStyles.headlineMd.copyWith(
                        color: AppColors.onImage,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Trajet concerné (si routeId fourni)
                    if (widget.routeId != null && widget.routeLabel != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.route,
                              color: AppColors.onImage.withValues(alpha: 0.70),
                              size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.routeLabel!,
                              style: AppTextStyles.bodySm.copyWith(
                                color: AppColors.onImage.withValues(alpha: 0.70),
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Note globale actuelle
                    if (_reviewsData != null) ...[
                      const SizedBox(height: 8),
                      _buildCompactRating(
                        _reviewsData!.averageRating,
                        _reviewsData!.totalReviews,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideAvatar() {
    final hasPhoto = widget.guidePhotoUrl != null &&
        widget.guidePhotoUrl!.isNotEmpty;

    if (hasPhoto) {
      final url = widget.guidePhotoUrl!.startsWith('http')
          ? widget.guidePhotoUrl!
          : '${ApiService.baseUrl}/${widget.guidePhotoUrl}';
      return CircleAvatar(
        radius: 32,
        backgroundColor: AppColors.onImage.withValues(alpha: 0.24),
        child: ClipOval(
          child: Image.network(
            url,
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                DefaultAvatar(fullName: widget.guideName, radius: 32),
          ),
        ),
      );
    }
    return DefaultAvatar(fullName: widget.guideName, radius: 32);
  }

  Widget _buildCompactRating(double avg, int count) {
    if (count == 0) {
      return Text(
        'Aucun avis pour l\'instant',
        style: AppTextStyles.bodySm.copyWith(
          color: AppColors.onImage.withValues(alpha: 0.60),
          fontSize: 12,
        ),
      );
    }
    return Row(
      children: [
        const Icon(Icons.star_rounded, color: AppColors.star, size: 16),
        const SizedBox(width: 4),
        Text(
          avg.toStringAsFixed(1),
          style: AppTextStyles.bodySm.copyWith(
            color: AppColors.onImage,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '($count avis)',
          style: AppTextStyles.bodySm.copyWith(
            color: AppColors.onImage.withValues(alpha: 0.70),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ONGLET 1 — FORMULAIRE
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildFormTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question principale
          Text(
            widget.routeId != null
                ? 'Comment s\'est passé ce trajet avec ${widget.guideName} ?'
                : 'Comment s\'est passée votre expérience avec ${widget.guideName} ?',
            textAlign: TextAlign.center,
            style: AppTextStyles.titleMd.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 32),

          // ── Étoiles interactives ─────────────────────────────────────────
          Text(
            'Votre note',
            style: AppTextStyles.bodySm.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildStarSelector(),
          const SizedBox(height: 8),

          // Label de la note sélectionnée
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _rating > 0 ? _ratingLabels[_rating] : 'Appuyez sur une étoile',
              key: ValueKey(_rating),
              style: AppTextStyles.bodySm.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _rating > 0 ? AppColors.primary : AppColors.textLight,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // ── Trajet badge (si avis sur trajet) ────────────────────────────
          if (widget.routeId != null && widget.routeLabel != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.route, color: AppColors.primary, size: 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Trajet : ${widget.routeLabel}',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Zone de commentaire ──────────────────────────────────────────
          Text(
            'Votre commentaire',
            style: AppTextStyles.bodySm.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            maxLines: 5,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText:
                  'Partagez votre avis (facultatif)…\n\nEx: Guide très accueillant, trajet bien organisé !',
              hintStyle: AppTextStyles.bodySm.copyWith(
                color: AppColors.textLight.withValues(alpha: 0.7),
                fontSize: 14,
              ),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              counterStyle: AppTextStyles.bodySm.copyWith(fontSize: 12),
            ),
          ),
          const SizedBox(height: 32),

          // ── Bouton soumettre ─────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: (_isSubmitting || _rating == 0) ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.outline,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: _rating > 0 ? 3 : 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: AppColors.onPrimary, strokeWidth: 2.5),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send_rounded,
                            color: AppColors.onPrimary, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Envoyer l\'avis',
                          style: AppTextStyles.titleMd.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onPrimary,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          if (_submitError != null) ...[
            const SizedBox(height: 8),
            InlineError(message: _submitError),
          ],
          const SizedBox(height: 16),

          // Note légale
          Center(
            child: Text(
              'Vous ne pourrez laisser qu\'un seul avis par guide.',
              style: AppTextStyles.bodySm.copyWith(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Sélecteur d'étoiles ───────────────────────────────────────────────────
  Widget _buildStarSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: List.generate(5, (i) {
        final star = i + 1;
        final filled = star <= (_hoverRating > 0 ? _hoverRating : _rating);
        return GestureDetector(
          onTap: () => setState(() => _rating = star),
          onLongPressStart: (_) => setState(() => _hoverRating = star),
          onLongPressEnd: (_) => setState(() => _hoverRating = 0),
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: child,
              ),
              child: Icon(
                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                key: ValueKey('$star-$filled'),
                color: filled ? AppColors.star : AppColors.outline,
                size: 44,
              ),
            ),
          ),
        );
      }),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ONGLET 2 — LISTE DES AVIS
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildReviewsTab() {
    if (_isLoadingReviews) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_reviewsError != null) {
      return ErrorState.fromApiError(_reviewsError!, onRetry: _loadReviews);
    }

    if (_reviewsData == null || _reviewsData!.reviews.isEmpty) {
      return _buildEmptyReviews();
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadReviews,
      child: CustomScrollView(
        slivers: [
          // Résumé global en haut
          SliverToBoxAdapter(
            child: _buildRatingSummary(),
          ),
          // Liste des avis
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) =>
                  _buildReviewCard(_reviewsData!.reviews[i]),
              childCount: _reviewsData!.reviews.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  // ── Résumé global ─────────────────────────────────────────────────────────
  Widget _buildRatingSummary() {
    final data = _reviewsData!;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Note centrale
          Column(
            children: [
              Text(
                data.averageRating.toStringAsFixed(1),
                style: AppTextStyles.displayLg.copyWith(
                  fontSize: 52,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              _buildStarsDisplay(data.averageRating, size: 18),
              const SizedBox(height: 4),
              Text(
                '${data.totalReviews} avis',
                style: AppTextStyles.bodySm.copyWith(fontSize: 13),
              ),
            ],
          ),
          const SizedBox(width: 24),
          // Barres de distribution
          Expanded(
            child: Column(
              children: List.generate(5, (i) {
                final star = 5 - i;
                final count = data.reviews
                    .where((r) => r.rating == star)
                    .length;
                final ratio = data.totalReviews > 0
                    ? count / data.totalReviews
                    : 0.0;
                return _buildRatingBar(star, ratio, count);
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBar(int star, double ratio, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$star', style: AppTextStyles.bodySm.copyWith(fontSize: 12)),
          const SizedBox(width: 4),
          const Icon(Icons.star_rounded, size: 12, color: AppColors.star),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                backgroundColor: AppColors.surfaceAlt,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 20,
            child: Text(
              '$count',
              style: AppTextStyles.bodySm.copyWith(fontSize: 11),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // ── Carte d'un avis ───────────────────────────────────────────────────────
  Widget _buildReviewCard(Review review) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar du touriste
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  review.touristName.isNotEmpty
                      ? review.touristName[0].toUpperCase()
                      : '?',
                  style: AppTextStyles.titleMd.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Nom + date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.touristName,
                      style: AppTextStyles.titleMd.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      review.timeAgo,
                      style: AppTextStyles.bodySm.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Badge trajet
              if (review.hasRoute)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.route,
                          size: 10, color: AppColors.primary),
                      const SizedBox(width: 3),
                      Text(
                        'Trajet',
                        style: AppTextStyles.bodySm.copyWith(
                          fontSize: 10,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Étoiles
          _buildStarsDisplay(review.rating.toDouble(), size: 16),
          // Commentaire
          if (review.comment != null &&
              review.comment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment!,
              style: AppTextStyles.bodyLg.copyWith(
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── État vide ─────────────────────────────────────────────────────────────
  Widget _buildEmptyReviews() {
    return const ErrorState(
      icon: Icons.rate_review_outlined,
      title: 'Aucun avis pour l\'instant',
      message: 'Soyez le premier à partager votre expérience\navec ce guide !',
    );
  }

  // ── Widget étoiles (lecture seule) ────────────────────────────────────────
  Widget _buildStarsDisplay(double rating, {double size = 18}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (rating >= i + 1) {
          return Icon(Icons.star_rounded, color: AppColors.star, size: size);
        } else if (rating > i) {
          return Icon(Icons.star_half_rounded,
              color: AppColors.star, size: size);
        }
        return Icon(Icons.star_outline_rounded,
            color: AppColors.outline, size: size);
      }),
    );
  }
}
