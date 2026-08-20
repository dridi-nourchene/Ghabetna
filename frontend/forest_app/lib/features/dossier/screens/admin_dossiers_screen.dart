// features/dossier/screens/admin_dossiers_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:forest_app/core/theme/app_colors.dart';
import 'package:forest_app/core/widgets/app_card.dart';
import 'package:forest_app/features/dossier/models/dossier_model.dart';
import 'package:forest_app/features/dossier/providers/dossier_provider.dart';

/// Icône d'une spécialité.
///
/// UN SEUL ENDROIT POUR LES CHANGER. Pour passer à tes propres images,
/// remplace les trois Icon par :
///
///   Image.asset('assets/icons/chasseur.png', width: 18, height: 18)
///
/// et rien d'autre ne bouge : ni le tableau, ni l'écran de détail.
Widget iconeSpecialite(String specialite, {double taille = 18}) =>
    switch (specialite) {
      'chasseur'   => Icon(Icons.gps_fixed,
          size: taille, color: AppColors.textSecondary),
      'apiculteur' => Icon(Icons.hive_outlined,
          size: taille, color: AppColors.textSecondary),
      'campeur'    => Icon(Icons.festival_outlined,
          size: taille, color: AppColors.textSecondary),
      _            => Icon(Icons.person_outline,
          size: taille, color: AppColors.textSecondary),
    };

/// Pilule de statut d'un dossier.
///
/// Construite sur les StatusPill de app_card.dart pour que les dossiers
/// aient exactement la même apparence que les utilisateurs ailleurs dans
/// l'administration.
StatusPill pilluleStatut(String statut) => switch (statut) {
      'en_attente' => StatusPill.pending(),
      'approuve'   => const StatusPill(
          label: 'Approuvé', bg: AppColors.successBg, fg: AppColors.primaryMid),
      'rejete'     => const StatusPill(
          label: 'Rejeté', bg: AppColors.dangerBg, fg: AppColors.danger),
      _            => StatusPill(
          label: statut, bg: AppColors.bgInput, fg: AppColors.textSecondary),
    };

String jjmmaaaa(DateTime? d) => d == null
    ? '—'
    : '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';

// ═══════════════════════════════════════════════════════════════
//  ÉCRAN
// ═══════════════════════════════════════════════════════════════

class AdminDossiersScreen extends ConsumerStatefulWidget {
  const AdminDossiersScreen({super.key});

  @override
  ConsumerState<AdminDossiersScreen> createState() =>
      _AdminDossiersScreenState();
}

class _AdminDossiersScreenState extends ConsumerState<AdminDossiersScreen> {
  String  _recherche  = '';
  String? _specialite;

  // Démarre sur la file de travail et non sur « tous ». Cet écran sert à
  // TRAITER des dossiers : ce que l'admin veut voir en arrivant, ce sont
  // ceux qui attendent une décision. Les autres restent à un clic.
  String? _statut = 'en_attente';

  @override
  void initState() {
    super.initState();
    // Après la première frame : modifier un provider pendant le build
    // déclencherait une exception Riverpod.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dossierListProvider.notifier).charger();
    });
  }

  @override
  Widget build(BuildContext context) {
    final etat = ref.watch(dossierListProvider);

    ref.listen(dossierListProvider, (_, next) {
      if (next.error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.error!),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
        ref.read(dossierListProvider.notifier).effacerErreur();
      }
    });

    final visibles = etat.filtrer(
      recherche:  _recherche,
      specialite: _specialite,
      statut:     _statut,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête ──────────────────────────────────
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dossiers citoyens',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3)),
              SizedBox(height: 3),
              Text('Approuvez ou rejetez les inscriptions du public.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 20),

          // ── Compteurs ────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _Compteur(
                  label: 'En attente',
                  valeur: etat.nbEnAttente,
                  icone: Icons.schedule,
                  fond: AppColors.warningBg,
                  encre: const Color(0xFF92400E),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _Compteur(
                  label: 'Approuvés',
                  valeur: etat.nbApprouves,
                  icone: Icons.check_circle_outline,
                  fond: AppColors.successBg,
                  encre: AppColors.primaryMid,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _Compteur(
                  label: 'Rejetés',
                  valeur: etat.nbRejetes,
                  icone: Icons.cancel_outlined,
                  fond: AppColors.dangerBg,
                  encre: AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── Filtres ──────────────────────────────────
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Recherche(
                        onChanged: (v) => setState(() => _recherche = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _Filtre(
                      valeur: _specialite,
                      libelleTous: 'Toutes spécialités',
                      options: const {
                        'chasseur':   'Chasseur',
                        'apiculteur': 'Apiculteur',
                        'campeur':    'Campeur',
                      },
                      onChanged: (v) => setState(() => _specialite = v),
                      largeur: 150,
                    ),
                    const SizedBox(width: 10),
                    _Filtre(
                      valeur: _statut,
                      libelleTous: 'Tous les statuts',
                      options: const {
                        'en_attente': 'En attente',
                        'approuve':   'Approuvé',
                        'rejete':     'Rejeté',
                      },
                      onChanged: (v) => setState(() => _statut = v),
                      largeur: 145,
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: etat.isLoading
                          ? null
                          : () =>
                              ref.read(dossierListProvider.notifier).charger(),
                      icon: const Icon(Icons.refresh, size: 18),
                      color: AppColors.textSecondary,
                      tooltip: 'Rafraîchir',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${visibles.length} dossier${visibles.length > 1 ? 's' : ''}'
                  ' · ${etat.nbEnAttente} en attente de décision',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Tableau ──────────────────────────────────
          AppCard(
            padding: EdgeInsets.zero,
            child: etat.isLoading && etat.dossiers.isEmpty
                ? const _Chargement()
                : visibles.isEmpty
                    ? const _Vide()
                    : _Tableau(dossiers: visibles),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  COMPTEUR
// ═══════════════════════════════════════════════════════════════

class _Compteur extends StatelessWidget {
  final String    label;
  final int       valeur;
  final IconData  icone;
  final Color     fond;
  final Color     encre;

  const _Compteur({
    required this.label,
    required this.valeur,
    required this.icone,
    required this.fond,
    required this.encre,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(12),
        // Les AppCard de l'administration sont plates. L'ombre isole ce
        // bandeau de synthèse du reste de la page, comme un bloc à part.
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 15, color: encre),
              const SizedBox(width: 7),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: encre)),
            ],
          ),
          const SizedBox(height: 6),
          Text('$valeur',
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w700, color: encre)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  FILTRES
// ═══════════════════════════════════════════════════════════════

class _Recherche extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _Recherche({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Nom, CIN ou email',
        hintStyle:
            const TextStyle(fontSize: 13, color: AppColors.textMuted),
        prefixIcon:
            const Icon(Icons.search, size: 17, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.bgInput,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: AppColors.primaryMid, width: 1),
        ),
      ),
    );
  }
}

/// Menu déroulant à valeur nullable : null signifie « tous ».
class _Filtre extends StatelessWidget {
  final String?               valeur;
  final String                libelleTous;
  final Map<String, String>   options;
  final ValueChanged<String?> onChanged;
  final double                largeur;

  const _Filtre({
    required this.valeur,
    required this.libelleTous,
    required this.options,
    required this.onChanged,
    required this.largeur,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: largeur,
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: valeur,
          isExpanded: true,
          isDense: true,
          icon: const Icon(Icons.expand_more,
              size: 18, color: AppColors.textMuted),
          style:
              const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          dropdownColor: AppColors.bgCard,
          borderRadius: BorderRadius.circular(8),
          onChanged: onChanged,
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(libelleTous,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ),
            ...options.entries.map(
              (e) => DropdownMenuItem<String?>(
                value: e.key,
                child: Text(e.value, style: const TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  TABLEAU
// ═══════════════════════════════════════════════════════════════

class _Tableau extends StatelessWidget {
  final List<DossierCitoyen> dossiers;
  const _Tableau({required this.dossiers});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _EnTete(),
        for (final d in dossiers) _Ligne(dossier: d),
      ],
    );
  }
}

class _EnTete extends StatelessWidget {
  const _EnTete();

  // Noir et 12.5 plutôt que gris et 11 : l'en-tête doit se lire d'un coup
  // d'œil, c'est lui qui indique ce que contient chaque colonne.
  static const _style = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: 0.2,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        border: Border(
            bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: const Row(
        children: [
          // Seule colonne alignée à gauche : elle porte une icône et deux
          // lignes de texte de longueurs très variables. Centrée, chaque nom
          // démarrerait à une abscisse différente et l'œil n'aurait plus de
          // ligne verticale à suivre pour balayer la liste.
          Expanded(flex: 4, child: Text('Nom complet', style: _style)),
          Expanded(
              flex: 2,
              child: Text('CIN',
                  style: _style, textAlign: TextAlign.center)),
          Expanded(
              flex: 3,
              child: Text('Email',
                  style: _style, textAlign: TextAlign.center)),
          Expanded(
              flex: 2,
              child: Text('Spécialité',
                  style: _style, textAlign: TextAlign.center)),
          Expanded(
              flex: 2,
              child: Text('Statut',
                  style: _style, textAlign: TextAlign.center)),
          SizedBox(width: 90),
        ],
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  final DossierCitoyen dossier;
  const _Ligne({required this.dossier});

  @override
  Widget build(BuildContext context) {
    final d = dossier.dossier;
    final traite = !d.estEnAttente;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: AppColors.borderLight, width: 0.5)),
      ),
      child: Row(
        children: [
          // ── Nom + date ──────────────────────────────
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.bgInput,
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: Center(child: iconeSpecialite(d.specialite)),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dossier.nom,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          // Un dossier orphelin — compte supprimé mais
                          // dossier encore là — reste visible, en rouge.
                          // C'est une anomalie que l'admin doit remarquer.
                          color: dossier.citoyenIntrouvable
                              ? AppColors.danger
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        traite
                            ? 'Traité le ${jjmmaaaa(d.traiteLe)}'
                            : 'Soumis le ${jjmmaaaa(d.soumisLe)}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            flex: 2,
            child: Text(dossier.cin,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            flex: 3,
            child: Text(dossier.email,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            flex: 2,
            child: Text(d.specialiteLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            flex: 2,
            child: Center(child: pilluleStatut(d.statutDossier)),
          ),

          // ── Action ───────────────────────────────────
          SizedBox(
            width: 90,
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                // Navigation par profil_id et non par user_id : c'est la clé
                // qu'attendent les trois routes de citizen_ms.
                onPressed: () =>
                    context.go('/admin/dossiers/${d.profilId}'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(
                      color: AppColors.border, width: 0.8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Détail',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  ÉTATS
// ═══════════════════════════════════════════════════════════════

class _Chargement extends StatelessWidget {
  const _Chargement();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(
                  color: AppColors.primaryMid, strokeWidth: 2.5),
              SizedBox(height: 16),
              Text('Chargement des dossiers...',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textMuted)),
            ],
          ),
        ),
      );
}

class _Vide extends StatelessWidget {
  const _Vide();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.folder_open_outlined,
                  size: 40, color: AppColors.textMuted),
              SizedBox(height: 12),
              Text('Aucun dossier trouvé',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              SizedBox(height: 4),
              Text('Essayez de modifier vos filtres.',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
        ),
      );
}
