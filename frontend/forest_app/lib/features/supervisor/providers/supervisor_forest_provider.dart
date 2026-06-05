import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forest_app/features/forest/models/forest_model.dart';
import 'package:forest_app/features/forest/services/forest_service.dart';
import 'package:forest_app/features/auth/providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────
//  STATE
// ─────────────────────────────────────────────────────────────

class SupervisorForestState {
  final List<Forest>                  forests;
  final Map<String, List<Parcelle>>   parcellesByForest;
  final Set<String>                   loadingParcelleIds;
  final bool                          isLoading;
  final String?                       error;

  const SupervisorForestState({
    this.forests            = const [],
    this.parcellesByForest  = const {},
    this.loadingParcelleIds = const {},
    this.isLoading          = false,
    this.error,
  });

  List<Parcelle> parcellesFor(String forestId) =>
      parcellesByForest[forestId] ?? [];

  SupervisorForestState copyWith({
    List<Forest>?               forests,
    Map<String, List<Parcelle>>? parcellesByForest,
    Set<String>?                loadingParcelleIds,
    bool?                       isLoading,
    String?                     error,
    bool                        clearError = false,
  }) =>
      SupervisorForestState(
        forests:            forests            ?? this.forests,
        parcellesByForest:  parcellesByForest  ?? this.parcellesByForest,
        loadingParcelleIds: loadingParcelleIds ?? this.loadingParcelleIds,
        isLoading:          isLoading          ?? this.isLoading,
        error:              clearError ? null : (error ?? this.error),
      );
}

// ─────────────────────────────────────────────────────────────
//  NOTIFIER
// ─────────────────────────────────────────────────────────────

class SupervisorForestNotifier extends StateNotifier<SupervisorForestState> {
  final ForestService _service;
  final String        _supervisorId;

  SupervisorForestNotifier({
    required ForestService service,
    required String supervisorId,
  })  : _service      = service,
        _supervisorId = supervisorId,
        super(const SupervisorForestState());

  /// Charge toutes les forêts puis filtre par superviseur_id
  Future<void> loadForests() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Récupérer toutes les forêts (page_size élevé)
      final result = await _service.getForests(pageSize: 500);

      // Filtrer côté client : seulement celles assignées à ce superviseur
      final myForests = result.items.where((f) {
        // Forest model expose superviseur_id (string ou null)
        // On compare en ignorant la casse pour la robustesse
        final sid = f.superviseurId;
        if (sid == null || sid.isEmpty) return false;
        return sid.toLowerCase() == _supervisorId.toLowerCase();
      }).toList();

      if (!mounted) return;
      state = state.copyWith(forests: myForests, isLoading: false);

      // Charger les parcelles pour chaque forêt en parallèle
      await _loadAllParcelles(myForests);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> _loadAllParcelles(List<Forest> forests) async {
    if (!mounted) return;

    // Marquer toutes comme en cours de chargement
    state = state.copyWith(
      loadingParcelleIds: forests.map((f) => f.id).toSet(),
    );

    // Charger en parallèle
    await Future.wait(forests.map((f) => _loadParcelles(f.id)));
  }

  Future<void> _loadParcelles(String forestId) async {
    if (!mounted) return;
    try {
      final result = await _service.getParcelles(
        forestId: forestId,
        pageSize: 500,
      );
      if (!mounted) return;
      state = state.copyWith(
        parcellesByForest: {
          ...state.parcellesByForest,
          forestId: result.items,
        },
        loadingParcelleIds:
            state.loadingParcelleIds.difference({forestId}),
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        loadingParcelleIds:
            state.loadingParcelleIds.difference({forestId}),
      );
    }
  }

  void clearError() {
    if (!mounted) return;
    state = state.copyWith(clearError: true);
  }
}

// ─────────────────────────────────────────────────────────────
//  PROVIDER
// ─────────────────────────────────────────────────────────────

final supervisorForestProvider = StateNotifierProvider<
    SupervisorForestNotifier, SupervisorForestState>((ref) {
  final auth        = ref.watch(authProvider);
  final supervisorId = auth.userId ?? '';   // userId exposé par AuthState
  return SupervisorForestNotifier(
    service:      ForestService(),
    supervisorId: supervisorId,
  );
});