import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_exception.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/bouton_principal.dart';
import '../../../core/widgets/courbe_header.dart';
import '../data/auth_api.dart';
import '../data/inscription_form.dart';
import 'ecran_confirmation.dart';
import 'etapes/etape_identite.dart';
import 'etapes/etape_justificatifs.dart';
import 'etapes/etape_recapitulatif.dart';
import 'etapes/etape_specialite.dart';

/// Les quatre étapes vivent dans UN SEUL écran, pas dans quatre routes.
///
/// Raison : l'état doit survivre aux allers-retours. Avec quatre routes,
/// revenir corriger le CIN depuis le récapitulatif détruirait les fichiers
/// déjà choisis. Ici tout est conservé dans ce State.
///
/// Même logique pour les TextEditingController : ils sont déclarés ICI et
/// passés aux étapes. Si chaque étape créait les siens, changer de page les
/// détruirait et le texte saisi disparaîtrait.
class InscriptionScreen extends StatefulWidget {
  const InscriptionScreen({super.key});

  @override
  State<InscriptionScreen> createState() => _InscriptionScreenState();
}

class _InscriptionScreenState extends State<InscriptionScreen> {
  final _form = InscriptionForm();
  final _pageController = PageController();
  final _api = const AuthApi();

  int _etape = 0;
  bool _envoiEnCours = false;
  String? _erreur;

  // Une clé de validation par étape contenant des champs. L'étape 2
  // (spécialité) et l'étape 4 (récapitulatif) n'en ont pas besoin.
  final _cleIdentite = GlobalKey<FormState>();
  final _cleJustificatifs = GlobalKey<FormState>();

  // ── Champs de saisie ────────────────────────────────────────────────
  final ctrlNom = TextEditingController();
  final ctrlCin = TextEditingController();
  final ctrlEmail = TextEditingController();
  final ctrlTelephone = TextEditingController();
  final ctrlMotDePasse = TextEditingController();
  final ctrlConfirmation = TextEditingController();
  final ctrlDelegation = TextEditingController();
  final ctrlSecteur = TextEditingController();
  final ctrlAdresse = TextEditingController();

  final ctrlPermisChasse = TextEditingController();
  final ctrlGouvDelivrance = TextEditingController();
  final ctrlPermisDetention = TextEditingController();
  final ctrlPermisPort = TextEditingController();

  final ctrlCodeApiculteur = TextEditingController();
  final ctrlCodeDelegation = TextEditingController();
  final ctrlCodeGouvernorat = TextEditingController();
  final ctrlNbRuchers = TextEditingController();
  final ctrlNbColonies = TextEditingController();

  @override
  void dispose() {
    // Un controller non libéré garde de la mémoire pour rien. Flutter
    // affiche un avertissement en mode debug si on l'oublie.
    for (final c in [
      ctrlNom, ctrlCin, ctrlEmail, ctrlTelephone, ctrlMotDePasse,
      ctrlConfirmation, ctrlDelegation, ctrlSecteur, ctrlAdresse,
      ctrlPermisChasse, ctrlGouvDelivrance, ctrlPermisDetention,
      ctrlPermisPort, ctrlCodeApiculteur, ctrlCodeDelegation,
      ctrlCodeGouvernorat, ctrlNbRuchers, ctrlNbColonies,
    ]) {
      c.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  /// Appelée par les étapes après chaque modification : redessine l'écran
  /// pour que le bouton et la progression reflètent l'état courant.
  void _rafraichir() => setState(() {});

  // ── Navigation entre étapes ─────────────────────────────────────────

  void _suivant() {
    FocusScope.of(context).unfocus();

    if (_etape == 0) {
      if (!_cleIdentite.currentState!.validate()) return;
      _lireIdentite();
    }

    if (_etape == 1 && _form.specialite == null) {
      setState(() => _erreur = 'Choisissez votre spécialité');
      return;
    }

    if (_etape == 2) {
      if (!_cleJustificatifs.currentState!.validate()) return;
      if (!_form.documentsComplets) {
        setState(() => _erreur = 'Joignez tous les documents demandés');
        return;
      }
      _lireJustificatifs();
    }

    setState(() {
      _erreur = null;
      _etape++;
    });
    _pageController.animateToPage(
      _etape,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _precedent() {
    FocusScope.of(context).unfocus();
    if (_etape == 0) {
      context.go('/login');
      return;
    }
    setState(() {
      _erreur = null;
      _etape--;
    });
    _pageController.animateToPage(
      _etape,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// Aller directement à une étape depuis le récapitulatif (« Modifier »).
  void _allerA(int etape) {
    setState(() {
      _erreur = null;
      _etape = etape;
    });
    _pageController.jumpToPage(etape);
  }

  // ── Recopie des champs vers le formulaire ───────────────────────────
  // On lit les controllers au moment de quitter l'étape plutôt qu'à chaque
  // frappe : moins de reconstructions, et le formulaire reste la seule
  // source de vérité au moment de l'envoi.

  void _lireIdentite() {
    _form
      ..nomComplet = ctrlNom.text
      ..cin = ctrlCin.text
      ..email = ctrlEmail.text
      ..telephone = ctrlTelephone.text
      ..motDePasse = ctrlMotDePasse.text
      ..delegation = ctrlDelegation.text
      ..secteur = ctrlSecteur.text
      ..adresse = ctrlAdresse.text;
  }

  void _lireJustificatifs() {
    _form
      ..numeroPermisChasse = ctrlPermisChasse.text
      ..gouvernoratDelivrance = ctrlGouvDelivrance.text
      ..numeroPermisDetention = ctrlPermisDetention.text
      ..numeroPermisPortTransport = ctrlPermisPort.text
      ..codeApiculteur = ctrlCodeApiculteur.text
      ..codeDelegation = ctrlCodeDelegation.text
      ..codeGouvernorat = ctrlCodeGouvernorat.text
      ..nombreRuchers = int.tryParse(ctrlNbRuchers.text)
      ..nombreColonies = int.tryParse(ctrlNbColonies.text);
  }

  // ── Envoi final ─────────────────────────────────────────────────────

  Future<void> _envoyer() async {
    setState(() {
      _envoiEnCours = true;
      _erreur = null;
    });

    try {
      final reponse = await _api.inscrire(
        champs: _form.versChamps(),
        documents: _form.documents,
      );

      if (!mounted) return;
      // pushReplacement : le citoyen ne doit pas pouvoir revenir sur le
      // formulaire avec le bouton retour, son dossier est déjà parti.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EcranConfirmation(
            profilId: reponse['profil_id']?.toString() ?? '',
          ),
        ),
      );
    } on ApiException catch (e) {
      // 409 = CIN ou email déjà utilisé → il faut revenir à l'étape 1.
      // 400 = document ou champ manquant → étape 3.
      if (!mounted) return;
      setState(() {
        _envoiEnCours = false;
        _erreur = e.message;
      });
      if (e.statusCode == 409) _allerA(0);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _envoiEnCours = false;
        _erreur = 'Envoi impossible. Vérifiez votre connexion.';
      });
    }
  }

  // ── Construction ────────────────────────────────────────────────────

  static const _titres = [
    ('Créer un compte', 'vos informations'),
    ('Votre spécialité', 'un seul choix'),
    ('Justificatifs', 'documents à fournir'),
    ('Vérifiez vos informations', 'avant envoi'),
  ];

  @override
  Widget build(BuildContext context) {
    final (titre, sousTitre) = _etape == 2 && _form.specialite != null
        ? (_form.specialite!.libelle, 'documents à fournir')
        : _titres[_etape];

    return Scaffold(
      backgroundColor: AppColors.surface0,
      body: Column(
        children: [
          CourbeHeader(
            hauteur: 132,
            child: Stack(
              children: [
                Positioned(
                  left: 16,
                  top: 4,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: AppColors.authBlanc, size: 22),
                    onPressed: _envoiEnCours ? null : _precedent,
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      titre,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: AppColors.authBlanc,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Étape ${_etape + 1} sur 4 · $sousTitre',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.authVertPale,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Progression(etape: _etape),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: PageView(
              controller: _pageController,
              // L'utilisateur ne fait pas défiler à la main : on valide
              // chaque étape avant de laisser passer à la suivante.
              physics: const NeverScrollableScrollPhysics(),
              children: [
                EtapeIdentite(
                  cle: _cleIdentite,
                  form: _form,
                  ctrlNom: ctrlNom,
                  ctrlCin: ctrlCin,
                  ctrlEmail: ctrlEmail,
                  ctrlTelephone: ctrlTelephone,
                  ctrlMotDePasse: ctrlMotDePasse,
                  ctrlConfirmation: ctrlConfirmation,
                  ctrlDelegation: ctrlDelegation,
                  ctrlSecteur: ctrlSecteur,
                  ctrlAdresse: ctrlAdresse,
                  onModif: _rafraichir,
                ),
                EtapeSpecialite(form: _form, onModif: _rafraichir),
                EtapeJustificatifs(
                  cle: _cleJustificatifs,
                  form: _form,
                  ctrlPermisChasse: ctrlPermisChasse,
                  ctrlGouvDelivrance: ctrlGouvDelivrance,
                  ctrlPermisDetention: ctrlPermisDetention,
                  ctrlPermisPort: ctrlPermisPort,
                  ctrlCodeApiculteur: ctrlCodeApiculteur,
                  ctrlCodeDelegation: ctrlCodeDelegation,
                  ctrlCodeGouvernorat: ctrlCodeGouvernorat,
                  ctrlNbRuchers: ctrlNbRuchers,
                  ctrlNbColonies: ctrlNbColonies,
                  onModif: _rafraichir,
                ),
                EtapeRecapitulatif(form: _form, onModifier: _allerA),
              ],
            ),
          ),

          // Barre d'action fixe en bas : le bouton reste atteignable au
          // pouce même quand la page défile.
          Container(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
            color: AppColors.surface0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_erreur != null) _Banniere(message: _erreur!),
                BoutonPrincipal(
                  libelle:
                      _etape == 3 ? 'Envoyer mon dossier' : 'Continuer',
                  enChargement: _envoiEnCours,
                  onPressed: _etape == 3 ? _envoyer : _suivant,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Quatre barres ; celle de l'étape courante est allongée. Se lit d'un coup
/// d'œil, sans avoir à compter des points.
class _Progression extends StatelessWidget {
  const _Progression({required this.etape});
  final int etape;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final active = i <= etape;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: i == etape ? 20 : 8,
          height: 4,
          decoration: BoxDecoration(
            color: active
                ? AppColors.authBlanc
                : AppColors.authBlanc.withOpacity(0.45),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

class _Banniere extends StatelessWidget {
  const _Banniere({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        border: Border.all(color: AppColors.errorBorder, width: 0.5),
        borderRadius: BorderRadius.circular(AppDims.controle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.errorText),
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
