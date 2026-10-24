"""Rebuild the CSV copies of the reference tables from the reference pages.

The readable pages in docs/reference/ are the source of truth. A page marks the table to
export with an HTML comment on the line just before it:

    <!-- csv: data/tables/apple-slot-signals.csv -->
    | Pin | Signal | ... |

This script finds every such marker, reads the Markdown table that follows, turns links
and formatting into plain text, and writes the CSV (path relative to the repository root).
Tables on one page with the same marker go into one CSV, in page order. Run it after
editing a reference page:

    python tools/export_tables.py
        write the CSVs

    python tools/export_tables.py --check
        report CSVs that are out of date
"""

import csv
import io
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
MARKER = re.compile(r"^<!--\s*csv:\s*(\S+)\s*-->\s*$")


def plain(cell):
    """Turn one Markdown table cell into plain text."""
    cell = cell.replace("\\|", "|")
    cell = re.sub(r"<a id=\"[^\"]*\"></a>", "", cell)      # link targets inside a cell
    cell = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", cell)  # [text](link) -> text
    cell = cell.replace("**", "").replace("`", "")
    return cell.strip()


def split_row(line):
    """Split a Markdown table row into cells, keeping escaped pipes inside cells."""
    body = line.strip()
    if body.startswith("|"):
        body = body[1:]
    if body.endswith("|") and not body.endswith("\\|"):
        body = body[:-1]
    return [plain(c) for c in re.split(r"(?<!\\)\|", body)]


def tables(page):
    """Yield (csv path, rows) for each marked table in one page."""
    lines = page.read_text(encoding="utf-8").splitlines()
    for i, line in enumerate(lines):
        match = MARKER.match(line)
        if not match:
            continue
        rows = []
        for row_line in lines[i + 1:]:
            if not row_line.strip().startswith("|"):
                break
            cells = split_row(row_line)
            if all(re.fullmatch(r":?-{3,}:?", c) for c in cells):
                continue  # the header separator row
            rows.append(cells)
        if not rows:
            raise ValueError(f"{page}: marker for {match.group(1)} is not followed by a table")
        yield match.group(1), rows


def render(rows):
    out = io.StringIO()
    csv.writer(out, lineterminator="\n").writerows(rows)
    return out.getvalue()


def main():
    check = "--check" in sys.argv
    stale = 0
    # Several tables on one page can share a CSV: their rows go into it in page order,
    # under the first table's header. Each later table must repeat that header.
    exports = {}
    for page in sorted((REPO / "docs" / "reference").glob("*.md")):
        for target, rows in tables(page):
            if (target, page) in exports:
                if rows[0] != exports[target, page][0]:
                    raise ValueError(f"{page}: tables for {target} have different headers")
                exports[target, page].extend(rows[1:])
            else:
                exports[target, page] = rows
    for (target, page), rows in exports.items():
        path = REPO / target
        text = render(rows)
        current = path.read_text(encoding="utf-8") if path.exists() else None
        if current == text:
            continue
        stale += 1
        if check:
            print(f"out of date: {target} (from {page.relative_to(REPO)})")
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8", newline="")
            print(f"wrote {target} ({len(rows) - 1} rows) from {page.relative_to(REPO)}")
    if check and stale:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
