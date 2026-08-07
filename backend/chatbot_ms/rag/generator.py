#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
rag/generator.py — ETAPE 6 : GENERATION
========================================
    Construction du prompt a partir des chunks recuperes, puis appel au LLM.

Ce module est volontairement ISOLE : si tu decides plus tard de deplacer
l'appel LLM vers agent_app, tu ne bouges que ce fichier.
"""

from __future__ import annotations

import os
from datetime import date

from . import config

# ============================================================================
# PROMPT SYSTEME
# ============================================================================

MOIS = ["janvier", "février", "mars", "avril", "mai", "juin", "juillet",
        "août", "septembre", "octobre", "novembre", "décembre"]


def date_du_jour() -> str:
    """
    La date est calculee dynamiquement, JAMAIS ecrite en dur.

    C'est essentiel : l'arrete est valable pour la saison 2025/2026. Sans
    date courante, le bot annoncerait des periodes de chasse deja closes
    comme si elles etaient en vigueur. C'est le risque numero 1 du projet.
    """
    d = date.today()
    return f"{d.day} {MOIS[d.month - 1]} {d.year}"


def prompt_systeme() -> str:
    return f"""Tu es l'assistant Ghabetna. Tu réponds aux chasseurs tunisiens \
à partir d'extraits de la réglementation officielle qui te sont fournis.

DATE DU JOUR : {date_du_jour()}

RÈGLES ABSOLUES :

1. FIDÉLITÉ. Réponds UNIQUEMENT à partir des extraits fournis. Si \
l'information ne s'y trouve pas, dis-le clairement et n'invente rien. Ne \
complète jamais avec des connaissances générales sur la chasse.

2. CITATION. Indique systématiquement le texte et le numéro d'article sur \
lesquels tu t'appuies.

3. VALIDITÉ TEMPORELLE. Un arrêté annuel n'est valable que pour sa saison. \
Si un extrait porte « validité : saison_2025_2026 », compare ses dates à la \
date du jour et préviens l'utilisateur si la période est écoulée.

4. HIÉRARCHIE DES NORMES. En cas d'apparente contradiction, la loi (Code \
forestier, loi 69-33) prime sur l'arrêté. Mais un arrêté peut légalement \
prévoir une dérogation quand la loi l'y autorise expressément : signale-le \
plutôt que de conclure à une contradiction.

5. AVERTISSEMENTS. Si un extrait est marqué [AVERTISSEMENT DE CONCORDANCE], \
tiens-en compte en priorité : il signale un renvoi périmé ou une difficulté \
d'interprétation.

6. PAS DE CALCUL DE DATE. N'affirme jamais qu'une date précise est autorisée \
ou interdite. Expose la règle (période, jours de la semaine, exceptions) et \
laisse l'utilisateur conclure.

7. SÉCURITÉ. La chasse engage la sécurité des personnes. En cas de doute, \
invite à contacter l'arrondissement régional des forêts.

8. FORME. Réponds en français, brièvement et directement. Si la question est \
posée en arabe ou en dialecte tunisien, réponds dans la même langue."""


# ============================================================================
# CONSTRUCTION DU CONTEXTE
# ============================================================================

def construire_contexte(chunks: list[dict]) -> str:
    """
    Assemble les extraits recuperes.

    Chaque extrait est ETIQUETE avec sa source, son article et sa validite.
    C'est cet etiquetage qui permet au LLM d'appliquer les regles 2, 3, 4
    et 5 du prompt systeme : sans lui, il ne pourrait ni citer, ni detecter
    une periode close, ni arbitrer entre loi et arrete.
    """
    blocs = []
    for i, c in enumerate(chunks, start=1):
        m = c["meta"]
        entete = f"[EXTRAIT {i}] {m['source']}"
        if m.get("article"):
            entete += f" — Article {m['article']}"
        if m.get("gouvernorat"):
            entete += f" — Gouvernorat de {m['gouvernorat']}"
        entete += f" (rang : {m['rang_normatif']}, validité : {m['validite']})"
        if m.get("type") == "avertissement":
            entete += " [AVERTISSEMENT DE CONCORDANCE]"
        blocs.append(f"{entete}\n{c['texte']}")

    return "\n\n---\n\n".join(blocs)


def construire_prompt(question: str, chunks: list[dict]) -> str:
    if not chunks:
        return (f"Aucun extrait pertinent n'a été trouvé dans le corpus.\n\n"
                f"QUESTION : {question}")
    return (f"EXTRAITS DE LA RÉGLEMENTATION :\n\n"
            f"{construire_contexte(chunks)}\n\n"
            f"QUESTION : {question}")


# ============================================================================
# APPEL AU LLM
# ============================================================================

def _appel_anthropic(systeme: str, utilisateur: str) -> str:
    """Cle dans la variable d'environnement ANTHROPIC_API_KEY."""
    import anthropic
    client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
    r = client.messages.create(
        model=config.LLM_MODEL,
        max_tokens=config.LLM_MAX_TOKENS,
        system=systeme,
        messages=[{"role": "user", "content": utilisateur}],
    )
    return r.content[0].text


def _appel_ollama(systeme: str, utilisateur: str) -> str:
    """
    Solution de repli 100 % locale. Aucune cle, aucun reseau externe :
    utile si la connexion est incertaine le jour de la soutenance.
        ollama pull qwen2.5:7b
    """
    import requests
    r = requests.post(
        f"{config.OLLAMA_URL}/api/chat",
        json={"model": config.LLM_MODEL, "stream": False,
              "messages": [{"role": "system", "content": systeme},
                           {"role": "user", "content": utilisateur}]},
        timeout=180,
    )
    r.raise_for_status()
    return r.json()["message"]["content"]


def generer(question: str, chunks: list[dict]) -> str:
    """Point d'entree unique : question + chunks -> reponse rédigée."""
    systeme = prompt_systeme()
    utilisateur = construire_prompt(question, chunks)

    if config.LLM_PROVIDER == "ollama":
        return _appel_ollama(systeme, utilisateur)
    return _appel_anthropic(systeme, utilisateur)