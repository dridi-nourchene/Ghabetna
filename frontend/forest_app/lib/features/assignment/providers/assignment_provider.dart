// features/assignment/providers/assignment_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forest_app/features/assignment/models/assignment_model.dart';
import 'package:forest_app/features/assignment/services/assignment_service.dart';
import 'package:forest_app/features/forest/models/forest_model.dart';

// ── State Agent ───────────────────────────────────────────────

class AgentAssignmentState {
  final List<AgentStatus> agents;
  final bool              isLoading;
  final String?           error;
  final String?           successMessage;
  // Conflit en cours
  final AssignmentResult? pendingConflict;

  const AgentAssignmentState({
    this.agents         = const [],
    this.isLoading      = false,
    this.error,
    this.successMessage,
    this.pendingConflict,
  });

  /// Les 4 derniers agents affectés (tri par nom pour la démo, l'API ne retourne pas de date)
  List<AgentStatus> get recentAssigned {
    final assigned = agents.where((a) => a.isAssigned).toList();
    return assigned.take(4).toList();
  }

  AgentAssignmentState copyWith({
    List<AgentStatus>?  agents,
    bool?               isLoading,
    String?             error,
    bool                clearError = false,
    String?             successMessage,
    bool                clearSuccess = false,
    AssignmentResult?   pendingConflict,
    bool                clearConflict = false,
  }) =>
      AgentAssignmentState(
        agents:          agents          ?? this.agents,
        isLoading:       isLoading       ?? this.isLoading,
        error:           clearError      ? null : (error ?? this.error),
        successMessage:  clearSuccess    ? null : (successMessage ?? this.successMessage),
        pendingConflict: clearConflict   ? null : (pendingConflict ?? this.pendingConflict),
      );
}

class AgentAssignmentNotifier extends StateNotifier<AgentAssignmentState> {
  final _service = AssignmentService();

  AgentAssignmentNotifier() : super(const AgentAssignmentState());

  Future<void> loadAgents() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final agents = await _service.getAgents();
      state = state.copyWith(agents: agents, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Retourne true si succès, false si conflit (conflit stocké dans pendingConflict)
  Future<bool> assignAgent({
    required String parcelleId,
    required String agentId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final result = await _service.assignAgent(
        parcelleId: parcelleId,
        agentId:    agentId,
      );

      if (result.conflict) {
        state = state.copyWith(isLoading: false, pendingConflict: result);
        return false;
      }

      // Succès → recharger la liste
      await loadAgents();
      state = state.copyWith(
        successMessage: 'Agent affecté avec succès à ${result.parcelleName}',
        clearConflict:  true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> confirmReassign({
    required String parcelleId,
    required String agentId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearConflict: true);
    try {
      final result = await _service.reassignAgent(
        parcelleId: parcelleId,
        agentId:    agentId,
      );
      await loadAgents();
      state = state.copyWith(
        successMessage: 'Affectation déplacée vers ${result.parcelleName}',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  void clearConflict() => state = state.copyWith(clearConflict: true);
  void clearMessages() => state = state.copyWith(clearError: true, clearSuccess: true);
}

final agentAssignmentProvider =
    StateNotifierProvider<AgentAssignmentNotifier, AgentAssignmentState>(
  (ref) => AgentAssignmentNotifier(),
);

// ── State Superviseur ─────────────────────────────────────────

class SuperviseurAssignmentState {
  final List<SuperviseurStatus> superviseurs;
  final bool                    isLoading;
  final String?                 error;
  final String?                 successMessage;

  const SuperviseurAssignmentState({
    this.superviseurs    = const [],
    this.isLoading       = false,
    this.error,
    this.successMessage,
  });

  List<SuperviseurStatus> get recentAssigned {
    final assigned = superviseurs.where((s) => s.isAssigned).toList();
    return assigned.take(4).toList();
  }

  SuperviseurAssignmentState copyWith({
    List<SuperviseurStatus>? superviseurs,
    bool?                    isLoading,
    String?                  error,
    bool                     clearError = false,
    String?                  successMessage,
    bool                     clearSuccess = false,
  }) =>
      SuperviseurAssignmentState(
        superviseurs:   superviseurs   ?? this.superviseurs,
        isLoading:      isLoading      ?? this.isLoading,
        error:          clearError     ? null : (error ?? this.error),
        successMessage: clearSuccess   ? null : (successMessage ?? this.successMessage),
      );
}

class SuperviseurAssignmentNotifier
    extends StateNotifier<SuperviseurAssignmentState> {
  final _service = AssignmentService();

  SuperviseurAssignmentNotifier() : super(const SuperviseurAssignmentState());

  Future<void> loadSuperviseurs() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final sups = await _service.getSuperviseurs();
      state = state.copyWith(superviseurs: sups, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<bool> assignSuperviseur({
    required String forestId,
    required String forestName,
    required String superviseurId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await _service.assignSuperviseur(
        forestId:       forestId,
        superviseurId:  superviseurId,
      );
      await loadSuperviseurs();
      state = state.copyWith(
        successMessage: 'Superviseur affecté à $forestName',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  void clearMessages() =>
      state = state.copyWith(clearError: true, clearSuccess: true);
}

final superviseurAssignmentProvider = StateNotifierProvider<
    SuperviseurAssignmentNotifier, SuperviseurAssignmentState>(
  (ref) => SuperviseurAssignmentNotifier(),
);