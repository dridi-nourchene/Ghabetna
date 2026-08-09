#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
scripts/build_embeddings.py — ETAPES 1 et 2 (processus TORCH)
==============================================================
    Etape 1 : chunking  -> data/index/chunks.json
    Etape 2 : embedding -> data/index/vecteurs.npy

Ce processus charge torch (via sentence-transformers) et RIEN D'AUTRE.
C'est le seul processus lourd du pipeline.

POURQUOI CETTE SEPARATION :
    l'embedding est l'etape lente (environ 11 minutes sur CPU). En l'isolant
    dans son propre processus, avec vecteurs.npy comme resultat sur disque,
    l'etape 3 se rejoue en quelques secondes sans recharger le modele.

    python -m scripts.build_embeddings
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from rag import config
from rag.chunker import chunker_corpus
from rag.indexer import embedder

if __name__ == "__main__":
    forcer = "--forcer" in sys.argv

    print(f"\n  python     : {sys.version.split()[0]}")
    print(f"  plateforme : {sys.platform}")

    print("\n=== ETAPE 1 : CHUNKING ===")
    chunks = chunker_corpus(verbeux=True)
    if not chunks:
        print(f"\nERREUR : aucun chunk. Verifie {config.CORPUS_DIR}")
        sys.exit(1)

    print(f"\n=== ETAPE 2 : EMBEDDING ({config.MODELE_EMBEDDING}) ===\n")
    vecteurs = embedder(chunks, forcer=forcer)

    print(f"\n  OK : {vecteurs.shape[0]} vecteurs de {vecteurs.shape[1]} dim.")
    print("\n  Suite :  python -m scripts.build_stores\n")