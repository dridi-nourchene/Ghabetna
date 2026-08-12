/// Modèles de la conversation.
/// Miroir exact des schémas Pydantic de chatbot_ms (app/schemas.py).

enum Role { user, assistant }

/// Spécialité du citoyen. Détermine le domaine interrogé par le RAG :
/// un chasseur accède à ["chasse", "app"], jamais à l'apiculture.
enum Specialite {
  chasseur('chasseur', 'Mode chasseur'),
  campeur('campeur', 'Mode campeur'),
  apiculteur('apiculteur', 'Mode apiculteur');

  const Specialite(this.code, this.libelle);
  final String code;
  final String libelle;

  static Specialite fromCode(String? c) => values.firstWhere(
        (s) => s.code == c,
        orElse: () => Specialite.chasseur,
      );
}

/// État du verdict calculé côté serveur par rag/calendrier.py.
enum VerdictEtat { autorise, refuse, passee }

/// Verdict de date. Absent quand la question ne porte pas à la fois sur une
/// espèce et une date : l'interface affiche alors la réponse seule.
class Verdict {
  final VerdictEtat etat;
  final String titre; // ex. « Non, pas demain »
  final String espece;
  final DateTime? prochaine; // prochaine ouverture

  const Verdict({
    required this.etat,
    required this.titre,
    required this.espece,
    this.prochaine,
  });

  factory Verdict.fromJson(Map<String, dynamic> j) => Verdict(
        etat: switch (j['etat']) {
          'autorise' => VerdictEtat.autorise,
          'passee' => VerdictEtat.passee,
          _ => VerdictEtat.refuse,
        },
        titre: j['titre'] as String? ?? '',
        espece: j['espece'] as String? ?? '',
        prochaine: j['prochaine'] == null
            ? null
            : DateTime.tryParse(j['prochaine'] as String),
      );
}

/// Extrait réglementaire ayant servi à la réponse.
class Source {
  final String source;
  final String? article;
  final String? gouvernorat;
  final String? validite;
  final String extrait;

  const Source({
    required this.source,
    this.article,
    this.gouvernorat,
    this.validite,
    required this.extrait,
  });

  factory Source.fromJson(Map<String, dynamic> j) => Source(
        source: j['source'] as String? ?? '',
        article: j['article'] as String?,
        gouvernorat: j['gouvernorat'] as String?,
        validite: j['validite'] as String?,
        extrait: j['extrait'] as String? ?? '',
      );

  /// « Article 4 de l'arrêté » — libellé compact affiché sous la réponse.
  String get libelleCourt {
    if (article == null || article!.isEmpty) return source;
    final s = source.toLowerCase();
    final base = s.contains('arrêté')
        ? "de l'arrêté"
        : s.contains('69-33')
            ? 'de la loi sur les armes'
            : 'du code forestier';
    return 'Article $article $base';
  }
}

/// Un message affiché dans le fil.
class ChatMessage {
  final Role role;
  final String texte;
  final Verdict? verdict;
  final List<Source> sources;
  final bool enErreur;

  const ChatMessage({
    required this.role,
    required this.texte,
    this.verdict,
    this.sources = const [],
    this.enErreur = false,
  });

  const ChatMessage.user(this.texte)
      : role = Role.user,
        verdict = null,
        sources = const [],
        enErreur = false;

  const ChatMessage.erreur(this.texte)
      : role = Role.assistant,
        verdict = null,
        sources = const [],
        enErreur = true;

  /// Format attendu par l'API pour l'historique.
  Map<String, String> toApi() => {
        'role': role == Role.user ? 'user' : 'assistant',
        'content': texte,
      };
}

/// Réponse complète de POST /api/chat/
class ChatResponse {
  final String reponse;
  final Verdict? verdict;
  final List<Source> sources;
  final bool depuisCache;
  final int dureeMs;

  const ChatResponse({
    required this.reponse,
    this.verdict,
    this.sources = const [],
    this.depuisCache = false,
    this.dureeMs = 0,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> j) => ChatResponse(
        reponse: j['reponse'] as String? ?? '',
        verdict: j['verdict'] == null
            ? null
            : Verdict.fromJson(j['verdict'] as Map<String, dynamic>),
        sources: ((j['sources'] as List?) ?? const [])
            .map((e) => Source.fromJson(e as Map<String, dynamic>))
            .toList(),
        depuisCache: j['depuis_cache'] as bool? ?? false,
        dureeMs: j['duree_ms'] as int? ?? 0,
      );
}
