import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forest_app/core/constants.dart';
import 'package:forest_app/core/token_storage.dart';

// ── Modèles légers, propres à ce provider ──────────────────────

class RecentUser {
  final String   userId;
  final String   fullName;
  final String   role;
  final String   status;
  final DateTime createdAt;

  const RecentUser({
    required this.userId,
    required this.fullName,
    required this.role,
    required this.status,
    required this.createdAt,
  });

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return fullName.substring(0, fullName.length >= 2 ? 2 : fullName.length).toUpperCase();
  }

  String get roleLabel => switch (role) {
        'supervisor' => 'Superviseur',
        'agent'      => 'Agent de terrain',
        _            => role,
      };

  factory RecentUser.fromJson(Map<String, dynamic> j) => RecentUser(
        userId:    j['user_id'] as String,
        fullName:  j['full_name'] as String? ?? '',
        role:      j['role']      as String? ?? '',
        status:    j['status']    as String? ?? '',
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime(2000),
      );
}

class RiskForest {
  final String forestName;
  final int    rejectedCount;
  final int    confirmedCount;

  const RiskForest({
    required this.forestName,
    required this.rejectedCount,
    required this.confirmedCount,
  });

  factory RiskForest.fromJson(Map<String, dynamic> j) => RiskForest(
        forestName:     j['forest_name']     as String? ?? '',
        rejectedCount:  j['rejected_count']  as int?    ?? 0,
        confirmedCount: j['confirmed_count'] as int?    ?? 0,
      );
}

class DashboardStats {
  final int              pendingUsers;
  final int              activeUsers;
  final int              forestsCount;
  final int              parcellesCount;
  final List<RecentUser> recentUsers;
  final List<RiskForest> riskForests;

  const DashboardStats({
    this.pendingUsers   = 0,
    this.activeUsers    = 0,
    this.forestsCount   = 0,
    this.parcellesCount = 0,
    this.recentUsers    = const [],
    this.riskForests    = const [],
  });
}

class DashboardStatsState {
  final DashboardStats stats;
  final bool           isLoading;
  final String?        error;

  const DashboardStatsState({
    this.stats     = const DashboardStats(),
    this.isLoading = false,
    this.error,
  });

  DashboardStatsState copyWith({
    DashboardStats? stats,
    bool?           isLoading,
    String?         error,
    bool            clearError = false,
  }) =>
      DashboardStatsState(
        stats:     stats     ?? this.stats,
        isLoading: isLoading ?? this.isLoading,
        error:     clearError ? null : (error ?? this.error),
      );
}

class DashboardStatsNotifier extends StateNotifier<DashboardStatsState> {
  final _storage = TokenStorage();
  static const _base = ApiConstants.baseUrl;

  DashboardStatsNotifier() : super(const DashboardStatsState());

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getAccessToken();
    return {
      'Content-Type':  'application/json',
      'Authorization': 'Bearer ${token ?? ''}',
    };
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final headers = await _authHeaders();

      final results = await Future.wait([
        http.get(Uri.parse('$_base/api/users/active'),   headers: headers),
        http.get(Uri.parse('$_base/api/users/inactive'), headers: headers),
        http.get(Uri.parse('$_base/api/forests/?page_size=1'),   headers: headers),
        http.get(Uri.parse('$_base/api/parcelles/?page_size=1'), headers: headers),
        http.get(Uri.parse('$_base/api/analytics/alerts-by-forest?limit=5'), headers: headers),
      ]);

      final activeRes    = results[0];
      final inactiveRes  = results[1];
      final forestsRes   = results[2];
      final parcellesRes = results[3];
      final alertsRes    = results[4];

      final activeList = activeRes.statusCode == 200
          ? (jsonDecode(activeRes.body) as List) : [];
      final inactiveList = inactiveRes.statusCode == 200
          ? (jsonDecode(inactiveRes.body) as List) : [];

      final allUsers = [
        ...activeList.map((j) => RecentUser.fromJson(j as Map<String, dynamic>)),
        ...inactiveList.map((j) => RecentUser.fromJson(j as Map<String, dynamic>)),
      ] ..removeWhere((u) => u.role == 'admin')
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final forestsTotal = forestsRes.statusCode == 200
          ? (jsonDecode(forestsRes.body)['total'] as int? ?? 0) : 0;
      final parcellesTotal = parcellesRes.statusCode == 200
          ? (jsonDecode(parcellesRes.body)['total'] as int? ?? 0) : 0;

      final riskForests = alertsRes.statusCode == 200
          ? ((jsonDecode(alertsRes.body)['items'] as List)
              .map((j) => RiskForest.fromJson(j as Map<String, dynamic>)).toList())
          : <RiskForest>[];

      state = state.copyWith(
        isLoading: false,
        stats: DashboardStats(
          pendingUsers:   inactiveList.length,
          activeUsers:    activeList.length,
          forestsCount:   forestsTotal,
          parcellesCount: parcellesTotal,
          recentUsers:    allUsers.take(5).toList(),
          riskForests:    riskForests.take(5).toList(),
        ),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final dashboardStatsProvider =
    StateNotifierProvider<DashboardStatsNotifier, DashboardStatsState>(
  (ref) => DashboardStatsNotifier(),
);