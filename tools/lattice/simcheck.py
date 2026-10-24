"""Check chipsim.py against the design sources: a fuse map pDS 2.61 built from an LDF runs
in chipsim.py while the LDF itself runs in ldfsim.py (no fuse decode at all); both get the
same random vectors on the source's input pins, clock pins and the Y1/RESET pin, and the
source's output pins are compared after each settles.

Usage: python simcheck.py SOURCE.LDF MAP.jed [SOURCE.LDF MAP.jed ...]"""
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import chipsim  # noqa: E402
import ldfsim  # noqa: E402
import lif as L  # noqa: E402
from jedec import read_jed  # noqa: E402


def complemented_signals(lif_path):
    """Signals pDS stores complemented in a GLB (output pin flag 0x800 in the design's LIF,
    set by _lf_Add_Cell_Output): with every chip output 0 at power-up they start at 1."""
    if not Path(lif_path).exists():
        return set()
    d = L.read(lif_path)
    out = set()
    for c in d["cells"][0]:
        for i in c["pins_out"]:
            p = d["pins"][i - 1]
            if p["i4"] & 0x800 and p["i10"]:
                out.add(d["nets"][p["i10"] - 1]["name"])
    return out


def run(ldf, jed, vectors=3000, seed=1, many=4, delay=False):
    chip = chipsim.Chip(read_jed(jed))
    pkg_ioc = {loc: chip.pkg[("IOC", loc)] for loc in chip.iocs}
    des = ldfsim.Design(Path(ldf).read_text(encoding="latin-1"), pkg_ioc)
    ref = ldfsim.Sim(des)
    ref.pin_delay = delay
    inverted = complemented_signals(Path(jed).with_suffix(".lif"))
    for sig in inverted:
        if sig in ref.v:
            ref.v[sig] = 1
    ins = sorted(set(des.pins_in.values()) | {p for _, p, _ in des.ioreg.values()} | {11, 33, 35})
    outs = sorted(des.pins_out)
    rnd = random.Random(seed)
    state = {p: 1 for p in ins}
    for p in ins:
        chip.drive(p, 1)
        ref.drive(p, 1)
    chip.power_up()
    ref.power_up()
    diffs = 0
    for n in range(vectors):
        if rnd.random() < 0.3:
            p = rnd.choice((11, 33, 35))
            state[p] ^= 1
            if p == 35 and des.y1_reset and rnd.random() < 0.7:
                state[p] = 1          # keep reset pulses short
        else:
            # data pins only: a clock pin changing with data is a setup-time race, which
            # the two models resolve differently (the chip's data path is longer)
            data = [p for p in ins if p not in (11, 33, 35)]
            for p in rnd.sample(data, min(len(data), rnd.randint(1, many))):
                state[p] = rnd.randrange(2)
        for p in ins:
            chip.drive(p, state[p])
            ref.drive(p, state[p])
        chip.settle()
        ref.settle()
        a = {p: chip.pin(p) for p in outs}
        b = {p: ref.pin(p) for p in outs}
        if a != b:
            diffs += 1
            if diffs <= 5:
                bad = {p: (a[p], b[p]) for p in outs if a[p] != b[p]}
                print(f"{Path(jed).name} vector {n}: pins differ (map, source): {bad}")
    # exhaustive walk: every combination of the data inputs (Gray code, one pin per step),
    # each followed by a pulse on every clock pin, when there are few enough data inputs
    data = [p for p in ins if p not in (11, 33, 35)]
    walked = 0
    if len(data) <= 14:
        clocks = [p for p in (11, 33, 35) if p in ins]
        g_prev = 0
        for k in range(1, 1 << len(data)):
            g = k ^ (k >> 1)
            b = (g ^ g_prev).bit_length() - 1
            g_prev = g
            state[data[b]] ^= 1
            steps = [None] + [c for c in clocks for _ in (0, 1)]
            for c in steps:
                if c is not None:
                    state[c] ^= 1
                    if c == 35 and des.y1_reset:
                        continue        # the Y1/RESET pin is pulsed by the random phase
                for p in ins:
                    chip.drive(p, state[p])
                    ref.drive(p, state[p])
                chip.settle()
                ref.settle()
                walked += 1
                a = {p: chip.pin(p) for p in outs}
                b2 = {p: ref.pin(p) for p in outs}
                if a != b2:
                    diffs += 1
                    if diffs <= 5:
                        bad = {p: (a[p], b2[p]) for p in outs if a[p] != b2[p]}
                        print(f"{Path(jed).name} walk step {walked}: pins differ (map, source): {bad}")
        print(f"{Path(jed).name}: walked all {1 << len(data)} combinations of {len(data)} data "
              f"inputs with clock pulses ({walked} settles)")
    if inverted:
        print(f"{Path(jed).name}: power-up 1 for signals pDS stores complemented: {sorted(inverted)}")
    print(f"{Path(jed).name} against {Path(ldf).name}: {vectors} vectors on {len(ins)} inputs, "
          f"{len(outs)} outputs compared, {diffs} vectors with any output different")
    return diffs == 0


if __name__ == "__main__":
    a = sys.argv[1:]
    many = 4
    delay = False
    while a and a[0].startswith("--"):
        if a[0] == "--one":
            many = 1
        elif a[0] == "--pin-delay":
            delay = True
        a = a[1:]
    ok = all([run(a[k], a[k + 1], many=many, delay=delay) for k in range(0, len(a), 2)])
    sys.exit(0 if ok else 1)
