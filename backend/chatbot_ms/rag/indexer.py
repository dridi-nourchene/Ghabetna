#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
rag/indexer.py — ETAPES 2, 3 et 4
==================================
    Etape 2 : EMBEDDING   -> chaque chunk devient un vecteur de 1024 nombres
    Etape 3 : INDEXATION  -> ces vecteurs sont stockes dans ChromaDB
    Etape 4 : INDEX BM25  -> index lexical complementaire

CACHE DES VECTEURS :
    L'embedding est l'etape LENTE (11 min sur CPU avec bge-m3). Elle est
    donc mise en cache dans data/index/vecteurs.npy, avec une empreinte du
    corpus. Si le corpus n'a pas change, on recharge le cache au lieu de
    tout recalculer : un plantage en etape 3 ou 4 ne coute plus que
    quelques secondes a rejouer.

CE MODULE NE TOURNE JAMAIS AU DEMARRAGE DU SERVEUR.
C'est un job ponctuel, lance par scripts/build_index.py.
"""

from __future__ import annotations

import hashlib
import json
import os
import pickle
import re
import shutil
import stat
import sys
import time
import unicodedata

import numpy as np

from . import config
from .chunker import chunker_corpus

VECTEURS_FILE = config.INDEX_DIR / "vecteurs.npy"
EMPREINTE_FILE = config.INDEX_DIR / "vecteurs.meta.json"


# ============================================================================
# TOKENISATION POUR BM25
# ============================================================================

def tokeniser(texte: str) -> list[str]:
    """
    Decoupe un texte en mots pour BM25.

    NOTE DE VOCABULAIRE (utile pour le memoire) :
    la "tokenisation" n'est PAS une etape de ton pipeline. Elle se produit a
    deux endroits, tous deux internes : dans le modele d'embedding
    (SentencePiece pour bge-m3), et ici pour BM25 ou elle se reduit a un
    decoupage en mots. Ce que tu ecris toi, c'est le CHUNKING.

    On PLIE LES ACCENTS pour que "Aïn Draham" et "Ain Draham" produisent les
    memes tokens : le texte officiel orthographie les toponymes de facon
    instable, et l'utilisateur tapera sans accents.
    """
    t = unicodedata.normalize("NFD", texte.lower())
    t = "".join(c for c in t if unicodedata.category(c) != "Mn")
    return re.findall(r"[a-z0-9]+", t)


# ============================================================================
# ETAPE 2 : EMBEDDING (avec cache)
# ============================================================================

def _empreinte_corpus(chunks: list[dict]) -> str:
    """
    Empreinte du corpus + du modele + du prefixe.
    Si l'un des trois change, le cache est invalide et on re-embedde.
    """
    h = hashlib.sha256()
    h.update(config.MODELE_EMBEDDING.encode())
    h.update(config.PREFIXE_PASSAGE.encode())
    for c in chunks:
        h.update(c["id"].encode())
        h.update(c["texte_indexe"].encode())
    return h.hexdigest()


def embedder(chunks: list[dict], forcer: bool = False):
    """
    Transforme chaque chunk en vecteur, en utilisant le cache si possible.

    On embedde "texte_indexe" (prefixe contextuel + texte), PAS le texte brut.
    C'est ce prefixe qui rend trouvable l'article 14 (13 mots) et les chunks
    de l'article 12 qui ne contiennent que des toponymes.

    normalize_embeddings=True ramene les vecteurs a une norme de 1, ce qui
    rend le produit scalaire equivalent au cosinus. Indispensable pour que
    la distance cosinus de ChromaDB soit correcte.
    """
    empreinte = _empreinte_corpus(chunks)

    # ---- tentative de rechargement du cache -------------------------------
    if not forcer and VECTEURS_FILE.exists() and EMPREINTE_FILE.exists():
        meta = json.loads(EMPREINTE_FILE.read_text())
        if meta.get("empreinte") == empreinte:
            vecteurs = np.load(VECTEURS_FILE)
            if len(vecteurs) == len(chunks):
                print(f"  CACHE VALIDE -> rechargement de {VECTEURS_FILE.name}")
                print(f"  {vecteurs.shape[0]} vecteurs de {vecteurs.shape[1]} "
                      f"dimensions (embedding evite)")
                return vecteurs
        print("  Cache present mais perime (corpus ou modele modifie)")

    # ---- calcul ------------------------------------------------------------
    from sentence_transformers import SentenceTransformer

    print(f"  Chargement du modele {config.MODELE_EMBEDDING}...")
    modele = SentenceTransformer(config.MODELE_EMBEDDING)

    dim = modele.get_sentence_embedding_dimension()
    if dim != config.DIMENSION:
        print(f"  ATTENTION : dimension reelle {dim} != config.DIMENSION "
              f"{config.DIMENSION}. Corrige config.py.")

    print(f"  Prefixe passage : {config.PREFIXE_PASSAGE!r}")
    print(f"  Encodage de {len(chunks)} chunks (etape lente, patience)...")

    textes = [config.PREFIXE_PASSAGE + c["texte_indexe"] for c in chunks]
    t0 = time.time()
    vecteurs = modele.encode(
        textes,
        batch_size=8,              # bge-m3 est lourd : batch modeste
        show_progress_bar=True,
        normalize_embeddings=True,
    )
    print(f"  Encodage termine en {time.time() - t0:.0f} s")

    # ---- sauvegarde IMMEDIATE du cache -------------------------------------
    # On sauvegarde AVANT l'etape 3. Si ChromaDB plante ensuite, ces
    # 11 minutes de calcul ne sont pas perdues.
    config.INDEX_DIR.mkdir(parents=True, exist_ok=True)
    np.save(VECTEURS_FILE, vecteurs)
    EMPREINTE_FILE.write_text(json.dumps({
        "empreinte": empreinte,
        "modele": config.MODELE_EMBEDDING,
        "dimension": int(vecteurs.shape[1]),
        "nb_chunks": len(chunks),
    }, indent=2))
    print(f"  Vecteurs mis en cache -> {VECTEURS_FILE.name}")

    return vecteurs


# ============================================================================
# ETAPE 3 : CHROMADB
# ============================================================================

def _forcer_suppression(fonc, chemin, info):
    """
    Gestionnaire d'erreur pour shutil.rmtree.
    Sous Windows, un fichier en lecture seule fait echouer la suppression :
    on retire l'attribut et on reessaie.
    """
    os.chmod(chemin, stat.S_IWRITE)
    fonc(chemin)


def _nettoyer_chroma() -> None:
    """
    Supprime l'ancienne base pour repartir de zero.

    PIEGE WINDOWS : si un autre processus Python detient encore la base
    (un test_retrieval reste ouvert, un notebook, un serveur), le fichier
    chroma.sqlite3 est VERROUILLE et la suppression echoue. Dans ce cas on
    ne bloque pas : on renomme l'ancien dossier et on continue.
    """
    if not config.CHROMA_DIR.exists():
        return
    try:
        shutil.rmtree(config.CHROMA_DIR, onerror=_forcer_suppression)
        print("  Ancienne base supprimee")
    except Exception as e:
        secours = config.CHROMA_DIR.with_name(f"chroma_db_old_{int(time.time())}")
        print(f"  Suppression impossible ({type(e).__name__}) : la base est "
              f"probablement ouverte par un autre processus Python.")
        print(f"  Contournement : renommage en {secours.name}")
        config.CHROMA_DIR.rename(secours)


def indexer_chroma(chunks: list[dict], vecteurs) -> int:
    """
    Stocke les vecteurs dans une base ChromaDB persistante.

    UNE SEULE collection pour tous les domaines (chasse, camper, apiculture,
    app). On les distingue par la metadonnee "domaine" : filtrage gratuit
    via where={"domaine": "chasse"}, une seule base a gerer.

    Chaque sous-etape est annoncee. Si le programme s'arrete, la derniere
    ligne affichee dit exactement ou.
    """
    import chromadb
    print(f"  chromadb version : {chromadb.__version__}")

    print("  [3.1] nettoyage de l'ancienne base...")
    _nettoyer_chroma()

    print("  [3.2] ouverture du client persistant...")
    client = chromadb.PersistentClient(path=str(config.CHROMA_DIR))

    print("  [3.3] creation de la collection...")
    collection = client.get_or_create_collection(
        name=config.NOM_COLLECTION,
        metadata={"hnsw:space": "cosine"},   # distance cosinus
    )

    print("  [3.4] insertion des chunks...")
    # Insertion par lots : donne de la visibilite sur la progression et
    # evite un pic memoire quand le corpus grossira.
    LOT = 50
    ids = [c["id"] for c in chunks]
    docs = [c["texte_affiche"] for c in chunks]     # texte MONTRE au LLM
    metas = [c["metadata"] for c in chunks]
    vecs = vecteurs.tolist()

    for debut in range(0, len(ids), LOT):
        fin = min(debut + LOT, len(ids))
        collection.add(
            ids=ids[debut:fin],
            embeddings=vecs[debut:fin],
            documents=docs[debut:fin],
            metadatas=metas[debut:fin],
        )
        print(f"        {fin}/{len(ids)} chunks inseres")

    n = collection.count()
    print(f"  [3.5] verification : {n} chunks dans la collection")
    return n


# ============================================================================
# ETAPE 4 : BM25
# ============================================================================

def indexer_bm25(chunks: list[dict]) -> int:
    """
    Construit l'index lexical.

    POURQUOI BM25 EN PLUS DU VECTORIEL :
    l'embedding comprend le SENS mais floute les tokens rares. Ton corpus en
    est sature : ~800 toponymes dans l'article 12, des termes sans voisin
    semantique ("slougui", "chevrotine", "adjudicataires"), des montants
    exacts que le dense ne distingue pas ("90 dinars" vs "150 dinars").

    Inversement, sur "puis-je tirer un sanglier la nuit", le dense trouve
    l'article 172 qui ne contient aucun de ces mots. Les deux sont
    complementaires : aucun ne remplace l'autre.
    """
    from rank_bm25 import BM25Okapi

    corpus = []
    for c in chunks:
        # texte + prefixe + alias OCR. Les alias permettent de trouver
        # l'article 176 en cherchant "chasseurs" alors que le texte officiel
        # ecrit "chausseurs".
        corpus.append(tokeniser(c["texte_indexe"] + " " + c["metadata"]["alias"]))

    bm25 = BM25Okapi(corpus)

    # On sauvegarde l'index ET l'ordre des ids : BM25Okapi renvoie des scores
    # par POSITION, il faut pouvoir remonter a l'identifiant du chunk.
    config.INDEX_DIR.mkdir(parents=True, exist_ok=True)
    with open(config.BM25_FILE, "wb") as f:
        pickle.dump({"bm25": bm25, "ids": [c["id"] for c in chunks]}, f)

    return len(corpus)


# ============================================================================
# ORCHESTRATION
# ============================================================================

def construire_index(verbeux: bool = True, forcer_embedding: bool = False) -> dict:
    print(f"\n  python     : {sys.version.split()[0]}")
    print(f"  plateforme : {sys.platform}")

    print("\n=== ETAPE 1 : CHUNKING ===")
    chunks = chunker_corpus(verbeux=verbeux)
    if not chunks:
        raise RuntimeError(
            f"Aucun chunk produit. Verifie que {config.CORPUS_DIR} contient "
            f"des sous-dossiers avec des .md")

    print(f"\n=== ETAPE 2 : EMBEDDING ({config.MODELE_EMBEDDING}) ===\n")
    vecteurs = embedder(chunks, forcer=forcer_embedding)

    print("\n=== ETAPE 3 : INDEXATION CHROMADB ===\n")
    n_chroma = indexer_chroma(chunks, vecteurs)

    print("\n=== ETAPE 4 : INDEX BM25 ===\n")
    n_bm25 = indexer_bm25(chunks)
    print(f"  {n_bm25} documents -> {config.BM25_FILE.name}")

    return {"chunks": len(chunks), "chroma": n_chroma, "bm25": n_bm25,
            "dimension": int(vecteurs.shape[1])}