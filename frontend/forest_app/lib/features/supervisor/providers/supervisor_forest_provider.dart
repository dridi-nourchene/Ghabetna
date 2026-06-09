// frontend/forest_app/lib/features/supervisor/providers/supervisor_forest_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forest_app/features/forest/models/forest_model.dart';
import 'package:forest_app/features/forest/services/forest_service.dart';
import 'package:forest_app/features/auth/providers/auth_provider.dart';

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
    List<Forest>?                forests,
    Map<String, List<Parcelle>>? parcellesByForest,
    Set<String>?                 loadingParcelleIds,
    bool?                        isLoading,
    String?                      error,
    bool                         clearError = false,
  }) =>
      SupervisorForestState(
        forests:            forests            ?? this.forests,
        parcellesByForest:  parcellesByForest  ?? this.parcellesByForest,
        loadingParcelleIds: loadingParcelleIds ?? this.loadingParcelleIds,
        isLoading:          isLoading          ?? this.isLoading,
        error:              clearError ? null : (error ?? this.error),
      );
}

class SupervisorForestNotifier extends StateNotifier<SupervisorForestState> {
  final ForestService _service;
  final String        _supervisorId;

  SupervisorForestNotifier({
    required ForestService service,
    required String supervisorId,
  })  : _service      = service,
        _supervisorId = supervisorId,
        super(const SupervisorForestState());

  Future<void> loadForests() async {
    if (!mounted) return;

    if (_supervisorId.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'Identifiant superviseur manquant — reconnectez-vous',
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await _service.getForests(pageSize: 100);

      if (!mounted) return;

      final supervisorIdNorm = _supervisorId.trim().toLowerCase();

      final myForests = result.items.where((f) {
        final sid = f.superviseurId;
        if (sid == null || sid.trim().isEmpty) return false;
        return sid.trim().toLowerCase() == supervisorIdNorm;
      }).toList();

      print('[SUPERVISOR] supervisorId = $_supervisorId');
      print('[SUPERVISOR] total forêts reçues = ${result.items.length}');
      print('[SUPERVISOR] forêts assignées = ${myForests.length}');

      for (final f in result.items) {
        print('[SUPERVISOR] "${f.name}" → superviseur_id = ${f.superviseurId}');
      }

      state = state.copyWith(forests: myForests, isLoading: false);

      if (myForests.isNotEmpty) {
        await _loadAllParcelles(myForests);
      }
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
    state = state.copyWith(
      loadingParcelleIds: forests.map((f) => f.id).toSet(),
    );
    await Future.wait(forests.map((f) => _loadParcelles(f.id)));
  }

  Future<void> _loadParcelles(String forestId) async {
    if (!mounted) return;
    try {
      final result = await _service.getParcelles(
        forestId: forestId,
        pageSize: 100,
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

final supervisorForestProvider = StateNotifierProvider<
    SupervisorForestNotifier, SupervisorForestState>((ref) {
  final auth = ref.watch(authProvider);
  final supervisorId = auth.userId?.trim() ?? '';

  print('[SUPERVISOR PROVIDER] userId = "$supervisorId"');

  return SupervisorForestNotifier(
    service:      ForestService(),
    supervisorId: supervisorId,
  );
});