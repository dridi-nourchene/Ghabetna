#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
rag/synonymes.py — EXPANSION DE REQUETE
========================================
Le chasseur et le texte officiel ne parlent pas la meme langue :

    l'utilisateur dit        le texte officiel dit
    ----------------------   ---------------------------------
    prix, combien ca coute   redevance domaniale, montant fixe a
    que risque-t-on          est puni de, emprisonnement, amende
    sanglier                 gros gibier
    tuer                     abattre, taxe d'abattage
    chien de chasse          slougui, chiens dresses

Ce decalage explique deux echecs du test de retrieval :
  - "quel est le prix du permis" ne remontait aucun montant chiffre
  - "que risque un chasseur" ne remontait aucune sanction

L'expansion N'EST APPLIQUEE QU'A BM25. On n'y touche pas cote dense :
l'embedding comprend deja les synonymes, et ajouter des mots a la requete
deplacerait son vecteur vers une moyenne floue, ce qui degraderait le
resultat au lieu de l'ameliorer.
"""

from __future__ import annotations

import re
import unicodedata

# Cle = mot de l'utilisateur (sans accents) ; valeur = mots du texte officiel.
SYNONYMES: dict[str, list[str]] = {
    # --- argent -----------------------------------------------------------
    "prix": ["redevance", "montant", "dinars", "cotisation", "perception"],
    "cout": ["redevance", "montant", "dinars"],
    "coute": ["redevance", "montant", "dinars"],
    "payer": ["redevance", "versement", "perception", "dinars"],
    "tarif": ["redevance", "montant", "dinars"],
    "gratuit": ["redevance", "montant"],

    # --- sanctions --------------------------------------------------------
    "risque": ["puni", "peine", "amende", "emprisonnement", "sanction"],
    "risquer": ["puni", "peine", "amende", "emprisonnement"],
    "sanction": ["puni", "peine", "amende", "emprisonnement", "retrait"],
    "punition": ["puni", "peine", "amende", "emprisonnement"],
    "amende": ["puni", "peine", "dinars"],
    "prison": ["emprisonnement", "peine", "puni"],
    "illegal": ["interdit", "prohibe", "crime", "delit"],
    "interdit": ["prohibe", "interdite", "interdites"],

    # --- gibier -----------------------------------------------------------
    "sanglier": ["gros", "gibier", "abattage", "battue"],
    "chacal": ["loup", "dore", "africain", "gros", "gibier"],
    "gros gibier": ["sanglier", "loup", "dore", "africain"],
    "tuer": ["abattre", "abattu", "abattage", "chasser"],
    "tirer": ["abattre", "tir", "chasser"],
    "attraper": ["capturer", "capture", "prise"],

    # --- moyens -----------------------------------------------------------
    "chien": ["slougui", "chiens", "dresses", "meute"],
    "faucon": ["oiseau", "vol", "fauconnier", "rapace", "epervier"],
    "fusil": ["arme", "armes", "feu", "calibre", "cartouches"],
    "arme": ["fusil", "carabine", "categorie", "munitions"],
    "balle": ["cartouches", "munitions", "chevrotine"],

    # --- administratif ----------------------------------------------------
    "permis": ["licence", "autorisation", "delivrance", "prorogation"],
    "licence": ["permis", "autorisation", "delivrance"],
    "papier": ["permis", "licence", "autorisation", "quittance"],
    "inscrire": ["affiliation", "association", "membre", "adhesion"],
    "association": ["federation", "regionale", "chasseurs"],

    # --- temps et lieu ----------------------------------------------------
    "quand": ["date", "periode", "ouverture", "fermeture", "saison"],
    "periode": ["date", "ouverture", "fermeture", "saison"],
    "saison": ["periode", "ouverture", "fermeture"],
    "ou": ["gouvernorat", "zone", "reserve", "perimetre"],
    "region": ["gouvernorat", "zone", "delegation", "imadat"],
    "endroit": ["zone", "lieu", "perimetre", "reserve"],
    "foret": ["forestier", "domaine", "boise"],
    "nuit": ["nocturne", "neige"],
}


def _normaliser(texte: str) -> str:
    """Minuscules sans accents, comme la tokenisation de BM25."""
    t = unicodedata.normalize("NFD", texte.lower())
    return "".join(c for c in t if unicodedata.category(c) != "Mn")


def enrichir(question: str) -> str:
    """
    Ajoute les synonymes officiels a la question, pour BM25 uniquement.

    On CONCATENE au lieu de remplacer : les mots d'origine gardent tout leur
    poids, les synonymes ne font qu'ouvrir des portes supplementaires.

        "quel est le prix du permis de chasse ?"
     -> "quel est le prix du permis de chasse ? redevance montant dinars
         cotisation perception licence autorisation delivrance prorogation"
    """
    q = _normaliser(question)
    mots = set(re.findall(r"[a-z0-9]+", q))
    ajouts: list[str] = []

    for cle, valeurs in SYNONYMES.items():
        # expression de plusieurs mots ("gros gibier") : recherche directe
        if " " in cle:
            if cle in q:
                ajouts.extend(valeurs)
        elif cle in mots:
            ajouts.extend(valeurs)

    if not ajouts:
        return question

    # dedoublonner en preservant l'ordre
    vus, uniques = set(), []
    for a in ajouts:
        if a not in vus:
            vus.add(a)
            uniques.append(a)

    return f"{question} {' '.join(uniques)}"