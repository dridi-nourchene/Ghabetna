#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
scripts/test_retrieval.py — TEST DU RETRIEVAL SANS LLM
=======================================================
A lancer AVANT de brancher le LLM. Si les bons articles ne remontent pas
ici, aucun prompt ne rattrapera le probleme.

    python -m scripts.test_retrieval
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from rag.retriever import Retriever

# Chaque question cible un mecanisme different du retrieval.
QUESTIONS = [
    "quelle est la periode de chasse du sanglier ?",          # dense
    "j ai le droit de chasser dans un perimetre loue ?",      # BM25 (art. 14)
    "puis-je chasser a Ain Draham ?",                          # BM25 sans accents
    "combien de lievres puis-je tuer par jour ?",              # art. 5
    "est-ce que je peux chasser la nuit ?",                    # dense (art. 172)
    "quelles armes sont interdites a la chasse ?",             # arrete art. 15
    "quel est le prix du permis de chasse ?",                  # arrete art. 2 et 3
    "que risque un chasseur qui chasse une espece protegee ?", # renvois
]

if __name__ == "__main__":
    r = Retriever()
    for q in QUESTIONS:
        r.expliquer(q, domaine="chasse")