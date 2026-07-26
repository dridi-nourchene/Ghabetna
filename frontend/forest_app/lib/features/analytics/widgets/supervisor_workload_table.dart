import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../providers/analytics_provider.dart';

class SupervisorWorkloadTable extends ConsumerWidget {
  const SupervisorWorkloadTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(supervisorWorkloadProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Charge et qualité des superviseurs',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          async.when(
            data: (workload) => Table(
              columnWidths: const {0: FlexColumnWidth(1.6)},
              children: [
                const TableRow(children: [
                  _Header('Superviseur', alignLeft: true),
                  _Header('Forêts'),
                  _Header('Charge'),
                  _Header('Taux rejet'),
                  _Header('Temps moy.'),
                ]),
                for (final item in workload.items)
                  TableRow(
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.borderLight, width: 0.5)),
                    ),
                    children: [
                      _Cell(item.nom, alignLeft: true),
                      _Cell('${item.forestCount}'),
                      _Cell('${item.alertCount}'),
                      _Cell(
                        '${item.rejectRate.toStringAsFixed(1)}%',
                        isDanger: item.rejectRate >= workload.threshold,
                      ),
                      _Cell('${item.avgTreatmentHours.toStringAsFixed(1)}h'),
                    ],
                  ),
              ],
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Text('Erreur : $e',
                style: const TextStyle(fontSize: 11, color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String label;
  final bool   alignLeft;
  const _Header(this.label, {this.alignLeft = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Text(label,
            textAlign: alignLeft ? TextAlign.left : TextAlign.center,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
      );
}

class _Cell extends StatelessWidget {
  final String text;
  final bool   alignLeft;
  final bool   isDanger;
  const _Cell(this.text, {this.alignLeft = false, this.isDanger = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Text(text,
            textAlign: alignLeft ? TextAlign.left : TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isDanger ? FontWeight.w700 : FontWeight.w400,
              color: isDanger ? AppColors.danger : AppColors.textPrimary,
            )),
      );
}