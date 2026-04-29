// features/forest/widgets/parcelle_widgets.dart

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../constants/forest_constant.dart';
import '../models/forest_model.dart';
import '../providers/forest_provider.dart';
import 'shared_widgets.dart';

// ═══════════════════════════════════════════════════════════════
//  ParcelleLabel — nom affiché sur la carte
// ═══════════════════════════════════════════════════════════════

class ParcelleLabel extends StatelessWidget {
  final String name;

  const ParcelleLabel({super.key, required this.name});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color:        const Color(0xFF1D4ED8).withOpacity(0.85),
            borderRadius: BorderRadius.circular(5),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withOpacity(0.2),
                blurRadius: 3,
                offset:     const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            name,
            style: const TextStyle(
              fontSize:   10,
              fontWeight: FontWeight.w600,
              color:      Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════
//  ParcellePopup — popup hover sur la carte
// ═══════════════════════════════════════════════════════════════

class ParcellePopup extends StatelessWidget {
  final Parcelle     parcelle;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  const ParcellePopup({
    super.key,
    required this.parcelle,
    required this.onDelete,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned(
      left: size.width / 2 - 110,
      top:  size.height * 0.15,
      child: PopupCard(
        title:    parcelle.name,
        subtitle: parcelle.areaLabel,
        icon:     Icons.crop_square_outlined,
        color:    const Color(0xFF1D4ED8),
        onDelete: onDelete,
        onClose:  onClose,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  ParcelleListPanel — liste des parcelles dans la sidebar
// ═══════════════════════════════════════════════════════════════

class ParcelleListPanel extends StatelessWidget {
  final List<Forest>            forests;
  final ParcelleState           parcelleState;
  final void Function({Forest? parentForest}) onCreateParcelle;
  final void Function(Parcelle) onParcelleDelete;
  final void Function(Forest)   onForestFly;

  const ParcelleListPanel({
    super.key,
    required this.forests,
    required this.parcelleState,
    required this.onCreateParcelle,
    required this.onParcelleDelete,
    required this.onForestFly,
  });

  @override
  Widget build(BuildContext context) {
    final allParcelles = parcelleState.byForest.values
        .expand((list) => list)
        .toList();

    return Column(children: [
      PanelHeader(
        title:    'Parcelles',
        count:    '${allParcelles.length} parcelle${allParcelles.length != 1 ? 's' : ''}',
        icon:     Icons.crop_square_outlined,
        color:    parcelleTabColor,
        btnLabel: '+ Parcelle',
        btnColor: parcelleBorder,
        onBtn:    () => onCreateParcelle(),
      ),
      const Divider(height: 1, color: AppColors.borderLight),
      Expanded(
        child: allParcelles.isEmpty
            ? const EmptyPanel(
                icon:    Icons.crop_square_outlined,
                message: 'Aucune parcelle chargée',
                sub:
                    'Dépliez une forêt dans l\'onglet Forêts\npour charger ses parcelles.',
              )
            : ListView.builder(
                padding:     EdgeInsets.zero,
                itemCount:   allParcelles.length,
                itemBuilder: (_, i) {
                  final p = allParcelles[i];
                  final parentForest = forests
                      .where((f) => f.id == p.forestId)
                      .firstOrNull;
                  return ParcelleRow(
                    parcelle:      p,
                    parentName:    parentForest?.name ?? '...',
                    onDelete:      () => onParcelleDelete(p),
                    onFlyToForest: parentForest != null
                        ? () => onForestFly(parentForest)
                        : null,
                  );
                },
              ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════
//  ParcelleRow — ligne d'une parcelle dans la liste
// ═══════════════════════════════════════════════════════════════

class ParcelleRow extends StatelessWidget {
  final Parcelle      parcelle;
  final String        parentName;
  final VoidCallback  onDelete;
  final VoidCallback? onFlyToForest;

  const ParcelleRow({
    super.key,
    required this.parcelle,
    required this.parentName,
    required this.onDelete,
    this.onFlyToForest,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: AppColors.borderLight, width: 0.5))),
        child: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
                color:        parcelleFill,
                borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.crop_square_outlined,
                size: 13, color: parcelleBorder),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(parcelle.name,
                      style: const TextStyle(
                          fontSize:   12,
                          fontWeight: FontWeight.w600,
                          color:      AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis),
                  Row(children: [
                    Text(parentName,
                        style: const TextStyle(
                            fontSize: 9,
                            color:    AppColors.textMuted)),
                    const SizedBox(width: 6),
                    Text('· ${parcelle.areaLabel}',
                        style: const TextStyle(
                            fontSize: 9,
                            color:    AppColors.textMuted)),
                  ]),
                ]),
          ),
          if (onFlyToForest != null)
            IconBtn(
              icon:  Icons.my_location,
              color: AppColors.primaryMid,
              onTap: onFlyToForest,
              size:  24,
            ),
          const SizedBox(width: 4),
          IconBtn(
              icon:  Icons.delete_outline,
              color: AppColors.danger,
              onTap: onDelete),
        ]),
      );
}

// ═══════════════════════════════════════════════════════════════
//  ForestSelector — sélecteur de forêt parente pour une parcelle
// ═══════════════════════════════════════════════════════════════

class ForestSelector extends StatelessWidget {
  final List<Forest>          forests;
  final void Function(Forest) onSelect;

  const ForestSelector({
    super.key,
    required this.forests,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Forêt parente *',
              style: TextStyle(
                  fontSize:   11,
                  fontWeight: FontWeight.w600,
                  color:      AppColors.textSecondary)),
          const SizedBox(height: 8),
          if (forests.isEmpty)
            const Text('Aucune forêt disponible',
                style: TextStyle(
                    fontSize:      11,
                    color:         AppColors.textMuted,
                    fontStyle:     FontStyle.italic))
          else
            ...forests.map((f) => GestureDetector(
                  onTap: () => onSelect(f),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.bgInput,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.border, width: 0.5),
                    ),
                    child: Row(children: [
                      const Icon(Icons.park_outlined,
                          size: 15, color: AppColors.primaryMid),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(f.name,
                              style: const TextStyle(
                                  fontSize:   12,
                                  color:      AppColors.textPrimary,
                                  fontWeight: FontWeight.w500))),
                      Text(f.areaLabel,
                          style: const TextStyle(
                              fontSize: 10,
                              color:    AppColors.textMuted)),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_ios,
                          size: 11, color: AppColors.textMuted),
                    ]),
                  ),
                )),
        ],
      );
}