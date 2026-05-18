import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    setState(() {
      _imageFile = file;
      _gpsInfo   = gps != null
          ? '✓ GPS extrait : ${gps.lat.toStringAsFixed(5)}, ${gps.lng.toStringAsFixed(5)}'
          : '⚠️ Pas de GPS dans cette image — localisation via centroïde forêt';
    });
  }

  void _showImageSourceDialog() {
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
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AgentColors.primary),
              title: const Text('Choisir depuis la galerie'),
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
    if (_selectedType == null) {
      _showSnack('Veuillez choisir un type d\'alerte', AgentColors.warning);
      return;
    }
    if (_selectedForest == null) {
      _showSnack('Veuillez choisir une forêt', AgentColors.warning);
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
      _showSnack('Alerte déclarée avec succès ✅', AgentColors.success);
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createAlertProvider);

    ref.listen<CreateAlertState>(createAlertProvider, (_, next) {
      if (next.error != null) {
        _showSnack(next.error!, AgentColors.danger);
      }
    });

    return Scaffold(
      backgroundColor: AgentColors.bgPage,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation:       0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: AgentColors.textPrimary),
          onPressed: () => context.go('/home'),
        ),
        title: const Text('Déclarer une alerte',
            style: TextStyle(
                fontSize:   17,
                fontWeight: FontWeight.w600,
                color:      AgentColors.textPrimary)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: const Color(0xFFE8EDE8)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Type d'alerte — même style que forêt ─────────
            _SectionLabel('Type d\'alerte *'),
            const SizedBox(height: 8),
            _TypeDropdownFixed(
              selected: _selectedType,
              onSelect: (t) => setState(() => _selectedType = t),
            ),

            const SizedBox(height: 20),

            // ── Forêt — dropdown taille fixe ─────────────────
            _SectionLabel('Forêt concernée *'),
            const SizedBox(height: 8),
            _ForestDropdownFixed(
              forests:  state.forests,
              loading:  state.isLoadingForests,
              selected: _selectedForest,
              onSelect: (f) => setState(() => _selectedForest = f),
            ),

            const SizedBox(height: 20),

            // ── Photo ─────────────────────────────────────────
            _SectionLabel('Photo'),
            const SizedBox(height: 8),
            _ImagePickerWidget(
              imageFile: _imageFile,
              gpsInfo:   _gpsInfo,
              onTap:     _showImageSourceDialog,
              onRemove:  () => setState(() {
                _imageFile = null;
                _gpsInfo   = null;
              }),
            ),

            const SizedBox(height: 20),

            // ── Description ───────────────────────────────────
            _SectionLabel('Description'),
            const SizedBox(height: 8),
            TextField(
              controller:  _descController,
              maxLines:    4,
              style: const TextStyle(
                  fontSize: 14, color: AgentColors.textPrimary),
              decoration: InputDecoration(
                hintText:  'Décrivez l\'incident observé...',
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

            // ── Bouton soumettre ──────────────────────────────
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
                    : const Text('Envoyer l\'alerte',
                        style: TextStyle(
                            fontSize:   16,
                            fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
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

// ══════════════════════════════════════════════════════════════
//  SECTION LABEL
// ══════════════════════════════════════════════════════════════

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

// ══════════════════════════════════════════════════════════════
//  TYPE DROPDOWN — style identique à _ForestDropdownFixed
// ══════════════════════════════════════════════════════════════

class _TypeDropdownFixed extends StatelessWidget {
  final AlertType?               selected;
  final void Function(AlertType) onSelect;

  const _TypeDropdownFixed({required this.selected, required this.onSelect});

  static const double _h = 52.0;

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
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: AgentColors.textMuted, size: 22),
              ),
              hint: const Padding(
                padding: EdgeInsets.only(left: 12),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 18, color: AgentColors.primary),
                  SizedBox(width: 8),
                  Text('Choisir un type...',
                      style: TextStyle(
                          fontSize: 14,
                          color:    AgentColors.textMuted)),
                ]),
              ),
              // Affichage dans le trigger (taille fixe)
              selectedItemBuilder: (ctx) => types.map((t) =>
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Row(children: [
                      Text(t.emoji,
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.label,
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
              // Items du menu déroulant
              items: types.map((t) => DropdownMenuItem<AlertType>(
                value: t,
                child: Row(children: [
                  Text(t.emoji,
                      style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(t.label,
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

// ══════════════════════════════════════════════════════════════
//  FOREST DROPDOWN — taille fixe, ne rétrécit JAMAIS à l'ouverture
//
//  Astuce : on wrape le DropdownButton dans un Container de
//  hauteur fixe. Le DropdownButton utilise isExpanded:true pour
//  remplir ce container, et selectedItemBuilder pour contrôler
//  l'affichage dans le trigger sans laisser Flutter le redessiner.
// ══════════════════════════════════════════════════════════════

class _ForestDropdownFixed extends StatelessWidget {
  final List<ForestSimple>          forests;
  final bool                        loading;
  final ForestSimple?               selected;
  final void Function(ForestSimple) onSelect;

  const _ForestDropdownFixed({
    required this.forests,
    required this.loading,
    required this.selected,
    required this.onSelect,
  });

  static const double _h = 52.0; // hauteur fixe du trigger

  @override
  Widget build(BuildContext context) {
    // ── États loading / vide ─────────────────────────────
    if (loading) {
      return _shell(
        selected: selected,
        child: const Row(children: [
          SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(
                  color: AgentColors.primary, strokeWidth: 2)),
          SizedBox(width: 10),
          Text('Chargement...', style: TextStyle(
              fontSize: 14, color: AgentColors.textMuted)),
        ]),
      );
    }

    if (forests.isEmpty) {
      return _shell(
        selected: selected,
        child: const Row(children: [
          Icon(Icons.info_outline, size: 16, color: AgentColors.textMuted),
          SizedBox(width: 8),
          Text('Aucune forêt disponible', style: TextStyle(
              fontSize: 14, color: AgentColors.textMuted)),
        ]),
      );
    }

    // ── Dropdown réel ────────────────────────────────────
    // On entoure dans un Container de hauteur fixe.
    // DropdownButtonHideUnderline supprime la bordure basse.
    // ButtonTheme(alignedDropdown:true) aligne le menu sur le trigger.
    return SizedBox(
      height: _h,
      child: _shell(
        selected: selected,
        usePadding: false, // le DropdownButton gère son propre padding
        child: DropdownButtonHideUnderline(
          child: ButtonTheme(
            alignedDropdown: true,
            child: DropdownButton<ForestSimple>(
              value:      selected,
              isExpanded: true,
              isDense:    false,
              icon: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: AgentColors.textMuted, size: 22),
              ),
              hint: const Padding(
                padding: EdgeInsets.only(left: 12),
                child: Row(children: [
                  Icon(Icons.park_outlined,
                      size: 18, color: AgentColors.primary),
                  SizedBox(width: 8),
                  Text('Choisir une forêt...',
                      style: TextStyle(
                          fontSize: 14,
                          color:    AgentColors.textMuted)),
                ]),
              ),
              // selectedItemBuilder : affichage dans le trigger (taille fixe)
              selectedItemBuilder: (ctx) => forests.map((f) =>
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
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
              // items du menu déroulant
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

  // Container décoratif partagé — toujours hauteur _h
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
          ? Align(alignment: Alignment.centerLeft, child: child)
          : child,
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  IMAGE PICKER
// ══════════════════════════════════════════════════════════════

class _ImagePickerWidget extends StatelessWidget {
  final File?        imageFile;
  final String?      gpsInfo;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _ImagePickerWidget({
    required this.imageFile,
    required this.gpsInfo,
    required this.onTap,
    required this.onRemove,
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
                        const Text('Ajouter une photo',
                            style: TextStyle(
                                fontSize:   14,
                                color:      AgentColors.textMuted,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        const Text('Caméra ou galerie',
                            style: TextStyle(
                                fontSize: 12,
                                color:    AgentColors.textMuted)),
                      ],
                    )
                  : Align(
                      alignment: Alignment.topRight,
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
                child: Text('Changer la photo',
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