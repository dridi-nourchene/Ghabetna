/// Modèles du dossier citoyen. Miroir de DossierOut (citizen_ms
/// app/schemas/citizen.py) — on ne reprend délibérément pas statut_dossier,
/// motif_rejet, soumis_le ni traite_le : un citoyen qui peut se connecter a
/// nécessairement un dossier approuvé (la connexion est bloquée sinon), donc
/// afficher "Approuvé" n'apporterait aucune information nouvelle.
library;

enum TypeDocument {
  cinRecto,
  cinVerso,
  permisChasse,
  permisDetention,
  permisPortTransport,
  certificatColonies;

  static TypeDocument depuis(String v) => switch (v) {
        'cin_recto' => cinRecto,
        'cin_verso' => cinVerso,
        'permis_chasse' => permisChasse,
        'permis_detention' => permisDetention,
        'permis_port_transport' => permisPortTransport,
        'certificat_colonies' => certificatColonies,
        _ => cinRecto,
      };

  String get libelle => switch (this) {
        TypeDocument.cinRecto => 'CIN — recto',
        TypeDocument.cinVerso => 'CIN — verso',
        TypeDocument.permisChasse => 'Permis de chasse',
        TypeDocument.permisDetention => 'Permis de détention d\'arme',
        TypeDocument.permisPortTransport => 'Permis de port et transport',
        TypeDocument.certificatColonies => 'Certificat d\'identification des colonies',
      };
}

class PieceJointe {
  const PieceJointe({
    required this.id,
    required this.type,
    required this.url,
    required this.mimeType,
  });

  final String id;
  final TypeDocument type;
  final String url;
  final String mimeType;

  factory PieceJointe.fromJson(Map<String, dynamic> j) => PieceJointe(
        id: j['piece_id'] as String,
        type: TypeDocument.depuis(j['type_document'] as String),
        url: j['url'] as String,
        mimeType: j['mime_type'] as String,
      );
}

class ProfilChasseur {
  const ProfilChasseur({
    required this.numeroPermisChasse,
    this.dateDelivrance,
    this.dateExpiration,
    this.gouvernoratDelivrance,
    required this.possedeArme,
    this.numeroPermisDetention,
    this.numeroPermisPortTransport,
  });

  final String numeroPermisChasse;
  final DateTime? dateDelivrance;
  final DateTime? dateExpiration;
  final String? gouvernoratDelivrance;
  final bool possedeArme;
  final String? numeroPermisDetention;
  final String? numeroPermisPortTransport;

  factory ProfilChasseur.fromJson(Map<String, dynamic> j) => ProfilChasseur(
        numeroPermisChasse: j['numero_permis_chasse'] as String,
        dateDelivrance: j['date_delivrance'] != null
            ? DateTime.tryParse(j['date_delivrance'] as String)
            : null,
        dateExpiration: j['date_expiration'] != null
            ? DateTime.tryParse(j['date_expiration'] as String)
            : null,
        gouvernoratDelivrance: j['gouvernorat_delivrance'] as String?,
        possedeArme: j['possede_arme'] as bool? ?? false,
        numeroPermisDetention: j['numero_permis_detention'] as String?,
        numeroPermisPortTransport: j['numero_permis_port_transport'] as String?,
      );
}

class Rucher {
  const Rucher({
    required this.numero,
    required this.emplacement,
    this.latitude,
    this.longitude,
    required this.nombreColonies,
  });

  final int numero;
  final String emplacement;
  final double? latitude;
  final double? longitude;
  final int nombreColonies;

  factory Rucher.fromJson(Map<String, dynamic> j) => Rucher(
        numero: j['numero_rucher'] as int,
        emplacement: j['emplacement'] as String,
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        nombreColonies: j['nombre_colonies'] as int? ?? 0,
      );
}

class ProfilApiculteur {
  const ProfilApiculteur({
    required this.codeApiculteur,
    required this.codeDelegation,
    required this.codeGouvernorat,
    required this.nombreColoniesDeclare,
    this.dateCertificat,
    this.ruchers = const [],
  });

  final String codeApiculteur;
  final String codeDelegation;
  final String codeGouvernorat;
  final int nombreColoniesDeclare;
  final DateTime? dateCertificat;
  final List<Rucher> ruchers;

  /// « 12-34-5678 » — gouvernorat, délégation puis code apiculteur, dans
  /// l'ordre où l'arrêté (annexe 16) les fait figurer sur la façade de la
  /// ruche.
  String get codeComplet => '$codeGouvernorat-$codeDelegation-$codeApiculteur';

  factory ProfilApiculteur.fromJson(Map<String, dynamic> j) => ProfilApiculteur(
        codeApiculteur: j['code_apiculteur'] as String,
        codeDelegation: j['code_delegation'] as String,
        codeGouvernorat: j['code_gouvernorat'] as String,
        nombreColoniesDeclare: j['nombre_colonies_declare'] as int? ?? 0,
        dateCertificat: j['date_certificat'] != null
            ? DateTime.tryParse(j['date_certificat'] as String)
            : null,
        ruchers: ((j['ruchers'] as List?) ?? const [])
            .map((r) => Rucher.fromJson(r as Map<String, dynamic>))
            .toList(),
      );
}

class DossierCitoyen {
  const DossierCitoyen({
    required this.specialite,
    required this.gouvernorat,
    required this.delegation,
    this.secteur,
    this.adresse,
    this.telephone,
    this.pieces = const [],
    this.chasseur,
    this.apiculteur,
  });

  final String specialite;
  final String gouvernorat;
  final String delegation;
  final String? secteur;
  final String? adresse;
  final String? telephone;
  final List<PieceJointe> pieces;
  final ProfilChasseur? chasseur;
  final ProfilApiculteur? apiculteur;

  factory DossierCitoyen.fromJson(Map<String, dynamic> j) => DossierCitoyen(
        specialite: j['specialite'] as String,
        gouvernorat: j['gouvernorat'] as String,
        delegation: j['delegation'] as String,
        secteur: j['secteur'] as String?,
        adresse: j['adresse'] as String?,
        telephone: j['telephone'] as String?,
        pieces: ((j['pieces'] as List?) ?? const [])
            .map((p) => PieceJointe.fromJson(p as Map<String, dynamic>))
            .toList(),
        chasseur: j['chasseur'] != null
            ? ProfilChasseur.fromJson(j['chasseur'] as Map<String, dynamic>)
            : null,
        apiculteur: j['apiculteur'] != null
            ? ProfilApiculteur.fromJson(j['apiculteur'] as Map<String, dynamic>)
            : null,
      );
}
