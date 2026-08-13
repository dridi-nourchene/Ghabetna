import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../data/chat_models.dart';

/// Bulle de l'utilisateur.
///
/// Coins uniformes sur les 4 angles : plus de coin "rentre". L'alignement
/// a droite du fil suffit a distinguer qui parle, sans avoir besoin d'une
/// forme differente entre les deux bulles.
class UserBubble extends StatelessWidget {
  const UserBubble({super.key, required this.texte});
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.84,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.bubbleUserBg,
            borderRadius: BorderRadius.circular(AppDims.bubble),
            boxShadow: AppShadows.bulle,
          ),
          child: Text(
            texte,
            style: const TextStyle(
              fontSize: 13,
              height: 1.55,
              color: AppColors.bubbleUserText,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bulle de l'assistant.
///
/// Fond blanc, meme border-radius uniforme que UserBubble, meme ombre.
/// AUCUNE source n'est affichee ici, quel que soit le sujet de la reponse :
/// ce choix a ete valide sur la maquette v3 et retire le liseré d'accent,
/// le bandeau de source et son dépliage. Le verdict (bandeau + encart de
/// prochaine ouverture) reste affiche : il fait partie de la reponse elle-
/// meme, pas d'une citation.
class AssistantBubble extends StatelessWidget {
  const AssistantBubble({super.key, required this.message});
  final ChatMessage message;

  static const _mois = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];
  static const _jours = [
    'lundi', 'mardi', 'mercredi', 'jeudi',
    'vendredi', 'samedi', 'dimanche',
  ];

  String _formatProchaine(DateTime d) =>
      '${_jours[d.weekday - 1]} ${d.day} ${_mois[d.month - 1]}';

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.84,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(AppDims.bubble),
            border: Border.all(color: AppColors.border, width: 0.5),
            boxShadow: AppShadows.bulle,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.verdict != null) _bandeauVerdict(message.verdict!),
              Text(
                message.texte,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: message.enErreur
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
              if (message.verdict?.prochaine != null)
                _encartProchaine(message.verdict!.prochaine!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bandeauVerdict(Verdict v) {
    final icone = switch (v.etat) {
      VerdictEtat.autorise => Icons.check_circle_outline,
      VerdictEtat.refuse => Icons.back_hand_outlined,
      VerdictEtat.passee => Icons.history,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 15, color: AppColors.accentBlueDark),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              v.titre,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.accentBlueDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Un refus sec n'aide pas : on indique la prochaine date valide,
  /// calculée côté serveur par rag/calendrier.py. Ce n'est pas une
  /// "source" à citer, c'est une information directement utile à
  /// l'utilisateur : elle reste affichée malgré le retrait des sources.
  Widget _encartProchaine(DateTime d) {
    return Container(
      margin: const EdgeInsets.only(top: 9),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.infoBg,
        borderRadius: BorderRadius.circular(AppDims.info),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.event_available_outlined,
              size: 15, color: AppColors.accentBlueDark),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Prochaine ouverture : ${_formatProchaine(d)}',
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.infoText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bandeau d'erreur unique, hors du fil de conversation.
///
/// Toutes les erreurs (reseau, timeout, 401, 500, 503) convergent vers ce
/// meme message : l'utilisateur n'a pas besoin de savoir laquelle s'est
/// produite, seulement que ca n'a pas marche et qu'il peut reessayer.
///
/// Volontairement PAS une bulle d'assistant : un bandeau centre, de
/// couleur ambre, ne peut pas etre confondu avec une reponse de Ghabetna.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key});

  static const _message = 'Connexion échouée. Réessayez dans un instant.';

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.90,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.errorBg,
            border: Border.all(color: AppColors.errorBorder, width: 0.5),
            borderRadius: BorderRadius.circular(AppDims.info),
            boxShadow: AppShadows.bulle,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 15, color: AppColors.errorText),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  _message,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.errorText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Trois points animés pendant l'attente de Groq (2 à 4 s).
/// Sans indicateur, l'utilisateur croit que l'application est bloquée.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const couleurs = [AppColors.dot1, AppColors.dot2, AppColors.dot3];
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          border: Border.all(color: AppColors.border, width: 0.5),
          borderRadius: BorderRadius.circular(AppDims.bubble),
          boxShadow: AppShadows.bulle,
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final phase = (_c.value - i * 0.18) % 1.0;
              final montee = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
              return Padding(
                padding: EdgeInsets.only(right: i < 2 ? 4 : 0),
                child: Transform.translate(
                  offset: Offset(0, -2.5 * montee),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: couleurs[i],
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}