#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
rag/config.py — tous les reglages au meme endroit.
Regle : aucune constante en dur ailleurs dans le code.
"""

import os
from pathlib import Path

# Charge le fichier .env AVANT tout appel a os.getenv().
# Sans cela, os.getenv("GROQ_API_KEY") lirait les variables d'environnement
# du systeme, qui ne contiennent rien : il faudrait exporter chaque variable
# a la main a chaque ouverture de terminal.
# En Docker, env_file fait deja ce travail et load_dotenv ne trouve rien :
# c'est sans effet, donc sans risque de conflit.
try:
    from dotenv import load_dotenv
    load_dotenv(Path(__file__).resolve().parent.parent / ".env")
except ImportError:
    # python-dotenv absent : on continue avec les variables du systeme.
    pass

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
# DOMAINES ET SPECIALITES
# ============================================================================
# Chaque citoyen a UNE specialite choisie a l'inscription. Le chatbot ne lui
# repond que sur celle-ci, PLUS le domaine "app" commun a tous (comment
# gagner des coins, creer une alerte, convertir en bonus...).
# L'etancheite entre chasse, camper et apiculture est totale.
DOMAINE_COMMUN = "app"

SPECIALITES = {
    "chasseur":   "chasse",
    "campeur":    "camper",
    "apiculteur": "apiculture",
}


def domaines_pour(specialite: str | None) -> list[str] | None:
    """
    "chasseur" -> ["chasse", "app"]
    None       -> None (aucun filtre : utile pour les tests)
    inconnue   -> ["app"] seulement
    """
    if not specialite:
        return None
    dom = SPECIALITES.get(specialite.strip().lower())
    return [dom, DOMAINE_COMMUN] if dom else [DOMAINE_COMMUN]


# ============================================================================
# LLM — GROQ
# ============================================================================
# Groq execute le modele sur du materiel specialise (LPU) : environ 500
# tokens/seconde, soit ~1 seconde pour une reponse de 300 mots. Un modele
# local sur CPU mettrait 1 a 2 minutes, ce qui rend l'usage impossible.
GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")
GROQ_MODEL = os.getenv("GROQ_MODEL", "llama-3.3-70b-versatile")
LLM_MAX_TOKENS = 1000
LLM_TEMPERATURE = 0.2        # bas : on veut de la fidelite, pas de la creativite

# ============================================================================
# CACHE DE REPONSES
# ============================================================================
# Filet de securite : si le reseau tombe, les questions deja posees repondent
# depuis le disque. Indispensable le jour d'une demonstration.
CACHE_ACTIF = os.getenv("CACHE_ACTIF", "1") == "1"
CACHE_FILE = INDEX_DIR / "cache_reponses.json"

# ============================================================================
# HISTORIQUE DE CONVERSATION
# ============================================================================
# Nombre de tours precedents envoyes au LLM.
MAX_TOURS_HISTORIQUE = 6

# Concatener la question precedente a la question actuelle POUR LE RETRIEVAL.
# "et pour le lievre ?" seule ne trouve rien ; precedee de "periode de chasse
# du sanglier", les mots "periode" et "chasse" font remonter les bons chunks.
CONCAT_HISTORIQUE_RETRIEVAL = True

# ============================================================================
# SERVICE
# ============================================================================
SERVICE_PORT = int(os.getenv("PORT", "8005"))

# ============================================================================
# METADONNEES PAR DEFAUT
# ============================================================================
# Appliquees quand un dossier de corpus n'a pas de _manifest.json.
# C'est ce qui permet d'ajouter camper/, apiculture/ ou app/ en deposant
# simplement des .md, sans toucher une ligne de code.
META_DEFAUT = {
    "source": "Document interne",
    "source_id": "interne",
    "rang_normatif": "documentaire",
    "rang_poids": 9,
    "validite": "permanent",
}