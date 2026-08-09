#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
rag/chunker.py — ETAPE 1 : decoupage des .md en chunks
=======================================================

REGLE FONDAMENTALE :
    Un chunk = un ARTICLE de loi.
    Le decoupage est SEMANTIQUE (on cherche le motif "Article N" dans le
    titre) et non SYNTAXIQUE : on ne peut pas se baser sur le niveau ## ou
    ###, car il varie d'un fichier a l'autre. Dans l'arrete les articles
    sont en H2 ; dans le code forestier ils sont en H2 pour le Titre I et
    en H3 pour le Titre II.

MULTI-DOMAINES :
    Le nom du sous-dossier de data/corpus/ DEVIENT la metadonnee "domaine".
    Ajouter l'apiculture = creer data/corpus/apiculture/ et y deposer des .md.
    Aucune ligne de code a modifier.

Ce module ne depend d'aucune librairie externe : il se teste seul.
"""

from __future__ import annotations

import json
import re
import unicodedata
from pathlib import Path

from . import config

# ============================================================================
# EXPRESSIONS REGULIERES
# ============================================================================

RE_TITRE = re.compile(r"^(#{1,6})\s+(.+?)\s*#*$")

# Detecte un ARTICLE quel que soit son niveau de titre.
# Gere "Article premier", "Article 12", "Article 134 bis".
RE_ARTICLE = re.compile(r"^Article\s+(premier|\d+\s*bis|\d+)\b", re.IGNORECASE)

# Sous-section geographique de l'article 12 de l'arrete
RE_GOUVERNORAT = re.compile(r"^Gouvernorat\s+(?:de\s+l'|du\s+|de\s+|d')?(.+)$", re.I)

# Les blocs > ajoutes dans les .md : deux types traites differemment
RE_NOTE_FIDELITE = re.compile(r"\*\*Note de fidélité\.?\*\*|\*\*Périmètre\.?\*\*", re.I)
RE_AVERTISSEMENT = re.compile(r"\*\*Avertissement de concordance\.?\*\*", re.I)

# Coquille officielle + forme correcte :  *(sic : « chasseurs »)*
RE_SIC = re.compile(r"\*\(sic\s*:?\s*«?\s*([^»)]*?)\s*»?\)\*")

RE_LIGNE_TABLEAU = re.compile(r"^\s*\|")
# Ligne de donnees d'un tableau markdown : | espece | ouverture | fermeture |
RE_LIGNE_SEPARATRICE = re.compile(r"^\s*\|[\s:|-]+\|\s*$")


# ============================================================================
# UTILITAIRES
# ============================================================================

def plier_accents(txt: str) -> str:
    """
    Aïn -> Ain, Béjà -> Beja.
    Sert UNIQUEMENT a fabriquer des identifiants techniques.
    Le texte affiche garde ses accents.
    """
    d = unicodedata.normalize("NFD", txt)
    return "".join(c for c in d if unicodedata.category(c) != "Mn")


def slug(txt: str, taille: int = 40) -> str:
    """'Sidi Bouzid' -> 'sidi_bouzid'"""
    t = plier_accents(txt.lower())
    return re.sub(r"[^a-z0-9]+", "_", t).strip("_")[:taille]


def numero_article(titre: str) -> str | None:
    """
    'Article premier' -> '1'  |  'Article 134 bis' -> '134bis'
    None si ce n'est pas un article (Chapitre, Visas, Preambule...).
    """
    m = RE_ARTICLE.match(titre)
    if not m:
        return None
    num = m.group(1).lower().replace(" ", "")
    return "1" if num == "premier" else num


def extraire_alias_sic(texte: str) -> list[str]:
    """
    Recupere les formes correctes derriere les *(sic : « ... »)*.
    L'article 176 ecrit "chausseurs" : coquille du texte OFFICIEL.
    On garde "chausseurs" a l'affichage (fidelite juridique) mais on ajoute
    "chasseurs" comme alias pour que BM25 puisse le retrouver.
    """
    return [m.group(1).strip() for m in RE_SIC.finditer(texte)
            if m.group(1).strip() and len(m.group(1).strip()) < 60]


# ============================================================================
# DECOUPAGE EN SECTIONS
# ============================================================================

def decouper_sections(texte: str) -> list[dict]:
    """
    Produit une liste de sections, chacune avec LA PILE DE SES PARENTS.

    La pile est essentielle : "### Article 165" ne dit pas a quel Titre ni a
    quel Chapitre il appartient. Ce sont ses parents qui le disent, et c'est
    cette information qui constituera le prefixe contextuel.
    """
    sections, courante = [], None
    parents: dict[int, str] = {}

    for ligne in texte.splitlines():
        m = RE_TITRE.match(ligne)
        if m:
            niveau, titre = len(m.group(1)), m.group(2).strip()
            if courante:
                sections.append(courante)
            # On oublie les parents de niveau >= au notre : en arrivant sur
            # "## Chapitre II" on oublie les "###" du chapitre precedent,
            # mais on garde le "# Titre II".
            parents = {k: v for k, v in parents.items() if k < niveau}
            courante = {"niveau": niveau, "titre": titre,
                        "parents": [parents[k] for k in sorted(parents)],
                        "lignes": []}
            parents[niveau] = titre
        elif courante is not None:
            courante["lignes"].append(ligne)

    if courante:
        sections.append(courante)
    return sections


# ============================================================================
# SEPARATION NORMATIF / NOTES
# ============================================================================

def separer_contenu(lignes: list[str]) -> tuple[str, list[str], list[str]]:
    """
    Trie le contenu en trois categories :

    1. normatif       -> le texte de loi lui-meme
    2. avertissements -> blocs "> **Avertissement de concordance**"
                         A INDEXER : ils empechent une reponse fausse
                         (renvoi perime de la loi 69-33 vers l'article 161).
    3. notes          -> blocs "> **Note de fidélité**", purement editoriaux,
                         exclus de l'index.
    """
    normatif, avertissements, notes = [], [], []
    bloc, type_bloc = [], None

    def cloturer():
        nonlocal bloc, type_bloc
        if bloc:
            contenu = "\n".join(bloc).strip()
            (avertissements if type_bloc == "avertissement" else notes).append(contenu)
        bloc, type_bloc = [], None

    for ligne in lignes:
        nue = ligne.strip()

        if nue.startswith(">"):
            contenu = nue.lstrip("> ").rstrip()
            if type_bloc is None:
                type_bloc = ("avertissement" if RE_AVERTISSEMENT.search(contenu)
                             else "note")
            bloc.append(contenu)
            continue

        if bloc:
            cloturer()

        if nue == "---":
            continue
        if nue.startswith("**Source officielle"):
            continue
        if nue.startswith("*(La suite de l'article"):
            continue

        normatif.append(nue)

    cloturer()
    texte = re.sub(r"\n{3,}", "\n\n", "\n".join(normatif)).strip()
    return texte, avertissements, notes


# ============================================================================
# SOUS-DECOUPAGE DES ARTICLES TROP LONGS
# ============================================================================

def eclater_tableau(texte: str) -> list[tuple[str, str]] | None:
    """
    Transforme un tableau markdown en une liste de (etiquette, phrase).

    POURQUOI : le tableau de l'article premier fait 2462 caracteres et
    melange 10 especes. Le signal "sanglier" s'y noyait parmi lievre,
    becasse et tourterelle : un vecteur unique ne peut pas representer
    10 regimes de dates differents.

    Meme principe que l'article 12 : un tableau est une base de donnees
    deguisee en prose, pas de la prose. On le decoupe par LIGNE.

    Retourne None si le texte n'est pas un tableau exploitable.
    """
    lignes = [l for l in texte.splitlines() if RE_LIGNE_TABLEAU.match(l)]
    if len(lignes) < 3:
        return None

    entetes, donnees = None, []
    for l in lignes:
        if RE_LIGNE_SEPARATRICE.match(l):
            continue
        cells = [c.strip() for c in l.strip().strip("|").split("|")]
        if entetes is None:
            entetes = cells
        else:
            donnees.append(cells)

    if not entetes or not donnees:
        return None

    sortie = []
    for cells in donnees:
        if len(cells) != len(entetes):
            continue
        # Premiere colonne = sujet de la ligne (l'espece)
        sujet = cells[0]
        details = ", ".join(f"{e} : {c}" for e, c in zip(entetes[1:], cells[1:]))
        sortie.append((sujet, f"{sujet}. {details}."))
    return sortie or None


def contient_tableau(texte: str) -> bool:
    """Un tableau markdown ne doit JAMAIS etre coupe au milieu."""
    return any(RE_LIGNE_TABLEAU.match(l) for l in texte.splitlines())


def sous_decouper(texte: str) -> list[str]:
    """
    Regroupe les paragraphes en blocs de <= TAILLE_MAX_CHUNK caracteres.

    Pourquoi : un embedding est un vecteur de taille FIXE. Plus le texte est
    long, plus le sens s'y dilue. L'article 3 de l'arrete melange redevances,
    eperviers, faucons, slougui, sanglier et etourneaux : un seul vecteur ne
    peut pas representer tout ca.

    On ne coupe jamais au milieu d'un paragraphe. Et on laisse les tableaux
    entiers meme s'ils depassent : le tableau de l'article premier fait
    ~2500 caracteres mais forme un bloc coherent.
    """
    if contient_tableau(texte) or len(texte) <= config.TAILLE_MAX_CHUNK:
        return [texte]

    paragraphes = [p.strip() for p in re.split(r"\n\s*\n", texte) if p.strip()]
    blocs, courant = [], []

    for p in paragraphes:
        if courant and sum(len(x) for x in courant) + len(p) > config.TAILLE_MAX_CHUNK:
            blocs.append("\n\n".join(courant))
            courant = [p]
        else:
            courant.append(p)

    if courant:
        blocs.append("\n\n".join(courant))
    return blocs


# ============================================================================
# PREFIXE CONTEXTUEL
# ============================================================================

def _libelle_court(meta: dict) -> str:
    """
    Version abregee de la source, pour le prefixe d'embedding.
    "Arrêté du 27 août 2025 (JORT n° 107 du 29 août 2025)" -> "Arrêté chasse 2025/2026"
    """
    sid = meta.get("source_id", "")
    return {
        "arrete_2025": "Arrêté chasse 2025/2026",
        "code_forestier": "Code forestier",
        "loi_69_33": "Loi armes 69-33",
    }.get(sid, meta["source"][:40])


def construire_prefixe(meta: dict, parents: list[str], titre: str) -> str:
    """
    PREFIXE LONG — pour BM25 uniquement, et pour l'affichage.

    Il porte la source complete et toute la hierarchie. Sur un index lexical
    c'est gratuit : BM25 pondere par l'IDF, donc les mots repetes dans les
    160 chunks ("arrêté", "titre") ont un poids quasi nul automatiquement.
    """
    morceaux = [meta["source"]]
    for p in parents:
        if p.startswith(("Titre", "Chapitre", "Partie", "Section")):
            morceaux.append(p)
    morceaux.append(titre)
    return " — ".join(morceaux)


def construire_prefixe_court(meta: dict, titre: str, extra: str = "") -> str:
    """
    PREFIXE COURT — pour l'EMBEDDING.

    POURQUOI DEUX PREFIXES :
    un embedding est un vecteur de taille fixe ou CHAQUE token compte. Le
    prefixe long fait ~25 tokens IDENTIQUES sur les 57 chunks de l'arrete.
    Sur un chunk court, il representait la moitie du contenu : tous les
    vecteurs se ressemblaient et la partie discriminante pesait trop peu.
    C'est ce qui faisait remonter l'article 10 (colportage) en tete de trois
    questions sans rapport.

    Contrairement a BM25, l'embedding n'a AUCUN mecanisme equivalent a l'IDF
    pour ignorer ce qui est commun a tout le corpus. Il faut donc le lui
    epargner : ici ~6 tokens au lieu de 25.
    """
    base = f"{_libelle_court(meta)}, {titre}"
    return f"{base}. {extra}" if extra else base


# ============================================================================
# CHARGEMENT DES METADONNEES D'UN DOMAINE
# ============================================================================

def charger_manifeste(dossier_domaine: Path) -> dict:
    """
    Lit data/corpus/<domaine>/_manifest.json s'il existe.

    Le nom du dossier donne le DOMAINE, mais pas le rang normatif ni la
    validite : c'est le role du manifeste. S'il est absent (cas de camping/
    ou app/), on applique META_DEFAUT et tout fonctionne quand meme.
    """
    f = dossier_domaine / "_manifest.json"
    if f.exists():
        return json.loads(f.read_text(encoding="utf-8"))
    return {}


# ============================================================================
# TRAITEMENT D'UN FICHIER
# ============================================================================

def chunker_fichier(chemin: Path, domaine: str, meta_fichier: dict) -> list[dict]:
    texte = chemin.read_text(encoding="utf-8")
    chunks = []

    for sec in decouper_sections(texte):
        corps, avertissements, _ = separer_contenu(sec["lignes"])
        titre = sec["titre"]
        prefixe = construire_prefixe(meta_fichier, sec["parents"], titre)

        # ---- EXCEPTION 1 : sous-sections geographiques de l'article 12 ----
        m_gouv = RE_GOUVERNORAT.match(titre)
        if m_gouv and corps:
            # "### Gouvernorat de Siliana" n'est pas un article : c'est une
            # subdivision de l'article 12. On remonte la pile des parents
            # pour retrouver l'article de rattachement.
            art_parent = next((numero_article(p) for p in reversed(sec["parents"])
                               if numero_article(p)), None)
            gouv = m_gouv.group(1).strip()
            court = construire_prefixe_court(
                meta_fichier, f"Article {art_parent}",
                f"Réserves de chasse interdites, gouvernorat de {gouv}")
            chunks.append(_fabriquer(meta_fichier, domaine, art_parent,
                                     slug(gouv), titre, prefixe, court, corps,
                                     "zone_geographique", gouv))
            continue

        article = numero_article(titre)

        # ---- EXCEPTION 2 : sections qui ne sont pas des articles ----------
        if article is None:
            # Visas, Preambule, Lacunes connues. Non normatifs mais utiles.
            # "Lacunes connues" permet au bot de repondre "cette information
            # n'est pas dans mon corpus" au lieu d'inventer.
            if corps and len(corps) > config.TAILLE_MIN_ALERTE:
                court = construire_prefixe_court(meta_fichier, titre)
                chunks.append(_fabriquer(meta_fichier, domaine, None,
                                         slug(titre), titre, prefixe, court,
                                         corps, "contexte", None))
            continue

        # ---- CAS NORMAL : un article --------------------------------------
        if corps:
            # --- EXCEPTION 4 : article contenant un tableau ----------------
            # Une ligne de tableau = un chunk. Sinon les 10 especes du
            # tableau de l'article premier se noient dans un seul vecteur.
            lignes_tab = eclater_tableau(corps) if contient_tableau(corps) else None

            if lignes_tab:
                # le texte hors tableau (alineas qui suivent) devient un chunk
                hors_tableau = "\n".join(
                    l for l in corps.splitlines()
                    if not RE_LIGNE_TABLEAU.match(l)).strip()

                for sujet, phrase in lignes_tab:
                    court = construire_prefixe_court(meta_fichier, titre, sujet)
                    chunks.append(_fabriquer(
                        meta_fichier, domaine, article, slug(sujet, 30), titre,
                        f"{prefixe} — {sujet}", court, phrase, "tableau", None))

                if len(hors_tableau) > config.TAILLE_MIN_ALERTE:
                    court = construire_prefixe_court(meta_fichier, titre)
                    chunks.append(_fabriquer(
                        meta_fichier, domaine, article, "suite", titre,
                        prefixe, court, hors_tableau, "norme", None))
            else:
                blocs = sous_decouper(corps)
                for i, bloc in enumerate(blocs, start=1):
                    # Si l'article a ete sous-decoupe, on l'indique au LLM
                    # pour qu'il sache qu'il ne voit qu'un extrait.
                    suffixe = f" (partie {i}/{len(blocs)})" if len(blocs) > 1 else ""
                    court = construire_prefixe_court(meta_fichier, titre)
                    chunks.append(_fabriquer(meta_fichier, domaine, article,
                                             f"p{i}" if len(blocs) > 1 else None,
                                             titre, prefixe + suffixe, court,
                                             bloc, "norme", None))

        # ---- EXCEPTION 3 : avertissements de concordance -------------------
        for j, avert in enumerate(avertissements, start=1):
            court = construire_prefixe_court(
                meta_fichier, titre, "avertissement de concordance")
            chunks.append(_fabriquer(meta_fichier, domaine, article,
                                     f"avert{j}",
                                     f"{titre} — avertissement de concordance",
                                     prefixe + " — avertissement de concordance",
                                     court, avert, "avertissement", None))

    return chunks


def _fabriquer(meta_fichier, domaine, article, sous_cle, titre, prefixe,
               prefixe_court, texte, type_chunk, gouvernorat) -> dict:
    """
    Fabrique un chunk normalise.

    Les metadonnees restent des types simples (str, int, float, bool) :
    ni liste, ni dict. D'ou les alias joints en une seule chaine. Cela
    garde le format lisible en JSON et compatible avec n'importe quel
    magasin de vecteurs.
    """
    ident = f"{meta_fichier['source_id']}_art{article or slug(titre, 20)}"
    if sous_cle:
        ident += f"_{sous_cle}"

    return {
        "id": ident,
        # texte_embedding -> COURT, ce qu'on vectorise. Chaque token compte.
        "texte_embedding": f"{prefixe_court}\n{texte}",
        # texte_indexe -> LONG, ce que BM25 lit. L'IDF neutralise le commun.
        "texte_indexe": f"{prefixe}\n\n{texte}",
        # texte_affiche -> ce qu'on MONTRE au LLM et a l'utilisateur
        "texte_affiche": texte,
        "prefixe": prefixe,
        "prefixe_court": prefixe_court,
        "metadata": {
            "domaine": domaine,
            "source": meta_fichier["source"],
            "source_id": meta_fichier["source_id"],
            "rang_normatif": meta_fichier["rang_normatif"],
            "rang_poids": meta_fichier["rang_poids"],
            "validite": meta_fichier["validite"],
            "article": article or "",
            "titre": titre,
            "type": type_chunk,
            "gouvernorat": gouvernorat or "",
            "alias": " | ".join(extraire_alias_sic(texte)),
            "nb_caracteres": len(texte),
        },
    }


# ============================================================================
# POINT D'ENTREE : SCAN DE TOUS LES DOMAINES
# ============================================================================

def chunker_corpus(verbeux: bool = True) -> list[dict]:
    """
    Parcourt data/corpus/<domaine>/*.md et produit tous les chunks.
    Le nom du sous-dossier devient la metadonnee "domaine".
    """
    tous = []

    for dossier in sorted(config.CORPUS_DIR.iterdir()):
        if not dossier.is_dir():
            continue
        domaine = dossier.name
        manifeste = charger_manifeste(dossier)
        fichiers = sorted(dossier.glob("*.md"))

        if not fichiers:
            continue
        if verbeux:
            print(f"\n  [{domaine}]")

        for f in fichiers:
            meta = {**config.META_DEFAUT, **manifeste.get(f.name, {})}
            # Si aucun manifeste, on derive un source_id du nom de fichier
            # pour que les identifiants de chunks restent uniques.
            if f.name not in manifeste:
                meta["source_id"] = slug(f.stem, 30)
                meta["source"] = f.stem.replace("_", " ")
            c = chunker_fichier(f, domaine, meta)
            tous.extend(c)
            if verbeux:
                print(f"    {f.name:38s} -> {len(c):3d} chunks")

    config.INDEX_DIR.mkdir(parents=True, exist_ok=True)
    config.CHUNKS_FILE.write_text(
        json.dumps(tous, ensure_ascii=False, indent=2), encoding="utf-8")

    if verbeux and tous:
        _rapport(tous)
    return tous


def _rapport(chunks: list[dict]) -> None:
    """Controle qualite affiche apres le chunking."""
    print(f"\n  TOTAL : {len(chunks)} chunks -> {config.CHUNKS_FILE}")

    for cle in ("domaine", "type"):
        compte = {}
        for c in chunks:
            v = c["metadata"][cle]
            compte[v] = compte.get(v, 0) + 1
        print(f"  Par {cle} : {compte}")

    tailles = [c["metadata"]["nb_caracteres"] for c in chunks]
    print(f"  Taille : min={min(tailles)} / moy={sum(tailles)//len(tailles)} "
          f"/ max={max(tailles)}")

    courts = [c["id"] for c in chunks
              if c["metadata"]["nb_caracteres"] < config.TAILLE_MIN_ALERTE
              and c["metadata"]["type"] == "norme"]
    if courts:
        print(f"  Chunks courts (< {config.TAILLE_MIN_ALERTE} car.) : {len(courts)}"
              f" — sauves par le prefixe contextuel")


if __name__ == "__main__":
    print("\n=== ETAPE 1 : CHUNKING ===")
    chunker_corpus()