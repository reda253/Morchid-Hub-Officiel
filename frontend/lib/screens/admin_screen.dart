import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../services/admin_service.dart';
import '../models/admin_models.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  
  List<UserData> _users = [];
  List<GuideProfile> _pendingGuides = [];
  List<SupportMessage> _supportMessages = [];
  
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
    setState(() => _isLoading = true);
    try {
      final users = await AdminService.fetchUsers();
      final pending = await AdminService.fetchPendingGuides();
      final support = await AdminService.fetchSupportMessages();
      
      if (!mounted) return;
      setState(() {
        _users = users;
        _pendingGuides = pending;
        _supportMessages = support;
        _totalUsers = users.length;
        _activeGuides = users.where((u) => u.isActive).length;
        _pendingApprovals = pending.length;
        _unresolvedSupport = support.where((m) => !m.isResolved).length;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'), 
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Administration', 
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
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
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
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
        : Column(
            children: [
              _buildStatsBanner(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildUsersList(),
                    _buildPendingGuidesList(),
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
          _buildStatItem('Total', _totalUsers.toString(), Icons.group),
          _buildStatItem('Actifs', _activeGuides.toString(), Icons.verified),
          _buildStatItem('En attente', _pendingApprovals.toString(), Icons.hourglass_empty),
          _buildStatItem('Support', _unresolvedSupport.toString(), Icons.support_agent),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary.withOpacity(0.6), size: 24),
        const SizedBox(height: 4),
        Text(
          value, 
          style: const TextStyle(
            fontSize: 18, 
            fontWeight: FontWeight.bold, 
            color: AppColors.textDark,
          ),
        ),
        Text(
          label, 
          style: const TextStyle(fontSize: 12, color: AppColors.textLight),
        ),
      ],
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
                  : AppColors.primary.withOpacity(0.2),
              child: Icon(
                user.role == 'guide' ? Icons.hiking : Icons.person,
                color: user.role == 'guide' ? Colors.white : AppColors.primary,
              ),
            ),
            title: Text(
              user.fullName, 
              style: const TextStyle(fontWeight: FontWeight.bold),
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
  
  Widget _buildPendingGuidesList() {
    if (_pendingGuides.isEmpty) {
      return const Center(
        child: Text(
          'Aucun guide en attente', 
          style: TextStyle(color: AppColors.textLight),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingGuides.length,
      itemBuilder: (context, index) {
        final guide = _pendingGuides[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête avec bouton visualisation
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Expérience: ${guide.yearsOfExperience} ans',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.visibility, color: AppColors.primary),
                      onPressed: () => _showGuideDocuments(guide),
                      tooltip: 'Voir les documents',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Bio
                Text(
                  guide.bio,
                  style: const TextStyle(color: AppColors.textLight),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                
                // Spécialités
                Wrap(
                  spacing: 8,
                  children: guide.specialties.map((s) => Chip(
                    label: Text(s, style: const TextStyle(fontSize: 12)),
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    labelStyle: const TextStyle(color: AppColors.primary),
                  )).toList(),
                ),
                const SizedBox(height: 12),
                
                // Boutons d'action
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _handleReject(guide.id),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Rejeter'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _handleApprove(guide.id),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approuver'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================
  // VISUALISATION DES DOCUMENTS
  // ============================================
  
  void _showGuideDocuments(GuideProfile guide) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                color: AppColors.textLight.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Titre
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Documents du guide',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
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
                    _buildDocumentSection(
                      'Carte de licence',
                      guide.licenseCardUrl,
                      Icons.badge,
                    ),
                    const SizedBox(height: 20),
                    _buildDocumentSection(
                      'Carte CINE',
                      guide.cineCardUrl,
                      Icons.credit_card,
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
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 250,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.textLight.withOpacity(0.2)),
          ),
          child: hasImage
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: AppColors.primary,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: AppColors.error),
                            SizedBox(height: 8),
                            Text(
                              'Erreur de chargement',
                              style: TextStyle(color: AppColors.textLight),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                )
              : const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported, size: 48, color: AppColors.textLight),
                      SizedBox(height: 8),
                      Text(
                        'Aucune image disponible',
                        style: TextStyle(color: AppColors.textLight),
                      ),
                    ],
                  ),
                ),
        ),
      ],
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
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejeter ce guide'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Veuillez expliquer le motif du rejet:',
              style: TextStyle(color: AppColors.textDark),
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: AppColors.textLight)),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().length < 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Le motif doit contenir au moins 10 caractères'),
                    backgroundColor: AppColors.error,
                  ),
                );
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
  }

  // ============================================
  // LISTE DES MESSAGES DE SUPPORT
  // ============================================
  
  Widget _buildSupportList() {
    if (_supportMessages.isEmpty) {
      return const Center(
        child: Text(
          'Aucun message de support',
          style: TextStyle(color: AppColors.textLight),
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
                  ? AppColors.success.withOpacity(0.2) 
                  : AppColors.error.withOpacity(0.2),
              child: Icon(
                message.isResolved ? Icons.check_circle : Icons.help_outline,
                color: message.isResolved ? AppColors.success : AppColors.error,
              ),
            ),
            title: Text(
              message.subject,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${message.userName} • ${_formatDate(message.createdAt)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textLight),
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
                          style: const TextStyle(color: AppColors.textLight),
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
                        style: const TextStyle(color: AppColors.textDark),
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
                            foregroundColor: Colors.white,
                          ),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Résolu le ${_formatDate(message.resolvedAt!)}',
                              style: const TextStyle(
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