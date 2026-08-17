import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_exception.dart';
import '../../../core/token_storage.dart';
import '../data/auth_api.dart';
import '../data/auth_models.dart';

enum StatutAuth { inconnu, connecte, deconnecte }

class AuthState {
  const AuthState({
    this.statut = StatutAuth.inconnu,
    this.session,
    this.erreur,
    this.enChargement = false,
  });

  /// inconnu = on n'a pas encore lu le coffre sécurisé. Le routeur laisse
  /// l'écran de démarrage affiché tant qu'on est dans cet état, sinon on
  /// verrait la page de connexion clignoter avant la redirection.
  final StatutAuth statut;
  final Session? session;
  final String? erreur;
  final bool enChargement;

  AuthState copyWith({
    StatutAuth? statut,
    Session? session,
    String? erreur,
    bool effacerErreur = false,
    bool? enChargement,
  }) =>
      AuthState(
        statut: statut ?? this.statut,
        session: session ?? this.session,
        erreur: effacerErreur ? null : (erreur ?? this.erreur),
        enChargement: enChargement ?? this.enChargement,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._api) : super(const AuthState()) {
    _restaurerSession();
  }

  final AuthApi _api;

  // ── Au lancement ────────────────────────────────────────────────────
  Future<void> _restaurerSession() async {
    try {
      final token = await TokenStorage.readToken();

      if (token == null || token.isEmpty) {
        state = state.copyWith(statut: StatutAuth.deconnecte);
        return;
      }

      if (!TokenStorage.estExpire(token)) {
        state = AuthState(
          statut: StatutAuth.connecte,
          session: Session.depuisJwt(token),
        );
        return;
      }

      // Jeton périmé : on tente le renouvellement avant de renvoyer le
      // citoyen sur la connexion. Sans ça, il retaperait son mot de passe
      // toutes les heures.
      final refresh = await TokenStorage.readRefreshToken();
      if (refresh == null || refresh.isEmpty) {
        await _deconnecter();
        return;
      }

      final nouveau = await _api.refresh(refresh);
      await TokenStorage.saveToken(nouveau);
      await _memoriserSpecialite(nouveau);

      state = AuthState(
        statut: StatutAuth.connecte,
        session: Session.depuisJwt(nouveau),
      );
    } catch (_) {
      // Refresh révoqué (compte banni ou rejeté par l'admin) ou coffre
      // illisible : dans les deux cas on repart de zéro.
      await _deconnecter();
    }
  }

  // ── Connexion ───────────────────────────────────────────────────────
  Future<bool> connecter(String email, String motDePasse) async {
    state = state.copyWith(enChargement: true, effacerErreur: true);

    try {
      final jetons = await _api.login(email: email, motDePasse: motDePasse);

      await TokenStorage.saveToken(jetons.accessToken);
      await TokenStorage.saveRefreshToken(jetons.refreshToken);
      await _memoriserSpecialite(jetons.accessToken);

      state = AuthState(
        statut: StatutAuth.connecte,
        session: Session.depuisJwt(jetons.accessToken),
      );
      return true;
    } on ApiException catch (e) {
      // 401 comme 403 arrivent ici. Le message d'auth_ms est déjà destiné à
      // l'utilisateur — « Votre dossier est en cours d'examen » notamment.
      state = state.copyWith(enChargement: false, erreur: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        enChargement: false,
        erreur: 'Connexion impossible. Vérifiez votre réseau.',
      );
      return false;
    }
  }

  Future<void> deconnecter() => _deconnecter();

  Future<void> _deconnecter() async {
    await TokenStorage.clear();
    state = const AuthState(statut: StatutAuth.deconnecte);
  }

  void effacerErreur() => state = state.copyWith(effacerErreur: true);

  /// La spécialité vient du JWT et non plus d'un choix manuel. On la
  /// recopie dans le coffre parce que chat_provider la lit depuis là :
  /// cette ligne suffit à faire disparaître le sélecteur de mode.
  Future<void> _memoriserSpecialite(String token) async {
    final s = TokenStorage.decode(token)['specialite'];
    if (s is String && s.isNotEmpty) {
      await TokenStorage.saveSpecialite(s);
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(const AuthApi()),
);
