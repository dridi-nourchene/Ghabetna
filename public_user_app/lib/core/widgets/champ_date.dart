import 'package:flutter/material.dart';

import '../theme.dart';

/// Champ de date en lecture seule qui ouvre le sélecteur natif.
///
/// Jamais de saisie clavier pour une date : sur mobile, taper 12/03/1998
/// est pénible et produit des formats incohérents. Le sélecteur garantit
/// une date valide, donc plus de 422 sur la conversion côté serveur.
///
/// TROIS CORRECTIONS PAR RAPPORT À LA VERSION PRÉCÉDENTE
///
/// 1. `locale: const Locale('fr')` a été retiré de showDatePicker.
///    main.dart ne déclare aucun localizationsDelegates : l'application ne
///    fournit que les libellés anglais par défaut. Forcer la locale « fr »
///    faisait échouer la recherche de MaterialLocalizations et le
///    sélecteur ne s'ouvrait pas du tout — au doigt, l'impression que le
///    champ est mort. Sans le paramètre, le sélecteur hérite de la locale
///    de l'application : il passe en français dès que main.dart déclare
///    les delegates, et fonctionne même si on ne les déclare pas.
///
/// 2. initialDate est ramenée dans l'intervalle [firstDate, lastDate].
///    showDatePicker impose cette condition par assertion. « Date de
///    naissance » borne derniere à aujourd'hui moins 18 ans alors que
///    l'initiale valait DateTime.now() : l'assertion sautait à chaque
///    ouverture. C'était la cause principale du champ qui ne réagissait
///    pas.
///
/// 3. Plus de TextEditingController créé dans build(). L'ancien en
///    fabriquait un à chaque reconstruction sans jamais le libérer.
///    FormField + InputDecorator donnent exactement le même habillage
///    sans champ de saisie derrière — et le clavier ne peut plus être
///    sollicité par erreur.
class ChampDate extends StatelessWidget {
  const ChampDate({
    super.key,
    required this.etiquette,
    required this.valeur,
    required this.onChange,
    this.premiere,
    this.derniere,
    this.obligatoire = false,
  });

  final String etiquette;
  final DateTime? valeur;
  final void Function(DateTime) onChange;
  final DateTime? premiere;
  final DateTime? derniere;
  final bool obligatoire;

  @override
  Widget build(BuildContext context) {
    final texte = valeur == null
        ? ''
        : '${valeur!.day.toString().padLeft(2, '0')}/'
            '${valeur!.month.toString().padLeft(2, '0')}/${valeur!.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: AppDims.espaceChamp),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDims.controle),
        boxShadow: AppShadows.champ,
      ),
      child: FormField<DateTime>(
        initialValue: valeur,
        // Le validateur lit `valeur`, la donnée du formulaire, et non
        // l'état interne du FormField : la source de vérité reste
        // InscriptionForm, comme partout ailleurs dans le parcours.
        validator: (_) =>
            (obligatoire && valeur == null) ? 'Date requise' : null,
        // Après un premier choix, le message disparaît dès que la date est
        // renseignée, sans attendre le prochain « Continuer ».
        autovalidateMode: AutovalidateMode.onUserInteraction,
        builder: (etat) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _ouvrir(context, etat),
            child: InputDecorator(
              isEmpty: valeur == null,
              decoration: InputDecoration(
                labelText: etiquette,
                errorText: etat.errorText,
                filled: true,
                fillColor: AppColors.surface2,
                isDense: true,
                suffixIcon: const Icon(Icons.calendar_today_outlined,
                    size: 18, color: AppColors.textMuted),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                labelStyle:
                    const TextStyle(fontSize: 13, color: AppColors.textMuted),
                floatingLabelStyle:
                    const TextStyle(fontSize: 12, color: AppColors.authVert),
                border: _b(AppColors.border, 0.5),
                enabledBorder: _b(AppColors.border, 0.5),
                focusedBorder: _b(AppColors.authVert, 1.2),
                errorBorder: _b(AppColors.errorBorder, 1),
                focusedErrorBorder: _b(AppColors.errorBorder, 1.2),
                errorStyle: const TextStyle(fontSize: 11.5),
              ),
              // L'espace insécable garde la hauteur d'une ligne quand
              // aucune date n'est choisie : le champ ne change pas de
              // taille au premier choix.
              child: Text(
                texte.isEmpty ? ' ' : texte,
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textPrimary),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _ouvrir(
    BuildContext context,
    FormFieldState<DateTime> etat,
  ) async {
    final maintenant = DateTime.now();
    final min = premiere ?? DateTime(1940);
    final max = derniere ?? DateTime(maintenant.year + 20);

    // Recadrage obligatoire : showDatePicker refuse une initialDate hors
    // bornes par assertion, et l'exception remonte avant même l'ouverture.
    var initiale = valeur ?? maintenant;
    if (initiale.isBefore(min)) initiale = min;
    if (initiale.isAfter(max)) initiale = max;

    final choix = await showDatePicker(
      context: context,
      initialDate: initiale,
      firstDate: min,
      lastDate: max,
    );

    if (choix == null) return;
    etat.didChange(choix);
    onChange(choix);
  }

  OutlineInputBorder _b(Color c, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDims.controle),
        borderSide: BorderSide(color: c, width: w),
      );
}