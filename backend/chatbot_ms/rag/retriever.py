#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
rag/retriever.py — ETAPE 5 : RECHERCHE HYBRIDE
===============================================
    5a. recherche DENSE   (store.py)  -> le SENS
    5b. recherche LEXICALE (BM25)     -> les MOTS EXACTS
    5c. fusion RRF + deduplication    -> top-5 envoye au LLM

Contrairement a l'indexation, ce module tourne A CHAQUE QUESTION.
Le modele et les index sont donc charges UNE FOIS a l'instanciation de la
classe Retriever, pas a chaque appel.
"""

from __future__ import annotations

import pickle

from sentence_transformers import SentenceTransformer

from . import config
from .indexer import tokeniser   # MEME tokenisation qu'a l'indexation
from .store import NumpyStore
from .synonymes import enrichir


class Retriever:
    def __init__(self):
        # REGLE ABSOLUE : le modele qui embedde la question doit etre le MEME
        # que celui qui a embedde les chunks. Deux modeles differents
        # produisent des espaces vectoriels incomparables : le systeme ne
        # retrouve plus rien, sans lever la moindre erreur.
        self.modele = SentenceTransformer(config.MODELE_EMBEDDING)

        # Magasin de vecteurs : recherche exacte par produit scalaire.
        self.store = NumpyStore()

        if not config.BM25_FILE.exists():
            raise FileNotFoundError(
                f"Index BM25 manquant : {config.BM25_FILE}\n\n"
                "Reconstruire : python -m scripts.build_stores"
            )

        with open(config.BM25_FILE, "rb") as f:
            data = pickle.load(f)
        self.bm25 = data["bm25"]
        self.bm25_ids = data["ids"]

        # Coherence : le magasin vectoriel et BM25 doivent indexer le MEME
        # corpus. S'ils divergent, le RRF fusionnerait deux classements
        # incompatibles et les rangs BM25 pointeraient vers de mauvais chunks.
        if self.store.count() != len(self.bm25_ids):
            raise RuntimeError(
                f"Incoherence : le magasin contient {self.store.count()} "
                f"chunks mais BM25 en indexe {len(self.bm25_ids)}.\n"
                "Reconstruire tout : python -m scripts.build_index"
            )

    # ========================================================================
    # 5a. RECHERCHE DENSE
    # ========================================================================

    def _dense(self, question: str, domaines: list[str] | None, k: int) -> list[dict]:
        """
        Compare le vecteur de la question aux vecteurs des chunks.

        Trouve ce qui a le meme SENS meme sans mot commun :
        "puis-je tirer un sanglier la nuit" -> article 172, qui ne contient
        ni "tirer", ni "sanglier", ni "puis-je".

        COUT REEL : environ 1 ms sur 160 chunks. Ce n'est jamais le goulot
        d'etranglement : l'appel au LLM prend 2 a 5 secondes, soit 2000 fois
        plus. Ne t'interdis pas de chunker finement par peur de la lenteur.
        """
        vec = self.modele.encode(
            [config.PREFIXE_QUERY + question],
            normalize_embeddings=True,
        )[0].tolist()
        return self.store.query(vec, k, domaines)

    # ========================================================================
    # 5b. RECHERCHE LEXICALE
    # ========================================================================

    def _bm25(self, question: str, domaines: list[str] | None, k: int) -> list[dict]:
        """
        BM25 = score de pertinence LEXICALE. Trois facteurs combines :

          TF       plus le mot apparait dans le chunk, plus le score monte,
                   mais avec SATURATION : la 10e occurrence pese bien moins
                   que la 2e.
          IDF      plus le mot est RARE dans tout le corpus, plus il pese.
                   "adjudicataires" vaut cher, "la" ne vaut rien.
          Longueur un chunk court contenant le mot bat un chunk long ou il
                   se noie.

        Teste sur ton corpus :
          "adjudicataires perimetres loues" -> art. 14 de l'arrete, score 19,
                                               tres loin devant le 2e
          "chasser a Ain Draham"            -> art. 12 Jendouba (sans accents)
          "chausseurs permis de chasse"     -> art. 176 du code forestier
        """
        # EXPANSION DE REQUETE, cote BM25 uniquement.
        # L'utilisateur dit "prix", le texte officiel dit "redevance
        # domaniale" : sans pont lexical, aucun montant chiffre ne remonte.
        # On n'applique PAS l'expansion au dense : ajouter des mots
        # deplacerait son vecteur vers une moyenne floue.
        scores = self.bm25.get_scores(tokeniser(enrichir(question)))

        # tri decroissant, on ecarte les scores nuls (aucun mot en commun)
        ordre = sorted(range(len(scores)), key=lambda i: -scores[i])[:k * 3]
        ordre = [i for i in ordre if scores[i] > 0][:k]
        if not ordre:
            return []

        par_id = self.store.get([self.bm25_ids[i] for i in ordre])

        sortie, rang = [], 0
        for idx in ordre:
            cid = self.bm25_ids[idx]
            if cid not in par_id:
                continue
            doc, meta = par_id[cid]
            # BM25 ne sait pas filtrer : on applique le domaine a posteriori
            if domaines and meta.get("domaine") not in domaines:
                continue
            rang += 1
            sortie.append({"id": cid, "texte": doc, "meta": meta,
                           "score": float(scores[idx]), "rang": rang})
        return sortie

    # ========================================================================
    # 5c. FUSION RRF
    # ========================================================================

    @staticmethod
    def _rrf(dense: list[dict], lexical: list[dict], k: int, top: int) -> list[dict]:
        """
        Reciprocal Rank Fusion.

        PROBLEME : on a deux classements dont les scores sont incomparables.
        Le dense produit une similarite cosinus entre 0 et 1 ; BM25 produit
        un score non borne qui depend du corpus (19.02 dans notre test).
        Les additionner n'aurait aucun sens.

        SOLUTION : ignorer les scores, ne garder que les RANGS.

            score(chunk) = somme sur chaque liste de   1 / (k + rang)

        Un chunk 1er en dense ET 3e en BM25  -> 1/61 + 1/63 = 0.0323
        Un chunk 1er en dense seulement      -> 1/61        = 0.0164

        Ce que les DEUX methodes valident remonte donc en tete, mais un chunk
        trouve par une seule reste concurrentiel : c'est exactement ce qu'on
        veut, puisque chaque methode rattrape l'angle mort de l'autre.

        La constante k=60 est la valeur standard de la litterature : elle
        amortit l'ecart entre les tout premiers rangs. Sans elle, le 1er
        ecraserait tous les autres.
        """
        scores, infos = {}, {}

        for liste, origine in ((dense, "dense"), (lexical, "bm25")):
            for item in liste:
                cid = item["id"]
                scores[cid] = scores.get(cid, 0) + 1 / (k + item["rang"])
                if cid not in infos:
                    infos[cid] = {**item, "origines": []}
                infos[cid]["origines"].append(f"{origine}#{item['rang']}")

        classes = sorted(scores.items(), key=lambda x: -x[1])

        # DEDUPLICATION : deux chunks peuvent porter le meme texte. Inutile
        # de gaspiller deux places du top-5 pour le meme contenu.
        resultats, vus = [], set()
        for cid, sc in classes:
            empreinte = infos[cid]["texte"][:200]
            if empreinte in vus:
                continue
            vus.add(empreinte)
            resultats.append({**infos[cid], "score_rrf": sc})
            if len(resultats) >= top:
                break
        return resultats

    # ========================================================================
    # API PUBLIQUE
    # ========================================================================

    def rechercher(self, question: str, domaines: list[str] | None = None,
                   question_precedente: str | None = None,
                   top: int | None = None) -> list[dict]:
        """
        Point d'entree unique : question -> top-k chunks pertinents.

        question_precedente sert au MULTI-TOUR. "et pour le lievre ?" ne
        contient ni "periode", ni "chasse", ni "date" : seule, elle ne
        retrouve rien. Concatenee a la question precedente, les mots du tour
        d'avant font remonter les bons chunks, et "lievre" oriente vers la
        bonne ligne du tableau.

        Limite assumee : au 5e tour sur des sujets differents, la
        concatenation ramene du bruit. La solution propre serait une
        reecriture de requete par le LLM, plus couteuse.
        """
        top = top or config.TOP_K_FINAL

        requete = question
        if config.CONCAT_HISTORIQUE_RETRIEVAL and question_precedente:
            requete = f"{question_precedente} {question}"

        dense = self._dense(requete, domaines, config.TOP_K_DENSE)
        lexical = self._bm25(requete, domaines, config.TOP_K_BM25)
        return self._rrf(dense, lexical, config.K_RRF, top)

    def expliquer(self, question: str, domaines: list[str] | None = None,
                  question_precedente: str | None = None) -> None:
        """Affiche le detail du retrieval. Sert au debug et a la demo."""
        requete = question
        if config.CONCAT_HISTORIQUE_RETRIEVAL and question_precedente:
            requete = f"{question_precedente} {question}"

        dense = self._dense(requete, domaines, config.TOP_K_DENSE)
        lexical = self._bm25(requete, domaines, config.TOP_K_BM25)
        top = self._rrf(dense, lexical, config.K_RRF, config.TOP_K_FINAL)

        print(f"\n  QUESTION : {question}")
        if requete != question:
            print(f"  REQUETE  : {requete}")
        print(f"  domaines={domaines or 'tous'} | dense={len(dense)} "
              f"| bm25={len(lexical)} | retenus={len(top)}\n")
        for i, c in enumerate(top, start=1):
            m = c["meta"]
            libelle = f"art. {m['article']}" if m["article"] else m["type"]
            gouv = f" [{m['gouvernorat']}]" if m["gouvernorat"] else ""
            print(f"  {i}. {m['source_id']} {libelle}{gouv}")
            print(f"     RRF={c['score_rrf']:.4f}  via {c['origines']}")
            print(f"     {c['texte'][:90].replace(chr(10), ' ')}...")
        print()