#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
scripts/build_stores.py — ETAPE 3 : INDEX BM25
===============================================
Lit chunks.json et vecteurs.npy produits par build_embeddings, et construit
l'index lexical.

Il n'y a PAS de "construction" du magasin vectoriel : vecteurs.npy EST le
magasin. La recherche se fait par produit scalaire direct (cf. rag/store.py).

Ce processus ne charge jamais torch : c'est ce qui le rend rapide et sans
conflit de librairies natives.

    python -m scripts.build_stores
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import numpy as np

from rag import config
from rag.indexer import VECTEURS_FILE, indexer_bm25

if __name__ == "__main__":
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

    if len(vecteurs) != len(chunks):
        print(f"ERREUR : {len(chunks)} chunks mais {len(vecteurs)} vecteurs.")
        print("Relance : python -m scripts.build_embeddings --forcer")
        sys.exit(1)

    print(f"\n  MAGASIN VECTORIEL")
    print(f"    {len(vecteurs)} vecteurs de {vecteurs.shape[1]} dimensions")
    print(f"    {vecteurs.nbytes / 1024:.0f} Ko en memoire")
    print(f"    recherche exacte par produit scalaire, rien a construire")

    print("\n=== ETAPE 3 : INDEX BM25 ===\n")
    n = indexer_bm25(chunks)
    print(f"  {n} documents -> {config.BM25_FILE.name}")

    print("\n=== INDEXATION TERMINEE ===")
    print(f"  chunks  : {len(chunks)}")
    print(f"  magasin : vecteurs.npy ({vecteurs.nbytes / 1024:.0f} Ko)")
    print(f"  bm25    : {n} documents")
    print("\n  Tester :  python -m scripts.test_retrieval\n")