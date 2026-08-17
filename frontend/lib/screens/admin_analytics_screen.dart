import 'package:flutter/material.dart';

import '../models/admin_models.dart';
import '../services/admin_service.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_colors.dart';
import '../widgets/revenue_bar_chart.dart';
import '../widgets/stat_tile.dart';

/// Tableau de bord analytique admin — revenu & abonnements RÉELS
/// (agrégés côté backend depuis la table `subscriptions`). Design Stitch.
class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashboardData> _load() async {
    final results = await Future.wait([
      AdminService.fetchAnalyticsOverview(),
      AdminService.fetchRevenueTimeseries(months: 6),
      AdminService.fetchSubscriptionsBreakdown(),
    ]);
    return _DashboardData(
      overview: results[0] as RevenueOverview,
      revenue: results[1] as RevenueTimeseries,
      subscriptions: results[2] as SubscriptionsBreakdown,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  String _money(double v, String currency) => '${v.toStringAsFixed(0)} $currency';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tableau de bord')),
      body: FutureBuilder<_DashboardData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorView(message: '${snap.error}', onRetry: _refresh);
          }
          final data = snap.data!;
          final o = data.overview;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Revenu & abonnements', style: AppTextStyles.headlineMd),
                const SizedBox(height: 4),
                Text('Données en temps réel', style: AppTextStyles.bodySm),
                const SizedBox(height: 16),

                // ── KPI ──────────────────────────────────────────────
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.55,
                  children: [
                    StatTile(
                      label: 'Revenu total',
                      value: _money(o.totalRevenue, o.currency),
                      icon: Icons.payments_outlined,
                    ),
                    StatTile(
                      label: 'MRR',
                      value: _money(o.mrr, o.currency),
                      icon: Icons.autorenew,
                    ),
                    StatTile(
                      label: 'Abonnements actifs',
                      value: '${o.activeSubscriptions}',
                      icon: Icons.verified_user_outlined,
                    ),
                    StatTile(
                      label: 'Ce mois-ci',
                      value: _money(o.revenueThisMonth, o.currency),
                      delta: '${o.revenueGrowthPct >= 0 ? '+' : ''}${o.revenueGrowthPct.toStringAsFixed(1)}%',
                      positive: o.revenueGrowthPct >= 0,
                      icon: Icons.calendar_today_outlined,
                    ),
                    StatTile(
                      label: 'Nouveaux abos',
                      value: '${o.newSubscriptionsThisMonth}',
                      icon: Icons.person_add_alt,
                    ),
                    StatTile(
                      label: 'ARPU',
                      value: _money(o.arpu, o.currency),
                      icon: Icons.insights_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Graphe revenu ────────────────────────────────────
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Revenu mensuel', style: AppTextStyles.titleMd),
                          Text(
                            _money(data.revenue.totalRevenue, data.revenue.currency),
                            style: AppTextStyles.titleMd.copyWith(color: AppColors.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      RevenueBarChart(
                        points: data.revenue.points,
                        currency: data.revenue.currency,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Répartition par tier ─────────────────────────────
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Abonnements par formule', style: AppTextStyles.titleMd),
                      const SizedBox(height: 12),
                      if (data.subscriptions.byTier.isEmpty)
                        Text('Aucun abonnement actif', style: AppTextStyles.bodySm)
                      else
                        ...data.subscriptions.byTier.map((t) => _TierRow(t: t, currency: data.subscriptions.currency)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DashboardData {
  final RevenueOverview overview;
  final RevenueTimeseries revenue;
  final SubscriptionsBreakdown subscriptions;
  _DashboardData({required this.overview, required this.revenue, required this.subscriptions});
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: child,
      );
}

class _TierRow extends StatelessWidget {
  final TierBreakdown t;
  final String currency;
  const _TierRow({required this.t, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 10, height: 10,
            decoration: const BoxDecoration(color: AppColors.mint, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t.tier.toUpperCase(),
              style: AppTextStyles.bodyLg.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Text('${t.active} actifs', style: AppTextStyles.bodySm),
          const SizedBox(width: 16),
          Text(
            '${t.revenue.toStringAsFixed(0)} $currency',
            style: AppTextStyles.bodyLg.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: AppTextStyles.bodySm),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
