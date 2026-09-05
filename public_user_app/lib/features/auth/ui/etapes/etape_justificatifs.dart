import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
                activeThumbColor: AppColors.authVert,
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
        // (2) + gouvernorat (2).
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

        // Message unique pour les trois segments. Chaque segment n'affiche
        // qu'une bordure rouge : son message est de hauteur nulle pour ne pas
        // décaler la rangée. Sans cette ligne, un code incomplet bloquait
        // « Continuer » sans que rien ne l'explique.
        FormField<String>(
          validator: (_) {
            const segments = [4, 2, 2];
            final valeurs = [
              ctrlCodeApiculteur.text.trim(),
              ctrlCodeDelegation.text.trim(),
              ctrlCodeGouvernorat.text.trim(),
            ];
            for (var i = 0; i < valeurs.length; i++) {
              final t = valeurs[i];
              if (t.length != segments[i] || int.tryParse(t) == null) {
                return 'Code incomplet : 4 chiffres, puis 2, puis 2.';
              }
            }
            return null;
          },
          builder: (etat) => etat.hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    etat.errorText!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.errorText,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),

        const SizedBox(height: 18),

        // Le nombre de colonies vient du certificat collectif (annexe 19),
        // c'est une donnée officielle reportée telle quelle. Il n'est ni
        // recalculé, ni comparé au total des ruchers : la déclaration des
        // ruchers est facultative, un écart n'est donc pas une anomalie.
        ChampTexte(
          etiquette: 'Nombre de colonies (certificat)',
          controleur: ctrlNbColonies,
          clavier: TextInputType.number,
          // int.tryParse accepterait « -12 », qui partirait vers
          // nombre_colonies_declare sans aucune contrainte de signe en base.
          validateur: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return 'Reportez le nombre inscrit sur le certificat';
            final n = int.tryParse(t);
            if (n == null || n < 0) return 'Chiffres uniquement, sans signe';
            return null;
          },
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

        _ZoneRuchers(form: form, onModif: onModif),
      ];
}

/// Déclaration des ruchers : liste des ruchers ajoutés + carte de saisie.
///
/// Stateful et isolé pour que EtapeJustificatifs reste sans état. Ce qui
/// change ici — carte ouverte, texte en cours de frappe — n'intéresse pas le
/// reste de l'étape ; seul un ajout ou une suppression remonte via onModif.
///
/// Les champs de la carte n'ont PAS de validateur. Ils vivent dans le Form
/// de l'étape, qui les validerait au clic sur « Continuer » et bloquerait le
/// passage à l'étape 4 dès que la carte est ouverte à vide. La vérification
/// se fait donc à la main dans _enregistrer().
class _ZoneRuchers extends StatefulWidget {
  const _ZoneRuchers({
    required this.form,
    required this.onModif,
  });

  final InscriptionForm form;
  final VoidCallback onModif;

  @override
  State<_ZoneRuchers> createState() => _ZoneRuchersState();
}

class _ZoneRuchersState extends State<_ZoneRuchers> {
  bool _saisieOuverte = false;
  String? _erreur;

  final _ctrlEmplacement = TextEditingController();
  final _ctrlColonies = TextEditingController();

  @override
  void dispose() {
    _ctrlEmplacement.dispose();
    _ctrlColonies.dispose();
    super.dispose();
  }

  void _ouvrir() {
    _ctrlEmplacement.clear();
    _ctrlColonies.clear();
    setState(() {
      _erreur = null;
      _saisieOuverte = true;
    });
  }

  void _annuler() => setState(() {
        _erreur = null;
        _saisieOuverte = false;
      });

  void _enregistrer() {
    final emplacement = _ctrlEmplacement.text.trim();
    final colonies = int.tryParse(_ctrlColonies.text.trim());

    if (emplacement.isEmpty) {
      setState(() => _erreur = 'Indiquez l\'emplacement du rucher');
      return;
    }
    // Rucher.emplacement est un String(255) en base et RucherIn impose
    // max_length=255. Au-delà, le dossier complet — pièces jointes
    // comprises — partirait pour revenir en 400.
    if (emplacement.length > 255) {
      setState(() => _erreur = 'Emplacement trop long : 255 caractères au maximum');
      return;
    }
    // RucherIn impose ge=0 côté serveur : refuser ici évite un 400 après
    // avoir renvoyé tout le dossier, pièces jointes comprises.
    if (colonies == null || colonies < 0) {
      setState(() => _erreur = 'Indiquez le nombre de colonies');
      return;
    }

    widget.form.ruchers.add(
      RucherSaisi(emplacement: emplacement, nombreColonies: colonies),
    );
    setState(() {
      _erreur = null;
      _saisieOuverte = false;
    });
    widget.onModif();
  }

  void _supprimer(int index) {
    widget.form.ruchers.removeAt(index);
    setState(() {});
    widget.onModif();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4, bottom: 2),
          child: Text(
            'Vos ruchers',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Facultatif. Vous pourrez les déclarer après validation.',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ),

        for (var i = 0; i < widget.form.ruchers.length; i++)
          _CarteRucher(
            numero: i + 1,
            rucher: widget.form.ruchers[i],
            onSupprimer: () => _supprimer(i),
          ),

        if (_saisieOuverte) _carteSaisie() else _boutonAjouter(),

        // Carte ouverte et déjà remplie : « Continuer » passerait à l'étape 4
        // et la saisie disparaîtrait sans un mot. Ce FormField participe au
        // Form de l'étape et bloque le passage, mais seulement si quelque
        // chose a réellement été tapé : ouvrir la carte puis se raviser ne
        // bloque rien.
        FormField<bool>(
          validator: (_) =>
              (_saisieOuverte && _ctrlEmplacement.text.trim().isNotEmpty)
                  ? 'Enregistrez ou annulez le rucher en cours de saisie.'
                  : null,
          builder: (etat) => etat.hasError
              ? Padding(
                  padding:
                      const EdgeInsets.only(bottom: AppDims.espaceChamp),
                  child: Text(
                    etat.errorText!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.errorText,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _boutonAjouter() {
    return GestureDetector(
      onTap: _ouvrir,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDims.espaceChamp),
        height: AppDims.controle * 3.29, // 46, comme BoutonPrincipal
        decoration: BoxDecoration(
          color: AppColors.authVertFond,
          borderRadius: BorderRadius.circular(AppDims.controle),
          border: Border.all(color: AppColors.authVertPointille, width: 1),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 18, color: AppColors.authVert),
            SizedBox(width: 8),
            Text(
              'Ajouter un rucher',
              style: TextStyle(fontSize: 14, color: AppColors.authVert),
            ),
          ],
        ),
      ),
    );
  }

  Widget _carteSaisie() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDims.espaceChamp),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 2),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppDims.controle),
        border: Border.all(color: AppColors.authVert, width: 0.8),
        boxShadow: AppShadows.champ,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              'Rucher n° ${widget.form.ruchers.length + 1}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          // Texte libre : c'est le champ officiel de l'annexe 18, qui ne
          // prévoit ni liste fermée ni coordonnées. La borne à 255 est
          // celle de la colonne : mieux vaut empêcher la frappe que
          // refuser après l'envoi du dossier complet.
          ChampTexte(
            etiquette: 'Emplacement',
            controleur: _ctrlEmplacement,
            longueurMax: 255,
            actionClavier: TextInputAction.next,
          ),
          ChampTexte(
            etiquette: 'Nombre de colonies',
            controleur: _ctrlColonies,
            clavier: TextInputType.number,
            actionClavier: TextInputAction.done,
          ),

          if (_erreur != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _erreur!,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.errorText,
                ),
              ),
            ),

          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _annuler,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppDims.controle),
                      border:
                          Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: const Center(
                      child: Text(
                        'Annuler',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _enregistrer,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.authVert,
                      borderRadius: BorderRadius.circular(AppDims.controle),
                    ),
                    child: const Center(
                      child: Text(
                        'Enregistrer',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.authBlanc,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Un rucher déjà déclaré, en lecture seule.
///
/// Pas de modification : le supprimer et le ressaisir coûte deux champs,
/// une édition inline coûterait un second état de carte pour un gain nul.
class _CarteRucher extends StatelessWidget {
  const _CarteRucher({
    required this.numero,
    required this.rucher,
    required this.onSupprimer,
  });

  final int numero;
  final RucherSaisi rucher;
  final VoidCallback onSupprimer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppDims.controle),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: AppShadows.champ,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rucher n° $numero',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  rucher.emplacement,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${rucher.nombreColonies} colonies',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onSupprimer,
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.delete_outline,
                  size: 19, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
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
            // Le clavier numérique n'empêche ni le collage ni les claviers
            // physiques. La contrainte en base est « ~ '^[0-9]{4}$' » : un
            // caractère non numérique arrivé jusque-là fait échouer
            // l'insertion, donc après la création du compte chez auth_ms.
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
              // Le message lisible est porté par le FormField commun placé
              // sous la rangée.
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