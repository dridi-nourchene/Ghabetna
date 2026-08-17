import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../chat/data/chat_models.dart' show Specialite;
import '../../data/inscription_form.dart';

/// Étape 4 : tout relire avant d'envoyer.
///
/// Chaque bloc a son lien « Modifier » qui ramène à l'étape concernée en
/// conservant la saisie. Sans ça, une faute de frappe sur le CIN — le champ
/// qui déclenche justement le 409 du serveur — obligerait à tout refaire.
class EtapeRecapitulatif extends StatelessWidget {
  const EtapeRecapitulatif({
    super.key,
    required this.form,
    required this.onModifier,
  });

  final InscriptionForm form;
  final void Function(int etape) onModifier;

  String _date(DateTime? d) => d == null
      ? '—'
      : '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final specialite = form.specialite;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Titre(
            icone: Icons.person_outline,
            texte: 'Identité',
            onModifier: () => onModifier(0),
          ),
          _Bloc(lignes: [
            ('Nom', form.nomComplet),
            ('CIN', form.cin),
            ('E-mail', form.email),
            if (form.telephone.isNotEmpty) ('Téléphone', form.telephone),
            ('Naissance', _date(form.dateNaissance)),
            ('Adresse', '${form.delegation}, ${form.gouvernorat}'),
          ]),

          _Titre(
            icone: Icons.badge_outlined,
            texte: 'Spécialité',
            onModifier: () => onModifier(1),
          ),
          _Bloc(lignes: [
            ('Type', specialite?.libelle ?? '—'),
            if (specialite == Specialite.chasseur)
              ('Permis', form.numeroPermisChasse),
            if (specialite == Specialite.chasseur)
              ('Expire le', _date(form.dateExpiration)),
            if (specialite == Specialite.chasseur)
              ('Arme', form.possedeArme ? 'Oui' : 'Non'),
            if (specialite == Specialite.apiculteur)
              ('Code ruche',
                  '${form.codeApiculteur} ${form.codeDelegation} ${form.codeGouvernorat}'),
            if (specialite == Specialite.apiculteur)
              ('Ruchers', '${form.nombreRuchers ?? 0}'),
            if (specialite == Specialite.apiculteur)
              ('Colonies', '${form.nombreColonies ?? 0}'),
          ]),

          _Titre(
            icone: Icons.folder_outlined,
            texte: 'Documents',
            onModifier: () => onModifier(2),
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(AppDims.controle),
              border: Border.all(color: AppColors.border, width: 0.5),
              boxShadow: AppShadows.champ,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${form.documents.length} pièce'
                    '${form.documents.length > 1 ? 's' : ''} jointe'
                    '${form.documents.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textPrimary),
                  ),
                ),
                const Icon(Icons.check, size: 18, color: AppColors.authVert),
              ],
            ),
          ),

          // Seule touche non verte du parcours : le citoyen doit comprendre
          // avant d'appuyer que son compte ne sera pas utilisable tout de
          // suite. C'est ce qui évite qu'il croie à une panne au moment de
          // se connecter.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.errorBg,
              borderRadius: BorderRadius.circular(AppDims.controle),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 17, color: AppColors.errorText),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Votre dossier sera examiné par l\'administration avant '
                    'l\'activation de votre compte.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.errorText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Titre extends StatelessWidget {
  const _Titre({
    required this.icone,
    required this.texte,
    required this.onModifier,
  });

  final IconData icone;
  final String texte;
  final VoidCallback onModifier;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icone, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texte,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          GestureDetector(
            onTap: onModifier,
            child: const Text(
              'Modifier',
              style: TextStyle(fontSize: 12, color: AppColors.authVert),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bloc extends StatelessWidget {
  const _Bloc({required this.lignes});
  final List<(String, String)> lignes;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppDims.controle),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: AppShadows.champ,
      ),
      child: Column(
        children: [
          for (var i = 0; i < lignes.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: i == 0
                  ? null
                  : const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppColors.border, width: 0.5),
                      ),
                    ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lignes[i].$1,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textMuted),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lignes[i].$2.isEmpty ? '—' : lignes[i].$2,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
