import 'package:flutter/material.dart';

import '../theme.dart';

/// Champ de saisie de la maquette : étiquette flottante, coins à 14,
/// ombre verte, hauteur alignée sur celle du bouton principal.
///
/// L'ombre est portée par le Container et non par le TextFormField : une
/// ombre appliquée au champ lui-même déborderait des coins arrondis.
class ChampTexte extends StatelessWidget {
  const ChampTexte({
    super.key,
    required this.etiquette,
    this.controleur,
    this.motDePasse = false,
    this.clavier,
    this.validateur,
    this.actionClavier,
    this.suffixe,
    this.longueurMax,
    this.actif = true,
  });

  final String etiquette;
  final TextEditingController? controleur;
  final bool motDePasse;
  final TextInputType? clavier;
  final String? Function(String?)? validateur;
  final TextInputAction? actionClavier;
  final Widget? suffixe;
  final int? longueurMax;
  final bool actif;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDims.espaceChamp),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDims.controle),
        boxShadow: AppShadows.champ,
      ),
      child: TextFormField(
        controller: controleur,
        obscureText: motDePasse,
        keyboardType: clavier,
        validator: validateur,
        textInputAction: actionClavier,
        enabled: actif,
        maxLength: longueurMax,
        style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
        decoration: InputDecoration(
          // labelText et non hintText : seul labelText monte au focus.
          // hintText disparaîtrait, et l'utilisateur perdrait l'indication
          // dès qu'il commence à taper.
          labelText: etiquette,
          counterText: '', // masque le compteur de maxLength
          suffixIcon: suffixe,
          filled: true,
          fillColor: AppColors.surface2,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 14,
          ),
          labelStyle: const TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
          floatingLabelStyle: const TextStyle(
            fontSize: 12,
            color: AppColors.authVert,
          ),
          border: _bordure(AppColors.border, 0.5),
          enabledBorder: _bordure(AppColors.border, 0.5),
          focusedBorder: _bordure(AppColors.authVert, 1.2),
          errorBorder: _bordure(AppColors.errorBorder, 1),
          focusedErrorBorder: _bordure(AppColors.errorBorder, 1.2),
          errorStyle: const TextStyle(fontSize: 11.5),
        ),
      ),
    );
  }

  OutlineInputBorder _bordure(Color couleur, double epaisseur) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDims.controle),
        borderSide: BorderSide(color: couleur, width: epaisseur),
      );
}
