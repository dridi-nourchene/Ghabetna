// features/profile/models/agent_profile.dart

/// Superviseur de la forêt où l'agent est affecté.
class ProfileSupervisor {
  final String  nom;
  final String? email;
  final String? phone;

  const ProfileSupervisor({required this.nom, this.email, this.phone});

  factory ProfileSupervisor.fromJson(Map<String, dynamic> j) =>
      ProfileSupervisor(
        nom:   j['nom']   as String? ?? '',
        email: j['email'] as String?,
        phone: j['phone'] as String?,
      );
}

/// Miroir de GET /api/assignments/me (forest_ms).
///
/// [nom] et [email] peuvent être null si l'agent n'est pas encore dans le
/// cache de forest_ms : l'écran retombe alors sur les valeurs du token.
class AgentProfile {
  final String             agentId;
  final String?            nom;
  final String?            email;
  final String?            phone;
  final String?            forestName;
  final String?            parcelleName;
  final ProfileSupervisor? superviseur;

  const AgentProfile({
    required this.agentId,
    this.nom,
    this.email,
    this.phone,
    this.forestName,
    this.parcelleName,
    this.superviseur,
  });

  bool get isAssigned => parcelleName != null;

  factory AgentProfile.fromJson(Map<String, dynamic> j) => AgentProfile(
        agentId:      j['agent_id']      as String,
        nom:          j['nom']           as String?,
        email:        j['email']         as String?,
        phone:        j['phone']         as String?,
        forestName:   j['forest_name']   as String?,
        parcelleName: j['parcelle_name'] as String?,
        superviseur:  j['superviseur'] != null
            ? ProfileSupervisor.fromJson(
                j['superviseur'] as Map<String, dynamic>)
            : null,
      );
}
