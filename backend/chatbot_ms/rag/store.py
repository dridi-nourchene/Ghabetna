#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
rag/store.py — MAGASIN DE VECTEURS
===================================
Deux backends interchangeables, meme interface :

    NumpyStore   recherche EXACTE par produit scalaire. Aucune dependance
                 native, aucun index a construire : les vecteurs sont deja
                 dans vecteurs.npy et les textes dans chunks.json.

    ChromaStore  base vectorielle avec index HNSW (approximatif).

POURQUOI NUMPY EST LE DEFAUT ICI :
    160 chunks x 1024 dimensions = une matrice de 640 Ko. La recherche se
    reduit a UNE multiplication matricielle : environ 0.3 ms, et le
    resultat est EXACT.

    HNSW (le moteur de ChromaDB) est un index APPROXIMATIF concu pour des
    millions de vecteurs. En dessous de ~50 000 chunks il est plus lent que
    le calcul direct, tout en introduisant une approximation et une
    dependance native compilee.

    Ordre de grandeur a retenir : la recherche coute 0.3 ms, l'appel au LLM
    coute 2 a 5 secondes. La recherche represente 0.01 % du temps total.
    Elle n'est JAMAIS le goulot d'etranglement.

    Bascule vers ChromaDB : config.BACKEND = "chroma"
"""

from __future__ import annotations

import json

import numpy as np

from . import config


# ============================================================================
# BACKEND NUMPY — recherche exacte
# ============================================================================

class NumpyStore:
    """
    Lit directement vecteurs.npy et chunks.json.
    Rien a construire : ces deux fichiers sont produits par l'etape 2.
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
        matrice-vecteur suffit : self.vecteurs @ v.
        """
        v = np.asarray(vecteur, dtype=np.float32)
        scores = self.vecteurs @ v            # (160, 1024) x (1024,) -> (160,)

        # Filtrage par domaine : on ecarte les chunks des autres corpus
        # (camper, apiculture, app) en mettant leur score a -inf.
        if domaine:
            masque = np.array(
                [m.get("domaine") == domaine for m in self.metas])
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


# ============================================================================
# BACKEND CHROMADB
# ============================================================================

class ChromaStore:
    """Meme interface, appuyee sur une collection ChromaDB persistante."""

    def __init__(self):
        import chromadb
        client = chromadb.PersistentClient(path=str(config.CHROMA_DIR))
        self.collection = client.get_collection(config.NOM_COLLECTION)

    def count(self) -> int:
        return self.collection.count()

    def query(self, vecteur, k: int, domaine: str | None = None) -> list[dict]:
        res = self.collection.query(
            query_embeddings=[list(vecteur)],
            n_results=k,
            where={"domaine": domaine} if domaine else None,
        )
        # ChromaDB renvoie une DISTANCE cosinus (0 = identique).
        # On la convertit en similarite : 1 - distance.
        return [
            {"id": i, "texte": d, "meta": m, "score": 1 - dist, "rang": r}
            for r, (i, d, m, dist) in enumerate(zip(
                res["ids"][0], res["documents"][0],
                res["metadatas"][0], res["distances"][0]), start=1)
        ]

    def get(self, ids: list[str]) -> dict[str, tuple[str, dict]]:
        res = self.collection.get(ids=ids)
        return {i: (d, m) for i, d, m in
                zip(res["ids"], res["documents"], res["metadatas"])}


# ============================================================================
# FABRIQUE
# ============================================================================

def ouvrir_store():
    """Instancie le backend choisi dans config.BACKEND."""
    if config.BACKEND == "chroma":
        return ChromaStore()
    return NumpyStore()