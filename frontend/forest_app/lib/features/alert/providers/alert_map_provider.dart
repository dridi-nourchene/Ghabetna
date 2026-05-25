// frontend/forest_app/lib/features/alert/providers/alert_map_provider.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/alert_map_model.dart';
import '../repositories/alert_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants.dart';

// ── Repository provider ───────────────────────────────────────

final alertRepositoryProvider = Provider<AlertRepository>((ref) {
  final auth = ref.watch(authProvider);
  return AlertRepository(
    baseUrl:  ApiConfig.baseUrl,
    getToken: () => auth.accessToken ?? '',
  );
});


// ═══════════════════════════════════════════════════════════════
//  MAP STATE — polling toutes les 30s
// ═══════════════════════════════════════════════════════════════

class SupervisorMapState {
  final List<AlertMapPoint> points;
  final bool                isLoading;
  final String?             error;
  final DateTime?           lastRefresh;

  const SupervisorMapState({
    this.points      = const [],
    this.isLoading   = false,
    this.error,
    this.lastRefresh,
  });

  SupervisorMapState copyWith({
    List<AlertMapPoint>? points,
    bool?                isLoading,
    String?              error,
    DateTime?            lastRefresh,
    bool                 clearError = false,
  }) =>
      SupervisorMapState(
        points:      points      ?? this.points,
        isLoading:   isLoading   ?? this.isLoading,
        error:       clearError  ? null : (error ?? this.error),
        lastRefresh: lastRefresh ?? this.lastRefresh,
      );
}

class SupervisorMapNotifier extends StateNotifier<SupervisorMapState> {
  final AlertRepository _repo;
  Timer? _timer;

  SupervisorMapNotifier(this._repo) : super(const SupervisorMapState());

  void startPolling() {
    // ← Annuler l'éventuel timer précédent avant d'en créer un nouveau
    _timer?.cancel();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _fetch());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refreshNow() => _fetch();

  Future<void> _fetch() async {
    // ← Guard : si le notifier est déjà dispose, on ne fait rien
    if (!mounted) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final points = await _repo.getSupervisorMapPoints();

      // ← Guard après l'await : la navigation peut avoir eu lieu pendant l'appel réseau
      if (!mounted) return;

      state = state.copyWith(
        points:      points,
        isLoading:   false,
        lastRefresh: DateTime.now(),
      );
    } catch (e) {
      // ← Guard après l'await dans le catch aussi
      if (!mounted) return;

      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}

final alertMapProvider =
    StateNotifierProvider<SupervisorMapNotifier, SupervisorMapState>((ref) {
  final repo = ref.watch(alertRepositoryProvider);
  return SupervisorMapNotifier(repo);
});


// ═══════════════════════════════════════════════════════════════
//  HISTORIQUE STATE
// ═══════════════════════════════════════════════════════════════

class HistoriqueState {
  final List<AlertDetail> alerts;
  final bool              isLoading;
  final String?           error;
  final String?           filterStatus;

  const HistoriqueState({
    this.alerts       = const [],
    this.isLoading    = false,
    this.error,
    this.filterStatus,
  });

  HistoriqueState copyWith({
    List<AlertDetail>? alerts,
    bool?              isLoading,
    String?            error,
    String?            filterStatus,
    bool               clearError  = false,
    bool               clearFilter = false,
  }) =>
      HistoriqueState(
        alerts:       alerts       ?? this.alerts,
        isLoading:    isLoading    ?? this.isLoading,
        error:        clearError   ? null : (error ?? this.error),
        filterStatus: clearFilter  ? null : (filterStatus ?? this.filterStatus),
      );
}

class HistoriqueNotifier extends StateNotifier<HistoriqueState> {
  final AlertRepository _repo;

  HistoriqueNotifier(this._repo) : super(const HistoriqueState());

  Future<void> load({String? status}) async {
    if (!mounted) return; // ← Guard

    state = state.copyWith(isLoading: true, clearError: true, filterStatus: status);
    try {
      final alerts = await _repo.getSupervisorAlerts(status: status);

      if (!mounted) return; // ← Guard après await

      state = state.copyWith(alerts: alerts, isLoading: false);
    } catch (e) {
      if (!mounted) return; // ← Guard après await dans catch

      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setFilter(String? status) => load(status: status);

  void clearError() {
    if (!mounted) return;
    state = state.copyWith(clearError: true);
  }
}

final historiqueProvider =
    StateNotifierProvider<HistoriqueNotifier, HistoriqueState>((ref) {
  final repo = ref.watch(alertRepositoryProvider);
  return HistoriqueNotifier(repo);
});


// ═══════════════════════════════════════════════════════════════
//  ALERT DETAIL STATE
// ═══════════════════════════════════════════════════════════════

class AlertDetailState {
  final AlertDetail? alert;
  final bool         isLoading;
  final bool         isUpdating;
  final String?      error;

  const AlertDetailState({
    this.alert,
    this.isLoading  = false,
    this.isUpdating = false,
    this.error,
  });

  AlertDetailState copyWith({
    AlertDetail? alert,
    bool?        isLoading,
    bool?        isUpdating,
    String?      error,
    bool         clearError = false,
  }) =>
      AlertDetailState(
        alert:      alert      ?? this.alert,
        isLoading:  isLoading  ?? this.isLoading,
        isUpdating: isUpdating ?? this.isUpdating,
        error:      clearError ? null : (error ?? this.error),
      );
}

class AlertDetailNotifier extends StateNotifier<AlertDetailState> {
  final AlertRepository _repo;

  AlertDetailNotifier(this._repo) : super(const AlertDetailState());

  Future<void> loadAlert(String alertId) async {
    if (!mounted) return; // ← Guard

    state = const AlertDetailState(isLoading: true);
    try {
      final alert = await _repo.getAlertById(alertId);

      if (!mounted) return; // ← Guard après await

      state = AlertDetailState(alert: alert);
    } catch (e) {
      if (!mounted) return; // ← Guard après await dans catch

      state = AlertDetailState(error: e.toString());
    }
  }

  Future<bool> updateStatus({
    required String alertId,
    required String status,
    String?         comment,
  }) async {
    if (!mounted) return false; // ← Guard

    state = state.copyWith(isUpdating: true);
    try {
      final updated = await _repo.updateStatus(
        alertId:           alertId,
        status:            status,
        supervisorComment: comment,
      );

      if (!mounted) return false; // ← Guard après await

      state = state.copyWith(alert: updated, isUpdating: false);
      return true;
    } catch (e) {
      if (!mounted) return false; // ← Guard après await dans catch

      state = state.copyWith(isUpdating: false, error: e.toString());
      return false;
    }
  }

  void clear() {
    if (!mounted) return;
    state = const AlertDetailState();
  }

  void clearError() {
    if (!mounted) return;
    state = state.copyWith(clearError: true);
  }
}

final alertDetailProvider =
    StateNotifierProvider<AlertDetailNotifier, AlertDetailState>((ref) {
  final repo = ref.watch(alertRepositoryProvider);
  return AlertDetailNotifier(repo);
});