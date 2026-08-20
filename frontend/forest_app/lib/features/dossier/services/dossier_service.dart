// features/dossier/services/dossier_service.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:forest_app/core/constants.dart';
import 'package:forest_app/core/token_storage.dart';
import 'package:forest_app/features/dossier/models/dossier_model.dart';

/// Erreur d'API portant son code HTTP.
///
/// Les autres services lèvent un Exception(message) : suffisant quand toutes
/// les erreurs se traitent pareil. Ici non — un 409 signifie « le dossier a
/// déjà été tranché », ce qui appelle un rechargement de l'écran et non un
/// message d'erreur. Sans le code, il faudrait deviner en lisant le texte.
class DossierException implements Exception {
  final int    statut;
  final String message;

  const DossierException(this.statut, this.message);

  /// Le dossier a été traité entre-temps, par un autre admin ou par un
  /// double-clic. L'écran doit se recharger, pas afficher une erreur.
  bool get dejaTraite => statut == 409;

  /// citizen_ms n'a pas pu joindre auth_ms : la décision n'a PAS été
  /// enregistrée, le dossier est resté en attente. On peut réessayer.
  bool get authIndisponible => statut == 503;

  @override
  String toString() => message;
}

class DossierService {
  final _storage = TokenStorage();

  static const String _base = '${ApiConstants.baseUrl}/api/citoyens';

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getAccessToken();
    return {
      'Content-Type':  'application/json',
      'Authorization': 'Bearer ${token ?? ''}',
    };
  }

  /// Décode le corps en UTF-8 explicitement.
  ///
  /// `response.body` se fie au charset du Content-Type. Starlette ne l'ajoute
  /// que pour les types text/*, jamais pour application/json : le paquet http
  /// retombe alors sur latin-1, comme le veut la spécification HTTP. Les
  /// accents deviennent illisibles — « Permis expiré » s'affiche « expirÃ© ».
  ///
  /// Tout ce qui transite ici est en français : noms, motifs de rejet,
  /// emplacements de ruchers. Passer par bodyBytes est indispensable.
  dynamic _json(http.Response r) => jsonDecode(utf8.decode(r.bodyBytes));

  /// Extrait le message d'erreur de FastAPI, quelle que soit sa forme.
  ///
  /// `detail` est une chaîne pour les HTTPException levées à la main, une
  /// liste d'objets pour les erreurs de validation Pydantic.
  DossierException _erreur(http.Response r, String defaut) {
    try {
      final corps  = _json(r);
      final detail = corps is Map ? corps['detail'] : null;

      if (detail is String) return DossierException(r.statusCode, detail);
      if (detail is List && detail.isNotEmpty) {
        final premier = detail.first;
        if (premier is Map && premier['msg'] != null) {
          return DossierException(r.statusCode, premier['msg'].toString());
        }
      }
    } catch (_) {
      // Corps vide ou illisible : on garde le message par défaut.
    }
    return DossierException(r.statusCode, defaut);
  }

  // ── GET /api/citoyens/dossiers ────────────────────────

  /// La file des dossiers, éventuellement filtrée par statut.
  ///
  /// [statut] doit valoir 'en_attente', 'approuve' ou 'rejete' — les valeurs
  /// de l'énumération StatutDossier. Une valeur inconnue fait répondre 422 au
  /// backend, jamais une liste vide.
  ///
  /// L'écran de liste ne s'en sert pas : il charge tout une fois et filtre en
  /// mémoire, pour que changer d'onglet n'attende pas le réseau. Le paramètre
  /// existe pour le jour où le volume l'exigera.
  Future<List<Dossier>> getDossiers({String? statut}) async {
    final uri = Uri.parse('$_base/dossiers').replace(
      queryParameters: statut == null ? null : {'statut': statut},
    );

    final r = await http
        .get(uri, headers: await _authHeaders())
        .timeout(ApiConstants.requestTimeout);

    if (r.statusCode == 200) {
      return (_json(r) as List)
          .map((d) => Dossier.fromJson(d as Map<String, dynamic>))
          .toList();
    }
    throw _erreur(r, 'Impossible de charger les dossiers');
  }

  // ── GET /api/citoyens/dossiers/{profil_id} ────────────

  /// Le dossier complet, avec ses pièces et son sous-profil.
  ///
  /// La liste renvoie déjà tout cela — serialiser_dossier est le même des
  /// deux côtés. On rappelle quand même l'API à l'ouverture du détail :
  /// entre le chargement de la liste et le clic, un autre admin a pu trancher
  /// le dossier. Approuver sur la foi d'une liste vieille de dix minutes est
  /// la meilleure façon de déclencher un 409.
  Future<Dossier> getDossier(String profilId) async {
    final r = await http
        .get(Uri.parse('$_base/dossiers/$profilId'),
            headers: await _authHeaders())
        .timeout(ApiConstants.requestTimeout);

    if (r.statusCode == 200) {
      return Dossier.fromJson(_json(r) as Map<String, dynamic>);
    }
    throw _erreur(r, 'Dossier introuvable');
  }

  // ── PATCH /api/citoyens/dossiers/{profil_id}/decision ─

  /// Approuve ou rejette, et renvoie le dossier tel qu'il est devenu.
  ///
  /// [approuve] est bien un booléen : DecisionIn attend `approuve: bool`, pas
  /// une chaîne 'approuve'. C'est aussi lui qui déclenche, côté backend, le
  /// changement de statut du compte chez auth_ms — active ou rejete.
  ///
  /// Le motif est envoyé UNIQUEMENT en cas de rejet. Sur une approbation,
  /// decider_dossier force motif_rejet à None de toute façon : l'envoyer
  /// serait du bruit.
  ///
  /// Le backend renvoie le DossierOut à jour. L'appelant s'en sert pour
  /// rafraîchir l'écran sans second appel.
  Future<Dossier> decider({
    required String profilId,
    required bool   approuve,
    String?         motifRejet,
  }) async {
    final r = await http
        .patch(
          Uri.parse('$_base/dossiers/$profilId/decision'),
          headers: await _authHeaders(),
          body: jsonEncode({
            'approuve': approuve,
            if (!approuve) 'motif_rejet': motifRejet,
          }),
        )
        .timeout(ApiConstants.requestTimeout);

    if (r.statusCode == 200) {
      return Dossier.fromJson(_json(r) as Map<String, dynamic>);
    }
    throw _erreur(r, 'La décision n\'a pas pu être enregistrée');
  }

  // ── Téléchargement d'une pièce jointe ─────────────────

  /// Récupère les octets d'un document, jeton compris.
  ///
  /// Impossible de passer par Image.network : sur le web, Flutter pose une
  /// balise <img> et c'est le NAVIGATEUR qui va chercher le fichier. Or le
  /// jeton vit dans la mémoire de l'application, pas dans le navigateur — la
  /// requête partirait nue et reviendrait en 401.
  ///
  /// Le chemin /api/citoyens/uploads n'est pas dans les PUBLIC_PATHS du
  /// middleware, contrairement au /uploads d'alert_ms. C'est voulu : un scan
  /// de carte d'identité ne doit pas être lisible par quiconque connaît son
  /// adresse. Le prix est ce téléchargement manuel.
  ///
  /// Délai large : plusieurs mégaoctets peuvent transiter, et la passerelle
  /// relaie le fichier depuis citizen_ms.
  Future<Uint8List> telechargerPiece(String url) async {
    final r = await http
        .get(Uri.parse(_urlPiece(url)), headers: await _authHeaders())
        .timeout(const Duration(seconds: 60));

    if (r.statusCode == 200) return r.bodyBytes;

    if (r.statusCode == 404) {
      throw const DossierException(404, 'Fichier introuvable sur le serveur');
    }
    throw DossierException(r.statusCode, 'Document non chargé');
  }

  /// Remet l'URL d'une pièce sur la bonne route, quelle que soit la config.
  ///
  /// citizen_ms fabrique cette URL avec `BASE_URL + /uploads/ + chemin`. Deux
  /// cas se présentent :
  ///
  ///   BASE_URL renseigné → 'http://.../api/citoyens/uploads/citoyens/...'
  ///                        rien à faire, on l'utilise telle quelle.
  ///
  ///   BASE_URL vide      → '/uploads/citoyens/...'
  ///                        adresse relative qui, envoyée à la passerelle,
  ///                        part chez ALERT_SERVICE_URL et revient en 404.
  ///                        On la réécrit sur le préfixe citoyen.
  ///
  /// La bonne correction reste de renseigner BASE_URL côté serveur. Cette
  /// réécriture évite seulement qu'un oubli de configuration se traduise par
  /// six carrés gris que personne ne sait expliquer.
  String _urlPiece(String url) {
    if (url.startsWith('http')) return url;

    final chemin = url.startsWith('/uploads/')
        ? url.substring('/uploads/'.length)
        : url;

    return '$_base/uploads/$chemin';
  }
}
