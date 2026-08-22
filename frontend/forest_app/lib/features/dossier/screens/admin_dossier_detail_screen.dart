// features/dossier/screens/admin_dossier_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:forest_app/core/theme/app_colors.dart';
import 'package:forest_app/core/widgets/app_card.dart';
import 'package:forest_app/features/dossier/models/dossier_model.dart';
import 'package:forest_app/features/dossier/providers/dossier_provider.dart';
import 'package:forest_app/features/dossier/screens/admin_dossiers_screen.dart'
    show iconeSpecialite, pilluleStatut, jjmmaaaa;
import 'package:forest_app/features/dossier/widgets/piece_jointe_tile.dart';

/// Date avec l'heure, réservée à l'en-tête et au récapitulatif.
///
/// Ailleurs la date seule suffit ; ici l'heure aide à situer une décision
/// dans une file traitée le même jour.
String _dateHeure(DateTime? d) => d == null
    ? '—'
    : '${jjmmaaaa(d)} à ${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';

class AdminDossierDetailScreen extends ConsumerStatefulWidget {
  final String profilId;

  const AdminDossierDetailScreen({super.key, required this.profilId});

  @override
  ConsumerState<AdminDossierDetailScreen> createState() =>
      _AdminDossierDetailScreenState();
}

class _AdminDossierDetailScreenState
    extends ConsumerState<AdminDossierDetailScreen> {
  final _ctrlMotif = TextEditingController();
  String? _erreurMotif;

  @override
  void initState() {
    super.initState();
    // Après la première frame : modifier un provider pendant le build
    // déclencherait une exception Riverpod.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dossierDetailProvider(widget.profilId).notifier).charger();
    });
  }

  @override
  void dispose() {
    _ctrlMotif.dispose();
    super.dispose();
  }

  // ── Décision ──────────────────────────────────────────

  Future<void> _approuver() async {
    setState(() => _erreurMotif = null);
    await _envoyer(approuve: true);
  }

  Future<void> _rejeter() async {
    final motif = _ctrlMotif.text.trim();

    // Miroir du validateur de DecisionIn et du CheckConstraint en base.
    // Vérifier ici évite un aller-retour pour apprendre ce qu'on savait
    // déjà — et surtout, ce texte est la seule chose que le citoyen lira
    // pour comprendre quoi corriger.
    if (motif.isEmpty) {
      setState(() => _erreurMotif =
          'Indiquez le motif : c\'est ce que le citoyen lira.');
      return;
    }

    // ctxDialog est NOMMÉ, et non ignoré avec un « _ ».
    //
    // Avec « _ », les deux boutons capturaient le context de l'ÉCRAN. Or
    // l'écran vit sous le navigateur imbriqué du ShellRoute, tandis que la
    // boîte est poussée sur le navigateur racine. Navigator.of(contexte de
    // l'écran) remontait donc au navigateur du shell, et pop() y retirait
    // la PAGE de détail au lieu de la boîte : le shell se retrouvait sans
    // enfant, d'où l'écran blanc.
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctxDialog) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        title: const Text('Rejeter ce dossier ?',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        // Le rejet est terminal dans auth_ms : UserStatus.rejete n'autorise
        // aucune transition suivante, et la ligne garde le CIN et l'email.
        // Le citoyen ne pourra ni être repêché, ni se réinscrire. L'admin
        // doit le savoir AVANT de cliquer, pas en recevant l'appel.
        content: const Text(
          'Cette décision est définitive. Le compte ne pourra plus être '
          'réactivé, et le citoyen ne pourra pas se réinscrire avec le '
          'même CIN.',
          style: TextStyle(
              fontSize: 13, height: 1.5, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctxDialog).pop(false),
            child: const Text('Annuler',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctxDialog).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );

    if (confirme != true) return;
    setState(() => _erreurMotif = null);
    await _envoyer(approuve: false, motif: motif);
  }

  Future<void> _envoyer({required bool approuve, String? motif}) async {
    final notifier =
        ref.read(dossierDetailProvider(widget.profilId).notifier);

    final ok = await notifier.decider(approuve: approuve, motif: motif);
    if (!mounted) return;

    // La liste porte les trois compteurs et la pastille de la barre
    // latérale. Sans ce rechargement, « 2 en attente » resterait affiché
    // alors qu'il n'en reste qu'un.
    if (ok) ref.read(dossierListProvider.notifier).charger();

    final etat    = ref.read(dossierDetailProvider(widget.profilId));
    final message = ok ? etat.succes : etat.error;
    if (message == null) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: ok ? AppColors.success : AppColors.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
    notifier.effacerMessages();
  }

  // ── Rendu ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final etat = ref.watch(dossierDetailProvider(widget.profilId));

    if (etat.isLoading && etat.dossier == null) {
      return const Center(
        child: CircularProgressIndicator(
            color: AppColors.primaryMid, strokeWidth: 2.5),
      );
    }

    if (etat.dossier == null) return _Introuvable(message: etat.error);

    final d = etat.dossier!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _retour(),
          const SizedBox(height: 12),
          _enTete(etat, d),
          const SizedBox(height: 18),

          if (d.motifRejet != null && d.motifRejet!.trim().isNotEmpty)
            _MotifRejet(motif: d.motifRejet!),

          _identite(etat, d),
          _adresse(d),
          if (d.chasseur != null) _chasseur(d.chasseur!),
          if (d.apiculteur != null) _apiculteur(d.apiculteur!),
          _pieces(d),

          if (d.estEnAttente) _decision(etat) else _decisionPrise(d),
        ],
      ),
    );
  }

  Widget _retour() => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => context.go('/admin/dossiers'),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back,
                  size: 15, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text('Dossiers citoyens',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      );

  Widget _enTete(DossierDetailState etat, Dossier d) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.bgInput,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Center(child: iconeSpecialite(d.specialite, taille: 21)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etat.nom,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        // Compte supprimé mais dossier encore là : anomalie
                        // entre les deux bases, signalée en rouge.
                        color: etat.citoyen == null
                            ? AppColors.danger
                            : AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text(
                  '${d.specialiteLabel} · soumis le ${_dateHeure(d.soumisLe)}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          pilluleStatut(d.statutDossier),
        ],
      );

  // ── Cartes d'information ──────────────────────────────

  Widget _identite(DossierDetailState etat, Dossier d) => _Section(
        titre: 'Identité',
        icone: Icons.person_outline,
        champs: [
          _Champ('Nom complet', etat.nom),
          _Champ('CIN', etat.cin),
          _Champ('Email', etat.email),
          _Champ('Téléphone', etat.citoyen?.phone ?? d.telephone ?? '—'),
          // Interpolation plutôt qu'un cast : le champ compile que
          // AppUser.birthDate soit un String ou un DateTime.
          _Champ('Date de naissance', '${etat.citoyen?.birthDate ?? '—'}'),
        ],
      );

  Widget _adresse(Dossier d) => _Section(
        titre: 'Adresse déclarée',
        icone: Icons.place_outlined,
        champs: [
          _Champ('Gouvernorat', d.gouvernorat),
          _Champ('Délégation', d.delegation),
          _Champ('Secteur', d.secteur ?? '—'),
          _Champ('Adresse', d.adresse ?? '—'),
        ],
      );

  Widget _chasseur(ProfilChasseur c) => _Section(
        titre: 'Données chasseur',
        icone: Icons.gps_fixed,
        champs: [
          _Champ('N° permis de chasse', c.numeroPermisChasse),
          _Champ('Délivré le', jjmmaaaa(c.dateDelivrance)),
          _Champ('Expire le', jjmmaaaa(c.dateExpiration)),
          _Champ('Gouvernorat de délivrance',
              c.gouvernoratDelivrance ?? '—'),
          _Champ('Possède une arme', c.possedeArme ? 'Oui' : 'Non'),
          // Les deux permis n'existent que si une arme a été déclarée.
          // Afficher deux tirets pour un chasseur sans arme laisserait
          // croire à une saisie incomplète.
          if (c.possedeArme) ...[
            _Champ('N° permis de détention',
                c.numeroPermisDetention ?? '—'),
            _Champ('N° permis de port et transport',
                c.numeroPermisPortTransport ?? '—'),
          ],
        ],
      );

  Widget _apiculteur(ProfilApiculteur a) => _Section(
        titre: 'Données apiculteur',
        icone: Icons.hive_outlined,
        champs: [
          _Champ('Code d\'identification', a.codeComplet),
          _Champ('Colonies déclarées', '${a.nombreColoniesDeclare}'),
          _Champ('Date du certificat', jjmmaaaa(a.dateCertificat)),
        ],
        apres: a.ruchers.isEmpty
            ? const Padding(
                padding: EdgeInsets.only(top: 14),
                // La déclaration des ruchers est facultative à
                // l'inscription — annexe 21. Une liste vide n'est pas une
                // anomalie, et rien ne la compare au certificat.
                child: Text('Aucun rucher déclaré à l\'inscription.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
              )
            : Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Ruchers déclarés · ${a.totalColoniesRuchers} colonies au total',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 8),
                    for (final r in a.ruchers)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.border, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Rucher n° ${r.numeroRucher} — ${r.emplacement}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textPrimary),
                              ),
                            ),
                            Text('${r.nombreColonies} colonies',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
      );

  Widget _pieces(Dossier d) => _Section(
        titre: 'Pièces jointes',
        icone: Icons.attach_file,
        champs: const [],
        apres: d.pieces.isEmpty
            ? const Text('Aucune pièce jointe.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted))
            : Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final p in d.pieces)
                    SizedBox(width: 172, child: PieceJointeTile(piece: p)),
                ],
              ),
      );

  // ── Zone de décision ──────────────────────────────────

  Widget _decision(DossierDetailState etat) {
    final bloque = etat.enCoursDeDecision;

    return _Section(
      titre: 'Décision',
      icone: Icons.gavel_outlined,
      champs: const [],
      apres: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Champ visible en permanence, et non révélé au clic sur
          // « Rejeter » : DecisionIn accepte un motif même sur une
          // approbation, et un champ qui surgit fait cliquer deux fois sur
          // une action irréversible.
          TextField(
            controller: _ctrlMotif,
            enabled: !bloque,
            maxLines: 3,
            maxLength: 1000, // Field(max_length=1000) dans DecisionIn
            style: const TextStyle(
                fontSize: 13, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Motif du rejet — visible par le citoyen',
              hintStyle: const TextStyle(
                  fontSize: 13, color: AppColors.textMuted),
              errorText: _erreurMotif,
              counterText: '',
              filled: true,
              fillColor: AppColors.bgInput,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AppColors.border, width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AppColors.border, width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: AppColors.primaryMid, width: 1),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Obligatoire pour un rejet, facultatif pour une approbation.',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Les deux boutons se désactivent pendant l'appel : un
              // double-clic déclencherait le 409 « dossier déjà traité ».
              OutlinedButton(
                onPressed: bloque ? null : _rejeter,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side:
                      const BorderSide(color: AppColors.danger, width: 0.8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9)),
                ),
                child: const Text('Rejeter le dossier',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: bloque ? null : _approuver,
                icon: bloque
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check, size: 16),
                label: Text(bloque ? 'Envoi...' : 'Approuver',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  // primaryDark, comme le bouton « Créer un utilisateur »
                  // de l'écran des utilisateurs : une seule couleur pour
                  // l'action principale dans toute l'administration.
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Remplace la zone de décision une fois le dossier tranché.
  ///
  /// decider_dossier répond 409 sur un dossier déjà traité : laisser les
  /// boutons visibles reviendrait à proposer une action condamnée d'avance.
  Widget _decisionPrise(Dossier d) => _Section(
        titre: 'Décision prise',
        icone: Icons.history,
        champs: [
          _Champ('Statut', d.statutLabel),
          _Champ('Traité le', _dateHeure(d.traiteLe)),
        ],
      );
}

// ═══════════════════════════════════════════════════════════════
//  BRIQUES
// ═══════════════════════════════════════════════════════════════

class _Section extends StatelessWidget {
  final String       titre;
  final IconData     icone;
  final List<Widget> champs;
  final Widget?      apres;

  const _Section({
    required this.titre,
    required this.icone,
    required this.champs,
    this.apres,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icone, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(titre,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                ],
              ),
              const SizedBox(height: 14),
              // Wrap et non Row : les champs se réorganisent quand la barre
              // latérale s'ouvre, au lieu de déborder.
              if (champs.isNotEmpty)
                Wrap(spacing: 28, runSpacing: 16, children: champs),
              if (apres != null) apres!,
            ],
          ),
        ),
      );
}

class _Champ extends StatelessWidget {
  final String label;
  final String valeur;

  const _Champ(this.label, this.valeur);

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 190,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted)),
            const SizedBox(height: 2),
            Text(valeur,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textPrimary)),
          ],
        ),
      );
}

/// Motif du rejet, rappelé en haut de la fiche.
///
/// C'est le texte que le citoyen a reçu. L'admin doit pouvoir le relire si
/// l'intéressé rappelle pour demander ce qui n'allait pas.
class _MotifRejet extends StatelessWidget {
  final String motif;
  const _MotifRejet({required this.motif});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.dangerBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline,
                size: 16, color: AppColors.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Motif du rejet',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger)),
                  const SizedBox(height: 4),
                  Text(motif,
                      style: const TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Introuvable extends StatelessWidget {
  final String? message;
  const _Introuvable({this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_off_outlined,
                size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(message ?? 'Dossier introuvable',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/admin/dossiers'),
              child: const Text('Retour à la liste'),
            ),
          ],
        ),
      );
}