#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
rag/calendrier.py — CALCUL DETERMINISTE DES DATES DE CHASSE
============================================================

POURQUOI CE MODULE EXISTE
--------------------------
Repondre a "puis-je chasser le sanglier le 21 janvier ?" demande de croiser
sept conditions :

    1. l'espece                      -> quelle periode d'ouverture
    2. la periode                    -> art. 1 de l'arrete
    3. le jour de la semaine         -> art. 4
    4. les jours feries              -> art. 4
    5. l'exception du 15 octobre     -> Ariana et Bizerte, art. 4
    6. le statut du chasseur         -> art. 18 pour les touristes
    7. la date du jour               -> la saison est-elle encore ouverte ?

Un LLM ne fait pas cette chaine de facon fiable. Il en produit une
approximation plausible, ce qui est PIRE qu'un refus : l'utilisateur ne peut
pas distinguer une reponse juste d'une reponse fausse.

Ici le calcul est du code Python : deterministe, testable, auditable. Le LLM
recoit le VERDICT deja calcule et se contente de le rediger.

CE QUE CE MODULE NE FAIT PAS
-----------------------------
- Les reserves de chasse de l'article 12 (~800 toponymes) : trop de variantes
  d'orthographe pour une correspondance fiable. Le verdict le signale.
- Les fetes religieuses, qui suivent le calendrier lunaire.
Dans les deux cas on le DIT au lieu de deviner.
"""

from __future__ import annotations

import re
import unicodedata
from datetime import date, timedelta

# ============================================================================
# DONNEES — arrete du 27 aout 2025, articles 1, 4, 12, 13 et 18
# ============================================================================
# jours : 0 = lundi ... 6 = dimanche (convention date.weekday())

ESPECES: dict[str, dict] = {
    "petit_gibier_sedentaire": {
        "libelle": "Lièvre, perdrix, caille sédentaire, pigeon biset, ganga unibande (El khedra)",
        "mots": ["lievre", "lievres", "perdrix", "perdreau", "perdreaux",
                 "caille sedentaire", "pigeon biset", "ganga unibande",
                 "khedra", "petit gibier"],
        "ouverture": date(2025, 10, 5),
        "fermeture": date(2025, 12, 7),
        "jours": [6],                       # dimanches uniquement
        "jours_libelle": "les dimanches et les jours fériés officiels",
        "article": "1 et 4",
        "touristes": False,                 # non ouvert aux touristes (art. 18)
    },
    "gros_gibier": {
        "libelle": "Gros gibier (sanglier et loup doré africain)",
        "mots": ["sanglier", "sangliers", "gros gibier", "loup dore",
                 "chacal", "chacal dore"],
        "ouverture": date(2025, 10, 5),
        "fermeture": date(2026, 2, 1),
        "jours": [0, 1, 2, 3, 4, 5, 6],     # tous les jours
        "jours_libelle": "tous les jours de la semaine",
        "article": "1 et 4",
        "touristes": True,
        # Huit gouvernorats du sud beneficient d'une fermeture repoussee
        "fermeture_etendue": date(2026, 4, 26),
        "gouvernorats_etendus": ["tozeur", "kebili", "gafsa", "gabes",
                                 "tataouine", "sfax", "sidi bouzid", "kasserine"],
    },
    "pigeon_ramier": {
        "libelle": "Pigeon ramier",
        "mots": ["pigeon ramier", "ramier", "palombe"],
        "ouverture": date(2025, 11, 9),
        "fermeture": date(2026, 3, 15),
        "jours": [2, 3, 4, 5, 6],           # mercredi -> dimanche
        "jours_libelle": "du mercredi au dimanche et les jours fériés officiels",
        "article": "1 et 4",
        "touristes": False,
    },
    "gibier_eau": {
        "libelle": "Gibier d'eau (bécassine, colvert, pilet, siffleur, souchet, "
                   "oie cendrée, sarcelles, fuligule morillon, foulque macroule, pluvier)",
        "mots": ["gibier d eau", "gibier eau", "becassine", "colvert", "pilet",
                 "siffleur", "souchet", "oie cendree", "sarcelle", "sarcelles",
                 "fuligule", "morillon", "foulque", "macroule", "pluvier",
                 "canard", "canards"],
        "ouverture": date(2025, 11, 9),
        "fermeture": date(2026, 3, 15),
        "jours": [2, 3, 4, 5, 6],
        "jours_libelle": "du mercredi au dimanche et les jours fériés officiels",
        "article": "1 et 4",
        "touristes": False,
        "note": "La chasse à la passée débute une heure avant le lever du soleil "
                "et se termine une heure après son coucher (article 1er).",
    },
    "grives_etourneaux": {
        "libelle": "Grives et étourneaux",
        "mots": ["grive", "grives", "etourneau", "etourneaux"],
        "ouverture": date(2025, 11, 9),
        "fermeture": date(2026, 3, 15),
        "jours": [2, 3, 4, 5, 6],
        "jours_libelle": "du mercredi au dimanche et les jours fériés officiels",
        "article": "1 et 4",
        "touristes": True,
        # Les touristes ont une fenetre plus courte (art. 18)
        "ouverture_touristes": date(2025, 12, 7),
        "fermeture_touristes": date(2026, 3, 15),
    },
    "becasse_bois": {
        "libelle": "Bécasse des bois",
        "mots": ["becasse", "becasse des bois"],
        "ouverture": date(2025, 11, 9),
        "fermeture": date(2026, 3, 15),
        "jours": [2, 3, 4, 5, 6],
        "jours_libelle": "du mercredi au dimanche et les jours fériés officiels",
        "article": "1 et 4",
        "touristes": False,
        "note": "Chasse autorisée uniquement dans les zones forestières des "
                "gouvernorats de Manouba, Siliana, Jendouba, Bizerte, Béja, "
                "Nabeul, Le Kef, Ben Arous et Zaghouan, sans battue et sans "
                "poste (article 1er).",
    },
    "caille_epervier": {
        "libelle": "Caille (chasse à l'aide de l'épervier)",
        "mots": ["caille a l epervier", "caille epervier", "chasse a l epervier"],
        "ouverture": date(2026, 4, 5),
        "fermeture": date(2026, 6, 28),
        "jours": [0, 1, 2, 3, 4, 5, 6],
        "jours_libelle": "selon l'article 4",
        "article": "1",
        "touristes": False,
        "note": "Uniquement dans le gouvernorat de Nabeul (article 1er).",
    },
    "tourterelle": {
        "libelle": "Tourterelle de passage et sédentaire, pigeon biset",
        "mots": ["tourterelle", "tourterelles"],
        "ouverture": date(2026, 7, 26),
        "fermeture": date(2026, 9, 20),
        "jours": [2, 3, 4, 5, 6],           # mercredi -> samedi (15h) + dimanche
        "jours_libelle": "du mercredi au samedi à partir de 15h, et toute la "
                         "journée les dimanches et jours fériés officiels",
        "article": "1 et 4",
        "touristes": False,
    },
    "gangas": {
        "libelle": "Ganga cata (Bou Herba), ganga tacheté (Bou Sboula), "
                   "ganga couronné (El Ghanay)",
        "mots": ["ganga cata", "bou herba", "ganga tachete", "bou sboula",
                 "ganga couronne", "ghanay", "ganga", "gangas"],
        "ouverture": date(2026, 7, 26),
        "fermeture": date(2026, 9, 20),
        "jours": [2, 3, 4, 5, 6],
        "jours_libelle": "du mercredi au dimanche et les jours fériés officiels",
        "article": "1 et 4",
        "touristes": False,
    },
}

# Jours feries civils tunisiens a date fixe.
# Les fetes religieuses (Aid, Mouled) suivent le calendrier lunaire : elles ne
# sont PAS calculees ici, et le verdict le signale explicitement.
FERIES_FIXES = {
    (1, 1):   "Nouvel An",
    (3, 20):  "Fête de l'Indépendance",
    (4, 9):   "Journée des Martyrs",
    (5, 1):   "Fête du Travail",
    (7, 25):  "Fête de la République",
    (8, 13):  "Fête de la Femme",
    (10, 15): "Fête de l'Évacuation",
}

def _jour(n: int) -> str:
    """1 -> '1er', les autres inchanges (usage francais des dates)."""
    return "1er" if n == 1 else str(n)


def fmt(d: date) -> str:
    return f"{_jour(d.day)} {MOIS_FR[d.month - 1]} {d.year}"


JOURS_FR = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"]
MOIS_FR = ["janvier", "février", "mars", "avril", "mai", "juin", "juillet",
           "août", "septembre", "octobre", "novembre", "décembre"]


# ============================================================================
# DETECTION DANS LA QUESTION
# ============================================================================

def _plier(txt: str) -> str:
    t = unicodedata.normalize("NFD", txt.lower())
    return "".join(c for c in t if unicodedata.category(c) != "Mn")


def detecter_espece(question: str) -> str | None:
    """
    Trouve l'espece citee. On teste les mots les PLUS LONGS d'abord :
    "caille a l epervier" doit gagner sur "caille", et "pigeon ramier" sur
    "pigeon biset".
    """
    q = _plier(question)
    candidats = []
    for cle, info in ESPECES.items():
        for mot in info["mots"]:
            if mot in q:
                candidats.append((len(mot), cle))
    if not candidats:
        return None
    return max(candidats)[1]


MOIS_MOTS = {m: i + 1 for i, m in enumerate(
    ["janvier", "fevrier", "mars", "avril", "mai", "juin", "juillet",
     "aout", "septembre", "octobre", "novembre", "decembre"])}


def detecter_date(question: str, aujourd_hui: date | None = None) -> date | None:
    """
    Reconnait :
        "aujourd'hui", "demain", "ce week-end"
        "le 21 janvier", "21 janvier 2026"
        "21/01/2026", "21-01-2026"
    Sans annee explicite, on prend celle qui place la date dans la saison en
    cours ou a venir.
    """
    aujourd_hui = aujourd_hui or date.today()
    q = _plier(question)

    if "aujourd hui" in q or "aujourdhui" in q or "maintenant" in q:
        return aujourd_hui
    if "demain" in q:
        return aujourd_hui + timedelta(days=1)

    # 21/01/2026 ou 21-01-2026
    m = re.search(r"\b(\d{1,2})[/-](\d{1,2})[/-](\d{4})\b", q)
    if m:
        j, mo, a = int(m.group(1)), int(m.group(2)), int(m.group(3))
        try:
            return date(a, mo, j)
        except ValueError:
            return None

    # "21 janvier" ou "21 janvier 2026"
    m = re.search(r"\b(\d{1,2})\s+(" + "|".join(MOIS_MOTS) + r")\b(?:\s+(\d{4}))?", q)
    if m:
        j, mo = int(m.group(1)), MOIS_MOTS[m.group(2)]
        if m.group(3):
            annee = int(m.group(3))
        else:
            # Pas d'annee : on choisit celle qui tombe dans la saison courante.
            annee = aujourd_hui.year
            try:
                candidate = date(annee, mo, j)
            except ValueError:
                return None
            if candidate < aujourd_hui - timedelta(days=180):
                annee += 1
        try:
            return date(annee, mo, j)
        except ValueError:
            return None

    return None


# ============================================================================
# CALCUL DU VERDICT
# ============================================================================

def _conclusion(autorise, passee: bool, libelle: str, d: date,
                motif: str) -> str:
    """
    Phrase unique, en francais courant, que le LLM n'a plus qu'a reformuler.

    POURQUOI : sans elle, le modele reconstruit son propre raisonnement a
    partir des puces du verdict et se trompe. Observe en conditions reelles :
    il avait ecrit "demain est un mercredi" pour un mardi, en inventant au
    passage une histoire d'horaire matinal. La conclusion arrivait juste,
    mais par un chemin faux — ce qu'un utilisateur ne peut pas detecter.
    """
    jour = JOURS_FR[d.weekday()]
    quand = f"le {fmt(d)} ({jour})"

    # On ecrit "chasse de X" sans article defini : le libelle contient des
    # genres et des nombres varies ("la tourterelle", "les gangas"), un
    # article fige produirait des fautes d'accord.
    esp = libelle.lower()

    if passee:
        if autorise:
            return (f"Cette date est passée. À l'époque, la chasse — {esp} — "
                    f"y était ouverte, mais {quand} est révolu : consultez "
                    f"l'arrêté de la saison en cours.")
        return (f"Cette date est passée, et la chasse — {esp} — n'y était de "
                f"toute façon pas autorisée : {motif}")
    if autorise:
        return f"Oui, la chasse est autorisée {quand} pour : {esp}."
    return f"Non, la chasse n'est pas autorisée {quand} pour {esp} : {motif}"


def _est_ferie(d: date) -> str | None:
    return FERIES_FIXES.get((d.month, d.day))


def chasse_autorisee(espece: str, d: date, gouvernorat: str | None = None,
                     statut: str = "resident",
                     aujourd_hui: date | None = None) -> dict:
    """
    Verdict structure pour une espece, une date, un lieu et un statut.

    statut : "resident" (tunisien ou resident) ou "touriste".

    Retourne un dictionnaire avec :
        autorise    True / False / None (None = indeterminable)
        raisons     liste des constats, dans l'ordre du raisonnement
        reserves    points que le calcul NE COUVRE PAS
    """
    aujourd_hui = aujourd_hui or date.today()
    info = ESPECES.get(espece)
    if not info:
        return {"autorise": None, "passee": False, "conclusion": "",
                "raisons": ["Espèce non reconnue."], "reserves": []}

    raisons: list[str] = []
    reserves: list[str] = []
    gouv = _plier(gouvernorat or "")

    # --- 1. la date est-elle passee ? -------------------------------------
    # Etat DISTINCT de "autorise". Dire "autorise" d'une date revolue serait
    # trompeur : l'utilisateur comprendrait qu'il peut y aller.
    passee = d < aujourd_hui
    if passee:
        raisons.append(
            f"Cette date est passée (nous sommes le {fmt(aujourd_hui)}). "
            f"Ce qui suit est un constat sur la saison écoulée, pas une "
            f"autorisation. Pour la saison en cours, consultez le nouvel "
            f"arrêté annuel auprès de la Direction générale des forêts.")

    # --- 2. periode d'ouverture -------------------------------------------
    ouverture, fermeture = info["ouverture"], info["fermeture"]

    if statut == "touriste":
        if not info.get("touristes"):
            motif = ("l'article 18 de l'arrêté n'ouvre la chasse touristique "
                     "qu'au gros gibier et aux grives et étourneaux.")
            return {
                "autorise": False, "passee": d < aujourd_hui,
                "raisons": [f"{info['libelle']} : {motif}"],
                "reserves": [],
                "conclusion": _conclusion(False, d < aujourd_hui,
                                          info["libelle"], d, motif),
            }
        ouverture = info.get("ouverture_touristes", ouverture)
        fermeture = info.get("fermeture_touristes", fermeture)

    # Fermeture repoussee dans les huit gouvernorats du sud (gros gibier)
    if "fermeture_etendue" in info and gouv:
        if any(g in gouv for g in info["gouvernorats_etendus"]):
            fermeture = info["fermeture_etendue"]
            raisons.append(
                f"Le gouvernorat cité fait partie des huit gouvernorats du sud "
                f"où la fermeture est repoussée au {fmt(fermeture)}.")
    elif "fermeture_etendue" in info and not gouv:
        reserves.append(
            f"Dans les gouvernorats de Tozeur, Kébili, Gafsa, Gabès, Tataouine, "
            f"Sfax, Sidi Bouzid et Kasserine, la fermeture est repoussée au "
            f"{fmt(info['fermeture_etendue'])}.")

    periode = f"du {fmt(ouverture)} au {fmt(fermeture)}"

    if not (ouverture <= d <= fermeture):
        motif = (f"la période d'ouverture est {periode} (article "
                 f"{info['article']} de l'arrêté), et cette date est en dehors.")
        raisons.append(f"{info['libelle']} : {motif}")
        return {"autorise": False, "passee": passee, "raisons": raisons,
                "reserves": reserves,
                "conclusion": _conclusion(False, passee, info["libelle"], d, motif)}

    raisons.append(
        f"{info['libelle']} : la date est dans la période d'ouverture, {periode} "
        f"(article {info['article']} de l'arrêté).")

    # --- 3. jour de la semaine --------------------------------------------
    jour_nom = JOURS_FR[d.weekday()]
    ferie = _est_ferie(d)

    if d.weekday() in info["jours"]:
        raisons.append(
            f"Le {fmt(d)} est un {jour_nom}, "
            f"jour autorisé : la chasse est permise {info['jours_libelle']}.")
    elif ferie:
        raisons.append(
            f"Le {jour_nom} n'est pas un jour de chasse ordinaire, mais cette "
            f"date est un jour férié officiel ({ferie}), ce qui l'autorise.")
    else:
        motif = (f"c'est un {jour_nom}, or cette espèce ne se chasse que "
                 f"{info['jours_libelle']} (article 4 de l'arrêté).")
        raisons.append(f"Le {fmt(d)} : {motif}")
        reserves.append(
            "Les fêtes religieuses suivent le calendrier lunaire : si cette "
            "date en est une, la chasse serait autorisée. Invitez "
            "l'utilisateur à le vérifier.")
        return {"autorise": False, "passee": passee, "raisons": raisons,
                "reserves": reserves,
                "conclusion": _conclusion(False, passee, info["libelle"], d, motif)}

    # --- 4. exception du 15 octobre 2025 ----------------------------------
    if d == date(2025, 10, 15) and espece in ("gros_gibier", "petit_gibier_sedentaire"):
        if not gouv or any(g in gouv for g in ("ariana", "bizerte")):
            raisons.append(
                "L'article 4 interdit la chasse le 15 octobre 2025 dans les "
                "gouvernorats d'Ariana et de Bizerte.")
            if gouv:
                motif = ("l'article 4 interdit la chasse le 15 octobre 2025 "
                         "dans les gouvernorats d'Ariana et de Bizerte.")
                return {"autorise": False, "passee": passee, "raisons": raisons,
                        "reserves": reserves,
                        "conclusion": _conclusion(False, passee, info["libelle"],
                                                  d, motif)}
            reserves.append("Interdiction spécifique à Ariana et Bizerte ce jour-là.")

    # --- 5. reserves systematiques ----------------------------------------
    reserves.append(
        "L'article 12 ferme la chasse dans de nombreuses réserves listées par "
        "gouvernorat ; l'article 13 y maintient toutefois le gros gibier, le "
        "gibier d'eau et le gibier de passage. Vérifiez que le lieu précis "
        "n'y figure pas.")
    if info.get("note"):
        reserves.append(info["note"])

    return {"autorise": True, "passee": passee, "raisons": raisons,
            "reserves": reserves,
            "conclusion": _conclusion(True, passee, info["libelle"], d, "")}


# ============================================================================
# MISE EN FORME POUR LE LLM
# ============================================================================

def verdict_texte(verdict: dict) -> str:
    """
    Transforme le verdict en bloc de texte injecte dans le prompt.

    Le LLM recoit ce bloc comme une SOURCE FAISANT AUTORITE : il doit le
    reprendre, pas le recalculer.
    """
    # Trois etats, et non deux : une date PASSEE ne doit jamais s'annoncer
    # "autorisée", meme si elle tombait dans la periode a l'epoque.
    if verdict.get("passee"):
        if verdict["autorise"] is True:
            entete = ("VERDICT CALCULÉ : DATE PASSÉE — la chasse était alors "
                      "ouverte, mais cette date est révolue")
        else:
            entete = ("VERDICT CALCULÉ : DATE PASSÉE — la chasse n'était de "
                      "toute façon pas autorisée ce jour-là")
    elif verdict["autorise"] is True:
        entete = "VERDICT CALCULÉ : AUTORISÉ"
    elif verdict["autorise"] is False:
        entete = "VERDICT CALCULÉ : NON AUTORISÉ"
    else:
        entete = "VERDICT CALCULÉ : INDÉTERMINÉ"

    lignes = [entete, ""]
    # La conclusion arrive AVANT le detail : c'est la phrase que le LLM doit
    # reprendre. Placee en fin de bloc, elle serait noyee dans les puces et
    # le modele reconstruirait son propre raisonnement.
    if verdict.get("conclusion"):
        lignes.append(f"RÉPONSE À DONNER (à reformuler, sans en changer le "
                      f"sens) : {verdict['conclusion']}")
        lignes.append("")
        lignes.append("Détail du raisonnement, à citer si utile :")
    for r in verdict["raisons"]:
        lignes.append(f"- {r}")
    if verdict["reserves"]:
        lignes.append("")
        lignes.append("Réserves (points non couverts par ce calcul) :")
        for r in verdict["reserves"]:
            lignes.append(f"- {r}")
    return "\n".join(lignes)


def analyser_question(question: str, gouvernorat: str | None = None,
                      statut: str = "resident") -> str | None:
    """
    Point d'entree utilise par l'API.

    Retourne le bloc de verdict si la question porte sur une espece ET une
    date. Sinon None : le RAG seul suffit.
    """
    espece = detecter_espece(question)
    if not espece:
        return None
    d = detecter_date(question)
    if not d:
        return None
    return verdict_texte(chasse_autorisee(espece, d, gouvernorat, statut))



def prochaine_ouverture(espece: str, apres: date,
                        gouvernorat: str | None = None,
                        statut: str = "resident") -> date | None:
    """
    Premiere date VALIDE a partir de "apres" : dans la periode ET un jour
    autorise. Permet a l'interface d'afficher "Prochaine ouverture : ..."
    au lieu d'un simple refus.

    On balaie au maximum un an, jour par jour. C'est trivial en cout (365
    iterations) et evite toute arithmetique de calendrier fragile.
    """
    info = ESPECES.get(espece)
    if not info:
        return None
    for delta in range(0, 366):
        d = apres + timedelta(days=delta)
        v = chasse_autorisee(espece, d, gouvernorat, statut, aujourd_hui=apres)
        if v["autorise"] and not v.get("passee"):
            return d
    return None


def analyser_question_struct(question: str, gouvernorat: str | None = None,
                             statut: str = "resident",
                             aujourd_hui: date | None = None) -> dict | None:
    """
    Version STRUCTUREE, destinee a l'interface mobile.

    Retourne None si la question ne porte pas a la fois sur une espece et
    une date. Sinon un dictionnaire directement serialisable :

        etat      "autorise" | "refuse" | "passee"
        titre     phrase courte pour le bandeau ("Non, pas demain")
        texte     le bloc complet injecte dans le prompt du LLM
        prochaine date ISO de la prochaine ouverture, ou None
    """
    aujourd_hui = aujourd_hui or date.today()
    espece = detecter_espece(question)
    if not espece:
        return None
    d = detecter_date(question, aujourd_hui)
    if not d:
        return None

    v = chasse_autorisee(espece, d, gouvernorat, statut, aujourd_hui)

    if v.get("passee"):
        etat, titre = "passee", "Cette date est passée"
    elif v["autorise"]:
        etat = "autorise"
        titre = ("Oui, c'est ouvert aujourd'hui" if d == aujourd_hui
                 else f"Oui, le {fmt(d)}")
    else:
        etat = "refuse"
        if d == aujourd_hui:
            titre = "Non, pas aujourd'hui"
        elif d == aujourd_hui + timedelta(days=1):
            titre = "Non, pas demain"
        else:
            titre = f"Non, pas le {fmt(d)}"

    suivante = None
    if etat != "autorise":
        # On cherche a partir de demain : inutile de reproposer aujourd'hui.
        n = prochaine_ouverture(espece, aujourd_hui + timedelta(days=1),
                                gouvernorat, statut)
        if n:
            suivante = n.isoformat()

    return {
        "etat": etat,
        "titre": titre,
        "texte": verdict_texte(v),
        "prochaine": suivante,
        "espece": ESPECES[espece]["libelle"],
    }