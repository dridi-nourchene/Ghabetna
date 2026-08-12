import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../data/chat_models.dart';

/// Bulle de l'utilisateur : fond bleu clair, coin bas-droit rentré.
class UserBubble extends StatelessWidget {
  const UserBubble({super.key, required this.texte});
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: const BoxDecoration(
            color: AppColors.bubbleUserBg,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppDims.bubble),
              topRight: Radius.circular(AppDims.bubble),
              bottomLeft: Radius.circular(AppDims.bubble),
              bottomRight: Radius.circular(AppDims.bubbleTail),
            ),
          ),
          child: Text(
            texte,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte de réponse : liseré bleu à gauche, bandeau de verdict, corps de
/// texte, encart « prochaine ouverture », ligne de sources dépliable.
///
/// Le bandeau et l'encart n'apparaissent que si le serveur a renvoyé un
/// verdict, c'est-à-dire quand la question portait à la fois sur une espèce
/// et une date. Sinon la carte se réduit au texte et aux sources.
class AssistantBubble extends StatefulWidget {
  const AssistantBubble({super.key, required this.message});
  final ChatMessage message;

  @override
  State<AssistantBubble> createState() => _AssistantBubbleState();
}

class _AssistantBubbleState extends State<AssistantBubble> {
  bool _sourcesOuvertes = false;

  static const _mois = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];

  static const _jours = [
    'lundi', 'mardi', 'mercredi', 'jeudi',
    'vendredi', 'samedi', 'dimanche',
  ];

  String _formatProchaine(DateTime d) {
    final jour = _jours[d.weekday - 1];
    return '$jour ${d.day} ${_mois[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.message;

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.90,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: const BoxDecoration(
            color: AppColors.surface2,
            border: Border(
              top: BorderSide(color: AppColors.border, width: 0.5),
              right: BorderSide(color: AppColors.border, width: 0.5),
              bottom: BorderSide(color: AppColors.border, width: 0.5),
              // Liseré d'accent : plus épais, il ancre la carte à gauche.
              left: BorderSide(color: AppColors.accentBlue, width: 3),
            ),
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(AppDims.bubble),
              bottomRight: Radius.circular(AppDims.bubble),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (m.verdict != null) _bandeauVerdict(m.verdict!),
              Text(
                m.texte,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: m.enErreur
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
              if (m.verdict?.prochaine != null)
                _encartProchaine(m.verdict!.prochaine!),
              if (m.sources.isNotEmpty) _ligneSources(m.sources),
              if (_sourcesOuvertes) ..._extraits(m.sources),
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
  /// calculée côté serveur par rag/calendrier.py.
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

  Widget _ligneSources(List<Source> sources) {
    // On n'affiche que la première : le retrieval remonte huit extraits,
    // dont certains sans rapport. Le reste est accessible au dépliage.
    final libelle = sources.length == 1
        ? sources.first.libelleCourt
        : '${sources.first.libelleCourt} et ${sources.length - 1} autre'
            '${sources.length > 2 ? 's' : ''}';

    return GestureDetector(
      onTap: () => setState(() => _sourcesOuvertes = !_sourcesOuvertes),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 9),
        child: Row(
          children: [
            const Icon(Icons.menu_book_outlined,
                size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                libelle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Icon(
              _sourcesOuvertes ? Icons.expand_less : Icons.expand_more,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _extraits(List<Source> sources) {
    return sources.map((s) {
      return Container(
        margin: const EdgeInsets.only(top: 7),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface0,
          borderRadius: BorderRadius.circular(AppDims.info),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.libelleCourt,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.accentBlueDark,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              s.extrait,
              style: const TextStyle(
                fontSize: 11,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }).toList();
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: AppColors.infoBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_outlined,
                size: 15, color: AppColors.accentBlueDark),
          ),
          const SizedBox(width: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              border: Border.all(color: AppColors.border, width: 0.5),
              borderRadius: BorderRadius.circular(14),
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
        ],
      ),
    );
  }
}
