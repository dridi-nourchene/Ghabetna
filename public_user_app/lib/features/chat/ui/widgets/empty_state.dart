import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../data/chat_models.dart';

/// État initial : le robot, un mot d'accueil, trois suggestions.
///
/// Les suggestions ne sont pas décoratives : elles apprennent en une seconde
/// le périmètre de l'assistant (réglementation du métier + aide de
/// l'application) et remplissent le cache de réponses avant une démonstration.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.specialite,
    required this.onSuggestion,
  });

  final Specialite specialite;
  final void Function(String) onSuggestion;

  static const _suggestionsCommunes = [
    (Icons.warning_amber_outlined, 'Comment signaler un incendie ?'),
    (Icons.monetization_on_outlined, 'Comment je gagne des coins ?'),
  ];

  List<(IconData, String)> get _suggestions => switch (specialite) {
        Specialite.chasseur => [
            (Icons.calendar_today_outlined,
                'Quelle est la période de chasse du sanglier ?'),
            ..._suggestionsCommunes,
          ],
        Specialite.apiculteur => [
            (Icons.place_outlined, 'Où puis-je installer mes ruches ?'),
            ..._suggestionsCommunes,
          ],
        Specialite.campeur => [
            (Icons.park_outlined, 'Où puis-je camper en forêt ?'),
            ..._suggestionsCommunes,
          ],
      };

  String get _sousTitre => switch (specialite) {
        Specialite.chasseur =>
          'Réglementation de la chasse, ou fonctionnement de l\'application.',
        Specialite.apiculteur =>
          'Réglementation apicole, ou fonctionnement de l\'application.',
        Specialite.campeur =>
          'Réglementation du camping, ou fonctionnement de l\'application.',
      };

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
      children: [
        Center(
          child: SizedBox(
            height: 104,
            child: Image.asset(
              'assets/images/robot_ghabetna.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.smart_toy_outlined,
                size: 72,
                color: AppColors.forestTree,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Bonjour, je suis votre assistant',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _sousTitre,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            height: 1.6,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        ..._suggestions.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: GestureDetector(
              onTap: () => onSuggestion(s.$2),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.infoBg,
                  borderRadius: BorderRadius.circular(AppDims.suggestion),
                  border: Border.all(
                    color: AppColors.suggestionBorder,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(s.$1, size: 15, color: AppColors.accentBlueDark),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        s.$2,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.infoText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
