import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../data/alert_models.dart';

/// Sélecteur du type d'alerte — les 9 valeurs d'alert_ms, sans distinction
/// agent/citoyen : rien dans le backend ne les sépare.
class TypeDropdown extends StatelessWidget {
  const TypeDropdown({super.key, required this.selection, required this.onSelect});

  final AlertType? selection;
  final void Function(AlertType) onSelect;

  static const double _hauteur = 52;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _hauteur,
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppDims.controle),
        border: Border.all(
          color: selection != null ? AppColors.authVert : AppColors.border,
          width: selection != null ? 1.2 : 0.5,
        ),
        boxShadow: AppShadows.champ,
      ),
      child: DropdownButtonHideUnderline(
        child: ButtonTheme(
          alignedDropdown: true,
          child: DropdownButton<AlertType>(
            value: selection,
            isExpanded: true,
            icon: const Padding(
              padding: EdgeInsetsDirectional.only(end: 10),
              child: Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textMuted, size: 22),
            ),
            hint: const Padding(
              padding: EdgeInsetsDirectional.only(start: 14),
              child: Text(
                'Choisir un type de signalement',
                style: TextStyle(fontSize: 14, color: AppColors.textMuted),
              ),
            ),
            selectedItemBuilder: (_) => AlertType.values
                .map((t) => Padding(
                      padding: const EdgeInsetsDirectional.only(start: 14),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _Ligne(t),
                      ),
                    ))
                .toList(),
            items: AlertType.values
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _Ligne(t),
                      ),
                    ))
                .toList(),
            dropdownColor: AppColors.surface2,
            borderRadius: BorderRadius.circular(AppDims.controle),
            menuMaxHeight: 320,
            onChanged: (t) {
              if (t != null) onSelect(t);
            },
          ),
        ),
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne(this.type);
  final AlertType type;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(type.emoji, style: const TextStyle(fontSize: 17)),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            type.libelle,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
