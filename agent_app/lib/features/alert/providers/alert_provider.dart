import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_app/features/alert/models/alert_model.dart';
import 'package:agent_app/features/alert/services/alert_service.dart';

// ── State déclaration alerte ──────────────────────────────────

class CreateAlertState {
  final List<ForestSimple> forests;
  final bool               isLoadingForests;
  final bool               isSubmitting;
  final String?            error;
  final bool               success;

  const CreateAlertState({
    this.forests         = const [],
    this.isLoadingForests = false,
    this.isSubmitting    = false,
    this.error,
    this.success         = false,
  });

  CreateAlertState copyWith({
    List<ForestSimple>? forests,
    bool?               isLoadingForests,
    bool?               isSubmitting,
    String?             error,
    bool                clearError = false,
    bool?               success,
  }) =>
      CreateAlertState(
        forests:          forests          ?? this.forests,
        isLoadingForests: isLoadingForests ?? this.isLoadingForests,
        isSubmitting:     isSubmitting     ?? this.isSubmitting,
        error:            clearError       ? null : (error ?? this.error),
        success:          success          ?? this.success,
      );
}

class CreateAlertNotifier extends StateNotifier<CreateAlertState> {
  final _service = AlertService();

  CreateAlertNotifier() : super(const CreateAlertState());

  Future<void> loadForests() async {
    state = state.copyWith(isLoadingForests: true, clearError: true);
    try {
      final forests = await _service.getForests();
      state = state.copyWith(forests: forests, isLoadingForests: false);
    } catch (e) {
      state = state.copyWith(
        isLoadingForests: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<bool> submitAlert({
    required AlertType   type,
    required String      forestId,
    String?              description,
    File?                imageFile,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true, success: false);

    try {
      // Extraire GPS depuis l'image
      double? lat, lng;
      if (imageFile != null) {
        final gps = await AlertService.extractGpsFromImage(imageFile);
        if (gps != null) {
          lat = gps.lat;
          lng = gps.lng;
          print('[EXIF] GPS extrait : $lat, $lng');
        } else {
          print('[EXIF] Pas de GPS dans l\'image — fallback centroïde forêt');
        }
      }

      await _service.createAlert(
        type:        type,
        forestId:    forestId,
        description: description,
        latitude:    lat,
        longitude:   lng,
        imageFile:   imageFile,
      );

      state = state.copyWith(isSubmitting: false, success: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  void reset() => state = const CreateAlertState();
}

final createAlertProvider =
    StateNotifierProvider<CreateAlertNotifier, CreateAlertState>(
  (ref) => CreateAlertNotifier(),
);

// ── State liste mes alertes ───────────────────────────────────

class MyAlertsState {
  final List<AlertModel> alerts;
  final bool             isLoading;
  final String?          error;

  const MyAlertsState({
    this.alerts    = const [],
    this.isLoading = false,
    this.error,
  });

  MyAlertsState copyWith({
    List<AlertModel>? alerts,
    bool?             isLoading,
    String?           error,
    bool              clearError = false,
  }) =>
      MyAlertsState(
        alerts:    alerts    ?? this.alerts,
        isLoading: isLoading ?? this.isLoading,
        error:     clearError ? null : (error ?? this.error),
      );
}

class MyAlertsNotifier extends StateNotifier<MyAlertsState> {
  final _service = AlertService();

  MyAlertsNotifier() : super(const MyAlertsState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final alerts = await _service.getMyAlerts();
      state = state.copyWith(alerts: alerts, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }
}

final myAlertsProvider =
    StateNotifierProvider<MyAlertsNotifier, MyAlertsState>(
  (ref) => MyAlertsNotifier(),
);