
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../models/analytics_models.dart';

class AlertsByForestChart extends StatelessWidget {
  final AlertsByForestData data;

  const AlertsByForestChart({super.key, required this.data});

  List<_BarEntry> get _entries {
    final entries = data.items
        .map((f) => _BarEntry(
              label:     f.forestName,
              rejected:  f.rejectedCount,
              confirmed: f.confirmedCount,
            ))
        .toList();

    if (data.hasOthers) {
      entries.add(_BarEntry(
        label:     'Autres (${data.othersForestCount})',
        rejected:  data.othersRejectedCount,
        confirmed: data.othersConfirmedCount,
        isOthers:  true,
      ));
    }
    return entries;
  }

  double get _maxY {
  final entries = _entries;
  if (entries.isEmpty) return 10;
  final maxVal = entries
      .map((e) => e.rejected > e.confirmed ? e.rejected : e.confirmed)
      .reduce((a, b) => a > b ? a : b);
  return (maxVal * 1.2).clamp(4, double.infinity).toDouble();
}

  @override
  Widget build(BuildContext context) {
    final entries  = _entries;
    final double interval = (_maxY / 4).clamp(1, double.infinity).toDouble();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────
          Row(
            children: [
              const Expanded(
                child: Text('Alertes par forêt',
                    style: TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                        color:      AppColors.textPrimary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: const Text('Top 10',
                    style: TextStyle(
                        fontSize:   11,
                        fontWeight: FontWeight.w600,
                        color:      AppColors.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const _Legend(),
          const SizedBox(height: 18),

          // ── Chart ─────────────────────────────────────
          SizedBox(
            height: 260,
            child: entries.isEmpty
                ? const Center(
                    child: Text('Aucune donnée',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  )
                : BarChart(
                    BarChartData(
                      maxY:        _maxY,
                      alignment:   BarChartAlignment.spaceAround,
                      groupsSpace: 20,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => AppColors.primaryDark, 
                          tooltipRoundedRadius: 8,
                          getTooltipItem: (group, _, rod, __) {
                            final isRejected = rod.color == AppColors.danger;
                            return BarTooltipItem(
                              '${isRejected ? "Rejetées" : "Confirmées/en cours"}\n${rod.toY.round()}',
                              const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            );
                          },
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: interval,
                        getDrawingHorizontalLine: (_) =>
                            const FlLine(color: AppColors.borderLight, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles:   true,
                            reservedSize: 34,
                            interval:     interval,
                            getTitlesWidget: (value, _) => Text(
                              value.round().toString(),
                              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles:   true,
                            reservedSize: 36,
                            getTitlesWidget: (value, _) {
                              final i = value.toInt();
                              if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  entries[i].label,
                                  style: TextStyle(
                                      fontSize:   10,
                                      fontWeight: entries[i].isOthers
                                          ? FontWeight.w400
                                          : FontWeight.w600,
                                      color: entries[i].isOthers
                                          ? AppColors.textMuted
                                          : AppColors.textSecondary),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: List.generate(entries.length, (i) {
                        final e = entries[i];
                        return BarChartGroupData(
                          x: i,
                          barsSpace: 4,
                          barRods: [
                            BarChartRodData(
                              toY:   e.rejected.toDouble(),
                              color: AppColors.danger,
                              width: 12,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                            ),
                            BarChartRodData(
                              toY:   e.confirmed.toDouble(),
                              color: AppColors.primaryDark,
                              width: 12,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Legend ───────────────────────────────────────────────────
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) => const Row(
        children: [
          _LegendDot(color: AppColors.danger,     label: 'Rejetées'),
          SizedBox(width: 16),
          _LegendDot(color: AppColors.primaryDark, label: 'Confirmées / en cours'),
        ],
      );
}

class _LegendDot extends StatelessWidget {
  final Color  color;
  final String label;
  const _LegendDot({required this.color, required this.label});

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

// ── Internal helper ────────────────────────────────────────
class _BarEntry {
  final String label;
  final int    rejected;
  final int    confirmed;
  final bool   isOthers;

  const _BarEntry({
    required this.label,
    required this.rejected,
    required this.confirmed,
    this.isOthers = false,
  });
}