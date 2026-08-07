#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
scripts/build_stores.py — ETAPES 3 et 4 (processus CHROMADB)
=============================================================
    Etape 3 : indexation ChromaDB -> data/index/chroma_db/
    Etape 4 : index BM25          -> data/index/bm25.pkl

Ce processus lit chunks.json et vecteurs.npy produits par build_embeddings.
Il NE CHARGE JAMAIS torch : c'est ce qui evite le conflit de DLL natives
qui tuait collection.add() sous Windows.

    python -m scripts.build_stores
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import numpy as np

from rag import config
from rag.indexer import EMPREINTE_FILE, VECTEURS_FILE, indexer_bm25, indexer_chroma

if __name__ == "__main__":
    # --- verification des entrees ------------------------------------------
    manquants = [str(p) for p in (config.CHUNKS_FILE, VECTEURS_FILE)
                 if not p.exists()]
    if manquants:
        print("ERREUR : fichier(s) manquant(s) :")
        for m in manquants:
            print(f"  - {m}")
        print("\nLance d'abord : python -m scripts.build_embeddings")
        sys.exit(1)

    chunks = json.loads(config.CHUNKS_FILE.read_text(encoding="utf-8"))
    vecteurs = np.load(VECTEURS_FILE)

    # Coherence : les vecteurs doivent correspondre aux chunks.
    if len(vecteurs) != len(chunks):
        print(f"ERREUR : {len(chunks)} chunks mais {len(vecteurs)} vecteurs.")
        print("Relance : python -m scripts.build_embeddings --forcer")
        sys.exit(1)

    print(f"\n  {len(chunks)} chunks | vecteurs {vecteurs.shape}")

    if config.BACKEND == "chroma":
        print("\n=== ETAPE 3 : INDEXATION CHROMADB ===\n")
        n_chroma = indexer_chroma(chunks, vecteurs)
    else:
        # BACKEND == "numpy" : rien a construire. vecteurs.npy et chunks.json
        # SONT le magasin. La recherche se fait par produit scalaire exact.
        print("\n=== ETAPE 3 : MAGASIN NUMPY ===\n")
        print("  Aucune construction necessaire : vecteurs.npy + chunks.json")
        print(f"  {len(vecteurs)} vecteurs de {vecteurs.shape[1]} dimensions")
        print(f"  Taille en memoire : {vecteurs.nbytes / 1024:.0f} Ko")
        print("  Recherche exacte par produit scalaire (~0.3 ms)")
        n_chroma = len(vecteurs)

    print("\n=== ETAPE 4 : INDEX BM25 ===\n")
    n_bm25 = indexer_bm25(chunks)
    print(f"  {n_bm25} documents -> {config.BM25_FILE.name}")

    print("\n=== INDEXATION TERMINEE ===")
    print(f"  chunks   : {len(chunks)}")
    print(f"  magasin  : {n_chroma} vecteurs ({config.BACKEND})")
    print(f"  bm25     : {n_bm25} documents")
    print("\n  Tester :  python -m scripts.test_retrieval\n")