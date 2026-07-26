import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../models/analytics_models.dart';
import '../providers/analytics_provider.dart';

// Types d'alertes affichés en colonnes (aligné sur AlertType du backend)
const _alertTypes = ['incendie', 'vol', 'inondation', 'glissement', 'maladie'];
const _alertTypeLabels = {
  'incendie':   'Incendie',
  'vol':        'Vol',
  'inondation': 'Inondation',
  'glissement': 'Glissement',
  'maladie':    'Maladie',
};

class ForestTypeMatrix extends ConsumerWidget {
  const ForestTypeMatrix({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matrix = ref.watch(matrixProvider);
    final search = ref.watch(matrixSearchProvider).toLowerCase();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Matrice forêt × type d\'alerte',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          TextField(
            onChanged: (v) => ref.read(matrixSearchProvider.notifier).state = v,
            decoration: InputDecoration(
              hintText: 'Rechercher une forêt...',
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border, width: 0.5),
              ),
            ),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (matrix.isLoading && matrix.data == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            _MatrixTable(
              rows: (matrix.data ?? [])
                  .where((r) => r.forestName.toLowerCase().contains(search))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _MatrixTable extends StatelessWidget {
  final List<ForestTypeMatrixRow> rows;
  const _MatrixTable({required this.rows});

  // Intensité de la teinte selon le compte, plafonnée pour rester lisible/transparente
  Color _cellColor(int count, int maxInRow) {
    if (count == 0) return Colors.transparent;
    final ratio = maxInRow == 0 ? 0.0 : (count / maxInRow).clamp(0.15, 1.0);
    // opacité max volontairement basse (0.35) pour un rendu discret, pas "flashy"
    return AppColors.danger.withOpacity(0.08 + ratio * 0.27);
  }

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text('Aucune forêt trouvée',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ),
      );
    }

    return Table(
      columnWidths: const {0: FlexColumnWidth(1.4)},
      children: [
        TableRow(
          children: [
            const _HeaderCell('Forêt', alignLeft: true),
            for (final t in _alertTypes) _HeaderCell(_alertTypeLabels[t]!),
          ],
        ),
        for (final row in rows)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Text(row.forestName,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ),
              for (final t in _alertTypes)
                _Cell(
                  count: row.countsByType[t] ?? 0,
                  color: _cellColor(
                    row.countsByType[t] ?? 0,
                    row.countsByType.values.isEmpty
                        ? 0
                        : row.countsByType.values.reduce((a, b) => a > b ? a : b),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final bool   alignLeft;
  const _HeaderCell(this.label, {this.alignLeft = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Text(label,
            textAlign: alignLeft ? TextAlign.left : TextAlign.center,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
      );
}

class _Cell extends StatelessWidget {
  final int   count;
  final Color color;
  const _Cell({required this.count, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(2),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
          child: Text(
            count == 0 ? '–' : '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: count == 0 ? FontWeight.w400 : FontWeight.w600,
              color: count == 0 ? AppColors.textMuted : AppColors.textPrimary,
            ),
          ),
        ),
      );
}