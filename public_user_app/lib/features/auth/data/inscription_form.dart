import '../../../core/fichier_joint.dart';
import '../../chat/data/chat_models.dart' show Specialite;

/// État du formulaire d'inscription.
///
/// Objet MUTABLE vivant dans le State de InscriptionScreen. Les quatre
/// étapes le lisent et le modifient directement : c'est ce qui permet de
/// revenir en arrière depuis le récapitulatif sans perdre les fichiers
/// déjà sélectionnés.
///
/// Le mot de passe transite ici mais n'est jamais écrit sur le disque : il
/// part vers citizen_ms, qui le fait suivre à auth_ms sans le stocker non
/// plus. Seul auth_ms le hache.
class InscriptionForm {
  // ── Étape 1 — identité ─────────────────────────────────
  String nomComplet = '';
  String cin = '';
  String email = '';
  String telephone = '';
  DateTime? dateNaissance;
  String motDePasse = '';

  String gouvernorat = '';
  String delegation = '';
  String secteur = '';
  String adresse = '';

  // ── Étape 2 — spécialité ───────────────────────────────
  Specialite? specialite;

  // ── Étape 3 — chasseur ─────────────────────────────────
  String numeroPermisChasse = '';
  DateTime? dateDelivrance;
  DateTime? dateExpiration;
  String gouvernoratDelivrance = '';
  bool possedeArme = false;
  String numeroPermisDetention = '';
  String numeroPermisPortTransport = '';

  // ── Étape 3 — apiculteur ───────────────────────────────
  String codeApiculteur = '';
  String codeDelegation = '';
  String codeGouvernorat = '';
  int? nombreRuchers;
  int? nombreColonies;
  DateTime? dateCertificat;

  // ── Documents ──────────────────────────────────────────
  /// Clé = nom du champ attendu par citizen_ms (cin_recto, permis_chasse…).
  final Map<String, FichierJoint> documents = {};

  /// Documents exigés selon la spécialité. Doit rester aligné sur
  /// _documents_requis() de citizen_service.py : si les deux divergent, le
  /// citoyen enverra un dossier que le serveur refusera avec un 400.
  List<(String, String)> get documentsRequis {
    const communs = [
      ('cin_recto', 'CIN recto'),
      ('cin_verso', 'CIN verso'),
    ];

    return switch (specialite) {
      Specialite.chasseur => [
          ...communs,
          ('permis_chasse', 'Permis de chasse'),
          // Loi 69-33 : détention et port/transport vont ensemble, une arme
          // qu'on ne peut pas transporter ne sert pas à la chasse.
          if (possedeArme) ('permis_detention', 'Permis de détention'),
          if (possedeArme)
            ('permis_port_transport', 'Permis de port et transport'),
        ],
      Specialite.apiculteur => [
          ...communs,
          // Il n'existe pas de permis d'apiculteur en droit tunisien : le
          // certificat collectif (annexe 19) fait foi.
          ('certificat_colonies', 'Certificat des colonies'),
        ],
      // Campeur : aucune pièce spécifique exigée par la loi.
      _ => communs,
    };
  }

  bool get documentsComplets =>
      documentsRequis.every((d) => documents.containsKey(d.$1));

  /// Cohérence entre le code de la ruche et l'adresse déclarée.
  ///
  /// L'annexe 16 précise que le domicile de l'apiculteur détermine le
  /// gouvernorat et la délégation du code. On avertit seulement : la
  /// décision reste à l'admin, l'application ne bloque pas.
  String? get avertissementCode {
    if (specialite != Specialite.apiculteur) return null;
    if (codeGouvernorat.isEmpty || gouvernorat.isEmpty) return null;
    return null; // table des codes officiels non intégrée pour l'instant
  }

  /// Conversion en champs de formulaire multipart.
  ///
  /// Les valeurs vides sont filtrées par postMultipart : inutile de les
  /// écarter ici, mais les dates doivent être au format ISO attendu par
  /// Pydantic (aaaa-mm-jj).
  Map<String, String> versChamps() {
    String d(DateTime? date) =>
        date == null ? '' : date.toIso8601String().split('T').first;

    final champs = <String, String>{
      'full_name': nomComplet.trim(),
      'email': email.trim(),
      'cin': cin.trim(),
      'password': motDePasse,
      'phone': telephone.trim(),
      'birth_date': d(dateNaissance),
      'specialite': specialite?.code ?? '',
      'gouvernorat': gouvernorat.trim(),
      'delegation': delegation.trim(),
      'secteur': secteur.trim(),
      'adresse': adresse.trim(),
    };

    if (specialite == Specialite.chasseur) {
      champs.addAll({
        'numero_permis_chasse': numeroPermisChasse.trim(),
        'date_delivrance': d(dateDelivrance),
        'date_expiration': d(dateExpiration),
        'gouvernorat_delivrance': gouvernoratDelivrance.trim(),
        // Envoyé même à false : c'est un booléen attendu par le serveur,
        // pas un champ optionnel.
        'possede_arme': possedeArme.toString(),
        if (possedeArme)
          'numero_permis_detention': numeroPermisDetention.trim(),
        if (possedeArme)
          'numero_permis_port_transport': numeroPermisPortTransport.trim(),
      });
    }

    if (specialite == Specialite.apiculteur) {
      champs.addAll({
        'code_apiculteur': codeApiculteur.trim(),
        'code_delegation': codeDelegation.trim(),
        'code_gouvernorat': codeGouvernorat.trim(),
        'nombre_ruchers': nombreRuchers?.toString() ?? '',
        'nombre_colonies_declare': nombreColonies?.toString() ?? '',
        'date_certificat': d(dateCertificat),
      });
    }

    return champs;
  }
}
