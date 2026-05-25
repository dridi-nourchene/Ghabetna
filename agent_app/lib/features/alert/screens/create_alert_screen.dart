// features/alert/screens/create_alert_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_app/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:agent_app/core/theme/app_colors.dart';
import 'package:agent_app/features/alert/models/alert_model.dart';
import 'package:agent_app/features/alert/providers/alert_provider.dart';
import 'package:agent_app/features/alert/services/alert_service.dart';

class CreateAlertScreen extends ConsumerStatefulWidget {
  const CreateAlertScreen({super.key});

  @override
  ConsumerState<CreateAlertScreen> createState() => _CreateAlertScreenState();
}

class _CreateAlertScreenState extends ConsumerState<CreateAlertScreen> {
  final _descController = TextEditingController();
  AlertType?    _selectedType;
  ForestSimple? _selectedForest;
  File?         _imageFile;
  String?       _gpsInfo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(createAlertProvider.notifier).loadForests();
    });
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source:       source,
      imageQuality: 80,
      maxWidth:     1920,
    );
    if (picked == null) return;

    final file = File(picked.path);
    final gps  = await AlertService.extractGpsFromImage(file);
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _imageFile = file;
      _gpsInfo   = gps != null
          ? '✓ GPS : ${gps.lat.toStringAsFixed(5)}, ${gps.lng.toStringAsFixed(5)}'
          : '⚠️ ${l10n.createAlertForestHint}';
    });
  }

  void _showImageSourceDialog() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color:        Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: AgentColors.primary),
              title: Text(l10n.createAlertCamera),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AgentColors.primary),
              title: Text(l10n.createAlertGallery),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;

    if (_selectedType == null) {
      _showSnack(l10n.createAlertTypeRequired, AgentColors.warning);
      return;
    }
    if (_selectedForest == null) {
      _showSnack(l10n.createAlertForestRequired, AgentColors.warning);
      return;
    }

    final ok = await ref.read(createAlertProvider.notifier).submitAlert(
          type:        _selectedType!,
          forestId:    _selectedForest!.id,
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          imageFile:   _imageFile,
        );

    if (ok && mounted) {
      _showSnack(l10n.createAlertSuccess, AgentColors.success);
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n  = AppLocalizations.of(context)!;
    final state = ref.watch(createAlertProvider);

    ref.listen<CreateAlertState>(createAlertProvider, (_, next) {
      if (next.error != null) {
        _showSnack(next.error!, AgentColors.danger);
      }
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Type d'alerte ────────────────────────────
          _SectionLabel(l10n.createAlertType),
          const SizedBox(height: 8),
          _TypeDropdownFixed(
            selected: _selectedType,
            l10n:     l10n,
            onSelect: (t) => setState(() => _selectedType = t),
          ),

          const SizedBox(height: 20),

          // ── Forêt ────────────────────────────────────
          _SectionLabel(l10n.createAlertForest),
          const SizedBox(height: 8),
          _ForestDropdownFixed(
            forests:  state.forests,
            loading:  state.isLoadingForests,
            selected: _selectedForest,
            l10n:     l10n,
            onSelect: (f) => setState(() => _selectedForest = f),
          ),

          const SizedBox(height: 20),

          // ── Photo ────────────────────────────────────
          _SectionLabel(l10n.createAlertPhoto),
          const SizedBox(height: 8),
          _ImagePickerWidget(
            imageFile:      _imageFile,
            gpsInfo:        _gpsInfo,
            onTap:          _showImageSourceDialog,
            addPhotoLabel:  l10n.createAlertAddPhoto,
            cameraOrGallery: l10n.createAlertCameraOrGallery,
            changeLabel:    l10n.createAlertChangePhoto,
            onRemove: () => setState(() {
              _imageFile = null;
              _gpsInfo   = null;
            }),
          ),

          const SizedBox(height: 20),

          // ── Description ──────────────────────────────
          _SectionLabel(l10n.createAlertDescription),
          const SizedBox(height: 8),
          TextField(
            controller:  _descController,
            maxLines:    4,
            style: const TextStyle(
                fontSize: 14, color: AgentColors.textPrimary),
            decoration: InputDecoration(
              hintText:  l10n.createAlertDescHint,
              hintStyle: const TextStyle(
                  fontSize: 14, color: AgentColors.textMuted),
              filled:    true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFFE8EDE8), width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFFE8EDE8), width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AgentColors.primary, width: 1.2),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),

          const SizedBox(height: 32),

          // ── Bouton soumettre ─────────────────────────
          SizedBox(
            width:  double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: state.isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AgentColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AgentColors.primary.withOpacity(0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: state.isSubmitting
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Text(l10n.createAlertSubmit,
                      style: const TextStyle(
                          fontSize:   16,
                          fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: color,
      behavior:        SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}

// ── Section Label ────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize:   13,
          fontWeight: FontWeight.w600,
          color:      AgentColors.textSecondary));
}

// ── Type Dropdown ────────────────────────────────────────────

class _TypeDropdownFixed extends StatelessWidget {
  final AlertType?               selected;
  final AppLocalizations         l10n;
  final void Function(AlertType) onSelect;

  const _TypeDropdownFixed({
    required this.selected,
    required this.l10n,
    required this.onSelect,
  });

  static const double _h = 52.0;

  String _typeLabel(AlertType t) => switch (t) {
    AlertType.incendie   => l10n.alertTypeIncendie,
    AlertType.vol        => l10n.alertTypeVol,
    AlertType.inondation => l10n.alertTypeInondation,
    AlertType.glissement => l10n.alertTypeGlissement,
    AlertType.maladie    => l10n.alertTypeMaladie,
    AlertType.depot_dechets => l10n.alertTypeDepotDechets,
    AlertType.chasse_illegale => l10n.alertTypeChasseIllegale,
    AlertType.activite_suspecte => l10n.alertTypeActiviteSuspecte,
    AlertType.autre      => l10n.alertTypeAutre,
  };

  @override
  Widget build(BuildContext context) {
    final types = AlertType.values;

    return SizedBox(
      height: _h,
      child: _shell(
        hasValue: selected != null,
        child: DropdownButtonHideUnderline(
          child: ButtonTheme(
            alignedDropdown: true,
            child: DropdownButton<AlertType>(
              value:      selected,
              isExpanded: true,
              isDense:    false,
              icon: const Padding(
                padding: EdgeInsetsDirectional.only(end: 8),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: AgentColors.textMuted, size: 22),
              ),
              hint: Padding(
                padding: const EdgeInsetsDirectional.only(start: 12),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 18, color: AgentColors.primary),
                  const SizedBox(width: 8),
                  Text(l10n.createAlertTypeHint,
                      style: const TextStyle(
                          fontSize: 14,
                          color:    AgentColors.textMuted)),
                ]),
              ),
              selectedItemBuilder: (ctx) => types.map((t) =>
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Row(children: [
                      Text(t.emoji,
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _typeLabel(t),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize:   14,
                            fontWeight: FontWeight.w600,
                            color:      AgentColors.textPrimary,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ).toList(),
              items: types.map((t) => DropdownMenuItem<AlertType>(
                value: t,
                child: Row(children: [
                  Text(t.emoji,
                      style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_typeLabel(t),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize:   14,
                            color:      AgentColors.textPrimary,
                            fontWeight: FontWeight.w500)),
                  ),
                ]),
              )).toList(),
              dropdownColor: Colors.white,
              borderRadius:  BorderRadius.circular(12),
              elevation:     4,
              menuMaxHeight: 300,
              onChanged: (t) { if (t != null) onSelect(t); },
            ),
          ),
        ),
      ),
    );
  }

  Widget _shell({required bool hasValue, required Widget child}) {
    return Container(
      height: _h,
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasValue ? AgentColors.primary : const Color(0xFFE0E8E0),
          width: hasValue ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── Forest Dropdown ──────────────────────────────────────────

class _ForestDropdownFixed extends StatelessWidget {
  final List<ForestSimple>          forests;
  final bool                        loading;
  final ForestSimple?               selected;
  final AppLocalizations            l10n;
  final void Function(ForestSimple) onSelect;

  const _ForestDropdownFixed({
    required this.forests,
    required this.loading,
    required this.selected,
    required this.l10n,
    required this.onSelect,
  });

  static const double _h = 52.0;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return _shell(
        selected: selected,
        child: Row(children: [
          const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(
                  color: AgentColors.primary, strokeWidth: 2)),
          const SizedBox(width: 10),
          Text(l10n.createAlertLoading, style: const TextStyle(
              fontSize: 14, color: AgentColors.textMuted)),
        ]),
      );
    }

    if (forests.isEmpty) {
      return _shell(
        selected: selected,
        child: Row(children: [
          const Icon(Icons.info_outline, size: 16, color: AgentColors.textMuted),
          const SizedBox(width: 8),
          Text(l10n.createAlertNoForest, style: const TextStyle(
              fontSize: 14, color: AgentColors.textMuted)),
        ]),
      );
    }

    return SizedBox(
      height: _h,
      child: _shell(
        selected: selected,
        usePadding: false,
        child: DropdownButtonHideUnderline(
          child: ButtonTheme(
            alignedDropdown: true,
            child: DropdownButton<ForestSimple>(
              value:      selected,
              isExpanded: true,
              isDense:    false,
              icon: const Padding(
                padding: EdgeInsetsDirectional.only(end: 8),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: AgentColors.textMuted, size: 22),
              ),
              hint: Padding(
                padding: const EdgeInsetsDirectional.only(start: 12),
                child: Row(children: [
                  const Icon(Icons.park_outlined,
                      size: 18, color: AgentColors.primary),
                  const SizedBox(width: 8),
                  Text(l10n.createAlertForestHint,
                      style: const TextStyle(
                          fontSize: 14,
                          color:    AgentColors.textMuted)),
                ]),
              ),
              selectedItemBuilder: (ctx) => forests.map((f) =>
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Row(children: [
                      const Icon(Icons.park_outlined,
                          size: 18, color: AgentColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(f.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize:   14,
                            fontWeight: FontWeight.w600,
                            color:      AgentColors.textPrimary,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ).toList(),
              items: forests.map((f) => DropdownMenuItem<ForestSimple>(
                value: f,
                child: Row(children: [
                  const Icon(Icons.park_outlined,
                      size: 16, color: AgentColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(f.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize:   14,
                            color:      AgentColors.textPrimary,
                            fontWeight: FontWeight.w500)),
                  ),
                ]),
              )).toList(),
              dropdownColor: Colors.white,
              borderRadius:  BorderRadius.circular(12),
              elevation:     4,
              menuMaxHeight: 280,
              onChanged: (f) { if (f != null) onSelect(f); },
            ),
          ),
        ),
      ),
    );
  }

  Widget _shell({
    required ForestSimple? selected,
    required Widget        child,
    bool usePadding = true,
  }) {
    return Container(
      height: _h,
      padding: usePadding
          ? const EdgeInsets.symmetric(horizontal: 14)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected != null
              ? AgentColors.primary
              : const Color(0xFFE0E8E0),
          width: selected != null ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: usePadding
          ? Align(alignment: AlignmentDirectional.centerStart, child: child)
          : child,
    );
  }
}

// ── Image Picker ─────────────────────────────────────────────

class _ImagePickerWidget extends StatelessWidget {
  final File?        imageFile;
  final String?      gpsInfo;
  final String       addPhotoLabel;
  final String       cameraOrGallery;
  final String       changeLabel;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _ImagePickerWidget({
    required this.imageFile,
    required this.gpsInfo,
    required this.onTap,
    required this.onRemove,
    required this.addPhotoLabel,
    required this.cameraOrGallery,
    required this.changeLabel,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: imageFile == null ? onTap : null,
            child: Container(
              width:  double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color:        imageFile != null ? null : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: imageFile != null
                      ? AgentColors.primary.withOpacity(0.4)
                      : const Color(0xFFE0E8E0),
                  width: imageFile != null ? 1.5 : 1.0,
                ),
                image: imageFile != null
                    ? DecorationImage(
                        image: FileImage(imageFile!),
                        fit:   BoxFit.cover,
                      )
                    : null,
              ),
              child: imageFile == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined,
                            size:  36,
                            color: AgentColors.primary.withOpacity(0.6)),
                        const SizedBox(height: 8),
                        Text(addPhotoLabel,
                            style: const TextStyle(
                                fontSize:   14,
                                color:      AgentColors.textMuted,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(cameraOrGallery,
                            style: const TextStyle(
                                fontSize: 12,
                                color:    AgentColors.textMuted)),
                      ],
                    )
                  : Align(
                      alignment: AlignmentDirectional.topEnd,
                      child: GestureDetector(
                        onTap: onRemove,
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color:  Colors.black.withOpacity(0.5),
                            shape:  BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
            ),
          ),
          if (imageFile != null)
            GestureDetector(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(changeLabel,
                    style: TextStyle(
                        fontSize:        12,
                        color:           AgentColors.primary,
                        decoration:      TextDecoration.underline,
                        decorationColor: AgentColors.primary)),
              ),
            ),
          if (gpsInfo != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: gpsInfo!.contains('✓')
                      ? const Color(0xFFE8F5EE)
                      : const Color(0xFFFFF8E6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(gpsInfo!,
                    style: TextStyle(
                        fontSize: 12,
                        color:    gpsInfo!.contains('✓')
                            ? AgentColors.primary
                            : const Color(0xFF9C6E00))),
              ),
            ),
        ],
      );
}