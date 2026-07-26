import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../analytics/providers/analytics_provider.dart';
import '../../analytics/widgets/kpi_cards_row.dart';
import '../../analytics/widgets/alerts_by_forest_chart.dart';
import '../../analytics/widgets/status_trend_chart.dart';
import '../../analytics/widgets/forest_type_matrix.dart';
import '../../analytics/widgets/top_agents_tables.dart';
import '../../analytics/widgets/supervisor_workload_table.dart';
import '../../analytics/models/analytics_models.dart';

class AdminAnalyticsScreen extends ConsumerWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(analyticsTabProvider);
    final alertsByForest = ref.watch(alertsByForestProvider).data;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Analytics',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3)),
          const SizedBox(height: 3),
          const Text('Vue agrégée — aucun détail d\'alerte individuelle affiché',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 16),

          _TabBar(current: tab, onChanged: (i) => ref.read(analyticsTabProvider.notifier).state = i),
          const SizedBox(height: 16),

          if (tab == 0) ...[
            const KpiCardsRow(),
            const SizedBox(height: 16),
            AlertsByForestChart(
              data: alertsByForest ?? const AlertsByForestData(items: []),
            ),
            const SizedBox(height: 16),
            const StatusTrendChart(),
            const SizedBox(height: 16),
            const ForestTypeMatrix(),
          ] else ...[
            const TopAgentsTables(),
            const SizedBox(height: 16),
            const SupervisorWorkloadTable(),
          ],
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final int                current;
  final ValueChanged<int>  onChanged;
  const _TabBar({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TabButton(label: 'Overview', selected: current == 0, onTap: () => onChanged(0)),
          _TabButton(label: 'Agents et superviseurs', selected: current == 1, onTap: () => onChanged(1)),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String       label;
  final bool         selected;
  final VoidCallback onTap;
  const _TabButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryDark : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }
}