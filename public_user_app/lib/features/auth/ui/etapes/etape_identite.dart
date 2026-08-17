import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme.dart';
import '../../../../core/widgets/champ_date.dart';
import '../../../../core/widgets/champ_texte.dart';
import '../../data/inscription_form.dart';

/// Étape 1 : ce qui est commun aux trois spécialités.
///
/// Les controllers viennent du parent : cette étape ne les crée pas et ne
/// les libère pas, sinon le texte serait perdu à chaque changement de page.
class EtapeIdentite extends StatelessWidget {
  const EtapeIdentite({
    super.key,
    required this.cle,
    required this.form,
    required this.ctrlNom,
    required this.ctrlCin,
    required this.ctrlEmail,
    required this.ctrlTelephone,
    required this.ctrlMotDePasse,
    required this.ctrlConfirmation,
    required this.ctrlDelegation,
    required this.ctrlSecteur,
    required this.ctrlAdresse,
    required this.onModif,
  });

  final GlobalKey<FormState> cle;
  final InscriptionForm form;
  final TextEditingController ctrlNom;
  final TextEditingController ctrlCin;
  final TextEditingController ctrlEmail;
  final TextEditingController ctrlTelephone;
  final TextEditingController ctrlMotDePasse;
  final TextEditingController ctrlConfirmation;
  final TextEditingController ctrlDelegation;
  final TextEditingController ctrlSecteur;
  final TextEditingController ctrlAdresse;
  final VoidCallback onModif;

  /// Les 24 gouvernorats. Une liste déroulante évite les fautes de frappe
  /// qui rendraient impossible tout regroupement par région côté admin.
  static const gouvernorats = [
    'Ariana', 'Béja', 'Ben Arous', 'Bizerte', 'Gabès', 'Gafsa',
    'Jendouba', 'Kairouan', 'Kasserine', 'Kébili', 'Le Kef', 'Mahdia',
    'La Manouba', 'Médenine', 'Monastir', 'Nabeul', 'Sfax', 'Sidi Bouzid',
    'Siliana', 'Sousse', 'Tataouine', 'Tozeur', 'Tunis', 'Zaghouan',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 8),
      child: Form(
        key: cle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ChampTexte(
              etiquette: 'Nom et prénom',
              controleur: ctrlNom,
              actionClavier: TextInputAction.next,
              validateur: (v) => (v == null || v.trim().length < 3)
                  ? 'Entrez votre nom complet'
                  : null,
            ),

            ChampTexte(
              etiquette: 'Numéro CIN',
              controleur: ctrlCin,
              clavier: TextInputType.number,
              longueurMax: 8,
              actionClavier: TextInputAction.next,
              // Le clavier numérique n'empêche pas de coller du texte :
              // ce filtre garantit que seuls des chiffres entrent.
              validateur: (v) {
                final t = (v ?? '').trim();
                if (t.length != 8) return 'Le CIN comporte 8 chiffres';
                if (int.tryParse(t) == null) return 'Chiffres uniquement';
                return null;
              },
            ),

            ChampTexte(
              etiquette: 'Adresse e-mail',
              controleur: ctrlEmail,
              clavier: TextInputType.emailAddress,
              actionClavier: TextInputAction.next,
              validateur: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'Entrez votre adresse e-mail';
                if (!t.contains('@') || !t.contains('.')) {
                  return 'Adresse e-mail invalide';
                }
                return null;
              },
            ),

            ChampTexte(
              etiquette: 'Téléphone',
              controleur: ctrlTelephone,
              clavier: TextInputType.phone,
              longueurMax: 8,
              actionClavier: TextInputAction.next,
              validateur: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null; // facultatif
                if (t.length != 8) return 'Le numéro comporte 8 chiffres';
                return null;
              },
            ),

            ChampDate(
              etiquette: 'Date de naissance',
              valeur: form.dateNaissance,
              // Un chasseur mineur ne peut pas obtenir de permis : on borne
              // la sélection plutôt que de refuser après coup.
              derniere: DateTime(DateTime.now().year - 18),
              onChange: (d) {
                form.dateNaissance = d;
                onModif();
              },
            ),

            ChampTexte(
              etiquette: 'Mot de passe',
              controleur: ctrlMotDePasse,
              motDePasse: true,
              actionClavier: TextInputAction.next,
              validateur: (v) {
                final t = v ?? '';
                if (t.length < 8) return 'Au moins 8 caractères';
                // Contrôle volontairement souple : la règle exacte est celle
                // d'auth_ms. Si elle refuse, son message 422 s'affiche tel
                // quel — deux règles écrites en double finiraient par diverger.
                return null;
              },
            ),

            ChampTexte(
              etiquette: 'Confirmer le mot de passe',
              controleur: ctrlConfirmation,
              motDePasse: true,
              actionClavier: TextInputAction.next,
              validateur: (v) => (v != ctrlMotDePasse.text)
                  ? 'Les mots de passe ne correspondent pas'
                  : null,
            ),

            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 14),
              child: Text(
                'Votre adresse',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),

            _Deroulant(
              etiquette: 'Gouvernorat',
              valeur: form.gouvernorat.isEmpty ? null : form.gouvernorat,
              options: gouvernorats,
              onChange: (v) {
                form.gouvernorat = v ?? '';
                onModif();
              },
            ),

            ChampTexte(
              etiquette: 'Délégation',
              controleur: ctrlDelegation,
              actionClavier: TextInputAction.next,
              validateur: (v) => (v == null || v.trim().isEmpty)
                  ? 'Entrez votre délégation'
                  : null,
            ),

            ChampTexte(
              etiquette: 'Secteur (facultatif)',
              controleur: ctrlSecteur,
              actionClavier: TextInputAction.next,
            ),

            ChampTexte(
              etiquette: 'Adresse (facultatif)',
              controleur: ctrlAdresse,
              actionClavier: TextInputAction.done,
            ),
          ],
        ),
      ),
    );
  }
}

/// Liste déroulante habillée comme ChampTexte, pour que l'écran reste
/// homogène : même hauteur, même rayon, même ombre.
class _Deroulant extends StatelessWidget {
  const _Deroulant({
    required this.etiquette,
    required this.valeur,
    required this.options,
    required this.onChange,
  });

  final String etiquette;
  final String? valeur;
  final List<String> options;
  final void Function(String?) onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDims.espaceChamp),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDims.controle),
        boxShadow: AppShadows.champ,
      ),
      child: DropdownButtonFormField<String>(
        value: valeur,
        isExpanded: true,
        style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
        validator: (v) => (v == null) ? 'Choisissez votre gouvernorat' : null,
        items: options
            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
            .toList(),
        onChanged: onChange,
        decoration: InputDecoration(
          labelText: etiquette,
          filled: true,
          fillColor: AppColors.surface2,
          isDense: true,
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
