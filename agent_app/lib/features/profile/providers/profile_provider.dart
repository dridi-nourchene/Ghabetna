// features/profile/providers/profile_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_app/features/profile/models/agent_profile.dart';
import 'package:agent_app/features/profile/services/profile_service.dart';

class ProfileState {
  final AgentProfile? profile;
  final String?       tokenNom;
  final String?       tokenEmail;
  final bool          isLoading;
  final bool          hasError;

  const ProfileState({
    this.profile,
    this.tokenNom,
    this.tokenEmail,
    this.isLoading = false,
    this.hasError  = false,
  });

  String get nom   => profile?.nom   ?? tokenNom   ?? '';
  String get email => profile?.email ?? tokenEmail ?? '';

  String get initiales {
    final mots = nom.trim().split(RegExp(r'\s+')).where((m) => m.isNotEmpty);
    if (mots.isEmpty) return '?';
    return mots.take(2).map((m) => m[0].toUpperCase()).join();
  }

  ProfileState copyWith({
    AgentProfile? profile,
    String?       tokenNom,
    String?       tokenEmail,
    bool?         isLoading,
    bool?         hasError,
  }) => ProfileState(
    profile:    profile    ?? this.profile,
    tokenNom:   tokenNom   ?? this.tokenNom,
    tokenEmail: tokenEmail ?? this.tokenEmail,
    isLoading:  isLoading  ?? this.isLoading,
    hasError:   hasError   ?? this.hasError,
  );
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  final _service = ProfileService();

  ProfileNotifier() : super(const ProfileState());

  Future<void> load() async {
    final identite = await _service.identityFromToken();
    state = state.copyWith(
      tokenNom:   identite.nom,
      tokenEmail: identite.email,
      isLoading:  true,
      hasError:   false,
    );
    try {
      final profile = await _service.getMyProfile();
      state = state.copyWith(profile: profile, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false, hasError: true);
    }
  }
}

// autoDispose : après une déconnexion puis la connexion d'un autre agent,
// l'écran ne doit jamais montrer le profil précédent.
final profileProvider =
    StateNotifierProvider.autoDispose<ProfileNotifier, ProfileState>(
  (ref) => ProfileNotifier(),
);
