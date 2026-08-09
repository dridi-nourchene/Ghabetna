#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
rag/config.py — tous les reglages au meme endroit.
Regle : aucune constante en dur ailleurs dans le code.
"""

import os
from pathlib import Path

# ============================================================================
# CHEMINS
# ============================================================================
# Depuis rag/config.py, parent.parent pointe sur backend/chatbot_ms/,
# que l'on soit en local ou dans un conteneur Docker.
BASE_DIR = Path(__file__).resolve().parent.parent

DATA_DIR = BASE_DIR / "data"
CORPUS_DIR = DATA_DIR / "corpus"      # data/corpus/<domaine>/*.md  -> SOURCE
INDEX_DIR = DATA_DIR / "index"        # genere -> a mettre dans .gitignore

CHUNKS_FILE = INDEX_DIR / "chunks.json"
BM25_FILE = INDEX_DIR / "bm25.pkl"

# ============================================================================
# MODELE D'EMBEDDING
# ============================================================================
# ATTENTION : ce reglage sert A LA FOIS a l'indexation et a la requete.
# Changer de modele oblige a TOUT reindexer : deux modeles produisent des
# espaces vectoriels incomparables, le systeme ne retrouverait plus rien.
MODELE_EMBEDDING = os.getenv("MODELE_EMBEDDING", "BAAI/bge-m3")
DIMENSION = 1024             # bge-m3 = 1024 | e5-base = 768 | MiniLM = 384

# PREFIXES : depend du modele, NE PAS se tromper.
#   BAAI/bge-m3                 -> AUCUN prefixe. En ajouter DEGRADE la qualite.
#   intfloat/multilingual-e5-*  -> "passage: " et "query: " OBLIGATOIRES.
#   paraphrase-multilingual-*   -> aucun prefixe.
# Dans les deux cas une erreur ici est SILENCIEUSE : ca tourne, mais mal.
PREFIXE_PASSAGE = os.getenv("PREFIXE_PASSAGE", "")
PREFIXE_QUERY = os.getenv("PREFIXE_QUERY", "")

# ============================================================================
# CHUNKING
# ============================================================================
TAILLE_MAX_CHUNK = 1500      # au-dela : sous-decoupage par paragraphe
TAILLE_MIN_ALERTE = 200      # en dessous : chunk signale comme court

# ============================================================================
# RETRIEVAL
# ============================================================================
TOP_K_DENSE = 20             # candidats de la recherche vectorielle
TOP_K_BM25 = 20              # candidats de la recherche lexicale
TOP_K_FINAL = 8              # chunks reellement envoyes au LLM
# 8 et non 5 : les questions a reponse composite ("prix du permis" = art. 2
# + art. 3 ; "que risque-t-on" = art. 193 + 134 bis + 209) ont besoin de
# plusieurs articles. Le cout est negligeable : ~400 tokens de contexte en
# plus, contre le risque de tronquer la reponse.
K_RRF = 60                   # constante du Reciprocal Rank Fusion

# ============================================================================
# LLM
# ============================================================================
LLM_PROVIDER = os.getenv("LLM_PROVIDER", "anthropic")   # anthropic | ollama
LLM_MODEL = os.getenv("LLM_MODEL", "claude-sonnet-4-6")
LLM_MAX_TOKENS = 1000
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://localhost:11434")

# ============================================================================
# METADONNEES PAR DEFAUT
# ============================================================================
# Appliquees quand un dossier de corpus n'a pas de _manifest.json.
# C'est ce qui permet d'ajouter camping/ ou apiculture/ en deposant
# simplement des .md, sans toucher une ligne de code.
META_DEFAUT = {
    "source": "Document interne",
    "source_id": "interne",
    "rang_normatif": "documentaire",
    "rang_poids": 9,
    "validite": "permanent",
}