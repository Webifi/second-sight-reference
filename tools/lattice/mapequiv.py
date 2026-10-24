"""Compare two ispLSI1016 fuse maps by behaviour in chipsim.py: the same random vectors on
every pin (one data pin per vector, or one clock pin alone, so no races), every pin
compared after both settle. For a map rebuilt from a decompiled source that pDS places
differently from the original.

Both maps start in their source's all-zero state: a GLB output that pDS stored
complemented (named in the router's file beside the map, MAP.lpr) starts at 1. Lattice
documents no power-up state, so a map without one is taken to store every signal true.

Usage: python mapequiv.py A.jed B.jed [vectors]"""
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import chipsim  # noqa: E402
from jedec import read_jed  # noqa: E402

CLOCK_PINS = (11, 33, 35)


def run(a_path, b_path, vectors=10000, seed=1):
    a = chipsim.Chip(read_jed(a_path))
    b = chipsim.Chip(read_jed(b_path))
    pins = sorted(a.pad_of_pin)
    # pins either map drives are outputs: leave them undriven from outside
    driven = set()
    for chip in (a, b):
        for loc in chip.iocs:
            if chip.d["iocs"][loc]["config"].get("P_IO_OE", (None,))[0] != "P_GND":
                driven.add(chip.pkg[("IOC", loc)])
    ins = [p for p in pins if p not in driven]
    state = {p: 1 for p in ins}
    for p in ins:
        a.drive(p, 1)
        b.drive(p, 1)
    for chip, path in ((a, a_path), (b, b_path)):
        ones = chipsim.complemented_outputs(Path(path).with_suffix(".lpr"), chip.mr.N)
        if ones:
            print(f"{Path(path).name}: start at 1 (stored complemented): {sorted(ones)}")
        chip.power_up(ones)
    rnd = random.Random(seed)
    data = [p for p in ins if p not in CLOCK_PINS]
    diffs = 0
    for n in range(vectors):
        if rnd.random() < 0.3:
            p = rnd.choice([c for c in CLOCK_PINS if c in ins])
        else:
            p = rnd.choice(data)
        state[p] ^= 1
        a.drive(p, state[p])
        b.drive(p, state[p])
        a.settle()
        b.settle()
        va = {q: a.pin(q) for q in pins}
        vb = {q: b.pin(q) for q in pins}
        if va != vb:
            diffs += 1
            if diffs <= 5:
                print(f"vector {n}: pins differ: {{{', '.join(f'{q}: {va[q]}/{vb[q]}' for q in pins if va[q] != vb[q])}}}")
    print(f"{Path(a_path).name} vs {Path(b_path).name}: {vectors} vectors on {len(ins)} inputs, "
          f"{diffs} with any pin different")
    return diffs == 0


if __name__ == "__main__":
    n = int(sys.argv[3]) if len(sys.argv) > 3 else 10000
    sys.exit(0 if run(sys.argv[1], sys.argv[2], n) else 1)
