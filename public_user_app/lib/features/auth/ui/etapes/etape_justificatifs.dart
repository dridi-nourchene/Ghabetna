import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../core/widgets/champ_date.dart';
import '../../../../core/widgets/champ_texte.dart';
import '../../../../core/widgets/selecteur_document.dart';
import '../../../chat/data/chat_models.dart' show Specialite;
import '../../data/inscription_form.dart';

/// Étape 3 : la seule étape dont le contenu change selon la spécialité.
///
/// Le campeur n'y voit que ses deux pièces d'identité — la loi tunisienne
/// n'exige aucune autorisation pour camper.
class EtapeJustificatifs extends StatelessWidget {
  const EtapeJustificatifs({
    super.key,
    required this.cle,
    required this.form,
    required this.ctrlPermisChasse,
    required this.ctrlGouvDelivrance,
    required this.ctrlPermisDetention,
    required this.ctrlPermisPort,
    required this.ctrlCodeApiculteur,
    required this.ctrlCodeDelegation,
    required this.ctrlCodeGouvernorat,
    required this.ctrlNbRuchers,
    required this.ctrlNbColonies,
    required this.onModif,
  });

  final GlobalKey<FormState> cle;
  final InscriptionForm form;
  final TextEditingController ctrlPermisChasse;
  final TextEditingController ctrlGouvDelivrance;
  final TextEditingController ctrlPermisDetention;
  final TextEditingController ctrlPermisPort;
  final TextEditingController ctrlCodeApiculteur;
  final TextEditingController ctrlCodeDelegation;
  final TextEditingController ctrlCodeGouvernorat;
  final TextEditingController ctrlNbRuchers;
  final TextEditingController ctrlNbColonies;
  final VoidCallback onModif;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 8),
      child: Form(
        key: cle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (form.specialite == Specialite.chasseur) ..._chasseur(context),
            if (form.specialite == Specialite.apiculteur)
              ..._apiculteur(context),

            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 12),
              child: Text(
                'Documents à joindre',
                style:
                    TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),

            // La liste vient du formulaire, qui l'aligne sur les règles de
            // citizen_service.py. Un seul endroit décide des documents
            // exigés, donc pas de divergence possible entre les deux écrans.
            for (final (champ, libelle) in form.documentsRequis)
              SelecteurDocument(
                libelle: libelle,
                fichier: form.documents[champ],
                onChange: (f) {
                  if (f == null) {
                    form.documents.remove(champ);
                  } else {
                    form.documents[champ] = f;
                  }
                  onModif();
                },
              ),
          ],
        ),
      ),
    );
  }

  // ── Chasseur ────────────────────────────────────────────────────────
  List<Widget> _chasseur(BuildContext context) => [
        ChampTexte(
          etiquette: 'Numéro du permis de chasse',
          controleur: ctrlPermisChasse,
          actionClavier: TextInputAction.next,
          validateur: (v) => (v == null || v.trim().isEmpty)
              ? 'Le numéro de permis est obligatoire'
              : null,
        ),

        Row(
          children: [
            Expanded(
              child: ChampDate(
                etiquette: 'Délivré le',
                valeur: form.dateDelivrance,
                derniere: DateTime.now(),
                onChange: (d) {
                  form.dateDelivrance = d;
                  onModif();
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ChampDate(
                etiquette: 'Expire le',
                valeur: form.dateExpiration,
                premiere: DateTime.now(),
                onChange: (d) {
                  form.dateExpiration = d;
                  onModif();
                },
              ),
            ),
          ],
        ),

        ChampTexte(
          etiquette: 'Gouvernorat de délivrance',
          controleur: ctrlGouvDelivrance,
          actionClavier: TextInputAction.next,
        ),

        // Interrupteur : les deux permis d'arme n'apparaissent que si le
        // chasseur en possède une. Un chasseur sans arme ne verra jamais
        // ces champs.
        Container(
          margin: const EdgeInsets.only(bottom: AppDims.espaceChamp),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.authVertFond,
            borderRadius: BorderRadius.circular(AppDims.controle),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Je possède une arme',
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                ),
              ),
              Switch(
                value: form.possedeArme,
                activeColor: AppColors.authVert,
                onChanged: (v) {
                  form.possedeArme = v;
                  // Si le chasseur se ravise, les pièces liées à l'arme
                  // n'ont plus lieu d'être : on les retire pour ne pas
                  // envoyer des documents que le serveur n'attend pas.
                  if (!v) {
                    form.documents.remove('permis_detention');
                    form.documents.remove('permis_port_transport');
                  }
                  onModif();
                },
              ),
            ],
          ),
        ),

        if (form.possedeArme) ...[
          ChampTexte(
            etiquette: 'N° permis de détention',
            controleur: ctrlPermisDetention,
            actionClavier: TextInputAction.next,
            validateur: (v) => (v == null || v.trim().isEmpty)
                ? 'Obligatoire si vous possédez une arme'
                : null,
          ),
          ChampTexte(
            etiquette: 'N° permis de port et transport',
            controleur: ctrlPermisPort,
            actionClavier: TextInputAction.done,
            // Loi 69-33 : une arme détenue sans droit de transport reste
            // immobilisée, donc les deux permis vont ensemble.
            validateur: (v) => (v == null || v.trim().isEmpty)
                ? 'Obligatoire si vous possédez une arme'
                : null,
          ),
        ],
      ];

  // ── Apiculteur ──────────────────────────────────────────────────────
  List<Widget> _apiculteur(BuildContext context) => [
        const Text(
          'Code d\'identification des ruches',
          style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        const Text(
          '8 chiffres inscrits sur la façade de la ruche',
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),

        // Trois segments et non huit chiffres d'un bloc : l'annexe 16 de
        // l'arrêté du 31 décembre 2015 définit apiculteur (4) + délégation
        // (2) + gouvernorat (2). Découper permet de vérifier plus tard la
        // cohérence avec l'adresse déclarée à l'étape 1.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _CodeSegment(
                controleur: ctrlCodeApiculteur,
                longueur: 4,
                indication: 'apiculteur',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CodeSegment(
                controleur: ctrlCodeDelegation,
                longueur: 2,
                indication: 'délégation',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CodeSegment(
                controleur: ctrlCodeGouvernorat,
                longueur: 2,
                indication: 'gouvernorat',
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        Row(
          children: [
            Expanded(
              child: ChampTexte(
                etiquette: 'Nb de ruchers',
                controleur: ctrlNbRuchers,
                clavier: TextInputType.number,
                validateur: (v) => (int.tryParse((v ?? '').trim()) == null)
                    ? 'Nombre requis'
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ChampTexte(
                etiquette: 'Nb de colonies',
                controleur: ctrlNbColonies,
                clavier: TextInputType.number,
                validateur: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null) return 'Nombre requis';
                  final r = int.tryParse(ctrlNbRuchers.text.trim()) ?? 0;
                  // Un rucher sans colonie n'a pas de sens : on le signale
                  // ici pour éviter que l'admin découvre l'incohérence.
                  if (r > n) return 'Moins de colonies que de ruchers';
                  return null;
                },
              ),
            ),
          ],
        ),

        ChampDate(
          etiquette: 'Date du certificat collectif',
          valeur: form.dateCertificat,
          derniere: DateTime.now(),
          onChange: (d) {
            form.dateCertificat = d;
            onModif();
          },
        ),
      ];
}

/// Un segment du code de ruche : champ court, centré, chiffres seulement.
class _CodeSegment extends StatelessWidget {
  const _CodeSegment({
    required this.controleur,
    required this.longueur,
    required this.indication,
  });

  final TextEditingController controleur;
  final int longueur;
  final String indication;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDims.controle),
            boxShadow: AppShadows.champ,
          ),
          child: TextFormField(
            controller: controleur,
            keyboardType: TextInputType.number,
            maxLength: longueur,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15),
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.length != longueur) return '';
              if (int.tryParse(t) == null) return '';
              return null;
            },
            decoration: InputDecoration(
              counterText: '',
              hintText: '0' * longueur,
              filled: true,
              fillColor: AppColors.surface2,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              // errorStyle à hauteur nulle : le message vide ne doit pas
              // décaler les trois champs les uns par rapport aux autres.
              errorStyle: const TextStyle(height: 0, fontSize: 0),
              border: _b(AppColors.border, 0.5),
              enabledBorder: _b(AppColors.border, 0.5),
              focusedBorder: _b(AppColors.authVert, 1.2),
              errorBorder: _b(AppColors.errorBorder, 1),
              focusedErrorBorder: _b(AppColors.errorBorder, 1.2),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          indication,
          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
      ],
    );
  }

  OutlineInputBorder _b(Color c, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDims.controle),
        borderSide: BorderSide(color: c, width: w),
      );
}
