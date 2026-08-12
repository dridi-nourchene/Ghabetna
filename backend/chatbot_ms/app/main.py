#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
app/main.py — MICROSERVICE CHATBOT (port 8005)
===============================================
Expose le RAG derriere une API HTTP consommee par le gateway.

POINT CRITIQUE — LE CHARGEMENT DU MODELE :
    bge-m3 met 10 a 20 secondes a se charger en memoire. Il est charge UNE
    SEULE FOIS au demarrage, via le lifespan, et conserve pour toute la duree
    de vie du service. Le charger par requete rendrait chaque question
    inutilisable.

    Consequence : le premier `docker compose up` est lent, puis chaque
    requete coute environ 1 seconde. A anticiper le jour d'une demonstration.

SANS ETAT :
    Aucune base de donnees. L'historique de conversation est conserve par
    Flutter et renvoye a chaque appel. Le service peut donc etre replique
    sans coordination.
"""

from __future__ import annotations

import logging
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from app.schemas import ChatRequest, ChatResponse, SourceOut, VerdictOut
from rag import cache, calendrier, config
from rag.generator import ErreurLLM, generer
from rag.retriever import Retriever

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("chatbot_ms")

# Instance unique du retriever, partagee par toutes les requetes.
_retriever: Retriever | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Charge le modele et les index au demarrage, une seule fois."""
    global _retriever
    t0 = time.time()
    logger.info("[CHATBOT] Chargement du modele %s...", config.MODELE_EMBEDDING)
    try:
        _retriever = Retriever()
        logger.info("[CHATBOT] Pret en %.1f s — %d chunks indexes",
                    time.time() - t0, _retriever.store.count())
    except Exception as e:
        # On ne bloque pas le demarrage : /health signalera le probleme,
        # ce qui est plus lisible qu'un conteneur en boucle de redemarrage.
        logger.error("[CHATBOT] Index indisponible : %s", e)
        logger.error("[CHATBOT] Reconstruire : python -m scripts.build_index")
    yield
    logger.info("[CHATBOT] Arret")


app = FastAPI(
    title="Ghabetna — Chatbot Service",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================================================
# HEALTHCHECK
# ============================================================================

@app.get("/health")
async def health():
    pret = _retriever is not None
    return {
        "status": "ok" if pret else "degraded",
        "service": "chatbot-service",
        "index": "ok" if pret else "manquant",
        "chunks": _retriever.store.count() if pret else 0,
        "modele": config.MODELE_EMBEDDING,
        "llm": config.GROQ_MODEL,
        "cle_groq": "presente" if config.GROQ_API_KEY else "ABSENTE",
        "cache": cache.taille(),
    }


# ============================================================================
# CHAT
# ============================================================================

@app.post("/api/chat/", response_model=ChatResponse)
async def chat(
    body: ChatRequest,
    x_user_specialite: str | None = Header(default=None),
    x_user_id: str | None = Header(default=None),
):
    """
    Question -> retrieval filtre par specialite -> generation.

    La specialite vient en priorite du header X-User-Specialite injecte par
    le gateway depuis le JWT. Le champ du corps sert de repli pour les tests
    via Swagger tant que l'authentification citoyenne n'est pas en place.
    """
    if _retriever is None:
        raise HTTPException(
            status_code=503,
            detail="Index non charge. Lancer : python -m scripts.build_index")

    t0 = time.time()
    specialite = x_user_specialite or body.specialite

    # Un chasseur interroge ["chasse", "app"] : sa reglementation plus l'aide
    # de l'application. Jamais camper, jamais apiculture.
    domaines = config.domaines_pour(specialite)

    # ---- cache : uniquement pour les questions SANS historique -------------
    # Avec historique, la meme question peut appeler une reponse differente
    # selon ce qui precede : la mettre en cache produirait des reponses fausses.
    # Le cache ne s'applique ni aux questions avec historique (la reponse
    # depend de ce qui precede) ni aux questions portant sur une date : le
    # meme "demain" ne designe pas le meme jour d'un jour a l'autre.
    utilisable = (not body.historique and calendrier.detecter_date(body.question) is None)
    if utilisable:
        en_cache = cache.lire(body.question, specialite)
        if en_cache:
            return ChatResponse(
                reponse=en_cache, sources=[], domaines=domaines or [],
                depuis_cache=True,
                duree_ms=int((time.time() - t0) * 1000))

    # ---- retrieval ---------------------------------------------------------
    # La question precedente sert au multi-tour : "et pour le lievre ?" seule
    # ne trouve rien, precedee du tour d'avant elle retrouve les bons chunks.
    precedente = None
    for tour in reversed(body.historique):
        if tour.role == "user":
            precedente = tour.content
            break

    chunks = _retriever.rechercher(
        body.question, domaines=domaines, question_precedente=precedente)

    # ---- calcul deterministe des dates -------------------------------------
    # Si la question porte sur une espece ET une date, le verdict est calcule
    # en Python. Un LLM ne fait pas de facon fiable la chaine espece ->
    # periode -> jour de semaine -> ferie -> statut -> date du jour : il en
    # produit une approximation plausible, ce qui est pire qu'un refus.
    verdict_struct = calendrier.analyser_question_struct(body.question)
    verdict = verdict_struct["texte"] if verdict_struct else None
    if verdict_struct:
        logger.info("[CHATBOT] Verdict calendrier : %s", verdict_struct["etat"])

    # ---- generation --------------------------------------------------------
    historique = [{"role": m.role, "content": m.content} for m in body.historique]
    try:
        reponse = generer(body.question, chunks, historique, specialite, verdict)
    except ErreurLLM as e:
        logger.error("[CHATBOT] %s", e)
        raise HTTPException(
            status_code=503,
            detail="Le service de génération est momentanément indisponible.")

    if utilisable:
        cache.ecrire(body.question, specialite, reponse)

    sources = [
        SourceOut(
            source=c["meta"]["source"],
            article=c["meta"].get("article") or None,
            gouvernorat=c["meta"].get("gouvernorat") or None,
            validite=c["meta"].get("validite"),
            extrait=c["texte"][:200],
        )
        for c in chunks
        if c["meta"].get("type") in ("norme", "tableau", "zone_geographique")
    ][:4]

    return ChatResponse(
        reponse=reponse,
        verdict=VerdictOut(
            etat=verdict_struct["etat"],
            titre=verdict_struct["titre"],
            espece=verdict_struct["espece"],
            prochaine=verdict_struct["prochaine"],
        ) if verdict_struct else None,
        sources=sources,
        domaines=domaines or [],
        depuis_cache=False,
        duree_ms=int((time.time() - t0) * 1000),
    )


@app.post("/api/chat/debug")
async def chat_debug(body: ChatRequest):
    """
    Retrieval SANS appel au LLM. Sert a verifier quels extraits remontent,
    sans consommer de quota Groq.
    """
    if _retriever is None:
        raise HTTPException(status_code=503, detail="Index non charge")

    domaines = config.domaines_pour(body.specialite)
    chunks = _retriever.rechercher(body.question, domaines=domaines)
    return {
        "question": body.question,
        "domaines": domaines,
        "chunks": [
            {"id": c["id"], "score_rrf": round(c["score_rrf"], 4),
             "origines": c["origines"], "article": c["meta"].get("article"),
             "source": c["meta"]["source_id"], "extrait": c["texte"][:150]}
            for c in chunks
        ],
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=config.SERVICE_PORT)