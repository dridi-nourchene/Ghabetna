// features/dossier/providers/dossier_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:forest_app/features/dossier/models/dossier_model.dart';
import 'package:forest_app/features/dossier/services/dossier_service.dart';
import 'package:forest_app/features/user/models/user_model.dart';
import 'package:forest_app/features/user/services/user_service.dart';

// ═══════════════════════════════════════════════════════════════
//  LISTE DES DOSSIERS
//
//  C'est ici, et uniquement ici, que les deux bases se rencontrent.
//  citizen_ms fournit les dossiers, auth_ms fournit les identités, et
//  le user_id sert de clé. Aucun écran ne sait que l'information vient
//  de deux endroits.
// ═══════════════════════════════════════════════════════════════

class DossierListState {
  final List<DossierCitoyen> dossiers;
  final bool                 isLoading;
  final String?              error;

  const DossierListState({
    this.dossiers  = const [],
    this.isLoading = false,
    this.error,
  });

  DossierListState copyWith({
    List<DossierCitoyen>? dossiers,
    bool?                 isLoading,
    String?               error,
    bool                  clearError = false,
  }) =>
      DossierListState(
        dossiers:  dossiers  ?? this.dossiers,
        isLoading: isLoading ?? this.isLoading,
        error:     clearError ? null : (error ?? this.error),
      );

  // Compteurs des trois cartes en haut de l'écran. Calculés à partir de la
  // liste déjà chargée : aucun appel supplémentaire, et ils restent justes
  // après une décision puisque la liste est rechargée.
  int get nbEnAttente =>
      dossiers.where((d) => d.dossier.statutDossier == 'en_attente').length;
  int get nbApprouves =>
      dossiers.where((d) => d.dossier.statutDossier == 'approuve').length;
  int get nbRejetes =>
      dossiers.where((d) => d.dossier.statutDossier == 'rejete').length;

  /// Applique les trois filtres du tableau.
  ///
  /// Placé sur l'état et non dans l'écran : la règle de recherche vit déjà
  /// dans DossierCitoyen.correspondA, et l'écran n'a pas à savoir quels
  /// champs sont interrogeables.
  ///
  /// Filtrage en mémoire et non côté serveur : la liste complète tient
  /// largement en mémoire, et changer d'onglet devient instantané au lieu
  /// d'attendre un aller-retour réseau.
  List<DossierCitoyen> filtrer({
    String  recherche  = '',
    String? specialite,
    String? statut,
  }) {
    return dossiers.where((d) {
      if (!d.correspondA(recherche)) return false;
      if (specialite != null && d.dossier.specialite != specialite) return false;
      if (statut != null && d.dossier.statutDossier != statut) return false;
      return true;
    }).toList();
  }
}

class DossierListNotifier extends StateNotifier<DossierListState> {
  final _dossiers = DossierService();
  final _users    = UserService();

  DossierListNotifier() : super(const DossierListState());

  Future<void> charger() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Les deux appels partent ensemble. En série, l'admin attendrait deux
      // allers-retours au lieu d'un.
      final resultats = await Future.wait([
        _dossiers.getDossiers(),
        _users.getCitoyens(),
      ]);

      final dossiers = resultats[0] as List<Dossier>;
      final citoyens = resultats[1] as List<AppUser>;

      state = state.copyWith(
        dossiers:  _joindre(dossiers, citoyens),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// La jointure applicative.
  ///
  /// Un index par user_id d'abord, puis un seul parcours des dossiers. Une
  /// recherche linéaire dans la liste des citoyens à chaque dossier ferait
  /// n × m comparaisons — invisible sur vingt lignes, sensible sur mille.
  ///
  /// Un dossier sans citoyen correspondant n'est PAS écarté : il apparaît
  /// avec « Utilisateur introuvable ». C'est une anomalie que l'admin doit
  /// voir, pas une ligne qui s'évapore.
  List<DossierCitoyen> _joindre(
    List<Dossier> dossiers,
    List<AppUser> citoyens,
  ) {
    final parId = {for (final c in citoyens) c.userId: c};

    final joints = dossiers
        .map((d) => DossierCitoyen(dossier: d, citoyen: parId[d.userId]))
        .toList();

    // Le plus récent en haut : l'admin traite la file par ordre d'arrivée
    // inverse. Les dates absentes finissent en bas plutôt que de faire
    // planter la comparaison.
    joints.sort((a, b) {
      final da = a.dossier.soumisLe;
      final db = b.dossier.soumisLe;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });

    return joints;
  }

  void effacerErreur() => state = state.copyWith(clearError: true);
}

final dossierListProvider =
    StateNotifierProvider<DossierListNotifier, DossierListState>(
  (ref) => DossierListNotifier(),
);

/// Compteur pour la pastille de la barre latérale.
///
/// Provider dérivé : il ne déclenche aucun appel, il lit la liste déjà
/// chargée. Vaut 0 tant que l'écran des dossiers n'a pas été ouvert une
/// première fois — à AdminShell de lancer `charger()` s'il veut la pastille
/// dès l'arrivée sur le tableau de bord.
final nbDossiersEnAttenteProvider = Provider<int>(
  (ref) => ref.watch(dossierListProvider).nbEnAttente,
);

// ═══════════════════════════════════════════════════════════════
//  DÉTAIL D'UN DOSSIER
// ═══════════════════════════════════════════════════════════════

class DossierDetailState {
  final Dossier?  dossier;
  final AppUser?  citoyen;
  final bool      isLoading;
  final String?   error;

  /// Vrai pendant l'appel de décision. Les deux boutons s'en servent pour
  /// se désactiver : un double-clic déclencherait un 409 côté serveur.
  final bool      enCoursDeDecision;

  /// Message affiché après une décision réussie, avant la fermeture.
  final String?   succes;

  const DossierDetailState({
    this.dossier,
    this.citoyen,
    this.isLoading         = false,
    this.error,
    this.enCoursDeDecision = false,
    this.succes,
  });

  DossierDetailState copyWith({
    Dossier? dossier,
    AppUser? citoyen,
    bool     effacerCitoyen = false,
    bool?    isLoading,
    String?  error,
    bool     clearError     = false,
    bool?    enCoursDeDecision,
    String?  succes,
    bool     clearSucces    = false,
  }) =>
      DossierDetailState(
        dossier:           dossier ?? this.dossier,
        citoyen:           effacerCitoyen ? null : (citoyen ?? this.citoyen),
        isLoading:         isLoading ?? this.isLoading,
        error:             clearError ? null : (error ?? this.error),
        enCoursDeDecision: enCoursDeDecision ?? this.enCoursDeDecision,
        succes:            clearSucces ? null : (succes ?? this.succes),
      );

  String get nom   => citoyen?.fullName ?? 'Utilisateur introuvable';
  String get cin   => citoyen?.cin      ?? '—';
  String get email => citoyen?.email    ?? '—';

  /// Les boutons ne s'affichent que sur un dossier encore ouvert. Un dossier
  /// déjà tranché se consulte, il ne se retranche pas — decider_dossier
  /// répondrait 409.
  bool get peutDecider =>
      dossier != null && dossier!.estEnAttente && !enCoursDeDecision;
}

class DossierDetailNotifier extends StateNotifier<DossierDetailState> {
  final _dossiers = DossierService();
  final _users    = UserService();
  final String    _profilId;

  DossierDetailNotifier(this._profilId) : super(const DossierDetailState());

  /// Recharge le dossier depuis l'API, même si la liste le contenait déjà.
  ///
  /// Deux raisons. D'abord un collègue a pu trancher entre le chargement de
  /// la liste et le clic. Ensuite, sur le web, l'admin peut arriver
  /// directement sur cette URL — rafraîchissement de page, lien collé — et
  /// la liste est alors vide. L'écran doit se suffire à lui-même.
  Future<void> charger() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final resultats = await Future.wait([
        _dossiers.getDossier(_profilId),
        _users.getCitoyens(),
      ]);

      final dossier  = resultats[0] as Dossier;
      final citoyens = resultats[1] as List<AppUser>;

      // firstWhere sans orElse lève une exception quand rien ne correspond.
      // On veut l'absence, pas l'erreur : un compte supprimé laisse un
      // dossier orphelin, qui doit rester consultable.
      AppUser? citoyen;
      for (final c in citoyens) {
        if (c.userId == dossier.userId) {
          citoyen = c;
          break;
        }
      }

      state = state.copyWith(
        dossier:        dossier,
        citoyen:        citoyen,
        effacerCitoyen: citoyen == null,
        isLoading:      false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Approuve ou rejette. Renvoie true si la décision est passée.
  ///
  /// L'écran se sert du booléen pour recharger la liste et fermer la page.
  /// Le notifier ne touche pas lui-même au provider de liste : il faudrait
  /// lui passer un Ref, qui peut survivre à la page et poser des problèmes
  /// de cycle de vie. Ton assignment_provider procède déjà comme ça.
  Future<bool> decider({required bool approuve, String? motif}) async {
    state = state.copyWith(
      enCoursDeDecision: true,
      clearError: true,
      clearSucces: true,
    );

    try {
      final maj = await _dossiers.decider(
        profilId:   _profilId,
        approuve:   approuve,
        motifRejet: motif,
      );

      state = state.copyWith(
        dossier:           maj,
        enCoursDeDecision: false,
        succes: approuve
            ? 'Dossier approuvé, le compte est activé'
            : 'Dossier rejeté, le citoyen sera informé du motif',
      );
      return true;
    } on DossierException catch (e) {
      // 409 : quelqu'un est passé avant nous. Ce n'est pas une panne, c'est
      // une course. On recharge pour montrer la décision réelle plutôt que
      // d'afficher une erreur devant un écran devenu faux.
      if (e.dejaTraite) {
        await charger();
        state = state.copyWith(
          enCoursDeDecision: false,
          error: 'Ce dossier vient d\'être traité par quelqu\'un d\'autre',
        );
        return false;
      }

      // 503 : citizen_ms n'a pas pu joindre auth_ms. Rien n'a été enregistré,
      // le dossier est toujours en attente. Réessayer est sans danger.
      state = state.copyWith(
        enCoursDeDecision: false,
        error: e.authIndisponible
            ? 'Service d\'authentification injoignable, rien n\'a été enregistré. Réessayez.'
            : e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        enCoursDeDecision: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  void effacerMessages() =>
      state = state.copyWith(clearError: true, clearSucces: true);
}

/// Un notifier par dossier consulté.
///
/// `.family` plutôt qu'un provider unique : deux dossiers ouverts l'un après
/// l'autre ne doivent pas se partager un état. `.autoDispose` pour que la
/// fermeture de la page libère le tout — sans quoi chaque dossier consulté
/// resterait en mémoire jusqu'à la déconnexion.
final dossierDetailProvider = StateNotifierProvider.autoDispose
    .family<DossierDetailNotifier, DossierDetailState, String>(
  (ref, profilId) => DossierDetailNotifier(profilId),
);
