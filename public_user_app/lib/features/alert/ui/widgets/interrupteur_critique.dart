import 'package:flutter/material.dart';

/// Carte « Incident critique » du formulaire de signalement.
///
/// Toute la carte est cliquable, pas seulement l'interrupteur : la cible
/// est plus grande, ce qui compte quand on signale en marchant.
class InterrupteurCritique extends StatelessWidget {
  const InterrupteurCritique({
    super.key,
    required this.valeur,
    required this.onChange,
  });

  final bool valeur;
  final ValueChanged<bool> onChange;

  static const _rouge = Color(0xFFE05555);
  static const _fond = Color(0xFFFFF5F5);
  static const _bordure = Color(0xFFF6D5D5);
  static const _fondIcone = Color(0xFFFDE8E8);
  static const _titre = Color(0xFF6B8577);
  static const _sousTitre = Color(0xFF8FA896);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChange(!valeur),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _fond,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: valeur ? _rouge.withOpacity(0.55) : _bordure,
            width: valeur ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: _fondIcone,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: _rouge, size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Incident critique',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _titre,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Cochez si la situation nécessite une intervention urgente',
                    style: TextStyle(fontSize: 13, height: 1.35, color: _sousTitre),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Switch(
              value: valeur,
              onChanged: onChange,
              activeColor: _rouge,
              activeTrackColor: _rouge.withOpacity(0.45),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFE3E8E4),
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
            ),
          ],
        ),
      ),
    );
  }
}
