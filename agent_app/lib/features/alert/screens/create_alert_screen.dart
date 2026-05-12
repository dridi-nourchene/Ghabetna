// features/alert/screens/create_alert_screen.dart

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
  String?       _gpsInfo; // affiché sous l'image pour feedback

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

  // ── Choisir une image ──────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source:      source,
      imageQuality: 80,
      maxWidth:    1920,
    );

    if (picked == null) return;

    final file = File(picked.path);

    // Extraire GPS immédiatement pour donner un feedback
    final gps = await AlertService.extractGpsFromImage(file);

    setState(() {
      _imageFile = file;
      _gpsInfo   = gps != null
          ? '! GPS extrait : ${gps.lat.toStringAsFixed(5)}, ${gps.lng.toStringAsFixed(5)}'
          : '⚠️ Pas de GPS dans cette image — localisation via centroïde forêt';
    });
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context:   context,
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

  // ── Soumettre ──────────────────────────────────────────────

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

            // ── Type d'alerte ────────────────────────────
            _SectionLabel('Type d\'alerte *'),
            const SizedBox(height: 8),
            _TypeDropdown(
              selected: _selectedType,
              onSelect: (t) => setState(() => _selectedType = t),
            ),

            const SizedBox(height: 20),

            // ── Forêt ────────────────────────────────────
            _SectionLabel('Forêt concernée *'),
            const SizedBox(height: 8),
            _ForestDropdown(
              forests:  state.forests,
              loading:  state.isLoadingForests,
              selected: _selectedForest,
              onSelect: (f) => setState(() => _selectedForest = f),
            ),

            const SizedBox(height: 20),

            // ── Photo ─────────────────────────────────────
            _SectionLabel('Photo'),
            const SizedBox(height: 8),
            _ImagePicker(
              imageFile: _imageFile,
              gpsInfo:   _gpsInfo,
              onTap:     _showImageSourceDialog,
              onRemove:  () => setState(() {
                _imageFile = null;
                _gpsInfo   = null;
              }),
            ),

            const SizedBox(height: 20),

            // ── Description ───────────────────────────────
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
                  borderSide:
                      const BorderSide(color: Color(0xFFE8EDE8), width: 0.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFFE8EDE8), width: 0.5),
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

            // ── Bouton soumettre ──────────────────────────
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
                  elevation:    0,
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
//  WIDGETS INTERNES
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

// ── Dropdown type d'alerte ─────────────────────────────────────
class _TypeDropdown extends StatelessWidget {
  final AlertType?            selected;
  final void Function(AlertType) onSelect;
  const _TypeDropdown({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8EDE8), width: 0.5),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<AlertType>(
            value:        selected,
            hint: const Padding(
              padding: EdgeInsets.only(left: 14),
              child: Text('Choisir un type...',
                  style: TextStyle(
                      fontSize: 14, color: AgentColors.textMuted)),
            ),
            isExpanded:   true,
            icon: const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.keyboard_arrow_down,
                  color: AgentColors.textMuted),
            ),
            borderRadius: BorderRadius.circular(12),
            items: AlertType.values
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: Row(children: [
                          Text(t.emoji,
                              style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Text(t.label,
                              style: const TextStyle(
                                  fontSize:   14,
                                  color:      AgentColors.textPrimary,
                                  fontWeight: FontWeight.w500)),
                        ]),
                      ),
                    ))
                .toList(),
            onChanged: (t) { if (t != null) onSelect(t); },
          ),
        ),
      );
}

// ── Dropdown forêt ────────────────────────────────────────────
class _ForestDropdown extends StatelessWidget {
  final List<ForestSimple>       forests;
  final bool                     loading;
  final ForestSimple?            selected;
  final void Function(ForestSimple) onSelect;

  const _ForestDropdown({
    required this.forests,
    required this.loading,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8EDE8), width: 0.5),
        ),
        child: loading
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: AgentColors.primary, strokeWidth: 2),
                  ),
                ),
              )
            : DropdownButtonHideUnderline(
                child: DropdownButton<ForestSimple>(
                  value:      selected,
                  hint: const Padding(
                    padding: EdgeInsets.only(left: 14),
                    child: Text('Choisir une forêt...',
                        style: TextStyle(
                            fontSize: 14, color: AgentColors.textMuted)),
                  ),
                  isExpanded:   true,
                  icon: const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(Icons.keyboard_arrow_down,
                        color: AgentColors.textMuted),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  items: forests
                      .map((f) => DropdownMenuItem(
                            value: f,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 14),
                              child: Row(children: [
                                const Icon(Icons.park_outlined,
                                    size: 16,
                                    color: AgentColors.primary),
                                const SizedBox(width: 10),
                                Text(f.name,
                                    style: const TextStyle(
                                        fontSize:   14,
                                        color:      AgentColors.textPrimary,
                                        fontWeight: FontWeight.w500)),
                              ]),
                            ),
                          ))
                      .toList(),
                  onChanged: (f) { if (f != null) onSelect(f); },
                ),
              ),
      );
}

// ── Zone image ────────────────────────────────────────────────
class _ImagePicker extends StatelessWidget {
  final File?        imageFile;
  final String?      gpsInfo;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _ImagePicker({
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
                      : const Color(0xFFE8EDE8),
                  width: imageFile != null ? 1.5 : 0.5,
                  style: imageFile != null
                      ? BorderStyle.solid
                      : BorderStyle.solid,
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
                        fontSize:   12,
                        color:      AgentColors.primary,
                        decoration: TextDecoration.underline)),
              ),
            ),
          if (gpsInfo != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: gpsInfo!.contains('!')
                      ? const Color(0xFFE8F5EE)
                      : const Color(0xFFFFF8E6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(gpsInfo!,
                    style: TextStyle(
                        fontSize: 12,
                        color:    gpsInfo!.contains('!')
                            ? AgentColors.primary
                            : const Color(0xFF9C6E00))),
              ),
            ),
        ],
      );
}