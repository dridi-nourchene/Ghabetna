import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('fr')
  ];

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ghabetna'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Application Agent DGF'**
  String get appSubtitle;

  /// No description provided for @loginTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connexion'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Accédez à votre espace agent'**
  String get loginSubtitle;

  /// No description provided for @loginEmail.
  ///
  /// In fr, this message translates to:
  /// **'Email'**
  String get loginEmail;

  /// No description provided for @loginEmailHint.
  ///
  /// In fr, this message translates to:
  /// **'votre@email.com'**
  String get loginEmailHint;

  /// No description provided for @loginPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get loginPassword;

  /// No description provided for @loginButton.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get loginButton;

  /// No description provided for @loginEmailRequired.
  ///
  /// In fr, this message translates to:
  /// **'Email requis'**
  String get loginEmailRequired;

  /// No description provided for @loginEmailInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Email invalide'**
  String get loginEmailInvalid;

  /// No description provided for @loginPasswordRequired.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe requis'**
  String get loginPasswordRequired;

  /// No description provided for @loginPasswordMin.
  ///
  /// In fr, this message translates to:
  /// **'Minimum 6 caractères'**
  String get loginPasswordMin;

  /// No description provided for @loginFooter.
  ///
  /// In fr, this message translates to:
  /// **'DGF — Direction Générale des Forêts'**
  String get loginFooter;

  /// No description provided for @homeGreeting.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour'**
  String get homeGreeting;

  /// No description provided for @homeCreateAlert.
  ///
  /// In fr, this message translates to:
  /// **'Déclarer une alerte'**
  String get homeCreateAlert;

  /// No description provided for @homeCreateAlertSub.
  ///
  /// In fr, this message translates to:
  /// **'Signaler un incendie, vol ou autre incident'**
  String get homeCreateAlertSub;

  /// No description provided for @homeMyAlerts.
  ///
  /// In fr, this message translates to:
  /// **'Mes alertes'**
  String get homeMyAlerts;

  /// No description provided for @homeMyAlertsSub.
  ///
  /// In fr, this message translates to:
  /// **'Consulter l\'historique de vos signalements'**
  String get homeMyAlertsSub;

  /// No description provided for @navHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get navHome;

  /// No description provided for @navAlert.
  ///
  /// In fr, this message translates to:
  /// **'Alerte'**
  String get navAlert;

  /// No description provided for @navHistory.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get navHistory;

  /// No description provided for @navLogout.
  ///
  /// In fr, this message translates to:
  /// **'Déconnexion'**
  String get navLogout;

  /// No description provided for @logoutTitle.
  ///
  /// In fr, this message translates to:
  /// **'Déconnexion'**
  String get logoutTitle;

  /// No description provided for @logoutMessage.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment vous déconnecter ?'**
  String get logoutMessage;

  /// No description provided for @logoutCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get logoutCancel;

  /// No description provided for @logoutConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Déconnecter'**
  String get logoutConfirm;

  /// No description provided for @createAlertTitle.
  ///
  /// In fr, this message translates to:
  /// **'Déclarer une alerte'**
  String get createAlertTitle;

  /// No description provided for @createAlertType.
  ///
  /// In fr, this message translates to:
  /// **'Type d\'alerte *'**
  String get createAlertType;

  /// No description provided for @createAlertTypeHint.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un type...'**
  String get createAlertTypeHint;

  /// No description provided for @createAlertForest.
  ///
  /// In fr, this message translates to:
  /// **'Forêt concernée *'**
  String get createAlertForest;

  /// No description provided for @createAlertForestHint.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une forêt...'**
  String get createAlertForestHint;

  /// No description provided for @createAlertPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Photo'**
  String get createAlertPhoto;

  /// No description provided for @createAlertAddPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une photo'**
  String get createAlertAddPhoto;

  /// No description provided for @createAlertCameraOrGallery.
  ///
  /// In fr, this message translates to:
  /// **'Caméra ou galerie'**
  String get createAlertCameraOrGallery;

  /// No description provided for @createAlertDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get createAlertDescription;

  /// No description provided for @createAlertDescHint.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez l\'incident observé...'**
  String get createAlertDescHint;

  /// No description provided for @createAlertSubmit.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer l\'alerte'**
  String get createAlertSubmit;

  /// No description provided for @createAlertSubmitting.
  ///
  /// In fr, this message translates to:
  /// **'Envoi en cours...'**
  String get createAlertSubmitting;

  /// No description provided for @createAlertSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Alerte déclarée avec succès ✅'**
  String get createAlertSuccess;

  /// No description provided for @createAlertTypeRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez choisir un type d\'alerte'**
  String get createAlertTypeRequired;

  /// No description provided for @createAlertForestRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez choisir une forêt'**
  String get createAlertForestRequired;

  /// No description provided for @createAlertCamera.
  ///
  /// In fr, this message translates to:
  /// **'Prendre une photo'**
  String get createAlertCamera;

  /// No description provided for @createAlertGallery.
  ///
  /// In fr, this message translates to:
  /// **'Choisir depuis la galerie'**
  String get createAlertGallery;

  /// No description provided for @createAlertChangePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Changer la photo'**
  String get createAlertChangePhoto;

  /// No description provided for @createAlertNoForest.
  ///
  /// In fr, this message translates to:
  /// **'Aucune forêt disponible'**
  String get createAlertNoForest;

  /// No description provided for @createAlertLoading.
  ///
  /// In fr, this message translates to:
  /// **'Chargement...'**
  String get createAlertLoading;

  /// No description provided for @myAlertsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes alertes'**
  String get myAlertsTitle;

  /// No description provided for @myAlertsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune alerte déclarée'**
  String get myAlertsEmpty;

  /// No description provided for @myAlertsEmptySub.
  ///
  /// In fr, this message translates to:
  /// **'Vos alertes apparaîtront ici'**
  String get myAlertsEmptySub;

  /// No description provided for @myAlertsRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get myAlertsRetry;

  /// No description provided for @alertTypeIncendie.
  ///
  /// In fr, this message translates to:
  /// **'Incendie'**
  String get alertTypeIncendie;

  /// No description provided for @alertTypeVol.
  ///
  /// In fr, this message translates to:
  /// **'Vol'**
  String get alertTypeVol;

  /// No description provided for @alertTypeInondation.
  ///
  /// In fr, this message translates to:
  /// **'Inondation'**
  String get alertTypeInondation;

  /// No description provided for @alertTypeGlissement.
  ///
  /// In fr, this message translates to:
  /// **'Glissement de terrain'**
  String get alertTypeGlissement;

  /// No description provided for @alertTypeMaladie.
  ///
  /// In fr, this message translates to:
  /// **'Maladie forestière'**
  String get alertTypeMaladie;

  /// No description provided for @alertTypeDepotDechets.
  ///
  /// In fr, this message translates to:
  /// **'Dépôt des déchets'**
  String get alertTypeDepotDechets;

  /// No description provided for @alertTypeChasseIllegale.
  ///
  /// In fr, this message translates to:
  /// **'Chasse illégale'**
  String get alertTypeChasseIllegale;

  /// No description provided for @alertTypeActiviteSuspecte.
  ///
  /// In fr, this message translates to:
  /// **'Activité suspecte'**
  String get alertTypeActiviteSuspecte;

  /// No description provided for @alertTypeAutre.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get alertTypeAutre;

  /// No description provided for @alertStatusEnCours.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get alertStatusEnCours;

  /// No description provided for @alertStatusTraiter.
  ///
  /// In fr, this message translates to:
  /// **'Traitée'**
  String get alertStatusTraiter;

  /// No description provided for @alertStatusRejeter.
  ///
  /// In fr, this message translates to:
  /// **'Rejetée'**
  String get alertStatusRejeter;

  /// No description provided for @statusUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Statut mis à jour'**
  String get statusUpdated;

  /// No description provided for @retry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @loading.
  ///
  /// In fr, this message translates to:
  /// **'Chargement...'**
  String get loading;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
