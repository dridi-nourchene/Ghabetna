#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
scripts/test_calendrier.py — TESTS DU CALCUL DETERMINISTE
==========================================================
Ne charge ni le modele, ni le reseau, ni Groq : instantane.

Chaque cas verifie une regle differente de l'arrete. C'est la preuve, pour
la soutenance, que le calcul de date est verifiable et non probabiliste.

    python -m scripts.test_calendrier
"""

import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from rag.calendrier import chasse_autorisee, detecter_date, detecter_espece

AUJ = date(2026, 8, 10)

# "passee" et "autorise" sont deux DIMENSIONS INDEPENDANTES :
# une date peut etre passee ET avoir ete ouverte, ou passee ET fermee.
# Chaque cas verifie donc le couple (passee, autorise).
#
# (question, gouvernorat, statut, passee_attendu, autorise_attendu, regle)
CAS = [
    ("chasser la tourterelle le 12 aout 2026 ?", None, "resident",
     False, True,  "periode en cours + mercredi autorise"),
    ("chasser la tourterelle le 10 aout 2026 ?", None, "resident",
     False, False, "lundi : hors jours autorises (art. 4)"),
    ("chasser le sanglier aujourd hui ?", None, "resident",
     False, False, "saison 2025/2026 fermee depuis fevrier"),
    ("chasser le sanglier le 21 janvier 2026 ?", None, "resident",
     True,  True,  "date revolue mais periode alors ouverte"),
    ("chasser le sanglier le 20 mars 2026 a Tozeur ?", "Tozeur", "resident",
     True,  True,  "fermeture repoussee au sud (art. 1)"),
    ("chasser le sanglier le 20 mars 2026 a Bizerte ?", "Bizerte", "resident",
     True,  False, "hors des 8 gouvernorats du sud : etait deja ferme"),
    ("touriste, chasser la tourterelle le 12 aout 2026", None, "touriste",
     False, False, "touristes limites au gros gibier et aux grives (art. 18)"),
    ("chasser le lievre le 21 janvier 2026 ?", None, "resident",
     True,  False, "passee ET petit gibier ferme depuis le 7 decembre"),
    ("chasser le ganga le 16 aout 2026 ?", None, "resident",
     False, True,  "dimanche autorise, periode ouverte"),
]

if __name__ == "__main__":
    ok = 0
    for question, gouv, statut, passee_att, autorise_att, regle in CAS:
        esp = detecter_espece(question)
        d = detecter_date(question, AUJ)
        if not esp or not d:
            print(f"  ECHEC DETECTION | {question}")
            continue

        v = chasse_autorisee(esp, d, gouv, statut, AUJ)
        passee, autorise = bool(v.get("passee")), v["autorise"]

        bon = (passee == passee_att) and (autorise == autorise_att)
        ok += bon
        etat = f"passee={str(passee):5} autorise={str(autorise):5}"
        print(f"  {'OK  ' if bon else 'RATE'} | {etat} | {regle}")

    print(f"\n  {ok}/{len(CAS)} cas conformes\n")
    sys.exit(0 if ok == len(CAS) else 1)