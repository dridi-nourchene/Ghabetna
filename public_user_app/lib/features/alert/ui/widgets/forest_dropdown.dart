import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../data/alert_models.dart';

class ForestDropdown extends StatelessWidget {
  const ForestDropdown({
    super.key,
    required this.forets,
    required this.chargement,
    required this.selection,
    required this.onSelect,
  });

  final List<ForestSimple> forets;
  final bool chargement;
  final ForestSimple? selection;
  final void Function(ForestSimple) onSelect;

  static const double _hauteur = 52;

  @override
  Widget build(BuildContext context) {
    if (chargement) {
      return _coquille(
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  color: AppColors.authVert, strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Chargement des forêts…',
                style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
          ],
        ),
      );
    }

    if (forets.isEmpty) {
      return _coquille(
        child: const Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
            SizedBox(width: 8),
            Text('Aucune forêt disponible',
                style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
          ],
        ),
      );
    }

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
          child: DropdownButton<ForestSimple>(
            value: selection,
            isExpanded: true,
            icon: const Padding(
              padding: EdgeInsetsDirectional.only(end: 10),
              child: Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textMuted, size: 22),
            ),
            hint: const Padding(
              padding: EdgeInsetsDirectional.only(start: 14),
              child: Row(
                children: [
                  Icon(Icons.park_outlined, size: 18, color: AppColors.authVert),
                  SizedBox(width: 8),
                  Text('Choisir une forêt',
                      style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                ],
              ),
            ),
            selectedItemBuilder: (_) => forets
                .map((f) => Padding(
                      padding: const EdgeInsetsDirectional.only(start: 14),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _Ligne(f),
                      ),
                    ))
                .toList(),
            items: forets
                .map((f) => DropdownMenuItem(
                      value: f,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _Ligne(f),
                      ),
                    ))
                .toList(),
            dropdownColor: AppColors.surface2,
            borderRadius: BorderRadius.circular(AppDims.controle),
            menuMaxHeight: 300,
            onChanged: (f) {
              if (f != null) onSelect(f);
            },
          ),
        ),
      ),
    );
  }

  Widget _coquille({required Widget child}) => Container(
        height: _hauteur,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(AppDims.controle),
          border: Border.all(color: AppColors.border, width: 0.5),
          boxShadow: AppShadows.champ,
        ),
        child: child,
      );
}

class _Ligne extends StatelessWidget {
  const _Ligne(this.foret);
  final ForestSimple foret;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.park_outlined, size: 17, color: AppColors.authVert),
        const SizedBox(width: 9),
        Flexible(
          child: Text(
            foret.nom,
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
