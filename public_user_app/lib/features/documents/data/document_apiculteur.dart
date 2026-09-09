/// Un formulaire administratif officiel que l'apiculteur peut consulter et
/// télécharger.
///
/// [assetPath] pointe vers le PDF exact publié au Journal Officiel de la
/// République Tunisienne (arrêté du 31 décembre 2015, JORT n° 7 du 22
/// janvier 2016) : ce sont les formulaires eux-mêmes, pas un résumé.
class DocumentApiculteur {
  const DocumentApiculteur({
    required this.titre,
    required this.reference,
    required this.description,
    required this.assetPath,
    required this.nomFichier,
  });

  final String titre;
  final String reference; // ex. « Annexe n° 16 »
  final String description;
  final String assetPath;
  final String nomFichier;
}

/// Liste figée : ce sont les quatre formulaires que l'arrêté impose de
/// remplir à l'apiculteur lui-même.
///
/// Le registre de suivi du rucher (annexe 20) et le registre national des
/// apiculteurs (annexe 17) sont volontairement absents : le premier est un
/// carnet que l'apiculteur tient de son côté, le second est rempli par
/// l'administration, pas par lui.
const documentsApiculteur = <DocumentApiculteur>[
  DocumentApiculteur(
    titre: 'Identification de la ruche',
    reference: 'Annexe n° 16',
    description: "Code à 8 chiffres à apposer sur la façade de chaque ruche "
        '(apiculteur, délégation, gouvernorat).',
    assetPath: 'assets/documents/identification_ruche.pdf',
    nomFichier: 'identification_ruche.pdf',
  ),
  DocumentApiculteur(
    titre: "Déclaration de détention et d'emplacement",
    reference: 'Annexe n° 18',
    description: 'À remplir pour déclarer des colonies non identifiées et '
        'obtenir la liste des codes auprès des services compétents.',
    assetPath: 'assets/documents/declaration_detention.pdf',
    nomFichier: 'declaration_detention_colonies.pdf',
  ),
  DocumentApiculteur(
    titre: "Certificat collectif d'identification",
    reference: 'Annexe n° 19',
    description: "Délivré par l'établissement chargé de l'identification "
        'une fois les colonies identifiées.',
    assetPath: 'assets/documents/certificat_collectif.pdf',
    nomFichier: 'certificat_collectif_identification.pdf',
  ),
  DocumentApiculteur(
    titre: 'Déclaration annuelle des colonies',
    reference: 'Annexe n° 21',
    description: 'À déposer chaque année, du 1er septembre à fin octobre, '
        'auprès du commissariat régional au développement agricole.',
    assetPath: 'assets/documents/declaration_annuelle.pdf',
    nomFichier: 'declaration_annuelle_colonies.pdf',
  ),
];
