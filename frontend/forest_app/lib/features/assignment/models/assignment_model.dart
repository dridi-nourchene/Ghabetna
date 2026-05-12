// features/assignment/models/assignment_model.dart

class AgentStatus {
  final String  userId;
  final String  nom;
  final String  email;
  final String  phone;
  final bool    isAssigned;
  final ParcelleInfo? currentParcelle;

  const AgentStatus({
    required this.userId,
    required this.nom,
    required this.email,
    required this.phone,
    required this.isAssigned,
    this.currentParcelle,
  });

  factory AgentStatus.fromJson(Map<String, dynamic> j) => AgentStatus(
        userId:          j['user_id'],
        nom:             j['nom'],
        email:           j['email'],
        phone:           j['phone'] ?? '',
        isAssigned:      j['is_assigned'] ?? false,
        currentParcelle: j['current_parcelle'] != null
            ? ParcelleInfo.fromJson(j['current_parcelle'])
            : null,
      );

  String get initials {
    final parts = nom.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return nom.substring(0, nom.length >= 2 ? 2 : nom.length).toUpperCase();
  }
}

class SuperviseurStatus {
  final String       userId;
  final String       nom;
  final String       email;
  final String       phone;
  final bool         isAssigned;
  final List<ForestInfo> currentForests;

  const SuperviseurStatus({
    required this.userId,
    required this.nom,
    required this.email,
    required this.phone,
    required this.isAssigned,
    required this.currentForests,
  });

  factory SuperviseurStatus.fromJson(Map<String, dynamic> j) => SuperviseurStatus(
        userId:         j['user_id'],
        nom:            j['nom'],
        email:          j['email'],
        phone:          j['phone'] ?? '',
        isAssigned:     j['is_assigned'] ?? false,
        currentForests: (j['current_forests'] as List? ?? [])
            .map((f) => ForestInfo.fromJson(f))
            .toList(),
      );

  String get initials {
    final parts = nom.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return nom.substring(0, nom.length >= 2 ? 2 : nom.length).toUpperCase();
  }
}

class ParcelleInfo {
  final String parcelleId;
  final String parcelleName;

  const ParcelleInfo({required this.parcelleId, required this.parcelleName});

  factory ParcelleInfo.fromJson(Map<String, dynamic> j) => ParcelleInfo(
        parcelleId:   j['parcelle_id'],
        parcelleName: j['parcelle_name'],
      );
}

class ForestInfo {
  final String forestId;
  final String forestName;

  const ForestInfo({required this.forestId, required this.forestName});

  factory ForestInfo.fromJson(Map<String, dynamic> j) => ForestInfo(
        forestId:   j['forest_id'],
        forestName: j['forest_name'],
      );
}

class AssignmentResult {
  final bool    conflict;
  final String  agentId;
  final String? agentNom;
  final String? agentEmail;
  final String? agentPhone;
  final String? parcelleId;
  final String? parcelleName;
  // Rempli si conflict=true
  final String? currentParcelleId;
  final String? currentParcelleName;
  final String? message;

  const AssignmentResult({
    required this.conflict,
    required this.agentId,
    this.agentNom,
    this.agentEmail,
    this.agentPhone,
    this.parcelleId,
    this.parcelleName,
    this.currentParcelleId,
    this.currentParcelleName,
    this.message,
  });

  factory AssignmentResult.fromJson(Map<String, dynamic> j) => AssignmentResult(
        conflict:             j['conflict'] ?? false,
        agentId:              j['agent_id'] ?? '',
        agentNom:             j['agent_nom'],
        agentEmail:           j['agent_email'],
        agentPhone:           j['agent_phone'],
        parcelleId:           j['parcelle_id'],
        parcelleName:         j['parcelle_name'],
        currentParcelleId:    j['current_parcelle_id'],
        currentParcelleName:  j['current_parcelle_name'],
        message:              j['message'],
      );
}

// Récent affiché dans la liste droite
class RecentAssignment {
  final String userId;
  final String nom;
  final String email;
  final String phone;
  final String targetName; // parcelle ou forêt
  final String initials;

  const RecentAssignment({
    required this.userId,
    required this.nom,
    required this.email,
    required this.phone,
    required this.targetName,
    required this.initials,
  });
}