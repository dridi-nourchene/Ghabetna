#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
scripts/evaluer.py — ÉVALUATION QUANTITATIVE DU RAG
=====================================================
Comble le manque identifié dans architecture_rag.pdf (section 9) : jusqu'ici,
scripts/test_retrieval.py ne permettait qu'une inspection qualitative à l'œil
(Retriever.expliquer). Ce script calcule des métriques chiffrées, répétables,
comparables entre deux versions du système.

Deux familles de métriques, correspondant aux sections 9.1 et 9.2 du document :

  RETRIEVAL (sans appel LLM, rapide, déterministe)
    Precision@k, Recall@k, MRR, nDCG@k — comparent les chunks réellement
    retrouvés par Retriever.rechercher() aux chunks attendus du gold standard
    (data/eval/gold_standard.json).

  GÉNÉRATION (avec appel LLM, sert de juge — même principe que RAGAS,
  réimplémenté ici sans dépendance externe pour rester transparent)
    Faithfulness      — la réponse s'appuie-t-elle uniquement sur le contexte
                         fourni, sans invention ? (règle 1 du prompt système)
    Answer relevancy  — la réponse répond-elle réellement à la question posée ?

Usage :
    python -m scripts.evaluer                  # retrieval + génération
    python -m scripts.evaluer --retrieval-only  # sans appel LLM (rapide, gratuit)

Écrit data/eval/resultats.json et affiche un tableau récapitulatif.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
import time
from pathlib import Path
from statistics import mean

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from rag import config
from rag.calendrier import analyser_question_struct
from rag.generator import ErreurLLM, appeler_groq, construire_messages, generer, prompt_systeme
from rag.retriever import Retriever

GOLD_FILE = config.DATA_DIR / "eval" / "gold_standard.json"
RESULTATS_FILE = config.DATA_DIR / "eval" / "resultats.json"

TOP_K = config.TOP_K_FINAL  # évalue exactement ce qui part réellement au LLM


# ============================================================================
# CHARGEMENT DU GOLD STANDARD
# ============================================================================

def charger_gold() -> list[dict]:
    if not GOLD_FILE.exists():
        raise FileNotFoundError(
            f"Gold standard manquant : {GOLD_FILE}\n"
            "Voir data/eval/gold_standard.json (section 9.4 de architecture_rag.pdf)."
        )
    data = json.loads(GOLD_FILE.read_text(encoding="utf-8"))
    return data["questions"]


# ============================================================================
# 9.1 — MÉTRIQUES DE RETRIEVAL (pas d'appel LLM)
# ============================================================================

def precision_at_k(retrouves: list[str], attendus: set[str], k: int) -> float:
    topk = retrouves[:k]
    if not topk:
        return 0.0
    pertinents = sum(1 for cid in topk if cid in attendus)
    return pertinents / len(topk)


def recall_at_k(retrouves: list[str], attendus: set[str], k: int) -> float:
    if not attendus:
        return 0.0
    topk = set(retrouves[:k])
    return len(topk & attendus) / len(attendus)


def reciprocal_rank(retrouves: list[str], attendus: set[str]) -> float:
    for rang, cid in enumerate(retrouves, start=1):
        if cid in attendus:
            return 1.0 / rang
    return 0.0


def ndcg_at_k(retrouves: list[str], attendus: set[str], k: int) -> float:
    topk = retrouves[:k]
    dcg = sum(
        1.0 / math.log2(rang + 1)
        for rang, cid in enumerate(topk, start=1)
        if cid in attendus
    )
    nb_ideal = min(len(attendus), k)
    idcg = sum(1.0 / math.log2(rang + 1) for rang in range(1, nb_ideal + 1))
    return dcg / idcg if idcg > 0 else 0.0


def evaluer_retrieval(retriever: Retriever, item: dict) -> dict:
    attendus = set(item["chunks_attendus"])
    chunks = retriever.rechercher(item["question"], domaines=item["domaines"], top=TOP_K)
    retrouves = [c["id"] for c in chunks]

    return {
        "id": item["id"],
        "question": item["question"],
        "chunks_attendus": sorted(attendus),
        "chunks_retrouves": retrouves,
        f"precision@{TOP_K}": round(precision_at_k(retrouves, attendus, TOP_K), 3),
        f"recall@{TOP_K}": round(recall_at_k(retrouves, attendus, TOP_K), 3),
        "mrr": round(reciprocal_rank(retrouves, attendus), 3),
        f"ndcg@{TOP_K}": round(ndcg_at_k(retrouves, attendus, TOP_K), 3),
        "_chunks": chunks,  # réutilisé pour la génération, retiré avant écriture
    }


# ============================================================================
# 9.2 — MÉTRIQUES DE GÉNÉRATION (juge = LLM, même appel Groq que la prod)
# ============================================================================
# Principe RAGAS, réimplémenté sans la dépendance : un second appel au même
# LLM évalue la sortie du premier sur un critère précis, en renvoyant un JSON
# strict {"score": 0-1, "justification": "..."} plutôt qu'une note en texte
# libre — plus facile à agréger et moins ambigu à parser.

_PROMPT_FAITHFULNESS = """Tu es un évaluateur strict. On te donne un CONTEXTE \
(extraits réglementaires) et une RÉPONSE générée à partir de ce contexte.

Ta tâche : vérifier si CHAQUE affirmation factuelle de la réponse est bien \
soutenue par le contexte, sans information inventée ou ajoutée depuis des \
connaissances générales.

Réponds UNIQUEMENT avec un JSON strict, sans texte autour :
{{"score": <0.0 à 1.0>, "justification": "<une phrase>"}}

score = 1.0 si toutes les affirmations sont soutenues par le contexte.
score = 0.0 si la réponse invente des faits absents du contexte.
score intermédiaire si certaines affirmations sont soutenues et d'autres non.

CONTEXTE :
{contexte}

RÉPONSE À ÉVALUER :
{reponse}
"""

_PROMPT_RELEVANCY = """Tu es un évaluateur strict. On te donne une QUESTION \
et une RÉPONSE.

Ta tâche : évaluer si la réponse traite bien le sujet de la question, sans \
digression ni hors-sujet.

Réponds UNIQUEMENT avec un JSON strict, sans texte autour :
{{"score": <0.0 à 1.0>, "justification": "<une phrase>"}}

score = 1.0 si la réponse est directement et complètement pertinente.
score = 0.0 si la réponse ne traite pas du tout la question posée.

QUESTION :
{question}

RÉPONSE À ÉVALUER :
{reponse}
"""


def _juger(prompt: str) -> dict:
    """Appelle Groq comme juge, avec une température nulle (déterminisme du
    jugement) et parse le JSON renvoyé. Retourne score=None si le parsing
    échoue, plutôt que de fausser silencieusement la moyenne avec un 0."""
    try:
        brut = appeler_groq(
            "Tu réponds uniquement en JSON strict, sans aucun texte autour.",
            [{"role": "user", "content": prompt}],
        )
        m = re.search(r"\{.*\}", brut, re.DOTALL)
        if not m:
            return {"score": None, "justification": f"JSON introuvable : {brut[:200]}"}
        parsed = json.loads(m.group(0))
        return {"score": float(parsed.get("score")), "justification": parsed.get("justification", "")}
    except ErreurLLM as e:
        return {"score": None, "justification": f"Groq injoignable : {e}"}
    except Exception as e:
        return {"score": None, "justification": f"Erreur de parsing : {e}"}


def evaluer_generation(item: dict, chunks: list[dict]) -> dict:
    from rag.generator import construire_contexte

    verdict_struct = analyser_question_struct(item["question"])
    verdict = verdict_struct["texte"] if verdict_struct else None

    t0 = time.time()
    try:
        reponse = generer(item["question"], chunks, specialite=None, verdict=verdict)
    except ErreurLLM as e:
        return {"id": item["id"], "erreur": str(e)}
    duree_ms = int((time.time() - t0) * 1000)

    contexte = construire_contexte(chunks) if chunks else "(aucun extrait)"
    faithfulness = _juger(_PROMPT_FAITHFULNESS.format(contexte=contexte, reponse=reponse))
    relevancy = _juger(_PROMPT_RELEVANCY.format(question=item["question"], reponse=reponse))

    return {
        "id": item["id"],
        "reponse_generee": reponse,
        "duree_ms": duree_ms,
        "faithfulness": faithfulness,
        "answer_relevancy": relevancy,
    }


# ============================================================================
# AGRÉGATION ET AFFICHAGE
# ============================================================================

def agreger(cles: list[str], resultats: list[dict]) -> dict:
    return {cle: round(mean(r[cle] for r in resultats), 3) for cle in cles}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--retrieval-only", action="store_true",
                        help="N'évalue que le retrieval, sans appeler Groq (gratuit, rapide).")
    args = parser.parse_args()

    gold = charger_gold()
    print(f"[EVAL] {len(gold)} questions chargées depuis {GOLD_FILE.name}")

    print("[EVAL] Chargement du retriever...")
    retriever = Retriever()

    # ---- 9.1 Retrieval ------------------------------------------------------
    resultats_retrieval = [evaluer_retrieval(retriever, item) for item in gold]

    cles_retrieval = [f"precision@{TOP_K}", f"recall@{TOP_K}", "mrr", f"ndcg@{TOP_K}"]
    moyennes_retrieval = agreger(cles_retrieval, resultats_retrieval)

    print("\n=== RETRIEVAL (moyenne sur {} questions, k={}) ===".format(len(gold), TOP_K))
    for cle, val in moyennes_retrieval.items():
        print(f"  {cle:15s} = {val}")

    print("\n  Détail par question :")
    for r in resultats_retrieval:
        marque = "OK" if r[f"recall@{TOP_K}"] == 1.0 else "MANQUE"
        print(f"  [{marque:6s}] {r['id']} — {r['question']}")

    # ---- 9.2 Génération (optionnel, coûte un appel Groq par question) ------
    resultats_generation = []
    if not args.retrieval_only:
        print(f"\n[EVAL] Évaluation de la génération ({len(gold)} appels Groq)...")
        for item, r in zip(gold, resultats_retrieval):
            resultats_generation.append(evaluer_generation(item, r["_chunks"]))

        scores_faith = [g["faithfulness"]["score"] for g in resultats_generation
                        if g.get("faithfulness", {}).get("score") is not None]
        scores_rel = [g["answer_relevancy"]["score"] for g in resultats_generation
                     if g.get("answer_relevancy", {}).get("score") is not None]
        durees = [g["duree_ms"] for g in resultats_generation if "duree_ms" in g]

        print("\n=== GÉNÉRATION (juge LLM, moyenne sur {} réponses) ===".format(len(scores_faith)))
        if scores_faith:
            print(f"  faithfulness     = {round(mean(scores_faith), 3)}")
        if scores_rel:
            print(f"  answer_relevancy = {round(mean(scores_rel), 3)}")
        if durees:
            durees_triees = sorted(durees)
            p95 = durees_triees[int(len(durees_triees) * 0.95) - 1] if len(durees_triees) > 1 else durees_triees[0]
            print(f"  latence moyenne  = {round(mean(durees))} ms")
            print(f"  latence p95      = {p95} ms")

    # ---- Écriture des résultats ---------------------------------------------
    for r in resultats_retrieval:
        r.pop("_chunks", None)

    RESULTATS_FILE.parent.mkdir(parents=True, exist_ok=True)
    RESULTATS_FILE.write_text(
        json.dumps({
            "top_k": TOP_K,
            "moyennes_retrieval": moyennes_retrieval,
            "retrieval": resultats_retrieval,
            "generation": resultats_generation,
        }, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"\n[EVAL] Résultats écrits dans {RESULTATS_FILE}")


if __name__ == "__main__":
    main()
