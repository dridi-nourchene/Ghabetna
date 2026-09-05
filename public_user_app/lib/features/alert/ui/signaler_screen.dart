import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/bouton_principal.dart';
import '../data/alert_gps.dart';
import '../data/alert_models.dart';
import '../providers/alert_provider.dart';
import 'widgets/forest_dropdown.dart';
import 'widgets/photo_picker.dart';
import 'widgets/type_dropdown.dart';

/// Le formulaire de signalement.
///
/// Hors coquille : c'est une ACTION, pas une destination (voir app_router).
/// Elle a donc son propre Scaffold et sa propre barre de retour, et ne
/// laisse jamais le citoyen changer d'onglet en plein remplissage.
class SignalerScreen extends ConsumerStatefulWidget {
  const SignalerScreen({super.key});

  @override
  ConsumerState<SignalerScreen> createState() => _SignalerScreenState();
}

class _SignalerScreenState extends ConsumerState<SignalerScreen> {
  final _descriptionCtrl = TextEditingController();
  AlertType? _type;
  ForestSimple? _foret;
  File? _photo;
  String? _infoGps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(signalerProvider.notifier).chargerForets();
    });
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _choisirPhoto(ImageSource source) async {
    final picker = ImagePicker();
    // Testé sans compression : le GPS reste à zéro même sur le fichier brut
    // (3,8 Mo). La compression n'est donc pas en cause — c'est très
    // probablement le Photo Picker système d'Android 13+ (utilisé par
    // image_picker pour la galerie) qui retire le GPS par confidentialité
    // avant même de nous transmettre le fichier. Voir alert_gps.dart.
    final choisie = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1920,
    );
    if (choisie == null) return;

    final fichier = File(choisie.path);
    final gps = await AlertGps.depuisPhoto(fichier);

    setState(() {
      _photo = fichier;
      _infoGps = gps != null
          ? '✓ Position trouvée dans la photo'
          : '⚠️ Pas de position dans la photo — la position de votre '
              'téléphone sera utilisée à la place si elle est disponible';
    });
  }

  Future<void> _envoyer() async {
    if (_type == null) {
      _snack('Choisissez un type de signalement.', AppColors.errorText);
      return;
    }
    if (_foret == null) {
      _snack('Choisissez une forêt.', AppColors.errorText);
      return;
    }

    final ok = await ref.read(signalerProvider.notifier).envoyer(
          type: _type!,
          forestId: _foret!.id,
          description: _descriptionCtrl.text.trim().isEmpty
              ? null
              : _descriptionCtrl.text.trim(),
          photo: _photo,
        );

    if (ok && mounted) {
      _snack('Signalement envoyé. Merci !', AppColors.authVert);
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) context.go('/alertes');
    }
  }

  void _snack(String message, Color couleur) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: couleur,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(signalerProvider);

    ref.listen<SignalerState>(signalerProvider, (_, next) {
      if (next.erreur != null) _snack(next.erreur!, AppColors.errorText);
    });

    return Scaffold(
      backgroundColor: AppColors.surface0,
      body: SafeArea(
        child: Column(
          children: [
            _entete(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Etiquette('Type de signalement'),
                    const SizedBox(height: 8),
                    TypeDropdown(
                      selection: _type,
                      onSelect: (t) => setState(() => _type = t),
                    ),
                    const SizedBox(height: 20),
                    const _Etiquette('Forêt concernée'),
                    const SizedBox(height: 8),
                    ForestDropdown(
                      forets: state.forets,
                      chargement: state.chargementForets,
                      selection: _foret,
                      onSelect: (f) => setState(() => _foret = f),
                    ),
                    const SizedBox(height: 20),
                    const _Etiquette('Photo (facultative)'),
                    const SizedBox(height: 8),
                    PhotoPicker(
                      photo: _photo,
                      infoGps: _infoGps,
                      onChoisir: () => afficherChoixSource(
                        context,
                        surAppareilPhoto: () => _choisirPhoto(ImageSource.camera),
                        surGalerie: () => _choisirPhoto(ImageSource.gallery),
                      ),
                      onRetirer: () => setState(() {
                        _photo = null;
                        _infoGps = null;
                      }),
                    ),
                    const SizedBox(height: 20),
                    const _Etiquette('Description (facultative)'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppDims.controle),
                        boxShadow: AppShadows.champ,
                      ),
                      child: TextField(
                        controller: _descriptionCtrl,
                        maxLines: 4,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Précisez ce que vous avez constaté…',
                          hintStyle: const TextStyle(
                              fontSize: 13, color: AppColors.textMuted),
                          filled: true,
                          fillColor: AppColors.surface2,
                          contentPadding: const EdgeInsets.all(14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppDims.controle),
                            borderSide:
                                const BorderSide(color: AppColors.border, width: 0.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppDims.controle),
                            borderSide:
                                const BorderSide(color: AppColors.border, width: 0.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppDims.controle),
                            borderSide:
                                const BorderSide(color: AppColors.authVert, width: 1.2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    BoutonPrincipal(
                      libelle: 'Envoyer le signalement',
                      enChargement: state.envoiEnCours,
                      onPressed: state.envoiEnCours ? null : _envoyer,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entete(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 20, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.go('/accueil'),
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          ),
          const Text(
            'Signaler une alerte',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Etiquette extends StatelessWidget {
  const _Etiquette(this.texte);
  final String texte;

  @override
  Widget build(BuildContext context) => Text(
        texte,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      );
}
