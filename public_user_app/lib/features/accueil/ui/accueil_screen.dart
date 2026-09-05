import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/chat/data/chat_models.dart' show Specialite;
import '../../../features/portefeuille/providers/portefeuille_provider.dart';
import 'widgets/bandeau_accueil.dart';
import 'widgets/carte_action.dart';

/// Point d'arrivée après la connexion.
///
/// Deux actions, rien d'autre. La liste des signalements a été retirée de
/// cet écran : elle appartient à l'onglet « Alertes ». Un écran d'actions qui
/// affiche aussi une liste finit par être ni l'un ni l'autre.
///
/// Le Scaffold et la barre de navigation viennent de la coquille du routeur,
/// pas d'ici : cet écran ne connaît que son propre contenu.
class AccueilScreen extends ConsumerWidget {
  const AccueilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider.select((a) => a.session));
    final solde = ref.watch(portefeuilleProvider);

    // La spécialité vient du JWT sous forme de code ('chasseur'…).
    // fromCode retombe sur chasseur si le claim manque — c'est le
    // comportement déjà en place dans le chat, on ne le change pas ici.
    final specialite = Specialite.fromCode(session?.specialite);

    return Column(
      children: [
        BandeauAccueil(
          nom: session?.nomAffiche ?? '',
          specialite: _libelleCourt(specialite),
          solde: solde,
        ),

        // Les deux cartes sont centrées dans l'espace restant, et non collées
        // sous le bandeau : c'est ce vide qui fait lire l'écran comme un
        // choix entre deux chemins plutôt que comme le haut d'une liste.
        //
        // Expanded + Center plutôt qu'un Spacer de part et d'autre : sur un
        // petit écran en mode paysage, le contenu doit pouvoir défiler au
        // lieu de déborder.
        Expanded(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              // Force le Center à disposer d'au moins la hauteur visible,
              // sinon la colonne se tasse en haut dès qu'elle tient.
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height * 0.42,
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CarteAction(
                        principale: true,
                        titre: 'Signaler une alerte',
                        // Pas d'énumération de types ici : la liste
                        // évoluerait à chaque ajout dans alerttype, et ce
                        // texte serait le dernier endroit qu'on penserait
                        // à mettre à jour.
                        sousTitre: 'Incident, dégât ou activité suspecte',
                        icone: Icons.local_fire_department_outlined,
                        onTap: () => context.go('/signaler'),
                      ),
                      const SizedBox(height: 14),
                      CarteAction(
                        titre: 'Assistant Ghabetna',
                        sousTitre: 'Périodes, permis, réglementation',
                        icone: Icons.forum_outlined,
                        onTap: () => context.go('/chat'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// « Mode chasseur » → « Chasseur ».
  ///
  /// `Specialite.libelle` est écrit pour le chat, où il désigne un mode
  /// d'interrogation du corpus. Dans le bandeau il désigne une personne :
  /// « Mode chasseur » y serait faux. On ne touche pas à l'enum — le
  /// vocabulaire de l'interface reste libre, le code garde celui du backend.
  String _libelleCourt(Specialite s) => switch (s) {
        Specialite.chasseur => 'Chasseur',
        Specialite.campeur => 'Campeur',
        Specialite.apiculteur => 'Apiculteur',
      };
}
