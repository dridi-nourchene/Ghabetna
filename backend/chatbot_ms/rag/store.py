#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
rag/store.py — MAGASIN DE VECTEURS
===================================
Recherche vectorielle EXACTE par produit scalaire.

POURQUOI PAS DE BASE VECTORIELLE :
    170 chunks x 1024 dimensions = une matrice de 700 Ko.
    Avec les corpus camper et beekeeper : ~500 chunks, 2 Mo.

    La recherche se reduit a UNE multiplication matricielle :
        scores = vecteurs @ question        ->  ~0.1 ms, resultat EXACT

    Un index type HNSW est un algorithme APPROXIMATIF qui devient utile
    quand on combine un tres gros corpus ET un debit de requetes eleve.
    Aucune des deux conditions n'est reunie ici. A cette echelle il serait
    plus lent que le calcul direct, tout en ajoutant une approximation et
    une dependance native compilee.

    Ordre de grandeur a retenir : la recherche coute 0.1 ms, l'appel au LLM
    coute 2 a 5 secondes. La recherche represente 0.005 % du temps total :
    elle n'est JAMAIS le goulot d'etranglement.

Cette classe isole le "comment on cherche" du "comment on classe"
(retriever.py). Si le corpus atteignait un jour des centaines de milliers
de chunks, seul ce fichier serait a reecrire.
"""

from __future__ import annotations

import json

import numpy as np

from . import config


class NumpyStore:
    """
    Lit directement vecteurs.npy et chunks.json produits par l'etape 2.
    Rien a construire : ces deux fichiers SONT le magasin.
    """

    def __init__(self):
        from .indexer import VECTEURS_FILE

        if not VECTEURS_FILE.exists() or not config.CHUNKS_FILE.exists():
            raise FileNotFoundError(
                "Fichiers manquants :\n"
                f"  - {VECTEURS_FILE}\n"
                f"  - {config.CHUNKS_FILE}\n\n"
                "Reconstruire : python -m scripts.build_embeddings"
            )

        self.vecteurs = np.load(VECTEURS_FILE).astype(np.float32)
        chunks = json.loads(config.CHUNKS_FILE.read_text(encoding="utf-8"))

        if len(chunks) != len(self.vecteurs):
            raise RuntimeError(
                f"Incoherence : {len(chunks)} chunks pour "
                f"{len(self.vecteurs)} vecteurs.\n"
                "Relance : python -m scripts.build_embeddings --forcer"
            )

        self.ids = [c["id"] for c in chunks]
        self.docs = [c["texte_affiche"] for c in chunks]
        self.metas = [c["metadata"] for c in chunks]
        self.index_par_id = {cid: i for i, cid in enumerate(self.ids)}

    def count(self) -> int:
        return len(self.ids)

    def query(self, vecteur, k: int, domaine: str | None = None) -> list[dict]:
        """
        Recherche exacte par similarite cosinus.

        Les vecteurs ont ete normalises a l'indexation (norme = 1), donc le
        PRODUIT SCALAIRE est exactement le cosinus. Une seule multiplication
        matrice-vecteur suffit.
        """
        v = np.asarray(vecteur, dtype=np.float32)
        scores = self.vecteurs @ v          # (170, 1024) x (1024,) -> (170,)

        # Filtrage par domaine : les chunks des autres corpus (camper,
        # beekeeper, app) sont ecartes en mettant leur score a -inf.
        if domaine:
            masque = np.array([m.get("domaine") == domaine for m in self.metas])
            scores = np.where(masque, scores, -np.inf)

        # argpartition trouve les k meilleurs sans trier tout le tableau,
        # puis on ne trie que ces k-la.
        k = min(k, len(scores))
        candidats = np.argpartition(-scores, k - 1)[:k]
        candidats = candidats[np.argsort(-scores[candidats])]

        return [
            {"id": self.ids[i], "texte": self.docs[i], "meta": self.metas[i],
             "score": float(scores[i]), "rang": rang}
            for rang, i in enumerate(candidats, start=1)
            if scores[i] > -np.inf
        ]

    def get(self, ids: list[str]) -> dict[str, tuple[str, dict]]:
        """Recupere des chunks par identifiant. Utilise apres BM25."""
        sortie = {}
        for cid in ids:
            i = self.index_par_id.get(cid)
            if i is not None:
                sortie[cid] = (self.docs[i], self.metas[i])
        return sortie