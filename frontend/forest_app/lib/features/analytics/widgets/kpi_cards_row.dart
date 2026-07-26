import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/analytics_provider.dart';

class KpiCardsRow extends ConsumerWidget {
  const KpiCardsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(overviewProvider);

    if (overview.isLoading && overview.data == null) {
      return const SizedBox(
        height: 96,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (overview.error != null) {
      return _ErrorBox(message: overview.error!);
    }

    final data = overview.data;
    if (data == null) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: _KpiCard.primary(
            label: 'Total alertes',
            value: '${data.totalAlerts}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiCard.white(
            label: 'Forêt la plus touchée',
            value: data.mostAffectedForestName ?? '—',
            sub: data.mostAffectedForestName != null
                ? '${data.mostAffectedForestCount} confirmées / en cours'
                : 'Aucune donnée',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiCard.white(
            label: 'Taux de validation global',
            value: '${data.globalValidationRate.round()}%',
            sub: ' ',
            valueColor: AppColors.success,
          ),
        ),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.dangerBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(message,
            style: const TextStyle(fontSize: 12, color: AppColors.danger)),
      );
}

class _KpiCard extends StatelessWidget {
  final String  label;
  final String  value;
  final String? sub;
  final bool    isPrimary;
  final Color?  valueColor;

  const _KpiCard._({
    required this.label,
    required this.value,
    this.sub,
    required this.isPrimary,
    this.valueColor,
  });

  factory _KpiCard.primary({required String label, required String value}) =>
      _KpiCard._(label: label, value: value, isPrimary: true);

  factory _KpiCard.white({
    required String label,
    required String value,
    String? sub,
    Color? valueColor,
  }) =>
      _KpiCard._(label: label, value: value, sub: sub, isPrimary: false, valueColor: valueColor);

  @override
  Widget build(BuildContext context) {
    final bg = isPrimary ? AppColors.primaryDark : AppColors.bgCard;
    final labelColor = isPrimary ? Colors.white.withOpacity(0.6) : AppColors.textSecondary;
    final resolvedValueColor =
        isPrimary ? Colors.white : (valueColor ?? AppColors.textPrimary);
    final subColor = isPrimary ? Colors.white.withOpacity(0.5) : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPrimary ? AppColors.primaryDark : AppColors.border,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: labelColor)),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w700, color: resolvedValueColor)),
          if (sub != null) ...[
            const SizedBox(height: 6),
            Text(sub!, style: TextStyle(fontSize: 11, color: subColor)),
          ],
        ],
      ),
    );
  }
}