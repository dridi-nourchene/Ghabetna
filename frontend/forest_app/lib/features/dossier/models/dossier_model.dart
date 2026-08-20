// features/dossier/models/dossier_model.dart

import 'package:forest_app/features/user/models/user_model.dart';

// ═══════════════════════════════════════════════════════════════
//  Modèles du dossier citoyen — miroir de DossierOut (citizen_ms)
//
//  Chaque nom Dart reprend la clé JSON du backend : statutDossier pour
//  statut_dossier, soumisLe pour soumis_le. Un 422 sur /dossiers se
//  cherche donc avec le même mot des deux côtés de la pile.
//
//  Toute clé lue ici correspond à une ligne de schemas/citizen.py.
//  Si le backend en renomme une, c'est le SEUL fichier à corriger.
//
//  Les identifiants restent des String et non des UUID : Dart n'a pas
//  de type UUID natif, et ces valeurs ne servent qu'à être renvoyées
//  telles quelles dans les URL.
// ═══════════════════════════════════════════════════════════════

/// Parse une date renvoyée par FastAPI, en tolérant l'absence.
///
/// Même prudence que RecentUser.fromJson : une date illisible ne doit pas
/// faire tomber tout l'écran. On préfère une valeur visiblement fausse à
/// une exception qui vide la liste.
DateTime? _date(dynamic v) =>
    v == null ? null : DateTime.tryParse(v as String);

// ── Pièce jointe ──────────────────────────────────────────

class PieceJointe {
  final String    pieceId;
  final String    typeDocument;   // 'cin_recto' | 'permis_chasse' | ...
  final String    url;
  final String    mimeType;
  final int       tailleOctets;
  final DateTime? televerseLe;

  const PieceJointe({
    required this.pieceId,
    required this.typeDocument,
    required this.url,
    required this.mimeType,
    required this.tailleOctets,
    this.televerseLe,
  });

  factory PieceJointe.fromJson(Map<String, dynamic> j) => PieceJointe(
        pieceId:      j['piece_id']      as String,
        typeDocument: j['type_document'] as String,
        url:          j['url']           as String? ?? '',
        mimeType:     j['mime_type']     as String? ?? '',
        tailleOctets: j['taille_octets'] as int?    ?? 0,
        televerseLe:  _date(j['televerse_le']),
      );

  /// Décide de l'affichage : vignette décodée en mémoire, ou carte PDF.
  ///
  /// On se fie au mime_type stocké en base, pas à l'extension du nom de
  /// fichier — c'est précisément la raison pour laquelle citizen_ms le
  /// conserve dans une colonne dédiée.
  bool get estImage => mimeType.startsWith('image/');

  /// Libellé humain du type de document.
  ///
  /// Les clés reprennent l'énumération TypeDocument du backend. Un type
  /// inconnu retombe sur sa valeur brute plutôt que sur une chaîne vide :
  /// mieux vaut afficher « permis futur » que rien du tout le jour où le
  /// backend en ajoute un.
  String get libelle => switch (typeDocument) {
        'cin_recto'             => 'CIN recto',
        'cin_verso'             => 'CIN verso',
        'photo_identite'        => 'Photo d\'identité',
        'permis_chasse'         => 'Permis de chasse',
        'permis_detention'      => 'Permis de détention',
        'permis_port_transport' => 'Permis de port et transport',
        'certificat_colonies'   => 'Certificat de colonies',
        _                       => typeDocument.replaceAll('_', ' '),
      };

  /// Taille lisible, affichée sous le nom du fichier.
  String get tailleLisible {
    if (tailleOctets <= 0) return '';
    if (tailleOctets < 1024 * 1024) {
      return '${(tailleOctets / 1024).round()} Ko';
    }
    return '${(tailleOctets / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }
}

// ── Sous-profil chasseur ──────────────────────────────────

class ProfilChasseur {
  final String    numeroPermisChasse;
  final DateTime? dateDelivrance;
  final DateTime? dateExpiration;
  final String?   gouvernoratDelivrance;
  final bool      possedeArme;
  final String?   numeroPermisDetention;
  final String?   numeroPermisPortTransport;

  const ProfilChasseur({
    required this.numeroPermisChasse,
    this.dateDelivrance,
    this.dateExpiration,
    this.gouvernoratDelivrance,
    required this.possedeArme,
    this.numeroPermisDetention,
    this.numeroPermisPortTransport,
  });

  factory ProfilChasseur.fromJson(Map<String, dynamic> j) => ProfilChasseur(
        numeroPermisChasse:        j['numero_permis_chasse'] as String? ?? '',
        dateDelivrance:            _date(j['date_delivrance']),
        dateExpiration:            _date(j['date_expiration']),
        gouvernoratDelivrance:     j['gouvernorat_delivrance'] as String?,
        possedeArme:               j['possede_arme'] as bool? ?? false,
        numeroPermisDetention:     j['numero_permis_detention'] as String?,
        numeroPermisPortTransport: j['numero_permis_port_transport'] as String?,
      );
}

// ── Rucher ────────────────────────────────────────────────

class Rucher {
  final int     numeroRucher;
  final String  emplacement;
  final double? latitude;
  final double? longitude;
  final int     nombreColonies;

  const Rucher({
    required this.numeroRucher,
    required this.emplacement,
    this.latitude,
    this.longitude,
    required this.nombreColonies,
  });

  factory Rucher.fromJson(Map<String, dynamic> j) => Rucher(
        numeroRucher:   j['numero_rucher']   as int?    ?? 0,
        emplacement:    j['emplacement']     as String? ?? '',
        // num puis toDouble : PostgreSQL renvoie parfois un entier pour une
        // colonne Float, et un cast direct en double lèverait une exception.
        latitude:       (j['latitude']  as num?)?.toDouble(),
        longitude:      (j['longitude'] as num?)?.toDouble(),
        nombreColonies: j['nombre_colonies'] as int?    ?? 0,
      );
}

// ── Sous-profil apiculteur ────────────────────────────────

class ProfilApiculteur {
  final String       codeApiculteur;
  final String       codeDelegation;
  final String       codeGouvernorat;
  final int          nombreColoniesDeclare;
  final DateTime?    dateCertificat;
  final List<Rucher> ruchers;

  const ProfilApiculteur({
    required this.codeApiculteur,
    required this.codeDelegation,
    required this.codeGouvernorat,
    required this.nombreColoniesDeclare,
    this.dateCertificat,
    required this.ruchers,
  });

  factory ProfilApiculteur.fromJson(Map<String, dynamic> j) => ProfilApiculteur(
        codeApiculteur:        j['code_apiculteur']  as String? ?? '',
        codeDelegation:        j['code_delegation']  as String? ?? '',
        codeGouvernorat:       j['code_gouvernorat'] as String? ?? '',
        nombreColoniesDeclare: j['nombre_colonies_declare'] as int? ?? 0,
        dateCertificat:        _date(j['date_certificat']),
        ruchers: (j['ruchers'] as List? ?? const [])
            .map((r) => Rucher.fromJson(r as Map<String, dynamic>))
            .toList(),
      );

  /// Code complet des ruches, tel qu'il figure sur la façade.
  String get codeComplet => '$codeApiculteur $codeDelegation $codeGouvernorat';

  /// Sert uniquement à titrer le tableau des ruchers : « 34 colonies au
  /// total ». Aucune comparaison avec le certificat n'est faite ici — les
  /// deux nombres sont affichés côte à côte, l'admin tire sa conclusion.
  int get totalColoniesRuchers =>
      ruchers.fold(0, (somme, r) => somme + r.nombreColonies);
}

// ── Dossier complet ───────────────────────────────────────

class Dossier {
  final String profilId;
  final String userId;
  final String specialite;      // 'chasseur' | 'apiculteur' | 'campeur'
  final String statutDossier;   // 'en_attente' | 'approuve' | 'rejete'

  final String  gouvernorat;
  final String  delegation;
  final String? secteur;
  final String? adresse;
  final String? telephone;

  final String?   motifRejet;
  final DateTime? soumisLe;
  final DateTime? traiteLe;

  final List<PieceJointe> pieces;
  final ProfilChasseur?   chasseur;
  final ProfilApiculteur? apiculteur;


  const Dossier({
    required this.profilId,
    required this.userId,
    required this.specialite,
    required this.statutDossier,
    required this.gouvernorat,
    required this.delegation,
    this.secteur,
    this.adresse,
    this.telephone,
    this.motifRejet,
    this.soumisLe,
    this.traiteLe,
    required this.pieces,
    this.chasseur,
    this.apiculteur
  });

  factory Dossier.fromJson(Map<String, dynamic> j) => Dossier(
        profilId:      j['profil_id']      as String,
        userId:        j['user_id']        as String,
        specialite:    j['specialite']     as String? ?? '',
        statutDossier: j['statut_dossier'] as String? ?? 'en_attente',
        gouvernorat:   j['gouvernorat']    as String? ?? '',
        delegation:    j['delegation']     as String? ?? '',
        secteur:       j['secteur']        as String?,
        adresse:       j['adresse']        as String?,
        telephone:     j['telephone']      as String?,
        motifRejet:    j['motif_rejet']    as String?,
        soumisLe:      _date(j['soumis_le']),
        traiteLe:      _date(j['traite_le']),
        pieces: (j['pieces'] as List? ?? const [])
            .map((p) => PieceJointe.fromJson(p as Map<String, dynamic>))
            .toList(),
        // Un campeur n'a ni l'un ni l'autre, un chasseur n'a que le premier.
        // Le null est la règle, pas l'exception.
        chasseur: j['chasseur'] == null
            ? null
            : ProfilChasseur.fromJson(j['chasseur'] as Map<String, dynamic>),
        apiculteur: j['apiculteur'] == null
            ? null
            : ProfilApiculteur.fromJson(j['apiculteur'] as Map<String, dynamic>),
  
      );

  bool get estEnAttente => statutDossier == 'en_attente';

  String get specialiteLabel => switch (specialite) {
        'chasseur'   => 'Chasseur',
        'apiculteur' => 'Apiculteur',
        'campeur'    => 'Campeur',
        _            => specialite,
      };

  String get statutLabel => switch (statutDossier) {
        'en_attente' => 'En attente',
        'approuve'   => 'Approuvé',
        'rejete'     => 'Rejeté',
        _            => statutDossier,
      };

  /// Adresse sur une ligne, pour la fiche de détail. Les champs facultatifs
  /// vides sont retirés plutôt que remplacés par un tiret : une adresse
  /// trouée est plus lisible qu'une adresse pleine de placeholders.
  String get adresseComplete => [
        adresse,
        secteur,
        delegation,
        gouvernorat,
      ].where((p) => p != null && p.trim().isNotEmpty).join(', ');
}

// ── Dossier + identité, tels que les écrans les consomment ──

/// Le résultat de la jointure applicative.
///
/// citizen_ms ne connaît que le user_id : le nom, la CIN et l'email vivent
/// dans auth_ms, sans clé étrangère entre les deux bases. Cette classe est
/// le point exact où les deux moitiés sont recollées, et le seul endroit à
/// modifier si la source de l'identité change un jour.
///
/// `citoyen` est volontairement nullable : un dossier peut survivre à la
/// suppression de son compte. Dans ce cas la ligne reste affichée avec une
/// mention explicite — un dossier orphelin est une anomalie que l'admin
/// doit voir, pas une ligne qui disparaît en silence.
class DossierCitoyen {
  final Dossier  dossier;
  final AppUser? citoyen;

  const DossierCitoyen({required this.dossier, this.citoyen});

  String  get nom       => citoyen?.fullName ?? 'Utilisateur introuvable';
  String  get cin       => citoyen?.cin      ?? '—';
  String  get email     => citoyen?.email    ?? '—';
  String? get telephone => citoyen?.phone    ?? dossier.telephone;

  bool get citoyenIntrouvable => citoyen == null;

  /// Utilisé par la recherche du tableau. Regroupé ici pour que l'écran
  /// n'ait pas à répéter la liste des champs interrogeables.
  bool correspondA(String recherche) {
    if (recherche.trim().isEmpty) return true;
    final q = recherche.toLowerCase();
    return nom.toLowerCase().contains(q) ||
        email.toLowerCase().contains(q) ||
        cin.contains(recherche.trim());
  }
}
