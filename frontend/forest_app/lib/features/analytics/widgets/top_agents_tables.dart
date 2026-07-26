import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../models/analytics_models.dart';
import '../providers/analytics_provider.dart';

class TopAgentsTables extends ConsumerWidget {
  const TopAgentsTables({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final validationAsync = ref.watch(topAgentsValidationProvider);
    final rejectionAsync  = ref.watch(topAgentsRejectionProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Top 5 agents — validation',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                validationAsync.when(
                  data: (agents) => Column(
                    children: [for (final a in agents) _ValidationRow(agent: a)],
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (e, _) => Text('Erreur : $e',
                      style: const TextStyle(fontSize: 11, color: AppColors.danger)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Top 5 agents — rejet',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                rejectionAsync.when(
                  data: (agents) => Column(
                    children: [for (final a in agents) _RejectionRow(agent: a)],
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (e, _) => Text('Erreur : $e',
                      style: const TextStyle(fontSize: 11, color: AppColors.danger)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ValidationRow extends StatefulWidget {
  final TopAgentValidation agent;
  const _ValidationRow({required this.agent});

  @override
  State<_ValidationRow> createState() => _ValidationRowState();
}

class _ValidationRowState extends State<_ValidationRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderLight, width: 0.5)),
      ),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.agent.nom,
                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
              Row(
                children: [
                  Text('${widget.agent.rate.round()}%',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RejectionRow extends StatefulWidget {
  final TopAgentRejection agent;
  const _RejectionRow({required this.agent});

  @override
  State<_RejectionRow> createState() => _RejectionRowState();
}

class _RejectionRowState extends State<_RejectionRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.agent;
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderLight, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(a.nom, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                  Row(
                    children: [
                      Text('${a.rate.round()}%',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.danger)),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: const Icon(Icons.keyboard_arrow_down,
                            size: 16, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ContactLine(icon: Icons.phone, text: a.agentPhone ?? '—'),
                  const SizedBox(height: 4),
                  _ContactLine(icon: Icons.email_outlined, text: a.agentEmail ?? '—'),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: AppColors.borderLight),
                  const SizedBox(height: 8),
                  const Text('Superviseur',
                      style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  const SizedBox(height: 4),
                  Text(a.supervisorNom ?? 'Non affecté',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  if (a.supervisorNom != null) ...[
                    const SizedBox(height: 4),
                    _ContactLine(icon: Icons.phone, text: a.supervisorPhone ?? '—'),
                    const SizedBox(height: 4),
                    _ContactLine(icon: Icons.email_outlined, text: a.supervisorEmail ?? '—'),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ContactLine extends StatelessWidget {
  final IconData icon;
  final String   text;
  const _ContactLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 11, color: AppColors.textPrimary)),
        ],
      );
}