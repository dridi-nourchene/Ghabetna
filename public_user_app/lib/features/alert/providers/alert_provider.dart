import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_exception.dart';
import '../data/alert_api.dart';
import '../data/alert_gps.dart';
import '../data/alert_models.dart';

final alertApiProvider = Provider<AlertApi>((ref) => const AlertApi());

// ── Signaler une alerte ─────────────────────────────────────────────────

class SignalerState {
  const SignalerState({
    this.forets = const [],
    this.chargementForets = false,
    this.envoiEnCours = false,
    this.erreur,
    this.succes = false,
  });

  final List<ForestSimple> forets;
  final bool chargementForets;
  final bool envoiEnCours;
  final String? erreur;
  final bool succes;

  SignalerState copyWith({
    List<ForestSimple>? forets,
    bool? chargementForets,
    bool? envoiEnCours,
    String? erreur,
    bool effacerErreur = false,
    bool? succes,
  }) =>
      SignalerState(
        forets: forets ?? this.forets,
        chargementForets: chargementForets ?? this.chargementForets,
        envoiEnCours: envoiEnCours ?? this.envoiEnCours,
        erreur: effacerErreur ? null : (erreur ?? this.erreur),
        succes: succes ?? this.succes,
      );
}

class SignalerNotifier extends StateNotifier<SignalerState> {
  SignalerNotifier(this._api) : super(const SignalerState());
  final AlertApi _api;

  Future<void> chargerForets() async {
    state = state.copyWith(chargementForets: true, effacerErreur: true);
    try {
      final forets = await _api.forets();
      state = state.copyWith(forets: forets, chargementForets: false);
    } on ApiException catch (e) {
      state = state.copyWith(chargementForets: false, erreur: e.message);
    } catch (e) {
      state = state.copyWith(
        chargementForets: false,
        erreur: 'Impossible de charger les forêts.',
      );
    }
  }

  Future<bool> envoyer({
    required AlertType type,
    required String forestId,
    String? description,
    File? photo,
  }) async {
    state = state.copyWith(
      envoiEnCours: true,
      effacerErreur: true,
      succes: false,
    );
    try {
      // Position du téléphone au moment de l'envoi, et GPS de la photo si
      // elle en contient un — même logique à double source qu'agent_app.
      final positionTelephone = await AlertGps.positionTelephone();

      double? incidentLat;
      double? incidentLng;
      if (photo != null) {
        final gps = await AlertGps.depuisPhoto(photo);
        incidentLat = gps?.lat;
        incidentLng = gps?.lng;
      }

      await _api.creer(
        type: type,
        forestId: forestId,
        description: description,
        incidentLat: incidentLat,
        incidentLng: incidentLng,
        agentLat: positionTelephone?.lat,
        agentLng: positionTelephone?.lng,
        photo: photo,
      );

      state = state.copyWith(envoiEnCours: false, succes: true);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(envoiEnCours: false, erreur: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        envoiEnCours: false,
        erreur: 'Le signalement n\'a pas pu être envoyé.',
      );
      return false;
    }
  }
}

final signalerProvider =
    StateNotifierProvider.autoDispose<SignalerNotifier, SignalerState>(
  (ref) => SignalerNotifier(ref.watch(alertApiProvider)),
);

// ── Mes signalements ─────────────────────────────────────────────────────

class MesAlertesState {
  const MesAlertesState({
    this.alertes = const [],
    this.chargement = false,
    this.erreur,
  });

  final List<AlertModel> alertes;
  final bool chargement;
  final String? erreur;

  MesAlertesState copyWith({
    List<AlertModel>? alertes,
    bool? chargement,
    String? erreur,
    bool effacerErreur = false,
  }) =>
      MesAlertesState(
        alertes: alertes ?? this.alertes,
        chargement: chargement ?? this.chargement,
        erreur: effacerErreur ? null : (erreur ?? this.erreur),
      );
}

class MesAlertesNotifier extends StateNotifier<MesAlertesState> {
  MesAlertesNotifier(this._api) : super(const MesAlertesState());
  final AlertApi _api;

  Future<void> charger() async {
    state = state.copyWith(chargement: true, effacerErreur: true);
    try {
      final alertes = await _api.mesAlertes();
      // Plus récent d'abord : c'est le signalement qu'on vient de faire
      // qu'on veut voir en premier, pas celui d'il y a trois mois.
      alertes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = state.copyWith(alertes: alertes, chargement: false);
    } on ApiException catch (e) {
      state = state.copyWith(chargement: false, erreur: e.message);
    } catch (e) {
      state = state.copyWith(
        chargement: false,
        erreur: 'Impossible de charger vos signalements.',
      );
    }
  }
}

final mesAlertesProvider =
    StateNotifierProvider.autoDispose<MesAlertesNotifier, MesAlertesState>(
  (ref) => MesAlertesNotifier(ref.watch(alertApiProvider)),
);
