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
CHROMA_DIR = INDEX_DIR / "chroma_db"
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
# MAGASIN DE VECTEURS
# ============================================================================
# "numpy"  : recherche EXACTE par produit scalaire. Aucune dependance native.
#            Optimal en dessous de ~50 000 chunks : plus rapide que HNSW,
#            resultat exact, rien a installer. C'est le defaut.
# "chroma" : base vectorielle avec index HNSW (approximatif), utile a partir
#            de centaines de milliers de chunks.
BACKEND = os.getenv("BACKEND", "numpy")

# ============================================================================
# CHROMADB (utilise uniquement si BACKEND == "chroma")
# ============================================================================
# UNE SEULE collection pour tous les domaines (chasse, camping, apiculture,
# app). On les distingue par la metadonnee "domaine" : filtrage gratuit,
# une seule base a gerer, un seul modele charge en memoire.
NOM_COLLECTION = "ghabetna"

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
TOP_K_FINAL = 5              # chunks reellement envoyes au LLM
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