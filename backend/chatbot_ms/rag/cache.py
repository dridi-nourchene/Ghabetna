#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
rag/cache.py — CACHE DE REPONSES
=================================
Filet de securite reseau.

Groq est rapide mais distant : sans connexion, le chatbot ne repond plus.
Ce cache garde les reponses deja obtenues sur disque. Si le reseau tombe
pendant une demonstration, les questions deja posees repondent
instantanement.

Ce n'est PAS un second LLM : c'est un simple dictionnaire persistant.

USAGE RECOMMANDE AVANT UNE SOUTENANCE :
    poser une fois chaque question de la demonstration -> elles sont mises
    en cache -> la demonstration fonctionne meme hors ligne.

La cle du cache inclut la specialite : un chasseur et un apiculteur qui
posent la meme question recoivent des extraits differents, donc des reponses
differentes.
"""

from __future__ import annotations

import hashlib
import json
import threading
import unicodedata

from rag import config

# Un verrou : FastAPI sert plusieurs requetes en parallele, deux ecritures
# simultanees corrompraient le fichier JSON.
_verrou = threading.Lock()
_cache: dict[str, str] | None = None


def _normaliser(texte: str) -> str:
    """
    "Puis-je chasser la nuit ?" et "puis je chasser la nuit"
    doivent donner la meme cle : minuscules, sans accents, espaces reduits.
    """
    t = unicodedata.normalize("NFD", texte.lower().strip())
    t = "".join(c for c in t if unicodedata.category(c) != "Mn")
    return " ".join(t.split())


def _cle(question: str, specialite: str | None) -> str:
    base = f"{_normaliser(question)}|{(specialite or '').lower()}"
    return hashlib.sha256(base.encode()).hexdigest()[:20]


def _charger() -> dict[str, str]:
    global _cache
    if _cache is None:
        if config.CACHE_FILE.exists():
            try:
                _cache = json.loads(config.CACHE_FILE.read_text(encoding="utf-8"))
            except Exception:
                _cache = {}
        else:
            _cache = {}
    return _cache


def lire(question: str, specialite: str | None) -> str | None:
    if not config.CACHE_ACTIF:
        return None
    return _charger().get(_cle(question, specialite))


def ecrire(question: str, specialite: str | None, reponse: str) -> None:
    if not config.CACHE_ACTIF:
        return
    with _verrou:
        cache = _charger()
        cache[_cle(question, specialite)] = reponse
        config.CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
        config.CACHE_FILE.write_text(
            json.dumps(cache, ensure_ascii=False, indent=2), encoding="utf-8")


def taille() -> int:
    return len(_charger())