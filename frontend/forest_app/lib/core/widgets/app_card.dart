import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Card blanc avec bordure fine — utilisé partout dans les dashboards
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: child,
    );
  }
}

/// En-tête de card avec titre à gauche et lien à droite
class AppCardHeader extends StatelessWidget {
  final String title;
  final String? linkLabel;
  final VoidCallback? onLinkTap;

  const AppCardHeader({
    super.key,
    required this.title,
    this.linkLabel,
    this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const Spacer(),
        if (linkLabel != null)
          GestureDetector(
            onTap: onLinkTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFC8E6D8), width: 0.5),
              ),
              child: Text(linkLabel!,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.primaryMid,
                      fontWeight: FontWeight.w500)),
            ),
          ),
      ],
    );
  }
}

/// Badge de statut coloré (Actif, En attente, Nouveau…)
class StatusPill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const StatusPill({
    super.key,
    required this.label,
    required this.bg,
    required this.fg,
  });

  factory StatusPill.active()  => const StatusPill(label: 'Actif',      bg: AppColors.successBg, fg: AppColors.primaryMid);
  factory StatusPill.pending() => const StatusPill(label: 'En attente', bg: AppColors.warningBg, fg: Color(0xFF92400E));
  factory StatusPill.newUser() => const StatusPill(label: 'Nouveau',    bg: AppColors.infoBg,    fg: AppColors.info);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w500)),
    );
  }
}