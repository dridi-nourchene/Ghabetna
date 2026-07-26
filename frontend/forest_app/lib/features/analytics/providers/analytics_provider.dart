import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/analytics_models.dart';
import '../services/analytics_service.dart';

final analyticsServiceProvider = Provider<AnalyticsService>((ref) => AnalyticsService());

// ── Filtres globaux (Forest▾ / Type▾ / Period▾) ───────────
final analyticsFiltersProvider =
    StateProvider<AnalyticsFilters>((ref) => const AnalyticsFilters());

// ── Top-N sélecteur du bar chart (5/10/20) ────────────────
final alertsByForestLimitProvider = StateProvider<int>((ref) => 10);

// ── Générique : état loading/data/error ───────────────────
class AsyncSection<T> {
  final T?      data;
  final bool    isLoading;
  final String? error;

  const AsyncSection({this.data, this.isLoading = false, this.error});

  AsyncSection<T> copyWith({T? data, bool? isLoading, String? error, bool clearError = false}) =>
      AsyncSection<T>(
        data:      data      ?? this.data,
        isLoading: isLoading ?? this.isLoading,
        error:     clearError ? null : (error ?? this.error),
      );
}

// ── §1 Overview ────────────────────────────────────────────
class OverviewNotifier extends StateNotifier<AsyncSection<OverviewData>> {
  final AnalyticsService _service;
  OverviewNotifier(this._service) : super(const AsyncSection());

  Future<void> load(AnalyticsFilters filters) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _service.getOverview(filters);
      state = AsyncSection(data: data);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final overviewProvider =
    StateNotifierProvider<OverviewNotifier, AsyncSection<OverviewData>>((ref) {
  final notifier = OverviewNotifier(ref.watch(analyticsServiceProvider));
  notifier.load(ref.watch(analyticsFiltersProvider));
  return notifier;
});

// ── §2 Alerts by forest ────────────────────────────────────
class AlertsByForestNotifier extends StateNotifier<AsyncSection<AlertsByForestData>> {
  final AnalyticsService _service;
  AlertsByForestNotifier(this._service) : super(const AsyncSection());

  Future<void> load(AnalyticsFilters filters, int limit) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _service.getAlertsByForest(filters, limit: limit);
      state = AsyncSection(data: data);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final alertsByForestProvider =
    StateNotifierProvider<AlertsByForestNotifier, AsyncSection<AlertsByForestData>>((ref) {
  final notifier = AlertsByForestNotifier(ref.watch(analyticsServiceProvider));
  notifier.load(ref.watch(analyticsFiltersProvider), ref.watch(alertsByForestLimitProvider));
  return notifier;
});

// ── §3 Status trend ────────────────────────────────────────
class StatusTrendNotifier extends StateNotifier<AsyncSection<List<StatusTrendPoint>>> {
  final AnalyticsService _service;
  StatusTrendNotifier(this._service) : super(const AsyncSection());

  Future<void> load(AnalyticsFilters filters) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _service.getStatusTrend(filters);
      state = AsyncSection(data: data);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final statusTrendProvider =
    StateNotifierProvider<StatusTrendNotifier, AsyncSection<List<StatusTrendPoint>>>((ref) {
  final notifier = StatusTrendNotifier(ref.watch(analyticsServiceProvider));
  notifier.load(ref.watch(analyticsFiltersProvider));
  return notifier;
});

// ── §4 Matrix ───────────────────────────────────────────────
class MatrixNotifier extends StateNotifier<AsyncSection<List<ForestTypeMatrixRow>>> {
  final AnalyticsService _service;
  MatrixNotifier(this._service) : super(const AsyncSection());

  Future<void> load(AnalyticsFilters filters) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _service.getForestTypeMatrix(filters);
      state = AsyncSection(data: data);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final matrixProvider =
    StateNotifierProvider<MatrixNotifier, AsyncSection<List<ForestTypeMatrixRow>>>((ref) {
  final notifier = MatrixNotifier(ref.watch(analyticsServiceProvider));
  notifier.load(ref.watch(analyticsFiltersProvider));
  return notifier;
});

// Filtre texte de recherche pour la matrice (local, pas de re-fetch)
final matrixSearchProvider = StateProvider<String>((ref) => '');

// ── §5 Top agents ───────────────────────────────────────────
final topAgentsValidationProvider =
    FutureProvider.autoDispose<List<TopAgentValidation>>((ref) {
  return ref.watch(analyticsServiceProvider).getTopAgentsValidation();
});

final topAgentsRejectionProvider =
    FutureProvider.autoDispose<List<TopAgentRejection>>((ref) {
  return ref.watch(analyticsServiceProvider).getTopAgentsRejection();
});

// ── §6 Supervisor workload ──────────────────────────────────
final supervisorWorkloadProvider =
    FutureProvider.autoDispose<SupervisorWorkloadData>((ref) {
  return ref.watch(analyticsServiceProvider).getSupervisorWorkload();
});

// ── Onglet actif de l'écran ──────────────────────────────────
final analyticsTabProvider = StateProvider<int>((ref) => 0);