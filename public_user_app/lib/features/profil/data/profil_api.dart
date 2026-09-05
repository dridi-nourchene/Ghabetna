import '../../../core/api_client.dart';
import '../../../core/api_config.dart';
import 'profil_models.dart';

/// Accès à GET /api/citoyens/mon-dossier via le gateway.
class ProfilApi {
  const ProfilApi({this.client = const ApiClient()});
  final ApiClient client;

  Future<DossierCitoyen> monDossier() async {
    final data = await client.get(ApiConfig.monDossier);
    return DossierCitoyen.fromJson(data);
  }
}
