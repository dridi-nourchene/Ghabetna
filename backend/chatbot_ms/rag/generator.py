#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
rag/generator.py — ETAPE FINALE : GENERATION
=============================================
Construit le prompt a partir des chunks recuperes, puis appelle Groq.

POURQUOI GROQ :
    Groq execute le modele sur du materiel specialise (LPU) et atteint
    environ 500 tokens/seconde, soit ~1 seconde pour une reponse de 300 mots.
    Le meme modele sur le CPU d'un portable mettrait 1 a 2 minutes :
    inutilisable pour un chasseur sur le terrain comme pour une demonstration.

    Le risque associe est la dependance reseau. Il est couvert par cache.py,
    et non par un modele local qui serait bien trop lent.
"""

from __future__ import annotations

from datetime import date

from . import config

MOIS = ["janvier", "février", "mars", "avril", "mai", "juin", "juillet",
        "août", "septembre", "octobre", "novembre", "décembre"]


def date_du_jour() -> str:
    """
    Date calculee dynamiquement, JAMAIS ecrite en dur.

    Essentiel : l'arrete de chasse n'est valable que pour la saison
    2025/2026. Sans date courante, le chatbot annoncerait des periodes deja
    closes comme si elles etaient en vigueur. C'est le principal risque de
    justesse du projet.
    """
    d = date.today()
    return f"{d.day} {MOIS[d.month - 1]} {d.year}"


# ============================================================================
# PROMPT SYSTEME
# ============================================================================

def prompt_systeme(specialite: str | None = None) -> str:
    qui = {
        "chasseur":   "aux chasseurs",
        "campeur":    "aux campeurs",
        "apiculteur": "aux apiculteurs",
    }.get((specialite or "").lower(), "aux citoyens")

    return f"""Tu es l'assistant Ghabetna. Tu réponds {qui} tunisiens à partir \
d'extraits de la réglementation officielle et de l'aide de l'application qui \
te sont fournis.

DATE DU JOUR : {date_du_jour()}

RÈGLES ABSOLUES :

1. FIDÉLITÉ. Réponds UNIQUEMENT à partir des extraits fournis. Si \
l'information ne s'y trouve pas, dis-le clairement et n'invente rien. Ne \
complète jamais avec des connaissances générales.

2. CITATION. Pour toute règle juridique, indique le texte et le numéro \
d'article. Pour les questions sur l'application, ce n'est pas nécessaire.

3. VALIDITÉ TEMPORELLE. Un arrêté annuel n'est valable que pour sa saison. \
Si un extrait porte « validité : saison_2025_2026 », compare ses dates à la \
date du jour et préviens l'utilisateur si la période est écoulée.

4. HIÉRARCHIE DES NORMES. En cas d'apparente contradiction, la loi prime sur \
l'arrêté. Mais un arrêté peut légalement prévoir une dérogation quand la loi \
l'y autorise : signale-le plutôt que de conclure à une contradiction.

5. AVERTISSEMENTS. Si un extrait est marqué [AVERTISSEMENT DE CONCORDANCE], \
tiens-en compte en priorité : il signale un renvoi périmé.

6. DATES — RÈGLE STRICTE. Tu ne calcules JAMAIS toi-même si une date précise \
est autorisée. Deux cas seulement :
   - Un bloc [VERDICT CALCULÉ] est fourni : il fait autorité. Sa ligne \
« RÉPONSE À DONNER » est la réponse exacte : reformule-la naturellement mais \
ne change RIEN à son sens, et surtout ne recalcule ni le jour de la semaine, \
ni la période, ni l'espèce. N'invente aucune circonstance que l'utilisateur \
n'a pas mentionnée (heure de la journée, lieu, matériel). Transmets ensuite \
les réserves indiquées.
   - Aucun bloc [VERDICT CALCULÉ] n'est fourni : expose la règle (période, \
jours de la semaine, exceptions) et invite explicitement l'utilisateur à \
vérifier lui-même, sans conclure à sa place.
   Une date antérieure à la date du jour ne s'annonce jamais « autorisée » : \
elle est révolue, dis-le.

7. JAMAIS DE JARGON INTERNE. L'utilisateur ne voit pas les extraits ni les \
blocs qui te sont fournis : il ne connaît ni « [VERDICT CALCULÉ] », ni \
« EXTRAIT 2 », ni « ce calcul ». N'écris jamais ces termes. Formule tout \
comme une réponse directe, en t'appuyant sur les numéros d'article, qui eux \
sont publics. Pour transmettre une réserve, dis par exemple « pensez à \
vérifier si ce jour est férié » plutôt que « cela n'a pas été vérifié par ce \
calcul ».

8. MESSAGES SANS QUESTION. Si le message est une salutation, un \
remerciement ou une formule de politesse, réponds par UNE SEULE phrase \
courte, sans citer aucun article et sans mentionner les extraits fournis. \
Ne te présente pas, n'énumère pas ce que tu sais faire. Exemples de longueur \
attendue : « Bonjour, comment puis-je vous aider ? » ou « Avec plaisir. »

9. SÉCURITÉ. En cas de doute sur une question réglementaire, invite à \
contacter l'arrondissement régional des forêts.

10. FORME. Réponds en français, brièvement et directement, sans titres ni \
listes à puces sauf si la question l'exige. Si la question est posée en \
arabe ou en dialecte tunisien, réponds dans la même langue.


11. HORS SUJET. Si la question ne relève ni de la réglementation, ni de \
l'application, réponds en UNE phrase : tu n'as pas d'information sur ce \
sujet, et rappelle brièvement ton domaine. N'explique pas ce que \
contiennent les extraits et ne demande pas de préciser la question. \
Exemple attendu : « Je n'ai pas d'information sur ce sujet. Je réponds sur \
la réglementation de la chasse et sur l'application. »

"""


# ============================================================================
# CONTEXTE
# ============================================================================

def construire_contexte(chunks: list[dict]) -> str:
    """
    Assemble les extraits recuperes.

    Chaque extrait est ETIQUETE avec sa source, son article et sa validite.
    C'est cet etiquetage qui permet au LLM d'appliquer les regles 2, 3, 4 et
    5 : sans lui, il ne pourrait ni citer, ni detecter une periode close, ni
    arbitrer entre loi et arrete.
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


def construire_messages(question: str, chunks: list[dict],
                        historique: list[dict] | None = None,
                        verdict: str | None = None) -> list[dict]:
    """
    Assemble les messages envoyes au LLM.

    L'historique est place AVANT le tour courant, sous forme de messages
    user/assistant classiques. Les extraits, eux, sont attaches au DERNIER
    message utilisateur : ils sont propres a CETTE question, il serait faux
    de les rattacher aux tours precedents.

    historique = [{"role": "user"|"assistant", "content": "..."}, ...]
    """
    messages: list[dict] = []

    if historique:
        # On borne le nombre de tours : chaque tour consomme du contexte, et
        # au-dela de quelques echanges l'ancien devient du bruit.
        for tour in historique[-config.MAX_TOURS_HISTORIQUE:]:
            role = tour.get("role")
            contenu = (tour.get("content") or "").strip()
            if role in ("user", "assistant") and contenu:
                messages.append({"role": role, "content": contenu})

    parties = []

    # Le verdict passe AVANT les extraits : c'est la source qui fait autorite
    # sur la question de date, les extraits ne servent qu'a l'etayer.
    if verdict:
        parties.append(f"[VERDICT CALCULÉ]\n{verdict}")

    if chunks:
        parties.append(f"EXTRAITS DE LA DOCUMENTATION :\n\n"
                       f"{construire_contexte(chunks)}")
    else:
        parties.append("Aucun extrait pertinent n'a été trouvé dans la "
                       "documentation.")

    parties.append(f"QUESTION : {question}")
    contenu = "\n\n".join(parties)

    messages.append({"role": "user", "content": contenu})
    return messages


# ============================================================================
# APPEL GROQ
# ============================================================================

class ErreurLLM(Exception):
    """Levee quand Groq est injoignable ou refuse la requete."""


def appeler_groq(systeme: str, messages: list[dict]) -> str:
    if not config.GROQ_API_KEY:
        raise ErreurLLM(
            "GROQ_API_KEY absente. Cle gratuite sur console.groq.com, "
            "a placer dans le fichier .env de chatbot_ms.")

    from groq import Groq

    try:
        client = Groq(api_key=config.GROQ_API_KEY)
        r = client.chat.completions.create(
            model=config.GROQ_MODEL,
            max_tokens=config.LLM_MAX_TOKENS,
            temperature=config.LLM_TEMPERATURE,
            messages=[{"role": "system", "content": systeme}] + messages,
        )
        return r.choices[0].message.content
    except Exception as e:
        raise ErreurLLM(f"Groq injoignable : {type(e).__name__} — {e}") from e


def generer(question: str, chunks: list[dict],
            historique: list[dict] | None = None,
            specialite: str | None = None,
            verdict: str | None = None) -> str:
    """
    Point d'entree unique : question + extraits + historique -> reponse.

    verdict : bloc produit par calendrier.analyser_question() quand la
    question porte a la fois sur une espece et sur une date. Le calcul est
    fait en Python, pas par le LLM : c'est la seule facon de le rendre fiable.
    """
    return appeler_groq(
        prompt_systeme(specialite),
        construire_messages(question, chunks, historique, verdict),
    )