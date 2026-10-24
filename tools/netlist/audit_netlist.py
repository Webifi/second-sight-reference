"""Validate exported CSV connectivity and create review indexes.

This checks the transcription's internal consistency, not the physical board.
Run after build_netlist.py and check_pinouts.py. Standard library only.
"""

import csv
import hashlib
import json
from collections import Counter, defaultdict
from pathlib import Path

# Outputs live in data/netlist/ at the repository root.
ROOT = Path(__file__).resolve().parents[2] / "data" / "netlist"


def read_csv(name):
    with (ROOT / name).open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def write_csv(name, rows, fields):
    with (ROOT / name).open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fields)
        writer.writeheader()
        writer.writerows(rows)


rows = read_csv("netlist.csv")
nets = read_csv("nets.csv")
bom = read_csv("bom.csv")
checks = read_csv("pinout_checks.csv")
pin_ids = [f"{row['refdes']}.{row['pin_number']}" for row in rows]
assert len(pin_ids) == len(set(pin_ids)), "Duplicate physical pin"
assert len(bom) == len({row["refdes"] for row in bom}), "Duplicate BOM part"
assert {row["refdes"] for row in rows} == {row["refdes"] for row in bom}
assert all(row["confidence"] in {"high", "medium", "low"} for row in rows)
assert all(row["net"] and int(row["pin_number"]) > 0 for row in rows)
assert all(set(row["sheet"].split(";")) <= {"1", "2", "3", "4", "5"} for row in rows)

forward = defaultdict(set)
for row, pin_id in zip(rows, pin_ids):
    forward[row["net"]].add(pin_id)
assert len(nets) == len({row["net"] for row in nets}), "Duplicate net row"
inverse = {}
for row in nets:
    pins = row["pins"].split(";")
    assert len(pins) == len(set(pins)) == int(row["pin_count"])
    inverse[row["net"]] = set(pins)
assert dict(forward) == inverse, "Forward/inverse connectivity mismatch"
for name, pins in inverse.items():
    if name.startswith(("NC_", "UNRESOLVED_")):
        assert len(pins) == 1, "Independent unknown/open pins accidentally merged"

# Each physical IC pin must have exactly one independent datasheet comparison.
ic_ids = {
    pin_id
    for row, pin_id in zip(rows, pin_ids)
    if row["refdes"].startswith("U") and row["refdes"] != "U1"
}
check_ids = [f"{row['refdes']}.{row['pin_number']}" for row in checks]
assert len(check_ids) == len(set(check_ids))
assert set(check_ids) == ic_ids
assert len(read_csv("bt478_bt481_pin_changes.csv")) == 44

singletons = [
    row
    for row in nets
    if int(row["pin_count"]) == 1 and not row["net"].startswith(("NC_", "UNRESOLVED_"))
]
write_csv("singleton_nets.csv", singletons, ["net", "pin_count", "pins"])
uncertain = [row for row in rows if row["confidence"] != "high"]
write_csv("uncertain_pins.csv", uncertain, list(rows[0]))
differences = [row for row in checks if row["status"] != "match"]
write_csv("pinout_differences.csv", differences, list(checks[0]))

checked_text = sorted(ROOT.glob("*.csv")) + sorted(ROOT.glob("*.md"))
checked_text += sorted(ROOT.glob("*.py"))
for path in checked_text:
    content = path.read_text(encoding="utf-8")
    assert "\ufffd" not in content and "\x00" not in content, path.name

sheet_counts = Counter(row["sheet"] for row in rows)
report = {
    "result": "PASS: CSV consistency and pin coverage only",
    "part_count": len(bom),
    "pin_positions": len(rows),
    "net_count_including_open_and_unknown": len(nets),
    "pins_by_sheet": dict(sorted(sheet_counts.items())),
    "confidence": dict(Counter(row["confidence"] for row in rows)),
    "ic_parts": len({row["refdes"] for row in checks}),
    "ic_pin_comparisons": len(checks),
    "pinout_status_counts": dict(Counter(row["status"] for row in checks)),
    "unresolved_pins": [
        pin_id
        for row, pin_id in zip(rows, pin_ids)
        if row["net"].startswith("UNRESOLVED_")
    ],
    "named_singleton_count": len(singletons),
    "checks": [
        "Unique physical pins and BOM references",
        "BOM and netlist component sets agree",
        "Valid sheet numbers, pin numbers and confidence values",
        "Exact forward/inverse connectivity equality",
        "No accidental merging of NC or unresolved pins",
        "Every IC pin has one datasheet comparison",
        "All 44 production RAMDAC pins compared",
        "UTF-8 output has no replacement or NUL characters",
    ],
    "limits": [
        "No board continuity or powered measurements",
        "Hidden power rails are inferences",
        "No original CAD netlist or GAL fusemaps",
        "Production differences do not change the prototype CSV",
    ],
    "sha256": {
        path.name: hashlib.sha256(path.read_bytes()).hexdigest()
        for path in checked_text
    },
}
(ROOT / "audit.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(
    json.dumps(
        {key: value for key, value in report.items() if key != "sha256"}, indent=2
    )
)
