import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Solde de coins du citoyen.
///
/// ─────────────────────────────────────────────────────────────────────
///  CE PROVIDER NE LIT AUCUNE DONNÉE RÉELLE. C'est volontaire, et c'est
///  la seule ligne du projet qui le fait.
/// ─────────────────────────────────────────────────────────────────────
///
/// Aucun des six microservices ne stocke ni ne calcule un solde : il n'y a
/// ni table, ni colonne, ni route. Le système de récompenses fait partie des
/// perspectives du projet, pas de ce qui est livré.
///
/// Pourquoi l'afficher quand même : la notion de coins existe déjà dans le
/// corpus du chatbot (domaine `app` — « comment gagner des coins, convertir
/// en bonus »). Un citoyen qui pose la question obtient une réponse ; ne
/// rien montrer dans l'interface serait plus incohérent que montrer un
/// solde préparatoire.
///
/// Pourquoi un provider et pas une constante posée dans le bandeau : le jour
/// où le service arrive, la bascule tient en une ligne ici. Sinon le nombre
/// se serait dispersé dans le bandeau, puis dans le profil, puis ailleurs.
///
/// Ce qu'il faudra remplacer :
///
///     final portefeuilleProvider = FutureProvider<int>((ref) async {
///       return ref.watch(portefeuilleApiProvider).solde();
///     });
///
/// Le bandeau devra alors gérer les états chargement / erreur, que la
/// version synchrone actuelle n'a pas.
///
/// À DIRE EN SOUTENANCE si la question tombe : « c'est un affichage
/// préparatoire, la source viendra du module de récompenses ». Annoncé,
/// c'est un choix ; découvert, c'est un mensonge d'interface.
const int soldeProvisoire = 240;

final portefeuilleProvider = Provider<int>((ref) => soldeProvisoire);
