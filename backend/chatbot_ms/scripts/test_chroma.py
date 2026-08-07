#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
scripts/test_chroma.py — ISOLE LE PROBLEME CHROMADB
====================================================
N'utilise ni le modele, ni le corpus : juste chromadb avec 3 faux vecteurs.
Si ce script crashe aussi, l'installation de chromadb est en cause et non
le code du projet.

    python scripts/test_chroma.py
"""
import sys, tempfile

print("python  :", sys.version.split()[0])
try:
    import numpy; print("numpy   :", numpy.__version__)
except ImportError: pass
import chromadb
print("chromadb:", chromadb.__version__)

print("[1] client...")
client = chromadb.PersistentClient(path=tempfile.mkdtemp())
print("[2] collection...")
col = client.get_or_create_collection("t", metadata={"hnsw:space": "cosine"})
print("[3] insertion...")
col.add(ids=["a", "b"], embeddings=[[0.1] * 1024, [0.2] * 1024],
        documents=["un", "deux"], metadatas=[{"d": "1"}, {"d": "2"}])
print("[4] count =", col.count())
print("OK — chromadb fonctionne")