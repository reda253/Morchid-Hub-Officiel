import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user_models.dart';
import '../services/storage_service.dart';

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

  // ── Liste des avis existants ──────────────────────────────────────────────
  ReviewListResponse? _reviewsData;
  bool _isLoadingReviews = true;
  String? _reviewsError;

  // ── Design system (synchronisé avec home_screen) ──────────────────────────
  static const Color primaryColor    = Color(0xFF2D6A4F);
  static const Color secondaryColor  = Color(0xFF1B4332);
  static const Color backgroundColor = Color(0xFFF8F9FA);
  static const Color textDark        = Color(0xFF2B2D42);
  static const Color textLight       = Color(0xFF8D99AE);
  static const Color starColor       = Color(0xFFFFC107);
  static const Color errorColor      = Color(0xFFE63946);

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
    } catch (e) {
      if (mounted) setState(() => _reviewsError = e.toString());
    } finally {
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  // ── Soumettre un avis ─────────────────────────────────────────────────────
  Future<void> _submitReview() async {
    if (_rating == 0) {
      _showSnackBar('Veuillez sélectionner une note', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

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
      if (mounted) _showSnackBar(e.message, isError: true);
    } catch (e) {
      if (mounted) _showSnackBar('Erreur inattendue : $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? errorColor : primaryColor,
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
      backgroundColor: backgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeader(),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(
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
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_reviewsData!.totalReviews}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white),
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
          colors: [primaryColor, secondaryColor],
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
                      style: const TextStyle(
                        color: Colors.white,
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
                          const Icon(Icons.route,
                              color: Colors.white70, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.routeLabel!,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
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
        backgroundColor: Colors.white24,
        child: ClipOval(
          child: Image.network(
            url,
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _defaultAvatar(32),
          ),
        ),
      );
    }
    return _defaultAvatar(32);
  }

  Widget _defaultAvatar(double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white24,
      child: Text(
        widget.guideName.isNotEmpty ? widget.guideName[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCompactRating(double avg, int count) {
    if (count == 0) {
      return const Text(
        'Aucun avis pour l\'instant',
        style: TextStyle(color: Colors.white60, fontSize: 12),
      );
    }
    return Row(
      children: [
        const Icon(Icons.star_rounded, color: starColor, size: 16),
        const SizedBox(width: 4),
        Text(
          avg.toStringAsFixed(1),
          style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 4),
        Text(
          '($count avis)',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
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
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: textDark,
            ),
          ),
          const SizedBox(height: 32),

          // ── Étoiles interactives ─────────────────────────────────────────
          const Text(
            'Votre note',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textLight,
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
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _rating > 0 ? primaryColor : textLight,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // ── Trajet badge (si avis sur trajet) ────────────────────────────
          if (widget.routeId != null && widget.routeLabel != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: primaryColor.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.route, color: primaryColor, size: 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Trajet : ${widget.routeLabel}',
                      style: const TextStyle(
                        color: primaryColor,
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
          const Text(
            'Votre commentaire',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textLight,
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
              hintStyle:
                  TextStyle(color: textLight.withOpacity(0.7), fontSize: 14),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: primaryColor, width: 1.5),
              ),
              counterStyle:
                  const TextStyle(color: textLight, fontSize: 12),
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
                backgroundColor: primaryColor,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: _rating > 0 ? 3 : 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child:
                          CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Envoyer l\'avis',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Note légale
          Center(
            child: Text(
              'Vous ne pourrez laisser qu\'un seul avis par guide.',
              style: TextStyle(color: textLight, fontSize: 12),
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
                color: filled ? starColor : Colors.grey.shade300,
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
        child: CircularProgressIndicator(color: primaryColor),
      );
    }

    if (_reviewsError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 60, color: textLight),
            const SizedBox(height: 16),
            Text('Impossible de charger les avis',
                style: TextStyle(color: textLight, fontSize: 15)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadReviews,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor),
            ),
          ],
        ),
      );
    }

    if (_reviewsData == null || _reviewsData!.reviews.isEmpty) {
      return _buildEmptyReviews();
    }

    return RefreshIndicator(
      color: primaryColor,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              _buildStarsDisplay(data.averageRating, size: 18),
              const SizedBox(height: 4),
              Text(
                '${data.totalReviews} avis',
                style: const TextStyle(color: textLight, fontSize: 13),
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
          Text('$star', style: const TextStyle(fontSize: 12, color: textLight)),
          const SizedBox(width: 4),
          const Icon(Icons.star_rounded, size: 12, color: starColor),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                backgroundColor: Colors.grey.shade100,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(primaryColor),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 20,
            child: Text(
              '$count',
              style:
                  const TextStyle(fontSize: 11, color: textLight),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                backgroundColor: primaryColor.withOpacity(0.15),
                child: Text(
                  review.touristName.isNotEmpty
                      ? review.touristName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: primaryColor,
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      review.timeAgo,
                      style: const TextStyle(
                          color: textLight, fontSize: 12),
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
                    color: primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: primaryColor.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.route,
                          size: 10, color: primaryColor),
                      SizedBox(width: 3),
                      Text(
                        'Trajet',
                        style: TextStyle(
                            fontSize: 10, color: primaryColor),
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
              style: const TextStyle(
                fontSize: 14,
                color: textDark,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.rate_review_outlined,
                size: 64,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Aucun avis pour l\'instant',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Soyez le premier à partager votre expérience\navec ce guide !',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: textLight),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(0),
              icon: const Icon(Icons.star_rounded),
              label: const Text('Laisser le premier avis'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Widget étoiles (lecture seule) ────────────────────────────────────────
  Widget _buildStarsDisplay(double rating, {double size = 18}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (rating >= i + 1) {
          return Icon(Icons.star_rounded, color: starColor, size: size);
        } else if (rating > i) {
          return Icon(Icons.star_half_rounded, color: starColor, size: size);
        }
        return Icon(Icons.star_outline_rounded,
            color: Colors.grey.shade300, size: size);
      }),
    );
  }
}