#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from __future__ import annotations
from pydantic import BaseModel, Field


class Message(BaseModel):
    """Un tour de conversation."""
    role: str = Field(..., description="'user' ou 'assistant'")
    content: str


class ChatRequest(BaseModel):
    question: str = Field(..., min_length=1, max_length=1000)

    # Historique conserve COTE CLIENT et renvoye a chaque appel.
    # Choix assume : chatbot_ms reste sans etat, donc sans base de donnees
    # et scalable horizontalement. Le cout est quelques kilo-octets par
    # requete, negligeable.
    historique: list[Message] = Field(default_factory=list)

    specialite: str | None = Field(
        default=None, description="chasseur | campeur | apiculteur") 
        # juste instantanee 7ata na3emlou l'authentification citoyenne bech nwalii nekhoha mel 
        #header X-User-Specialite injecte par le gateway depuis le JWT


class SourceOut(BaseModel):
    """Source citee, affichable sous la reponse dans Flutter."""
    source: str
    article: str | None = None
    gouvernorat: str | None = None
    validite: str | None = None
    extrait: str


class ChatResponse(BaseModel):
    reponse: str
    verdict: VerdictOut | None = None
    sources: list[SourceOut] = Field(default_factory=list)
    domaines: list[str] = Field(default_factory=list)
    depuis_cache: bool = False
    duree_ms: int = 0


class VerdictOut(BaseModel):
    """
    Verdict calcule par rag/calendrier.py.

    Present uniquement quand la question porte a la fois sur une espece et
    une date. L'interface s'en sert pour afficher le bandeau colore et
    l'encart "Prochaine ouverture" ; sans lui, elle affiche simplement la
    reponse en texte.
    """
    etat: str = Field(..., description="autorise | refuse | passee")
    titre: str = Field(..., description="Phrase du bandeau, ex. 'Non, pas demain'")
    espece: str
    prochaine: str | None = Field(
        default=None, description="Date ISO de la prochaine ouverture")