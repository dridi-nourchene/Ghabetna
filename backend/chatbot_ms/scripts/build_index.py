#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
scripts/build_index.py — INDEXATION COMPLETE
=============================================
Une seule commande, mais DEUX PROCESSUS separes :

    processus 1 (torch)  : chunking + embedding -> chunks.json, vecteurs.npy
    processus 2 (leger)  : index BM25          -> bm25.pkl

Cette separation n'est pas un contournement, c'est l'architecture correcte :
l'embedding produit des vecteurs, l'indexation les consomme. Ce sont deux
jobs distincts.

Elle permet aussi de rejouer l'etape 3 sans refaire les 11 minutes
d'embedding : vecteurs.npy est mis en cache.

    python -m scripts.build_index
    python -m scripts.build_index --forcer     # ignore le cache des vecteurs
"""

import subprocess
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent


def lancer(module: str, args: list[str]) -> None:
    """Lance un module dans un processus Python NEUF."""
    cmd = [sys.executable, "-m", module] + args
    print(f"\n{'=' * 70}")
    print(f"  PROCESSUS : {' '.join(cmd[1:])}")
    print(f"{'=' * 70}")

    r = subprocess.run(cmd, cwd=RACINE)

    if r.returncode != 0:
        print(f"\n  ECHEC : {module} s'est arrete avec le code {r.returncode}")
        if r.returncode < 0 or r.returncode > 128:
            print("  Code negatif ou > 128 = crash natif (DLL), pas une "
                  "erreur Python.")
        sys.exit(r.returncode)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if a.startswith("--")]
    lancer("scripts.build_embeddings", args)
    lancer("scripts.build_stores", [])
    print("\n  Tout est indexe. Tester : python -m scripts.test_retrieval\n")