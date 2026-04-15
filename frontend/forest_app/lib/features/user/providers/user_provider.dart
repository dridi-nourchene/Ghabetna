// features/user/providers/user_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forest_app/features/user/models/user_model.dart';
import 'package:forest_app/features/user/services/user_service.dart';

// ── State ────────────────────────────────────────────────
enum UserListStatus { initial, loading, loaded, error }

class UserListState {
  final UserListStatus status;
  final List<AppUser>  activeUsers;
  final List<AppUser>  inactiveUsers;
  final String?        error;
  // For optimistic UI: tracks which user is being deleted
  final Set<String>    deletingIds;

  const UserListState({
    this.status       = UserListStatus.initial,
    this.activeUsers  = const [],
    this.inactiveUsers= const [],
    this.error,
    this.deletingIds  = const {},
  });

  // All non-admin users combined (active + inactive), sorted by name
  List<AppUser> get allUsers => [
        ...activeUsers,
        ...inactiveUsers,
      ]..sort((a, b) => a.fullName.compareTo(b.fullName));

  bool get isLoading => status == UserListStatus.loading;

  UserListState copyWith({
    UserListStatus? status,
    List<AppUser>?  activeUsers,
    List<AppUser>?  inactiveUsers,
    String?         error,
    Set<String>?    deletingIds,
  }) =>
      UserListState(
        status:        status        ?? this.status,
        activeUsers:   activeUsers   ?? this.activeUsers,
        inactiveUsers: inactiveUsers ?? this.inactiveUsers,
        error:         error,          // null clears error
        deletingIds:   deletingIds   ?? this.deletingIds,
      );
}

// ── Notifier ─────────────────────────────────────────────
class UserListNotifier extends StateNotifier<UserListState> {
  final _service = UserService();

  UserListNotifier() : super(const UserListState());

  // ── Fetch all users (active + inactive) ───────────────
  Future<void> loadUsers() async {
    state = state.copyWith(status: UserListStatus.loading);
    try {
      final results = await Future.wait([
        _service.getActiveUsers(),
        _service.getInactiveUsers(),
      ]);
      state = state.copyWith(
        status:        UserListStatus.loaded,
        activeUsers:   results[0],
        inactiveUsers: results[1],
      );
    } catch (e) {
      state = state.copyWith(
        status: UserListStatus.error,
        error:  e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // ── Delete user (optimistic: remove immediately, restore on error) ──
  Future<void> deleteUser(String userId) async {
    // Mark as deleting
    state = state.copyWith(
      deletingIds: {...state.deletingIds, userId},
    );

    // Optimistic removal
    final prevActive   = state.activeUsers;
    final prevInactive = state.inactiveUsers;
    state = state.copyWith(
      activeUsers:   state.activeUsers.where((u) => u.userId != userId).toList(),
      inactiveUsers: state.inactiveUsers.where((u) => u.userId != userId).toList(),
    );

    try {
      await _service.deleteUser(userId);
      // Remove from deleting set on success
      state = state.copyWith(
        deletingIds: state.deletingIds.difference({userId}),
      );
    } catch (e) {
      // Restore on error
      state = state.copyWith(
        activeUsers:   prevActive,
        inactiveUsers: prevInactive,
        deletingIds:   state.deletingIds.difference({userId}),
        error:         e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // ── Update user in local state after edit ─────────────
  void updateUserLocally(AppUser updated) {
    state = state.copyWith(
      activeUsers: state.activeUsers
          .map((u) => u.userId == updated.userId ? updated : u)
          .toList(),
      inactiveUsers: state.inactiveUsers
          .map((u) => u.userId == updated.userId ? updated : u)
          .toList(),
    );
  }

  // ── Add user to local state after creation ────────────
  void addUserLocally(AppUser user) {
    if (user.status == 'active') {
      state = state.copyWith(activeUsers: [...state.activeUsers, user]);
    } else {
      state = state.copyWith(inactiveUsers: [...state.inactiveUsers, user]);
    }
  }

  void clearError() => state = state.copyWith(error: null);
}

// ── Provider ─────────────────────────────────────────────
final userListProvider =
    StateNotifierProvider<UserListNotifier, UserListState>(
  (ref) => UserListNotifier(),
);