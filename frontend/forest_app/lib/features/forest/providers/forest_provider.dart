// features/forest/providers/forest_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forest_app/features/forest/models/forest_model.dart';
import 'package:forest_app/features/forest/services/forest_service.dart';

// ═══════════════════════════════════════════════════════════════
//  FOREST STATE
// ═══════════════════════════════════════════════════════════════

class ForestListState {
  final List<Forest>  forests;
  final bool          isLoading;
  final String?       error;
  final Set<String>   deletingIds;

  const ForestListState({
    this.forests     = const [],
    this.isLoading   = false,
    this.error,
    this.deletingIds = const {},
  });

  ForestListState copyWith({
    List<Forest>? forests,
    bool?         isLoading,
    String?       error,
    Set<String>?  deletingIds,
  }) =>
      ForestListState(
        forests:     forests     ?? this.forests,
        isLoading:   isLoading   ?? this.isLoading,
        error:       error,          // null clears error
        deletingIds: deletingIds ?? this.deletingIds,
      );
}

class ForestListNotifier extends StateNotifier<ForestListState> {
  final _service = ForestService();

  ForestListNotifier() : super(const ForestListState());

  Future<void> loadForests({String? search}) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _service.getForests(search: search);
      state = state.copyWith(
        forests:   result.items,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error:     e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<Forest?> createForest({
    required String name,
    required Map<String, dynamic> geojson,
  }) async {
    try {
      final forest = await _service.createForest(name: name, geojson: geojson);
      state = state.copyWith(forests: [...state.forests, forest]);
      return forest;
    } catch (e) {
      state = state.copyWith(
          error: e.toString().replaceAll('Exception: ', ''));
      return null;
    }
  }

  Future<Forest?> updateForest(
    String forestId, {
    String? name,
    Map<String, dynamic>? geojson,
  }) async {
    try {
      final updated = await _service.updateForest(forestId,
          name: name, geojson: geojson);
      state = state.copyWith(
        forests: state.forests
            .map((f) => f.id == forestId ? updated : f)
            .toList(),
      );
      return updated;
    } catch (e) {
      state = state.copyWith(
          error: e.toString().replaceAll('Exception: ', ''));
      return null;
    }
  }

  Future<bool> deleteForest(String forestId) async {
    state = state.copyWith(
        deletingIds: {...state.deletingIds, forestId});

    final prev = state.forests;
    state = state.copyWith(
        forests: state.forests.where((f) => f.id != forestId).toList());

    try {
      await _service.deleteForest(forestId);
      state = state.copyWith(
          deletingIds: state.deletingIds.difference({forestId}));
      return true;
    } catch (e) {
      state = state.copyWith(
        forests:     prev,
        deletingIds: state.deletingIds.difference({forestId}),
        error:       e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  void clearError() => state = state.copyWith(error: null);
}

final forestListProvider =
    StateNotifierProvider<ForestListNotifier, ForestListState>(
  (ref) => ForestListNotifier(),
);

// ═══════════════════════════════════════════════════════════════
//  PARCELLE STATE — keyed by forestId
// ═══════════════════════════════════════════════════════════════

class ParcelleState {
  final Map<String, List<Parcelle>> byForest;    // forestId → parcelles
  final Set<String>                 loadingIds;  // forestIds currently loading
  final Set<String>                 deletingIds;
  final String?                     error;

  const ParcelleState({
    this.byForest    = const {},
    this.loadingIds  = const {},
    this.deletingIds = const {},
    this.error,
  });

  List<Parcelle> forForest(String forestId) => byForest[forestId] ?? [];

  ParcelleState copyWith({
    Map<String, List<Parcelle>>? byForest,
    Set<String>?                 loadingIds,
    Set<String>?                 deletingIds,
    String?                      error,
  }) =>
      ParcelleState(
        byForest:    byForest    ?? this.byForest,
        loadingIds:  loadingIds  ?? this.loadingIds,
        deletingIds: deletingIds ?? this.deletingIds,
        error:       error,
      );
}

class ParcelleNotifier extends StateNotifier<ParcelleState> {
  final _service = ForestService();

  ParcelleNotifier() : super(const ParcelleState());

  Future<void> loadParcelles(String forestId) async {
    state = state.copyWith(
        loadingIds: {...state.loadingIds, forestId});
    try {
      final result = await _service.getParcelles(forestId: forestId);
      state = state.copyWith(
        byForest:   {...state.byForest, forestId: result.items},
        loadingIds: state.loadingIds.difference({forestId}),
      );
    } catch (e) {
      state = state.copyWith(
        loadingIds: state.loadingIds.difference({forestId}),
        error:      e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<Parcelle?> createParcelle({
    required String forestId,
    required String name,
    required Map<String, dynamic> geojson,
  }) async {
    try {
      final p = await _service.createParcelle(
          forestId: forestId, name: name, geojson: geojson);
      final current = state.forForest(forestId);
      state = state.copyWith(
          byForest: {...state.byForest, forestId: [...current, p]});
      return p;
    } catch (e) {
      state = state.copyWith(
          error: e.toString().replaceAll('Exception: ', ''));
      return null;
    }
  }

  Future<Parcelle?> updateParcelle(
    String parcelleId,
    String forestId, {
    String? name,
    Map<String, dynamic>? geojson,
  }) async {
    try {
      final updated = await _service.updateParcelle(parcelleId,
          name: name, geojson: geojson);
      final list = state.forForest(forestId)
          .map((p) => p.id == parcelleId ? updated : p)
          .toList();
      state = state.copyWith(
          byForest: {...state.byForest, forestId: list});
      return updated;
    } catch (e) {
      state = state.copyWith(
          error: e.toString().replaceAll('Exception: ', ''));
      return null;
    }
  }

  Future<bool> deleteParcelle(String parcelleId, String forestId) async {
    state = state.copyWith(
        deletingIds: {...state.deletingIds, parcelleId});
    final prev = state.forForest(forestId);
    state = state.copyWith(
      byForest: {
        ...state.byForest,
        forestId: prev.where((p) => p.id != parcelleId).toList(),
      },
    );
    try {
      await _service.deleteParcelle(parcelleId);
      state = state.copyWith(
          deletingIds: state.deletingIds.difference({parcelleId}));
      return true;
    } catch (e) {
      state = state.copyWith(
        byForest:    {...state.byForest, forestId: prev},
        deletingIds: state.deletingIds.difference({parcelleId}),
        error:       e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  void clearError() => state = state.copyWith(error: null);
}

final parcelleProvider =
    StateNotifierProvider<ParcelleNotifier, ParcelleState>(
  (ref) => ParcelleNotifier(),
);