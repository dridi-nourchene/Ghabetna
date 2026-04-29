// features/forest/widgets/shared_widgets.dart

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../constants/forest_constant.dart';

// ═══════════════════════════════════════════════════════════════
//  SideTab — tab vertical sur le bord droit de la sidebar
// ═══════════════════════════════════════════════════════════════

class SideTab extends StatelessWidget {
  final String     label;
  final IconData   icon;
  final Color      color;
  final bool       isActive;
  final bool       isTop;
  final VoidCallback onTap;

  const SideTab({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.isActive,
    required this.isTop,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 26,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isActive ? color : color.withOpacity(0.82),
            borderRadius: BorderRadius.only(
              topLeft:    isTop ? const Radius.circular(8) : Radius.zero,
              bottomLeft: isTop ? Radius.zero : const Radius.circular(8),
            ),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset:     const Offset(-2, 0),
              ),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              isActive ? Icons.chevron_left : Icons.chevron_right,
              color: Colors.white,
              size:  16,
            ),
            const SizedBox(height: 8),
            RotatedBox(
              quarterTurns: 1,
              child: Text(
                label,
                style: TextStyle(
                  fontSize:      8,
                  fontWeight:    FontWeight.w700,
                  color:         Colors.white.withOpacity(isActive ? 1.0 : 0.7),
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ]),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════
//  PanelHeader
// ═══════════════════════════════════════════════════════════════

class PanelHeader extends StatelessWidget {
  final String title, count, btnLabel;
  final IconData icon;
  final Color color, btnColor;
  final VoidCallback onBtn;

  const PanelHeader({
    super.key,
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.btnLabel,
    required this.btnColor,
    required this.onBtn,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          border: const Border(
              bottom: BorderSide(color: AppColors.borderLight, width: 0.5)),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              Text(count,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textMuted)),
            ]),
          ),
          GestureDetector(
            onTap: onBtn,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: btnColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                    color: btnColor.withOpacity(0.35), width: 0.8),
              ),
              child: Text(btnLabel,
                  style: TextStyle(
                      fontSize: 11,
                      color: btnColor,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      );
}

// ═══════════════════════════════════════════════════════════════
//  PanelSearch
// ═══════════════════════════════════════════════════════════════

class PanelSearch extends StatelessWidget {
  final void Function(String) onChanged;

  const PanelSearch({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(10),
        child: SizedBox(
          height: 34,
          child: TextField(
            onChanged: onChanged,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText:   'Rechercher...',
              hintStyle:  const TextStyle(
                  fontSize: 11, color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search,
                  size: 14, color: AppColors.textMuted),
              filled:    true,
              fillColor: AppColors.bgInput,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(
                    color: AppColors.border, width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(
                    color: AppColors.border, width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(
                    color: AppColors.primaryMid, width: 1.0),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 0),
              isDense: true,
            ),
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════
//  IconBtn
// ═══════════════════════════════════════════════════════════════

class IconBtn extends StatelessWidget {
  final IconData      icon;
  final Color         color;
  final VoidCallback? onTap;
  final double        size;

  const IconBtn({
    super.key,
    required this.icon,
    required this.color,
    this.onTap,
    this.size = 26,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: color.withOpacity(0.25), width: 0.5),
          ),
          child: Icon(icon, size: size * 0.55, color: color),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════
//  EmptyPanel
// ═══════════════════════════════════════════════════════════════

class EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String   message;
  final String?  sub;

  const EmptyPanel({
    super.key,
    required this.icon,
    required this.message,
    this.sub,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 36, color: AppColors.textMuted),
            const SizedBox(height: 10),
            Text(message,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            if (sub != null) ...[
              const SizedBox(height: 4),
              Text(sub!,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted),
                  textAlign: TextAlign.center),
            ],
          ]),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════
//  ErrorBanner
// ═══════════════════════════════════════════════════════════════

class ErrorBanner extends StatelessWidget {
  final String       message;
  final VoidCallback onDismiss;

  const ErrorBanner({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.08),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
              color: AppColors.danger.withOpacity(0.3), width: 0.5),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline,
              size: 14, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.danger))),
          GestureDetector(
              onTap: onDismiss,
              child: const Icon(Icons.close,
                  size: 14, color: AppColors.danger)),
        ]),
      );
}

// ═══════════════════════════════════════════════════════════════
//  DeleteDialog
// ═══════════════════════════════════════════════════════════════

class DeleteDialog extends StatelessWidget {
  final String  name;
  final String? extra;

  const DeleteDialog({super.key, required this.name, this.extra});

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded,
              color: AppColors.danger, size: 20),
          SizedBox(width: 8),
          Text('Confirmer la suppression',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
        ]),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5),
            children: [
              const TextSpan(text: 'Supprimer '),
              TextSpan(
                  text: name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const TextSpan(text: ' ? Action irréversible.'),
              if (extra != null)
                TextSpan(
                    text: '\n$extra',
                    style:
                        const TextStyle(color: AppColors.danger)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler',
                style:
                    TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      );
}

// ═══════════════════════════════════════════════════════════════
//  LoadingChip
// ═══════════════════════════════════════════════════════════════

class LoadingChip extends StatelessWidget {
  const LoadingChip({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppColors.border, width: 0.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primaryMid)),
          SizedBox(width: 8),
          Text('Chargement...',
              style: TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ]),
      );
}

// ═══════════════════════════════════════════════════════════════
//  PopupCard + PopBtn — partagés forêt et parcelle
// ═══════════════════════════════════════════════════════════════

class PopupCard extends StatelessWidget {
  final String        title;
  final String        subtitle;
  final IconData      icon;
  final Color         color;
  final VoidCallback? onEdit;
  final VoidCallback  onDelete;
  final VoidCallback  onClose;

  const PopupCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onEdit,
    required this.onDelete,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) => Material(
        elevation:    8,
        borderRadius: BorderRadius.circular(12),
        shadowColor:  Colors.black26,
        child: Container(
          width:   220,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.border, width: 0.5),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color:        color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 15, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textMuted)),
                    ]),
              ),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close,
                    size: 15, color: AppColors.textMuted),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              if (onEdit != null) ...[
                Expanded(
                    child: PopBtn(
                  label: 'Modifier',
                  icon:  Icons.edit_outlined,
                  color: color,
                  onTap: onEdit!,
                )),
                const SizedBox(width: 8),
              ],
              Expanded(
                  child: PopBtn(
                label: 'Supprimer',
                icon:  Icons.delete_outline,
                color: AppColors.danger,
                onTap: onDelete,
              )),
            ]),
          ]),
        ),
      );
}

class PopBtn extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;

  const PopBtn({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
                color: color.withOpacity(0.25), width: 0.5),
          ),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 5),
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ]),
        ),
      );
}