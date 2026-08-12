#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
scripts/diagnostic.py — QUE CONTIENT REELLEMENT L'INDEX ?
==========================================================
Inspecte chunks.json et teste le filtrage par domaine, sans charger le
modele d'embedding. Repond a la question : pourquoi tel profil ne recoit-il
aucun extrait ?

    python -m scripts.diagnostic
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from rag import config

if __name__ == "__main__":
    print("\n=== FICHIERS SOURCES ===\n")
    if not config.CORPUS_DIR.exists():
        print(f"  ABSENT : {config.CORPUS_DIR}")
        sys.exit(1)

    for d in sorted(config.CORPUS_DIR.iterdir()):
        if not d.is_dir():
            continue
        mds = sorted(d.glob("*.md"))
        manifeste = d / "_manifest.json"
        print(f"  {d.name}/")
        print(f"    _manifest.json : {'OUI' if manifeste.exists() else 'ABSENT'}")
        if not mds:
            print(f"    (aucun .md — ce dossier sera ignore)")
        for f in mds:
            print(f"    - {f.name}  ({f.stat().st_size} octets)")

    print("\n=== INDEX ===\n")
    if not config.CHUNKS_FILE.exists():
        print(f"  ABSENT : {config.CHUNKS_FILE}")
        print("  Lancer : python -m scripts.build_index")
        sys.exit(1)

    chunks = json.loads(config.CHUNKS_FILE.read_text(encoding="utf-8"))
    print(f"  {len(chunks)} chunks dans {config.CHUNKS_FILE.name}")

    par_domaine = {}
    for c in chunks:
        d = c["metadata"]["domaine"]
        par_domaine[d] = par_domaine.get(d, 0) + 1
    print(f"  Par domaine : {par_domaine}")

    sources = sorted({c["metadata"]["source_id"] for c in chunks})
    print(f"  source_id   : {sources}")
    if any(s.endswith("_chasse") or s.startswith("arrete_chasse") for s in sources):
        print("    ATTENTION : ces identifiants sont derives du NOM DE FICHIER,")
        print("    donc _manifest.json n'a pas ete lu. Les metadonnees")
        print("    juridiques (rang_normatif, validite) sont incorrectes.")

    print("\n=== FILTRAGE PAR SPECIALITE ===\n")
    for spec in ("chasseur", "campeur", "apiculteur", None):
        doms = config.domaines_pour(spec)
        if doms is None:
            n = len(chunks)
        else:
            n = sum(1 for c in chunks if c["metadata"]["domaine"] in doms)
        etat = "OK" if n else "AUCUN CHUNK ACCESSIBLE"
        print(f"  {str(spec):12} -> domaines={str(doms):28} {n:4d} chunks  {etat}")

    print("\n=== VERSIONS DU CODE ===\n")
    import inspect
    from rag.store import NumpyStore
    sig = str(inspect.signature(NumpyStore.query))
    ok = "domaines" in sig
    print(f"  store.query{sig}")
    print(f"  -> {'A JOUR' if ok else 'ANCIENNE VERSION : remplace rag/store.py'}")

    # On lit le fichier au lieu de l'importer : importer retriever.py
    # chargerait sentence-transformers, inutile pour ce controle.
    src = (Path(__file__).resolve().parent.parent / "rag" / "retriever.py"
           ).read_text(encoding="utf-8")
    ok = "domaines: list[str] | None" in src
    print(f"  retriever.rechercher(domaines=...) "
          f"-> {'A JOUR' if ok else 'ANCIENNE VERSION : remplace rag/retriever.py'}")

    ok_syn = (Path(__file__).resolve().parent.parent / "rag" / "synonymes.py").exists()
    print(f"  rag/synonymes.py                  "
          f"-> {'PRESENT' if ok_syn else 'ABSENT : expansion de requete inactive'}")
    print()