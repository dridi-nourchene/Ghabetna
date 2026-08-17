import '../../../core/api_client.dart';
import '../../../core/api_config.dart';
import '../../../core/fichier_joint.dart';
import 'auth_models.dart';

/// Accès aux routes d'authentification et d'inscription via le gateway.
///
/// L'application n'appelle jamais un microservice directement : le gateway
/// est le seul point d'entrée exposé.
class AuthApi {
  const AuthApi({this.client = const ApiClient()});
  final ApiClient client;

  /// Peut lever une ApiException :
  ///   401 → email ou mot de passe incorrect
  ///   403 → dossier en cours d'examen, refusé, ou compte suspendu
  ///
  /// Le message du 403 vient tel quel d'auth_ms et il est déjà rédigé pour
  /// le citoyen : on l'affiche sans le réécrire côté client, sinon les deux
  /// textes divergeront au premier changement.
  Future<Jetons> login({
    required String email,
    required String motDePasse,
  }) async {
    final data = await client.post(
      ApiConfig.login,
      body: {'email': email, 'password': motDePasse},
    );
    return Jetons.fromJson(data);
  }

  /// Renouvelle l'access token. Le refresh est à usage unique : auth_ms
  /// révoque l'ancien à chaque appel (rotation).
  Future<String> refresh(String refreshToken) async {
    final data = await client.post(
      ApiConfig.refresh,
      body: {'refresh_token': refreshToken},
    );
    return data['access_token'] as String? ?? '';
  }

  /// Inscription : un seul envoi contenant les champs ET les documents.
  ///
  /// Route publique — le citoyen n'a pas encore de compte, donc pas de
  /// jeton. Elle est déclarée dans PUBLIC_ROUTES du gateway.
  ///
  /// Codes d'erreur remontés par citizen_ms :
  ///   409 → CIN ou email déjà utilisé (le citoyen doit corriger)
  ///   400 → document manquant ou champ métier absent
  ///   503 → auth_ms indisponible (réessayer plus tard)
  ///
  /// Renvoie profil_id, user_id et statut_dossier.
  Future<Map<String, dynamic>> inscrire({
    required Map<String, String> champs,
    required Map<String, FichierJoint> documents,
  }) {
    return client.postMultipart(
      ApiConfig.inscription,
      champs: champs,
      fichiers: documents,
    );
  }
}
