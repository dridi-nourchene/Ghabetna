// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Ghabetna';

  @override
  String get appSubtitle => 'Application Agent DGF';

  @override
  String get loginTitle => 'Connexion';

  @override
  String get loginSubtitle => 'Accédez à votre espace agent';

  @override
  String get loginEmail => 'Email';

  @override
  String get loginEmailHint => 'votre@email.com';

  @override
  String get loginPassword => 'Mot de passe';

  @override
  String get loginButton => 'Se connecter';

  @override
  String get loginEmailRequired => 'Email requis';

  @override
  String get loginEmailInvalid => 'Email invalide';

  @override
  String get loginPasswordRequired => 'Mot de passe requis';

  @override
  String get loginPasswordMin => 'Minimum 6 caractères';

  @override
  String get loginFooter => 'DGF — Direction Générale des Forêts';

  @override
  String get homeGreeting => 'Bonjour';

  @override
  String get homeCreateAlert => 'Déclarer une alerte';

  @override
  String get homeCreateAlertSub =>
      'Signaler un incendie, vol ou autre incident';

  @override
  String get homeMyAlerts => 'Mes alertes';

  @override
  String get homeMyAlertsSub => 'Consulter l\'historique de vos signalements';

  @override
  String get navHome => 'Accueil';

  @override
  String get navAlert => 'Alerte';

  @override
  String get navHistory => 'Historique';

  @override
  String get navLogout => 'Déconnexion';

  @override
  String get logoutTitle => 'Déconnexion';

  @override
  String get logoutMessage => 'Voulez-vous vraiment vous déconnecter ?';

  @override
  String get logoutCancel => 'Annuler';

  @override
  String get logoutConfirm => 'Déconnecter';

  @override
  String get createAlertTitle => 'Déclarer une alerte';

  @override
  String get createAlertType => 'Type d\'alerte *';

  @override
  String get createAlertTypeHint => 'Choisir un type...';

  @override
  String get createAlertForest => 'Forêt concernée *';

  @override
  String get createAlertForestHint => 'Choisir une forêt...';

  @override
  String get createAlertPhoto => 'Photo';

  @override
  String get createAlertAddPhoto => 'Ajouter une photo';

  @override
  String get createAlertCameraOrGallery => 'Caméra ou galerie';

  @override
  String get createAlertDescription => 'Description';

  @override
  String get createAlertDescHint => 'Décrivez l\'incident observé...';

  @override
  String get createAlertSubmit => 'Envoyer l\'alerte';

  @override
  String get createAlertSubmitting => 'Envoi en cours...';

  @override
  String get createAlertSuccess => 'Alerte déclarée avec succès ✅';

  @override
  String get createAlertTypeRequired => 'Veuillez choisir un type d\'alerte';

  @override
  String get createAlertForestRequired => 'Veuillez choisir une forêt';

  @override
  String get createAlertCamera => 'Prendre une photo';

  @override
  String get createAlertGallery => 'Choisir depuis la galerie';

  @override
  String get createAlertChangePhoto => 'Changer la photo';

  @override
  String get createAlertNoForest => 'Aucune forêt disponible';

  @override
  String get createAlertLoading => 'Chargement...';

  @override
  String get myAlertsTitle => 'Mes alertes';

  @override
  String get myAlertsEmpty => 'Aucune alerte déclarée';

  @override
  String get myAlertsEmptySub => 'Vos alertes apparaîtront ici';

  @override
  String get myAlertsRetry => 'Réessayer';

  @override
  String get alertTypeIncendie => 'Incendie';

  @override
  String get alertTypeVol => 'Vol';

  @override
  String get alertTypeInondation => 'Inondation';

  @override
  String get alertTypeGlissement => 'Glissement de terrain';

  @override
  String get alertTypeMaladie => 'Maladie forestière';

  @override
  String get alertTypeDepotDechets => 'Dépôt des déchets';

  @override
  String get alertTypeChasseIllegale => 'Chasse illégale';

  @override
  String get alertTypeActiviteSuspecte => 'Activité suspecte';

  @override
  String get alertTypeAutre => 'Autre';

  @override
  String get alertStatusEnCours => 'En cours';

  @override
  String get alertStatusTraiter => 'Traitée';

  @override
  String get alertStatusRejeter => 'Rejetée';

  @override
  String get statusUpdated => 'Statut mis à jour';

  @override
  String get retry => 'Réessayer';

  @override
  String get cancel => 'Annuler';

  @override
  String get loading => 'Chargement...';
}
