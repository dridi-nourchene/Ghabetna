import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_exception.dart';
import '../data/profil_api.dart';
import '../data/profil_models.dart';

final profilApiProvider = Provider<ProfilApi>((ref) => const ProfilApi());

class ProfilState {
  const ProfilState({this.dossier, this.chargement = false, this.erreur});

  final DossierCitoyen? dossier;
  final bool chargement;
  final String? erreur;

  ProfilState copyWith({
    DossierCitoyen? dossier,
    bool? chargement,
    String? erreur,
    bool effacerErreur = false,
  }) =>
      ProfilState(
        dossier: dossier ?? this.dossier,
        chargement: chargement ?? this.chargement,
        erreur: effacerErreur ? null : (erreur ?? this.erreur),
      );
}

class ProfilNotifier extends StateNotifier<ProfilState> {
  ProfilNotifier(this._api) : super(const ProfilState());
  final ProfilApi _api;

  Future<void> charger() async {
    state = state.copyWith(chargement: true, effacerErreur: true);
    try {
      final dossier = await _api.monDossier();
      state = state.copyWith(dossier: dossier, chargement: false);
    } on ApiException catch (e) {
      state = state.copyWith(chargement: false, erreur: e.message);
    } catch (_) {
      state = state.copyWith(
        chargement: false,
        erreur: 'Impossible de charger votre dossier.',
      );
    }
  }
}

final profilProvider = StateNotifierProvider.autoDispose<ProfilNotifier, ProfilState>(
  (ref) => ProfilNotifier(ref.watch(profilApiProvider)),
);
