import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../services/admin_service.dart';
import '../services/api_service.dart';
import '../models/admin_models.dart';
import '../widgets/ui_kit.dart';
import '../widgets/stat_tile.dart';
import '../widgets/error_state.dart';
import '../widgets/inline_error.dart';
import '../routes/app_routes.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String? _loadErrorMessage;

  List<UserData> _users = [];
  List<SupportMessage> _supportMessages = [];

  // Sous-filtre de l'onglet Approbations (Stitch : Pending / Approved / Rejected)
  String _guideFilter = 'pending';
  List<GuideProfile> _guidesForFilter = [];
  bool _loadingGuides = false;
  String? _guidesLoadError;
  
  // Dashboard stats
  int _totalUsers = 0;
  int _activeGuides = 0;
  int _pendingApprovals = 0;
  int _unresolvedSupport = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);  // 3 onglets maintenant
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadErrorMessage = null;
    });
    try {
      final users = await AdminService.fetchUsers();
      final pending = await AdminService.fetchPendingGuides();
      final support = await AdminService.fetchSupportMessages();

      if (!mounted) return;
      setState(() {
        _users = users;
        _guidesForFilter = pending;   // filtre par défaut = pending
        _guideFilter = 'pending';
        _supportMessages = support;
        _totalUsers = users.length;
        _activeGuides = users.where((u) => u.isActive).length;
        _pendingApprovals = pending.length;
        _unresolvedSupport = support.where((m) => !m.isResolved).length;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadErrorMessage = e is ApiError ? e.message : 'Erreur: $e';
      });
    }
  }

  Future<void> _loadGuidesByFilter(String status) async {
    final previousFilter = _guideFilter;
    setState(() {
      _guideFilter = status;
      _loadingGuides = true;
    });
    try {
      final guides = await AdminService.fetchGuidesByStatus(status);
      if (!mounted) return;
      setState(() {
        _guidesForFilter = guides;
        _loadingGuides = false;
        _guidesLoadError = null;
        if (status == 'pending') {
          _pendingApprovals = guides.length;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingGuides = false;
        // Only revert if nothing more recent has already taken over the
        // filter selection while this request was in flight - otherwise a
        // slow, failing tap could stomp a newer tap's optimistic state.
        if (_guideFilter == status) {
          _guideFilter = previousFilter;
          _guidesLoadError = e is ApiError ? e.message : 'Erreur: $e';
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Administration',
          style: AppTextStyles.headlineMd.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.bold),
        ),
        // Transparent so the gradient painted by flexibleSpace shows through.
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.onPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights, color: AppColors.onPrimary),
            tooltip: 'Tableau de bord (revenu & abonnements)',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.adminAnalytics),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.onPrimary),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.onPrimary,
          unselectedLabelColor: AppColors.onPrimary.withValues(alpha: 0.7),
          indicatorColor: AppColors.onPrimary,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Utilisateurs'),
            Tab(icon: Icon(Icons.pending_actions), text: 'Approbations'),
            Tab(icon: Icon(Icons.support_agent), text: 'Support'),
          ],
        ),
      ),
      body: _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          )
        : _loadErrorMessage != null
        ? ErrorState(
            title: 'Une erreur est survenue',
            message: _loadErrorMessage!,
            onRetry: _loadData,
          )
        : Column(
            children: [
              _buildStatsBanner(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildUsersList(),
                    _buildGuideApprovalsTab(),
                    _buildSupportList(),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  // ============================================
  // BANNIÈRE DE STATISTIQUES
  // ============================================
  
  Widget _buildStatsBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(child: StatTile(label: 'Total', value: _totalUsers.toString(), icon: Icons.group)),
          const SizedBox(width: 8),
          Expanded(child: StatTile(label: 'Actifs', value: _activeGuides.toString(), icon: Icons.verified)),
          const SizedBox(width: 8),
          Expanded(child: StatTile(label: 'En attente', value: _pendingApprovals.toString(), icon: Icons.hourglass_empty)),
          const SizedBox(width: 8),
          Expanded(child: StatTile(label: 'Support', value: _unresolvedSupport.toString(), icon: Icons.support_agent)),
        ],
      ),
    );
  }

  // ============================================
  // LISTE DES UTILISATEURS
  // ============================================
  
  Widget _buildUsersList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: user.role == 'guide'
                  ? AppColors.secondary
                  : AppColors.primary.withValues(alpha: 0.2),
              child: Icon(
                user.role == 'guide' ? Icons.hiking : Icons.person,
                color: user.role == 'guide' ? AppColors.onPrimary : AppColors.primary,
              ),
            ),
            title: Text(
              user.fullName,
              style: AppTextStyles.titleMd,
            ),
            subtitle: Text('${user.email}\nRole: ${user.role}'),
            trailing: Switch(
              value: user.isActive,
              activeColor: AppColors.primary,
              onChanged: (val) async {
                try {
                  await AdminService.toggleUserStatus(user.id);
                  if (!context.mounted) return;
                  _loadData();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: $e'), 
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  // ============================================
  // LISTE DES GUIDES EN ATTENTE (AVEC VISUALISATION)
  // ============================================
  
  Widget _buildGuideApprovalsTab() {
    const filters = {
      'pending': 'En attente',
      'approved': 'Approuvés',
      'rejected': 'Rejetés',
    };
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: filters.entries.map((e) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(e.value),
                  selected: _guideFilter == e.key,
                  onSelected: (_) => _loadGuidesByFilter(e.key),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: _loadingGuides
              ? const Center(child: CircularProgressIndicator())
              : _guidesLoadError != null
                  ? ErrorState(
                      title: 'Une erreur est survenue',
                      message: _guidesLoadError!,
                      onRetry: () => _loadGuidesByFilter(_guideFilter),
                    )
                  : _guidesForFilter.isEmpty
                      ? Center(
                          child: Text('Aucun guide (${filters[_guideFilter]})',
                              style: AppTextStyles.bodySm),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _guidesForFilter.length,
                          itemBuilder: (context, i) => _buildGuideCard(_guidesForFilter[i]),
                        ),
        ),
      ],
    );
  }

  Widget _buildGuideCard(GuideProfile guide) {
    final isPending = guide.approvalStatus == 'pending';
    final isRejected = guide.approvalStatus == 'rejected';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Expérience : ${guide.yearsOfExperience} ans',
                      style: AppTextStyles.titleMd),
                ),
                StatusBadge(status: guide.approvalStatus),
                IconButton(
                  icon: const Icon(Icons.visibility, color: AppColors.primary),
                  onPressed: () => _showGuideDocuments(guide),
                  tooltip: 'Voir les documents',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(guide.bio, style: AppTextStyles.bodySm, maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: guide.specialties
                  .map((s) => Chip(
                        label: Text(s, style: AppTextStyles.labelCaps.copyWith(color: AppColors.primary)),
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      ))
                  .toList(),
            ),
            if (isRejected && (guide.rejectionReason ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Text('Motif : ${guide.rejectionReason}',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
              ),
            ],
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _handleReject(guide.id),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Rejeter'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _handleApprove(guide.id),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approuver'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: AppColors.onPrimary),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================
  // VISUALISATION DES DOCUMENTS
  // ============================================
  
  void _showGuideDocuments(GuideProfile guide) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // Transparent so the sheet's own rounded-top surface (below) shows
      // through instead of the framework's opaque default.
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textLight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Titre
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Documents du guide',
                      style: AppTextStyles.headlineMd,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            const Divider(),
            
            // Documents
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDocumentSection(
                      'Photo de profil',
                      guide.profilePhotoUrl,
                      Icons.person,
                    ),
                    const SizedBox(height: 20),
                    _buildProtectedDocumentSection(
                      'Carte de licence',
                      guide.licenseCardUrl,
                      Icons.badge,
                      guideId: guide.id,
                      docType: 'license',
                    ),
                    const SizedBox(height: 20),
                    _buildProtectedDocumentSection(
                      'Carte CINE',
                      guide.cineCardUrl,
                      Icons.credit_card,
                      guideId: guide.id,
                      docType: 'cine',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentSection(String title, String? url, IconData icon) {
    final imageUrl = AdminService.getImageUrl(url);
    final hasImage = imageUrl.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(title, style: AppTextStyles.titleMd),
          ],
        ),
        const SizedBox(height: 12),
        // "Not submitted" must stay visually distinct from "submitted but
        // failed to load" — an admin decides approve/reject on whether the
        // document exists at all. BrandImage's placeholder covers loading
        // and load-error identically (both cases DO have a URL), so only
        // route through it once a URL is actually present; render a bespoke
        // "no document" surface ourselves otherwise (ui_kit.dart is closed).
        hasImage
            ? BrandImage(url: imageUrl, height: 250, radius: 12, icon: icon)
            : _buildMissingDocumentPlaceholder(),
      ],
    );
  }

  /// Pièces d'identité (licence, CINE) — servies uniquement par l'endpoint
  /// administrateur, avec un jeton porteur. Elles ne sont plus accessibles via
  /// /uploads, donc l'URL stockée en base ne sert plus qu'à savoir si le guide
  /// a bien déposé le document : la distinction « non fourni » / « fourni mais
  /// illisible » doit rester visible pour décider d'approuver ou de rejeter.
  Widget _buildProtectedDocumentSection(
    String title,
    String? url,
    IconData icon, {
    required String guideId,
    required String docType,
  }) {
    final hasDocument = url != null && url.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(title, style: AppTextStyles.titleMd),
          ],
        ),
        const SizedBox(height: 12),
        hasDocument
            ? FutureBuilder<Map<String, String>>(
                future: ApiService.authHeadersForImages(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox(
                      height: 250,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      ApiService.guideDocumentUrl(guideId, docType),
                      headers: snapshot.data,
                      height: 250,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _buildUnavailableDocumentPlaceholder(),
                    ),
                  );
                },
              )
            : _buildMissingDocumentPlaceholder(),
      ],
    );
  }

  /// Document déposé mais impossible à charger — distinct de « aucun document ».
  Widget _buildUnavailableDocumentPlaceholder() {
    return Container(
      width: double.infinity,
      height: 250,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.broken_image_outlined, size: 48, color: AppColors.error),
            const SizedBox(height: 8),
            Text('Document indisponible', style: AppTextStyles.bodySm),
          ],
        ),
      ),
    );
  }

  Widget _buildMissingDocumentPlaceholder() {
    return Container(
      width: double.infinity,
      height: 250,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.image_not_supported_outlined, size: 48, color: AppColors.textLight),
            const SizedBox(height: 8),
            Text('Aucun document fourni', style: AppTextStyles.bodySm),
          ],
        ),
      ),
    );
  }

  // ============================================
  // APPROBATION ET REJET
  // ============================================
  
  Future<void> _handleApprove(String id) async {
    try {
      await AdminService.approveGuide(id);
      if (!mounted) return;
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Guide approuvé'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleReject(String id) async {
    final reasonController = TextEditingController();
    try {
      String? reasonError;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Rejeter ce guide'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Veuillez expliquer le motif du rejet:',
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.textDark),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Ex: Les documents fournis ne sont pas suffisamment lisibles...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
                InlineError(message: reasonError),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Annuler', style: AppTextStyles.bodySm),
              ),
              ElevatedButton(
                onPressed: () {
                  if (reasonController.text.trim().length < 10) {
                    setDialogState(() {
                      reasonError = 'Le motif doit contenir au moins 10 caractères';
                    });
                    return;
                  }
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
                child: const Text('Rejeter'),
              ),
            ],
          ),
        ),
      );

      if (confirmed == true && mounted) {
        try {
          await AdminService.rejectGuide(id, reasonController.text.trim());
          if (!mounted) return;
          _loadData();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Guide rejeté'),
              backgroundColor: AppColors.error,
            ),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } finally {
      reasonController.dispose();
    }
  }

  // ============================================
  // LISTE DES MESSAGES DE SUPPORT
  // ============================================
  
  Widget _buildSupportList() {
    if (_supportMessages.isEmpty) {
      return Center(
        child: Text(
          'Aucun message de support',
          style: AppTextStyles.bodySm,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _supportMessages.length,
      itemBuilder: (context, index) {
        final message = _supportMessages[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: message.isResolved
                  ? AppColors.success.withValues(alpha: 0.2)
                  : AppColors.error.withValues(alpha: 0.2),
              child: Icon(
                message.isResolved ? Icons.check_circle : Icons.help_outline,
                color: message.isResolved ? AppColors.success : AppColors.error,
              ),
            ),
            title: Text(
              message.subject,
              style: AppTextStyles.titleMd,
            ),
            subtitle: Text(
              '${message.userName} • ${_formatDate(message.createdAt)}',
              style: AppTextStyles.bodySm,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Email de l'utilisateur
                    Row(
                      children: [
                        const Icon(Icons.email, size: 16, color: AppColors.textLight),
                        const SizedBox(width: 8),
                        Text(
                          message.userEmail,
                          style: AppTextStyles.bodySm,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Message
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        message.message,
                        style: AppTextStyles.bodySm.copyWith(color: AppColors.textDark),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Bouton Marquer comme résolu
                    if (!message.isResolved)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _handleResolveSupport(message.id),
                          icon: const Icon(Icons.check),
                          label: const Text('Marquer comme résolu'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: AppColors.onPrimary,
                          ),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Résolu le ${_formatDate(message.resolvedAt!)}',
                              style: AppTextStyles.bodySm.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleResolveSupport(String messageId) async {
    try {
      await AdminService.resolveSupportMessage(messageId);
      if (!mounted) return;
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Message marqué comme résolu'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ============================================
  // HELPERS
  // ============================================
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return 'Il y a ${diff.inMinutes} min';
      }
      return 'Il y a ${diff.inHours}h';
    } else if (diff.inDays == 1) {
      return 'Hier';
    } else if (diff.inDays < 7) {
      return 'Il y a ${diff.inDays} jours';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}