import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/bouton_principal.dart';
import '../../../core/widgets/champ_texte.dart';
import '../../../core/widgets/courbe_header.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _motDePasse = TextEditingController();
  bool _masque = true;

  @override
  void dispose() {
    _email.dispose();
    _motDePasse.dispose();
    super.dispose();
  }

  Future<void> _soumettre() async {
    if (!_formKey.currentState!.validate()) return;
    // Ferme le clavier : sinon la bannière d'erreur apparaît sous les
    // touches et le citoyen ne la voit jamais.
    FocusScope.of(context).unfocus();

    await ref.read(authProvider.notifier).connecter(
          _email.text.trim(),
          _motDePasse.text,
        );
    // Aucune navigation ici : le redirect de go_router s'en charge dès que
    // le statut passe à connecté.
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.surface0,
      // resizeToAvoidBottomInset laisse le clavier pousser le contenu ; le
      // ScrollView évite le débordement sur les petits écrans.
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CourbeHeader(
              hauteur: 150,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'Connexion',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      color: AppColors.authBlanc,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Bienvenue sur Ghabetna',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.authVertPale,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(28, 22, 28, 30),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (auth.erreur != null) _Banniere(message: auth.erreur!),

                    ChampTexte(
                      etiquette: 'Adresse e-mail',
                      controleur: _email,
                      clavier: TextInputType.emailAddress,
                      actionClavier: TextInputAction.next,
                      actif: !auth.enChargement,
                      validateur: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return 'Entrez votre adresse e-mail';
                        if (!t.contains('@') || !t.contains('.')) {
                          return 'Adresse e-mail invalide';
                        }
                        return null;
                      },
                    ),

                    ChampTexte(
                      etiquette: 'Mot de passe',
                      controleur: _motDePasse,
                      motDePasse: _masque,
                      actionClavier: TextInputAction.done,
                      actif: !auth.enChargement,
                      suffixe: IconButton(
                        icon: Icon(
                          _masque
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                          color: AppColors.textMuted,
                        ),
                        onPressed: () => setState(() => _masque = !_masque),
                      ),
                      validateur: (v) => (v == null || v.isEmpty)
                          ? 'Entrez votre mot de passe'
                          : null,
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 22),
                        child: Text(
                          'Mot de passe oublié ?',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.authVert,
                          ),
                        ),
                      ),
                    ),

                    BoutonPrincipal(
                      libelle: 'Se connecter',
                      enChargement: auth.enChargement,
                      onPressed: _soumettre,
                    ),

                    const SizedBox(height: 26),

                    Text(
                      'Pas encore de compte ?',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => context.go('/inscription'),
                      child: const Text(
                        'Créer un compte',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.authVert,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bannière ambre, réutilisant les couleurs d'erreur déjà définies pour le
/// chat. Volontairement distincte du vert : une erreur ne doit jamais
/// ressembler à un élément normal de l'interface.
class _Banniere extends StatelessWidget {
  const _Banniere({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        border: Border.all(color: AppColors.errorBorder, width: 0.5),
        borderRadius: BorderRadius.circular(AppDims.controle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              size: 18, color: AppColors.errorText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppColors.errorText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
