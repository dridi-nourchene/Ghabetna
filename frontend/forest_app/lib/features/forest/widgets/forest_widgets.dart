// features/forest/widgets/forest_widgets.dart

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../constants/forest_constant.dart';
import '../models/forest_model.dart';
import '../providers/forest_provider.dart';
import 'shared_widgets.dart';

// ═══════════════════════════════════════════════════════════════
//  ForestLabel — nom affiché sur la carte
// ═══════════════════════════════════════════════════════════════

class ForestLabel extends StatelessWidget {
  final String name;
  final bool   isEditing;

  const ForestLabel({
    super.key,
    required this.name,
    required this.isEditing,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isEditing
                ? Colors.grey.withOpacity(0.85)
                : AppColors.primaryDark.withOpacity(0.88),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withOpacity(0.25),
                blurRadius: 4,
                offset:     const Offset(0, 2),
              ),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.park,
                size:  11,
                color: isEditing
                    ? Colors.white70
                    : const Color(0xFF86EFAC)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                name,
                style: const TextStyle(
                    fontSize:   11,
                    fontWeight: FontWeight.w700,
                    color:      Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════
//  ForestPopup — popup hover sur la carte
// ═══════════════════════════════════════════════════════════════

class ForestPopup extends StatelessWidget {
  final Forest       forest;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  const ForestPopup({
    super.key,
    required this.forest,
    required this.onEdit,
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
        title:    forest.name,
        subtitle: forest.areaLabel,
        icon:     Icons.park_outlined,
        color:    AppColors.primaryDark,
        onEdit:   onEdit,
        onDelete: onDelete,
        onClose:  onClose,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  ForestListPanel — liste des forêts dans la sidebar
// ═══════════════════════════════════════════════════════════════

class ForestListPanel extends StatefulWidget {
  final List<Forest>    forests;
  final ParcelleState   parcelleState;
  final bool            isLoading;
  final String?         expandedForestId;
  final Set<String>     deletingIds;
  final void Function(Forest)    onForestTap;
  final void Function(String)    onForestExpand;
  final void Function(Forest)    onForestEdit;
  final void Function(Forest)    onForestDelete;
  final void Function(Parcelle)  onParcelleDelete;
  final VoidCallback             onCreateForest;
  final void Function(Forest)    onCreateParcelle;

  const ForestListPanel({
    super.key,
    required this.forests,
    required this.parcelleState,
    required this.isLoading,
    required this.expandedForestId,
    required this.deletingIds,
    required this.onForestTap,
    required this.onForestExpand,
    required this.onForestEdit,
    required this.onForestDelete,
    required this.onParcelleDelete,
    required this.onCreateForest,
    required this.onCreateParcelle,
  });

  @override
  State<ForestListPanel> createState() => _ForestListPanelState();
}

class _ForestListPanelState extends State<ForestListPanel> {
  String _search = '';

  List<Forest> get _filtered => _search.isEmpty
      ? widget.forests
      : widget.forests
          .where((f) =>
              f.name.toLowerCase().contains(_search.toLowerCase()))
          .toList();

  @override
  Widget build(BuildContext context) => Column(children: [
        PanelHeader(
          title:    'Forêts · Tunisie',
          count:    '${widget.forests.length} forêt${widget.forests.length != 1 ? 's' : ''}',
          icon:     Icons.park_outlined,
          color:    AppColors.primaryDark,
          btnLabel: '+ Forêt',
          btnColor: forestAccent,
          onBtn:    widget.onCreateForest,
        ),
        PanelSearch(onChanged: (v) => setState(() => _search = v)),
        const Divider(height: 1, color: AppColors.borderLight),
        Expanded(
          child: widget.isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primaryMid, strokeWidth: 2))
              : _filtered.isEmpty
                  ? EmptyPanel(
                      icon:    Icons.park_outlined,
                      message: _search.isNotEmpty
                          ? 'Aucun résultat'
                          : 'Aucune forêt',
                      sub: _search.isEmpty
                          ? 'Créez la première forêt.'
                          : null,
                    )
                  : ListView.builder(
                      padding:     EdgeInsets.zero,
                      itemCount:   _filtered.length,
                      itemBuilder: (_, i) {
                        final f = _filtered[i];
                        return ForestRow(
                          forest:           f,
                          isDeleting:       widget.deletingIds.contains(f.id),
                          isExpanded:       widget.expandedForestId == f.id,
                          parcelles:        widget.parcelleState.forForest(f.id),
                          isLoadingParc:    widget.parcelleState.loadingIds.contains(f.id),
                          onTap:            () => widget.onForestTap(f),
                          onExpand:         () => widget.onForestExpand(f.id),
                          onEdit:           () => widget.onForestEdit(f),
                          onDelete:         () => widget.onForestDelete(f),
                          onParcelleDelete: widget.onParcelleDelete,
                          onCreateParcelle: () => widget.onCreateParcelle(f),
                        );
                      },
                    ),
        ),
      ]);
}

// ═══════════════════════════════════════════════════════════════
//  ForestRow — ligne d'une forêt dans la liste
// ═══════════════════════════════════════════════════════════════

class ForestRow extends StatelessWidget {
  final Forest            forest;
  final bool              isDeleting;
  final bool              isExpanded;
  final List<Parcelle>    parcelles;
  final bool              isLoadingParc;
  final VoidCallback      onTap;
  final VoidCallback      onExpand;
  final VoidCallback      onEdit;
  final VoidCallback      onDelete;
  final void Function(Parcelle) onParcelleDelete;
  final VoidCallback      onCreateParcelle;

  const ForestRow({
    super.key,
    required this.forest,
    required this.isDeleting,
    required this.isExpanded,
    required this.parcelles,
    required this.isLoadingParc,
    required this.onTap,
    required this.onExpand,
    required this.onEdit,
    required this.onDelete,
    required this.onParcelleDelete,
    required this.onCreateParcelle,
  });

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
        opacity:  isDeleting ? 0.4 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Column(children: [
          InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 11),
              decoration: const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(
                          color: AppColors.borderLight, width: 0.5))),
              child: Row(children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                      color: AppColors.successBg,
                      borderRadius: BorderRadius.circular(7)),
                  child: const Icon(Icons.park_outlined,
                      size: 15, color: AppColors.primaryMid),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(forest.name,
                            style: const TextStyle(
                                fontSize:   12,
                                fontWeight: FontWeight.w600,
                                color:      AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis),
                        Text(forest.areaLabel,
                            style: const TextStyle(
                                fontSize: 10,
                                color:    AppColors.textMuted)),
                      ]),
                ),
                IconBtn(
                    icon:  Icons.edit_outlined,
                    color: AppColors.primaryMid,
                    onTap: isDeleting ? null : onEdit),
                const SizedBox(width: 4),
                IconBtn(
                    icon:  Icons.delete_outline,
                    color: AppColors.danger,
                    onTap: isDeleting ? null : onDelete),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onExpand,
                  child: Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size:  18,
                    color: AppColors.textMuted,
                  ),
                ),
              ]),
            ),
          ),
          if (isExpanded)
            Container(
              color: const Color(0xFFF9FAF7),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                  child: Row(children: [
                    const Text('Parcelles',
                        style: TextStyle(
                            fontSize:      9,
                            fontWeight:    FontWeight.w700,
                            color:         AppColors.textSecondary,
                            letterSpacing: 0.5)),
                    const Spacer(),
                    GestureDetector(
                      onTap: onCreateParcelle,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: parcelleFill,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                              color: parcelleBorder.withOpacity(0.4),
                              width: 0.5),
                        ),
                        child: const Row(children: [
                          Icon(Icons.add,
                              size: 10, color: parcelleBorder),
                          SizedBox(width: 3),
                          Text('Ajouter',
                              style: TextStyle(
                                  fontSize:   9,
                                  color:      parcelleBorder,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ]),
                ),
                if (isLoadingParc)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: parcelleBorder)),
                  )
                else if (parcelles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
                    child: Text('Aucune parcelle',
                        style: TextStyle(
                            fontSize:      10,
                            color:         AppColors.textMuted.withOpacity(0.7),
                            fontStyle:     FontStyle.italic)),
                  )
                else
                  ...parcelles.map((p) => SmallParcelleRow(
                        parcelle: p,
                        onDelete: () => onParcelleDelete(p),
                      )),
              ]),
            ),
        ]),
      );
}

// ═══════════════════════════════════════════════════════════════
//  SmallParcelleRow — parcelle dans la liste dépliée d'une forêt
// ═══════════════════════════════════════════════════════════════

class SmallParcelleRow extends StatelessWidget {
  final Parcelle     parcelle;
  final VoidCallback onDelete;

  const SmallParcelleRow({
    super.key,
    required this.parcelle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(22, 6, 14, 6),
        decoration: const BoxDecoration(
            border: Border(
                top: BorderSide(
                    color: AppColors.borderLight, width: 0.5))),
        child: Row(children: [
          Container(
              width: 6, height: 6,
              decoration: const BoxDecoration(
                  color: parcelleBorder, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(parcelle.name,
                      style: const TextStyle(
                          fontSize:   11,
                          fontWeight: FontWeight.w500,
                          color:      AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis),
                  Text(parcelle.areaLabel,
                      style: const TextStyle(
                          fontSize: 9, color: AppColors.textMuted)),
                ]),
          ),
          IconBtn(
              icon:  Icons.delete_outline,
              color: AppColors.danger,
              onTap: onDelete,
              size:  22),
        ]),
      );
}

// ═══════════════════════════════════════════════════════════════
//  DrawFormPanel — formulaire création forêt/parcelle
// ═══════════════════════════════════════════════════════════════

class DrawFormPanel extends StatelessWidget {
  final String       title;
  final String       subtitle;
  final String       fieldHint;
  final IconData     fieldIcon;
  final Color        accentColor;
  final TextEditingController nameCtrl;
  final GlobalKey<FormState>  formKey;
  final bool     isDrawing;
  final bool     isClosed;
  final bool     canClose;
  final int      pointCount;
  final bool     isSubmitting;
  final String?  formError;
  final Widget?  forestSelector;
  final VoidCallback onDismissError;
  final VoidCallback onToggleDraw;
  final VoidCallback onClose;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  const DrawFormPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.fieldHint,
    required this.fieldIcon,
    required this.accentColor,
    required this.nameCtrl,
    required this.formKey,
    required this.isDrawing,
    required this.isClosed,
    required this.canClose,
    required this.pointCount,
    required this.isSubmitting,
    required this.formError,
    this.forestSelector,
    required this.onDismissError,
    required this.onToggleDraw,
    required this.onClose,
    required this.onUndo,
    required this.onClear,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) => Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.06),
            border: const Border(
                bottom: BorderSide(
                    color: AppColors.borderLight, width: 0.5)),
          ),
          child: Row(children: [
            GestureDetector(
              onTap: onBack,
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                      color: AppColors.border, width: 0.5),
                ),
                child: const Icon(Icons.arrow_back,
                    size: 15, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize:   13,
                            fontWeight: FontWeight.w700,
                            color:      AppColors.textPrimary)),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textMuted),
                        overflow: TextOverflow.ellipsis),
                  ]),
            ),
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: Icon(fieldIcon, size: 13, color: accentColor),
            ),
          ]),
        ),
        // Body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: formKey,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (formError != null) ...[
                      ErrorBanner(
                          message:   formError!,
                          onDismiss: onDismissError),
                      const SizedBox(height: 14),
                    ],
                    if (forestSelector != null) ...[
                      forestSelector!,
                      const SizedBox(height: 16),
                    ],
                    const Text('Nom *',
                        style: TextStyle(
                            fontSize:   11,
                            fontWeight: FontWeight.w600,
                            color:      AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: nameCtrl,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textPrimary),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Champ requis'
                              : null,
                      decoration: InputDecoration(
                        hintText:  fieldHint,
                        hintStyle: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted),
                        prefixIcon: Icon(fieldIcon,
                            size: 16, color: AppColors.textMuted),
                        filled:    true,
                        fillColor: AppColors.bgInput,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: AppColors.border, width: 0.5)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: AppColors.border, width: 0.5)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: accentColor, width: 1.2)),
                        errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: AppColors.danger, width: 0.8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Polygone *',
                        style: TextStyle(
                            fontSize:   11,
                            fontWeight: FontWeight.w600,
                            color:      AppColors.textSecondary)),
                    const SizedBox(height: 10),
                    DrawTools(
                      isDrawing:   isDrawing,
                      isClosed:    isClosed,
                      canClose:    canClose,
                      pointCount:  pointCount,
                      accentColor: accentColor,
                      onToggle:    onToggleDraw,
                      onClose:     onClose,
                      onUndo:      onUndo,
                      onClear:     onClear,
                    ),
                    const SizedBox(height: 12),
                    PolygonStatus(
                      pointCount:  pointCount,
                      isClosed:    isClosed,
                      isDrawing:   isDrawing,
                      accentColor: accentColor,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isSubmitting ? null : onSubmit,
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 14, height: 14,
                                child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2))
                            : const Icon(Icons.save_outlined,
                                size: 16),
                        label: Text(isSubmitting
                            ? 'Enregistrement...'
                            : 'Enregistrer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isClosed
                              ? accentColor
                              : AppColors.textMuted,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(9)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: isSubmitting ? null : onBack,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(
                              color: AppColors.border, width: 0.8),
                          padding: const EdgeInsets.symmetric(
                              vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(9)),
                        ),
                        child: const Text('Annuler',
                            style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  ]),
            ),
          ),
        ),
      ]);
}

// ═══════════════════════════════════════════════════════════════
//  EditForestPanel — formulaire modification forêt
// ═══════════════════════════════════════════════════════════════

class EditForestPanel extends StatelessWidget {
  final Forest      forest;
  final TextEditingController nameCtrl;
  final GlobalKey<FormState>  formKey;
  final bool     hasNewPolygon;
  final bool     isDrawing;
  final bool     isClosed;
  final bool     canClose;
  final int      pointCount;
  final bool     isSubmitting;
  final String?  formError;
  final VoidCallback onDismissError;
  final VoidCallback onStartRedraw;
  final VoidCallback onCancelRedraw;
  final VoidCallback onToggleDraw;
  final VoidCallback onClose;
  final VoidCallback onUndo;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  const EditForestPanel({
    super.key,
    required this.forest,
    required this.nameCtrl,
    required this.formKey,
    required this.hasNewPolygon,
    required this.isDrawing,
    required this.isClosed,
    required this.canClose,
    required this.pointCount,
    required this.isSubmitting,
    required this.formError,
    required this.onDismissError,
    required this.onStartRedraw,
    required this.onCancelRedraw,
    required this.onToggleDraw,
    required this.onClose,
    required this.onUndo,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            color: AppColors.primaryDark.withOpacity(0.05),
            border: const Border(
                bottom: BorderSide(
                    color: AppColors.borderLight, width: 0.5)),
          ),
          child: Row(children: [
            GestureDetector(
              onTap: onBack,
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                      color: AppColors.border, width: 0.5),
                ),
                child: const Icon(Icons.arrow_back,
                    size: 15, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Modifier la forêt',
                        style: TextStyle(
                            fontSize:   13,
                            fontWeight: FontWeight.w700,
                            color:      AppColors.textPrimary)),
                    Text(forest.name,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textMuted),
                        overflow: TextOverflow.ellipsis),
                  ]),
            ),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: formKey,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (formError != null) ...[
                      ErrorBanner(
                          message:   formError!,
                          onDismiss: onDismissError),
                      const SizedBox(height: 14),
                    ],
                    const Text('Nom *',
                        style: TextStyle(
                            fontSize:   11,
                            fontWeight: FontWeight.w600,
                            color:      AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: nameCtrl,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textPrimary),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Champ requis'
                              : null,
                      decoration: InputDecoration(
                        hintText: 'Nom de la forêt',
                        hintStyle: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted),
                        prefixIcon: const Icon(Icons.park_outlined,
                            size: 16, color: AppColors.textMuted),
                        filled:    true,
                        fillColor: AppColors.bgInput,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: AppColors.border, width: 0.5)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: AppColors.border, width: 0.5)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: AppColors.primaryMid,
                                width: 1.2)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Polygone',
                        style: TextStyle(
                            fontSize:   11,
                            fontWeight: FontWeight.w600,
                            color:      AppColors.textSecondary)),
                    const SizedBox(height: 10),
                    if (hasNewPolygon) ...[
                      PolyLegend(
                        oldColor: oldPolyBorder,
                        newColor: newPolyBorder,
                        oldLabel: 'Ancien (affiché en gris)',
                        newLabel: 'Nouveau (en cours de dessin)',
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (!hasNewPolygon) ...[
                      ActionBtn(
                        label: 'Redessiner le polygone',
                        icon:  Icons.draw_outlined,
                        color: AppColors.warning,
                        onTap: onStartRedraw,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'L\'ancien polygone restera visible (gris)\njusqu\'à ce que vous confirmiez.',
                        style: TextStyle(
                            fontSize: 10,
                            color:    AppColors.textMuted,
                            height:   1.4),
                      ),
                    ] else ...[
                      DrawTools(
                        isDrawing:   isDrawing,
                        isClosed:    isClosed,
                        canClose:    canClose,
                        pointCount:  pointCount,
                        accentColor: forestAccent,
                        onToggle:    onToggleDraw,
                        onClose:     onClose,
                        onUndo:      onUndo,
                        onClear:     () {},
                      ),
                      const SizedBox(height: 8),
                      ActionBtn(
                        label: 'Annuler — garder l\'ancien',
                        icon:  Icons.undo,
                        color: AppColors.textSecondary,
                        onTap: onCancelRedraw,
                      ),
                      const SizedBox(height: 10),
                      PolygonStatus(
                        pointCount:  pointCount,
                        isClosed:    isClosed,
                        isDrawing:   isDrawing,
                        accentColor: forestAccent,
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isSubmitting ? null : onSubmit,
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 14, height: 14,
                                child: CircularProgressIndicator(
                                    color:       Colors.white,
                                    strokeWidth: 2))
                            : const Icon(Icons.save_outlined,
                                size: 16),
                        label: Text(isSubmitting
                            ? 'Mise à jour...'
                            : 'Enregistrer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(9)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: isSubmitting ? null : onBack,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(
                              color: AppColors.border, width: 0.8),
                          padding: const EdgeInsets.symmetric(
                              vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(9)),
                        ),
                        child: const Text('Annuler',
                            style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  ]),
            ),
          ),
        ),
      ]);
}

// ═══════════════════════════════════════════════════════════════
//  DrawTools + helpers
// ═══════════════════════════════════════════════════════════════

class DrawTools extends StatelessWidget {
  final bool isDrawing, isClosed, canClose;
  final int  pointCount;
  final Color accentColor;
  final VoidCallback onToggle, onClose, onUndo, onClear;

  const DrawTools({
    super.key,
    required this.isDrawing,
    required this.isClosed,
    required this.canClose,
    required this.pointCount,
    required this.accentColor,
    required this.onToggle,
    required this.onClose,
    required this.onUndo,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 6, runSpacing: 6, children: [
        DrawChip(
          label: isDrawing ? 'Arrêter' : 'Dessiner',
          icon:  isDrawing
              ? Icons.stop
              : Icons.edit_location_alt_outlined,
          color: isDrawing ? AppColors.warning : accentColor,
          onTap: onToggle,
        ),
        DrawChip(
          label: 'Fermer',
          icon:  Icons.check_circle_outline,
          color: canClose ? AppColors.success : AppColors.textMuted,
          onTap: canClose ? onClose : null,
        ),
        DrawChip(
          label: 'Annuler',
          icon:  Icons.undo,
          color: pointCount > 0
              ? AppColors.info
              : AppColors.textMuted,
          onTap: pointCount > 0 ? onUndo : null,
        ),
        DrawChip(
          label: 'Effacer',
          icon:  Icons.delete_sweep_outlined,
          color: pointCount > 0
              ? AppColors.danger
              : AppColors.textMuted,
          onTap: pointCount > 0 ? onClear : null,
        ),
      ]);
}

class DrawChip extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final Color        color;
  final VoidCallback? onTap;

  const DrawChip({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: disabled
              ? AppColors.bgInput
              : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: disabled
                ? AppColors.border
                : color.withOpacity(0.35),
            width: 0.8,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size:  12,
              color: disabled ? AppColors.textMuted : color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize:   10,
                  fontWeight: FontWeight.w600,
                  color: disabled ? AppColors.textMuted : color)),
        ]),
      ),
    );
  }
}

class PolygonStatus extends StatelessWidget {
  final int   pointCount;
  final bool  isClosed, isDrawing;
  final Color accentColor;

  const PolygonStatus({
    super.key,
    required this.pointCount,
    required this.isClosed,
    required this.isDrawing,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    if (pointCount == 0) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: AppColors.bgInput,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
                color: AppColors.border, width: 0.5)),
        child: const Row(children: [
          Icon(Icons.mouse_outlined,
              size: 12, color: AppColors.textMuted),
          SizedBox(width: 8),
          Expanded(
              child: Text(
                  'Appuyez sur Dessiner puis cliquez sur la carte',
                  style: TextStyle(
                      fontSize: 10, color: AppColors.textMuted))),
        ]),
      );
    }
    final (text, color) = isClosed
        ? ('✓ Polygone fermé — $pointCount points',
            AppColors.success)
        : isDrawing
            ? ('$pointCount points — continuez à cliquer',
                accentColor)
            : ('$pointCount points — appuyez sur Fermer',
                AppColors.warning);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(7),
          border:
              Border.all(color: color.withOpacity(0.3), width: 0.5)),
      child: Row(children: [
        Icon(
            isClosed
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            size:  12,
            color: color),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize:   10,
                    color:      color,
                    fontWeight: FontWeight.w500))),
      ]),
    );
  }
}

class PolyLegend extends StatelessWidget {
  final Color  oldColor, newColor;
  final String oldLabel, newLabel;

  const PolyLegend({
    super.key,
    required this.oldColor,
    required this.newColor,
    required this.oldLabel,
    required this.newLabel,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: AppColors.bgInput,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
                color: AppColors.border, width: 0.5)),
        child: Column(children: [
          _LegendRow(color: oldColor, label: oldLabel),
          const SizedBox(height: 4),
          _LegendRow(color: newColor, label: newLabel),
        ]),
      );
}

class _LegendRow extends StatelessWidget {
  final Color  color;
  final String label;
  const _LegendRow({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 12, height: 3,
            decoration: BoxDecoration(
                color:        color,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: AppColors.textSecondary)),
      ]);
}

class ActionBtn extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;

  const ActionBtn({
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
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: color.withOpacity(0.3), width: 0.8)),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        fontSize:   12,
                        fontWeight: FontWeight.w600,
                        color:      color)),
              ]),
        ),
      );
}

class DrawHint extends StatelessWidget {
  const DrawHint({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
              color:        Colors.black.withOpacity(0.65),
              borderRadius: BorderRadius.circular(12)),
          child: const Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.touch_app_outlined,
                color: Colors.white70, size: 28),
            SizedBox(height: 8),
            Text('Cliquez sur la carte pour ajouter des points',
                style: TextStyle(color: Colors.white, fontSize: 13),
                textAlign: TextAlign.center),
            SizedBox(height: 4),
            Text('Puis « Fermer » pour finaliser le polygone',
                style:
                    TextStyle(color: Colors.white60, fontSize: 10),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

class DrawCounter extends StatelessWidget {
  final int  count;
  final bool isClosed, isParc;

  const DrawCounter({
    super.key,
    required this.count,
    required this.isClosed,
    required this.isParc,
  });

  @override
  Widget build(BuildContext context) {
    final color = isClosed
        ? AppColors.success
        : isParc
            ? parcelleBorder
            : forestAccent;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
          color:        color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color:      Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset:     const Offset(0, 2))
          ]),
      child: Text(
        isClosed
            ? '✓ $count points — polygone fermé'
            : '$count point${count != 1 ? 's' : ''}',
        style: const TextStyle(
            fontSize:   11,
            fontWeight: FontWeight.w700,
            color:      Colors.white),
      ),
    );
  }
}