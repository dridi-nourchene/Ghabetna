// features/alert/providers/alert_map_provider.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forest_app/features/alert/models/alert_map_model.dart';
import 'package:forest_app/features/alert/services/alert_map_service.dart';

// ── State map alertes ─────────────────────────────────────────

class AlertMapState {
  final List<AlertMapPoint> points;
  final bool                isLoading;
  final String?             error;
  final DateTime?           lastRefresh;

  const AlertMapState({
    this.points      = const [],
    this.isLoading   = false,
    this.error,
    this.lastRefresh,
  });

  AlertMapState copyWith({
    List<AlertMapPoint>? points,
    bool?                isLoading,
    String?              error,
    bool                 clearError = false,
    DateTime?            lastRefresh,
  }) =>
      AlertMapState(
        points:      points      ?? this.points,
        isLoading:   isLoading   ?? this.isLoading,
        error:       clearError  ? null : (error ?? this.error),
        lastRefresh: lastRefresh ?? this.lastRefresh,
      );
}

class AlertMapNotifier extends StateNotifier<AlertMapState> {
  final _service = AlertMapService();
  Timer? _pollingTimer;

  AlertMapNotifier() : super(const AlertMapState());

  // ── Démarrer le polling ───────────────────────────────────

  void startPolling() {
    // Charger immédiatement
    _fetch();
    // Puis toutes les 30 secondes
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetch(),
    );
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> refreshNow() => _fetch();

  Future<void> _fetch() async {
    // Si premier chargement → afficher spinner
    // Si refresh → pas de spinner (silencieux)
    if (state.points.isEmpty) {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    try {
      final points = await _service.getMapPoints();
      state = state.copyWith(
        points:      points,
        isLoading:   false,
        clearError:  true,
        lastRefresh: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error:     e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}

final alertMapProvider =
    StateNotifierProvider<AlertMapNotifier, AlertMapState>(
  (ref) => AlertMapNotifier(),
);

// ── State détail alerte (popup) ───────────────────────────────

class AlertDetailState {
  final AlertDetail? alert;
  final bool         isLoading;
  final bool         isUpdating;
  final String?      error;
  final String?      successMessage;

  const AlertDetailState({
    this.alert,
    this.isLoading   = false,
    this.isUpdating  = false,
    this.error,
    this.successMessage,
  });

  AlertDetailState copyWith({
    AlertDetail? alert,
    bool?        isLoading,
    bool?        isUpdating,
    String?      error,
    bool         clearError   = false,
    String?      successMessage,
    bool         clearSuccess = false,
  }) =>
      AlertDetailState(
        alert:          alert          ?? this.alert,
        isLoading:      isLoading      ?? this.isLoading,
        isUpdating:     isUpdating     ?? this.isUpdating,
        error:          clearError     ? null : (error ?? this.error),
        successMessage: clearSuccess   ? null : (successMessage ?? this.successMessage),
      );
}

class AlertDetailNotifier extends StateNotifier<AlertDetailState> {
  final _service = AlertMapService();

  AlertDetailNotifier() : super(const AlertDetailState());

  Future<void> loadAlert(String alertId) async {
    state = const AlertDetailState(isLoading: true);
    try {
      final alert = await _service.getAlertDetail(alertId);
      state = state.copyWith(alert: alert, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error:     e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<bool> updateStatus({
    required String alertId,
    required String status,
    String?         comment,
  }) async {
    state = state.copyWith(isUpdating: true, clearError: true);
    try {
      final updated = await _service.updateAlertStatus(
        alertId:      alertId,
        status:       status,
        adminComment: comment,
      );
      state = state.copyWith(
        alert:         updated,
        isUpdating:    false,
        successMessage: 'Statut mis à jour avec succès',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isUpdating: false,
        error:      e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  void clear() => state = const AlertDetailState();
}

final alertDetailProvider =
    StateNotifierProvider<AlertDetailNotifier, AlertDetailState>(
  (ref) => AlertDetailNotifier(),
);