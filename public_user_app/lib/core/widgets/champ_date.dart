import 'package:flutter/material.dart';

import '../theme.dart';

/// Champ de date en lecture seule qui ouvre le sélecteur natif.
///
/// Jamais de saisie clavier pour une date : sur mobile, taper 12/03/1998
/// est pénible et produit des formats incohérents. Le sélecteur garantit
/// une date valide, donc plus de 422 sur la conversion côté serveur.
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
      child: TextFormField(
        readOnly: true,
        controller: TextEditingController(text: texte),
        style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
        validator: (_) =>
            (obligatoire && valeur == null) ? 'Date requise' : null,
        onTap: () async {
          final maintenant = DateTime.now();
          final choix = await showDatePicker(
            context: context,
            initialDate: valeur ?? maintenant,
            firstDate: premiere ?? DateTime(1940),
            lastDate: derniere ?? DateTime(maintenant.year + 20),
            locale: const Locale('fr'),
          );
          if (choix != null) onChange(choix);
        },
        decoration: InputDecoration(
          labelText: etiquette,
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
          errorStyle: const TextStyle(fontSize: 11.5),
        ),
      ),
    );
  }

  OutlineInputBorder _b(Color c, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDims.controle),
        borderSide: BorderSide(color: c, width: w),
      );
}
