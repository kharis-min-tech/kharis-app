#!/usr/bin/env python3
"""Builds the bundled King James Version: assets/bible/kjv.json.gz.

Source: the public-domain KJV (1769 text) in OSIS from
https://github.com/seven1m/open-bibles (eng-kjv.osis.xml). Run from anywhere:

    tool/build_kjv_asset.py                      # downloads the OSIS file
    tool/build_kjv_asset.py path/to/eng-kjv.osis.xml

Output, gzipped UTF-8 JSON in canonical order, 66 books only:

    {"GEN": [["In the beginning God created...", ...], ...], ...}

one list per chapter, one plain-text string per verse (verse n at index n-1).
Book ids and chapter counts are checked against kCanonBooks in
lib/core/constants/bible_books.dart. The translators' italics (<transChange>)
are kept as plain words; titles (book titles, Psalm superscriptions, acrostic
letters) are dropped. The gzip header carries no timestamp, so the same source
always builds the same bytes.
"""

from __future__ import annotations

import gzip
import json
import re
import sys
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

SOURCE_URL = (
    "https://raw.githubusercontent.com/seven1m/open-bibles/master/eng-kjv.osis.xml"
)
APP = Path(__file__).resolve().parent.parent
CANON_FILE = APP / "lib/core/constants/bible_books.dart"
OUT = APP / "assets/bible/kjv.json.gz"
NS = "{http://www.bibletechnologies.net/2003/OSIS/namespace}"

# OSIS book id -> USFM id (the YouVersion book ids in kCanonBooks).
OSIS_TO_USFM = {
    "Gen": "GEN", "Exod": "EXO", "Lev": "LEV", "Num": "NUM", "Deut": "DEU",
    "Josh": "JOS", "Judg": "JDG", "Ruth": "RUT", "1Sam": "1SA", "2Sam": "2SA",
    "1Kgs": "1KI", "2Kgs": "2KI", "1Chr": "1CH", "2Chr": "2CH", "Ezra": "EZR",
    "Neh": "NEH", "Esth": "EST", "Job": "JOB", "Ps": "PSA", "Prov": "PRO",
    "Eccl": "ECC", "Song": "SNG", "Isa": "ISA", "Jer": "JER", "Lam": "LAM",
    "Ezek": "EZK", "Dan": "DAN", "Hos": "HOS", "Joel": "JOL", "Amos": "AMO",
    "Obad": "OBA", "Jonah": "JON", "Mic": "MIC", "Nah": "NAM", "Hab": "HAB",
    "Zeph": "ZEP", "Hag": "HAG", "Zech": "ZEC", "Mal": "MAL",
    "Matt": "MAT", "Mark": "MRK", "Luke": "LUK", "John": "JHN", "Acts": "ACT",
    "Rom": "ROM", "1Cor": "1CO", "2Cor": "2CO", "Gal": "GAL", "Eph": "EPH",
    "Phil": "PHP", "Col": "COL", "1Thess": "1TH", "2Thess": "2TH",
    "1Tim": "1TI", "2Tim": "2TI", "Titus": "TIT", "Phlm": "PHM", "Heb": "HEB",
    "Jas": "JAS", "1Pet": "1PE", "2Pet": "2PE", "1John": "1JN", "2John": "2JN",
    "3John": "3JN", "Jude": "JUD", "Rev": "REV",
}

# Elements whose text is never verse text.
SKIP = {"note", "title", "rdg", "reference"}


def canon() -> list[tuple[str, int]]:
    """(usfm, chapters) in canonical order, read from kCanonBooks."""
    text = CANON_FILE.read_text(encoding="utf-8")
    books = re.findall(r"CanonBook\('(\w+)', '[^']*', (\d+), _\w+\)", text)
    if len(books) != 66:
        sys.exit(f"expected 66 books in {CANON_FILE}, found {len(books)}")
    return [(usfm, int(n)) for usfm, n in books]


def load_source(argv: list[str]) -> bytes:
    if len(argv) > 1:
        return Path(argv[1]).read_bytes()
    print(f"downloading {SOURCE_URL}", file=sys.stderr)
    with urllib.request.urlopen(SOURCE_URL, timeout=60) as response:
        return response.read()


def collect_verses(root: ET.Element) -> dict[str, list[str]]:
    """osisID -> text pieces, for milestone (sID/eID) and container verses."""
    pieces: dict[str, list[str]] = {}
    current: str | None = None

    def add(text: str | None) -> None:
        if current is not None and text:
            pieces[current].append(text)

    def walk(el: ET.Element) -> None:
        nonlocal current
        tag = el.tag.removeprefix(NS)
        container = None
        if tag == "verse":
            if "eID" in el.attrib:
                current = None
            elif "osisID" in el.attrib:
                # A multi-verse osisID ("Gen.1.1 Gen.1.2") files its text
                # under the first verse.
                current = el.attrib["osisID"].split()[0]
                pieces.setdefault(current, [])
                if "sID" not in el.attrib:
                    container = current
        if tag in SKIP:
            return
        if tag == "lb":
            add(" ")
        add(el.text)
        for child in el:
            walk(child)
            add(child.tail)
        if container is not None:
            current = None

    walk(root)
    return pieces


def clean(pieces: list[str]) -> str:
    return re.sub(r"\s+", " ", "".join(pieces).replace("\u00b6", "")).strip()


def main(argv: list[str]) -> None:
    books = canon()
    root = ET.fromstring(load_source(argv))
    pieces = collect_verses(root)

    by_book: dict[str, dict[int, dict[int, str]]] = {}
    dropped: set[str] = set()
    for osis_id, parts in pieces.items():
        book, chapter, verse = osis_id.split(".")
        usfm = OSIS_TO_USFM.get(book)
        if usfm is None:
            dropped.add(book)
            continue
        by_book.setdefault(usfm, {}).setdefault(int(chapter), {})[int(verse)] = (
            clean(parts)
        )

    out: dict[str, list[list[str]]] = {}
    total_chapters = total_verses = 0
    for usfm, chapter_count in books:
        chapters = by_book.get(usfm)
        if chapters is None:
            sys.exit(f"{usfm} missing from the source")
        if sorted(chapters) != list(range(1, chapter_count + 1)):
            sys.exit(f"{usfm}: chapters {sorted(chapters)} != 1..{chapter_count}")
        out[usfm] = []
        for c in range(1, chapter_count + 1):
            verses = chapters[c]
            if sorted(verses) != list(range(1, len(verses) + 1)):
                sys.exit(f"{usfm} {c}: verse numbers are not 1..{len(verses)}")
            empty = [v for v, t in verses.items() if not t]
            if empty:
                sys.exit(f"{usfm} {c}: empty verses {empty}")
            out[usfm].append([verses[v] for v in range(1, len(verses) + 1)])
            total_verses += len(verses)
        total_chapters += chapter_count

    data = json.dumps(out, ensure_ascii=False, separators=(",", ":")).encode()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(gzip.compress(data, compresslevel=9, mtime=0))

    print(f"books: {len(out)}  chapters: {total_chapters}  verses: {total_verses}")
    print(f"dropped (outside the canon): {', '.join(sorted(dropped)) or 'none'}")
    print(f"wrote {OUT.relative_to(APP)}: {OUT.stat().st_size:,} bytes "
          f"({len(data):,} bytes JSON)")


if __name__ == "__main__":
    main(sys.argv)
