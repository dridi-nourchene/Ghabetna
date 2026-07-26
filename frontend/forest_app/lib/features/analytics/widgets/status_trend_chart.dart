import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../models/analytics_models.dart';
import '../providers/analytics_provider.dart';

class StatusTrendChart extends ConsumerWidget {
  const StatusTrendChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trend = ref.watch(statusTrendProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Évolution des statuts (hebdomadaire)',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const _Legend(),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: trend.isLoading && trend.data == null
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : (trend.data == null || trend.data!.isEmpty)
                    ? const Center(
                        child: Text('Aucune donnée',
                            style: TextStyle(fontSize: 12, color: AppColors.textMuted)))
                    : _Chart(points: trend.data!),
          ),
        ],
      ),
    );
  }
}

class _Chart extends StatelessWidget {
  final List<StatusTrendPoint> points;
  const _Chart({required this.points});

  @override
  Widget build(BuildContext context) {
    List<FlSpot> spots(int Function(StatusTrendPoint) pick) => [
          for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), pick(points[i]).toDouble())
        ];

    final maxY = points
        .expand((p) => [p.enCours, p.traiter, p.rejeter])
        .fold<int>(0, (a, b) => a > b ? a : b)
        .toDouble();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: (maxY * 1.2).clamp(4, double.infinity),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.borderLight, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (v, _) => Text(v.round().toString(),
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                final label = points[i].period.length >= 10
                    ? points[i].period.substring(5)
                    : points[i].period;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(label,
                      style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          _line(spots((p) => p.enCours), AppColors.warning),
          _line(spots((p) => p.traiter), AppColors.success),
          _line(spots((p) => p.rejeter), AppColors.danger),
        ],
      ),
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) => LineChartBarData(
        spots: spots,
        isCurved: true,
        color: color,
        barWidth: 2,
        dotData: const FlDotData(show: false),
      );
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) => const Row(
        children: [
          _Dot(color: AppColors.warning, label: 'En cours'),
          SizedBox(width: 14),
          _Dot(color: AppColors.success, label: 'Traitées'),
          SizedBox(width: 14),
          _Dot(color: AppColors.danger, label: 'Rejetées'),
        ],
      );
}

class _Dot extends StatelessWidget {
  final Color  color;
  final String label;
  const _Dot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      );
}