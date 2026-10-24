"""Drive U7 through Apple and Z180 bus cycles and check what it does.

Each Apple cycle follows docs/04-capture-logic.md: the address phase (PHASE 0, pin CPU,
low) with address, R/W, M2SEL and the bank bit on M2B0; falling Y2 edges, the first after
CPU falls opening the bank window that samples M2B0; the data phase (CPU high), when a
qualifying write is copied (CATCH_N low) and an event can be latched; a falling Y0 edge,
which loads the tracked softswitches; then CPU falls again. A Z180 access raises AX with
the port's low three bits on HA0-HA2 (and drives HD0-HD3 on a write), then lowers AX.

A "chip" is a fuse map in chipsim.py, or a design source in ldfsim.py; both are driven
by package pin, and the pin names come from the source's I/O cells (XPIN ... LOCK n).

    python u7_test.py directed ORIGINAL.jed FIXED.jed SOURCE.ldf
        the v2.0 behaviour checks (E14, E15, E28, and the unchanged $9000 band flag) on
        both maps
    python u7_test.py compare SOURCE.ldf A [B ...]
        the same random bus cycles on each A, B, ... (fuse maps .jed, or sources .ldf),
        every output pin compared after each cycle
"""
import itertools
import random
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import chipsim  # noqa: E402
import ldfsim  # noqa: E402
from jedec import read_jed  # noqa: E402

OUTPUT_PINS = ["CATCH_N", "ADIN_N", "ADOUT_N", "CATCH_BANK", "INT1_N", "RDY0", "HD0", "HD1", "HD2", "HD3"]


def pin_names(ldf_text):
    """{signal name of an I/O cell: package pin} from the source's SYM IOC sections."""
    text = re.sub(r"//[^\n]*", "", ldf_text)
    names = {}
    for cell, name, body in re.findall(r"SYM\s+IOC\s+(\S+)\s+1\s+(\S+);(.*?)END;", text, re.S):
        m = re.search(r"LOCK\s+(\d+)", body)
        names[name] = int(m.group(1)) if m else ldfsim.DEDICATED[cell]
    return names


class Bus:
    """A chip driven by pin name."""

    def __init__(self, path, ldf_text):
        self.path = Path(path)
        self.pins = pin_names(ldf_text)
        if self.path.suffix.lower() == ".jed":
            self.chip = chipsim.Chip(read_jed(path))
            ones = chipsim.complemented_outputs(self.path.with_suffix(".lpr"), self.chip.mr.N)
        else:
            text = self.path.read_text(encoding="latin-1")
            pkg = {}
            self.chip = ldfsim.Sim(ldfsim.Design(text, pkg))
            ones = None
        for name, pin in self.pins.items():
            if name not in OUTPUT_PINS or name in ("HD2", "HD3"):
                self.chip.drive(pin, 1)
        if ones is None:
            self.chip.power_up()
        else:
            self.chip.power_up(ones)

    def set(self, **values):
        for name, v in values.items():
            self.chip.drive(self.pins[name], v)
        self.chip.settle()

    def get(self, name):
        return self.chip.pin(self.pins[name])


def y2_edge(c):
    c.set(CLK_Y2=0)
    c.set(CLK_Y2=1)


def apple(c, address, write=True, bank=0, m2sel=0, ad4=0, ad6=0):
    """One Apple bus cycle; returns the output pins seen during its data phase."""
    c.set(CPU=1)
    y2_edge(c)
    c.set(CPU=0, ARW=0 if write else 1, M2SEL_N=m2sel, M2B0=bank, AD4=ad4, AD6=ad6,
          **{f"AA{i}": (address >> i) & 1 for i in range(16)})
    y2_edge(c)
    y2_edge(c)
    # the IIgs drives M2B0 only early in the address phase; the card's pull-down holds it
    # low for the rest of the cycle
    c.set(M2B0=0)
    c.set(CPU=1)
    seen = {p: c.get(p) for p in OUTPUT_PINS}
    y2_edge(c)
    c.set(CLK_Y0=0)
    c.set(CLK_Y0=1)
    y2_edge(c)
    c.set(CPU=0)
    y2_edge(c)
    return seen


def z180_write(c, port, value):
    """The Z180 puts out address and data, then asserts the port decode (AX), then drops
    it, and only then lets go of the data, as its I/O write cycle does."""
    c.set(HA0=port & 1, HA1=(port >> 1) & 1, HA2=(port >> 2) & 1,
          HD2=(value >> 2) & 1, HD3=(value >> 3) & 1)
    c.set(AX=1)
    c.set(AX=0)
    c.set(HD2=None, HD3=None)


def z180_read(c, port):
    """Address first, then AX; the value U7 drives on HD0-HD3 is read while AX is high."""
    c.set(HD2=None, HD3=None, HA0=port & 1, HA1=(port >> 1) & 1, HA2=(port >> 2) & 1)
    c.set(AX=1)
    value = sum(c.get(f"HD{i}") << i for i in range(4))
    c.set(AX=0)
    return value


def start(path, ldf_text):
    c = Bus(path, ldf_text)
    c.set(CLK_Y0=1, CLK_Y2=1, M2SEL_N=1, ARW=1, AX=0)
    z180_write(c, 1, 0b1000)          # port $A1: MODE_D3 = 1 (IIgs mode), COPY_INHIBIT = 0
    z180_read(c, 4)                   # clear the band flags
    z180_read(c, 5)
    z180_read(c, 0)                   # acknowledge: no event pending
    return c


def directed(original, fixed, ldf_text):
    """The v2.0 changes, each on the original map and the fixed map."""
    ok = True

    def check(what, a, b, want_a, want_b):
        nonlocal ok
        good = a == want_a and b == want_b
        ok &= good
        print(f"  {what:<58} original {a}  v2.0 {b}  {'ok' if good else 'NOT AS INTENDED'}")

    print("Unchanged: $9000 band flag (port $A5 bit 3) after one IIgs write to bank $E1:")
    for address in (0x9000, 0x9CFF, 0x9D00, 0x9FFF, 0x8FFF):
        flags = []
        for m in (original, fixed):
            c = start(m, ldf_text)
            apple(c, address, write=True, bank=1)
            flags.append((z180_read(c, 5) >> 3) & 1)
        want = int(0x9000 <= address <= 0x9FFF)
        check(f"write ${address:04X}", flags[0], flags[1], want, want)
    print("E14: IIgs write to bank $E1 made while RAMWRT is on:")
    for address in (0x2000, 0x6000, 0x9000):
        res = []
        for m in (original, fixed):
            c = start(m, ldf_text)
            apple(c, 0xC005, write=True)                  # RAMWRT on
            seen = apple(c, address, write=True, bank=1)
            # BANK_Q (pin CATCH_BANK) loads as the data phase ends, with CATCH_N rising
            res.append((1 - seen["CATCH_N"], c.get("CATCH_BANK")))
        copied_orig = int(address < 0x6000)
        check(f"write ${address:04X}: (copied, SRAM bank)", res[0], res[1],
              (copied_orig, 0) if copied_orig else (0, res[0][1]), (1, 1))
    print("E15: IIgs write to $C034 (border color):")
    res = []
    for m in (original, fixed):
        c = start(m, ldf_text)
        apple(c, 0xC034, write=True)
        irq = 1 - c.get("INT1_N")
        res.append((irq, z180_read(c, 7) if irq else 0, z180_read(c, 6) if irq else 0))
    check("event raised, port $A7, port $A6", res[0], res[1], (0, 0, 0), (1, 0x3, 0x4))
    print("E28: SRAM bank of each copied bank $00 write against the Apple's rule, every")
    print("     combination of 80STORE, PAGE2, HIRES and RAMWRT, IIgs and IIe mode:")
    wrong = [bank_rule_errors(m, ldf_text) for m in (original, fixed)]
    for (n, bad), name in zip(wrong, ("original", "v2.0")):
        print(f"  {name:<8} {n} copied writes, {len(bad)} in the wrong bank")
        for line in bad[:6]:
            print(f"           {line}")
    good = wrong[0][1] != [] and wrong[1][1] == []
    ok &= good
    print(f"  {'ok' if good else 'NOT AS INTENDED'}")
    print("all as intended" if ok else "NOT as intended")
    return ok


def apple_bank(store80, page2, hires, ramwrt, address):
    """The bank, 0 main or 1 auxiliary, the Apple puts a bank $00 write in (Apple IIgs
    Hardware Reference, Table 3-3; the IIe's rule is the same): with 80STORE on, PAGE2
    picks it for text page 1, and for hires page 1 while HIRES is on; RAMWRT picks it
    everywhere else."""
    if store80 and (0x0400 <= address <= 0x07FF or (hires and 0x2000 <= address <= 0x3FFF)):
        return page2
    return ramwrt


def bank_rule_errors(path, ldf_text):
    """Sets every combination of the four switches through the Apple's own softswitch
    writes, then writes one address in each page the card copies; returns the number of
    copied writes and a line for each one CATCH_BANK files in another bank than
    apple_bank()."""
    copied = 0
    bad = []
    for iigs in (True, False):
        c = start(path, ldf_text)
        if not iigs:
            z180_write(c, 1, 0b0000)  # port $A1: MODE_D3 = 0 (IIe mode)
        addresses = (0x0400, 0x0800, 0x2000, 0x4000) + ((0x6000, 0x8000) if iigs else ())
        for store80, page2, hires, ramwrt in itertools.product((0, 1), repeat=4):
            for switch in (0xC000 | store80, 0xC054 | page2, 0xC056 | hires, 0xC004 | ramwrt):
                apple(c, switch, write=True)
                z180_read(c, 0)        # acknowledge the event $C054-$C057 may raise
            for address in addresses:
                seen = apple(c, address, write=True)
                if seen["CATCH_N"]:
                    continue           # not copied ($6000-$9FFF in IIgs mode needs RAMWRT)
                copied += 1
                want = apple_bank(store80, page2, hires, ramwrt, address)
                got = c.get("CATCH_BANK")
                if got != want:
                    bad.append(f"{'IIgs' if iigs else 'IIe '} 80STORE {store80} PAGE2 {page2} "
                               f"HIRES {hires} RAMWRT {ramwrt}: ${address:04X} to bank {got}, "
                               f"Apple bank {want}")
    return copied, bad


def compare(ldf_text, paths, cycles=3000, seed=1):
    """The same random bus cycles on every chip; every output pin compared."""
    chips = [start(p, ldf_text) for p in paths]
    rnd = random.Random(seed)
    differences = 0
    for n in range(cycles):
        kind = rnd.random()
        if kind < 0.75:
            args = dict(address=rnd.choice([rnd.randrange(0x10000), 0xC000 | rnd.randrange(0x100),
                                             0x0400 + rnd.randrange(0x800), 0x2000 + rnd.randrange(0x8000),
                                             0x9D00 + rnd.randrange(0x300)]),
                        write=rnd.random() < 0.7, bank=rnd.randrange(2), m2sel=int(rnd.random() < 0.1),
                        ad4=rnd.randrange(2), ad6=rnd.randrange(2))
            seen = [apple(c, **args) for c in chips]
            what = f"Apple {'write' if args['write'] else 'read'} ${args['address']:04X} bank {args['bank']}"
        elif kind < 0.9:
            port = rnd.randrange(8)
            seen = [{"HD": z180_read(c, port)} for c in chips]
            what = f"Z180 read port $A{port}"
        else:
            port, value = rnd.choice([0, 1, 2, 3]), rnd.randrange(16)
            for c in chips:
                z180_write(c, port, value)
            seen = [{} for _ in chips]
            what = f"Z180 write port $A{port} = {value:X}"
        pins = [{p: c.get(p) for p in OUTPUT_PINS} for c in chips]
        for i in range(1, len(chips)):
            if seen[i] != seen[0] or pins[i] != pins[0]:
                differences += 1
                if differences <= 10:
                    print(f"  cycle {n}: {what}: {Path(paths[0]).name} {seen[0]} {pins[0]} / "
                          f"{Path(paths[i]).name} {seen[i]} {pins[i]}")
    print(f"{cycles} random bus cycles on {', '.join(Path(p).name for p in paths)}: "
          f"{differences} with any pin different")
    return differences == 0


def main(argv):
    if argv[0] == "directed":
        ok = directed(argv[1], argv[2], Path(argv[3]).read_text(encoding="latin-1"))
    elif argv[0] == "compare":
        ok = compare(Path(argv[1]).read_text(encoding="latin-1"), argv[2:])
    else:
        raise SystemExit(__doc__)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
