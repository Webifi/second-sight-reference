"""Chip-level emulator of an ispLSI1016 fuse map, built on pDS 2.61's own device file.

Structure (what is connected to what) comes only from Lattice's files:
  * mapread.py reads every select of the map through PLSI16.SDF, pDS 2.61's device file:
    product terms, OR gates, demultiplexers, configuration multiplexers, the routing pool
    (GRP), the output routing pool (ORP), the clock/reset multiplexers of the top cell. It
    refuses a map with a programmed fuse the device file does not explain.
  * the fixed wiring is the device file's own records: each GLB's O2/O3 or O0/O1 to an I/O
    cell's ORP bypass input (P_IO_ID), each I/O cell's register to its neighbour
    (P_IO_QFADJ), the megablock output-enable wires (four GLBs' OE term on each), the
    dedicated inputs to their GLBs (P_LC_IN0/1), the clock pins into the top cell.
  * each cell is evaluated through its template primitives in PLSI16.SDF (LogicCell,
    IOCell, DirinCell): AND, demux (the side not chosen reads 0
    on the OR side and 1 on the DMX side), fixed OR,
    OR gate, configuration mux, XOR, D register, OR with inverted second input (or2b1),
    I/O register (fflreg: QF flip-flop, QL latch), input buffer, three-state buffer. A pin
    named with a trailing B is the complement of the pin without it.

Behaviour that the device file does not define comes from Lattice's documents:
  * registers load on the rising edge of their clock (the clock is polarity selectable:
    P_LC_CLKP / P_LC_CLKPB, P_IO_CLKP / P_IO_CLKPB); Lattice's own library macros ID21 and
    IL21 add an XINV for "inverted clock" / "inverted enable" (LATSYSM.LIB).
  * the I/O cell's fflreg is master-slave: QF loads on the rising edge of the cell's clock,
    and QL (the master latch) is open while that clock is 0. Library macro LD11 defines the
    D latch as Q0 = (Q0.PIN & D0) # (Q0.PIN & !G) # (G & D0), open while G is 1, and
    pDS 2.61 compiles IL11 with the cell's clock inverted (P_IO_CLKPB).
  * the global reset pin (Y1/RESET) is active low and resets every GLB and I/O register; it
    is ORed with the GLB's product-term reset; a reset register holds 0
    (1996 Data Book, 1000 Family Architectural Description pp2-15 and 2-17).
  * an I/O pin with nothing driving it reads 1 (active pull-up, ibid. p2-17).

Timing is unit delay: every GLB output, OE wire and I/O cell output takes one step to
follow its inputs (all of them move together), registers sample on the step their clock
rises, and settle() steps until nothing changes. This shows latches built from feedback,
races and oscillations the way the logic makes them; it does not model nanoseconds.

Use package pin numbers from 16PLCC44.PKG:

    chip = Chip(read_jed("map.jed"))
    chip.drive(pin=15, value=1)
    chip.settle()

Read a pin value:

    chip.pin(37)
"""
import os
import re
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from mapread import MapRead  # noqa: E402

# pDS 2.61's device file and package file for the ispLSI1016 in the 44-pin PLCC, from its
# install folder: PDS_DIR, else C:\PDS of the Wine prefix pds261_build.sh uses
PDS_DIR = Path(os.environ.get("PDS_DIR") or
               Path(os.environ.get("PDS_PREFIX", Path.home() / ".wine-pds261")) / "drive_c" / "PDS")
SDF = PDS_DIR / "PLSI16.SDF"
PKG = PDS_DIR / "16PLCC44.PKG"


def read_pkg(path):
    """Package pin records of a pDS .PKG file: pin number string, then six words
    (kind, class, cell index, megablock, ...). Kind 1 = I/O cell, kinds 3 and 12 = dedicated
    input, kinds 2, 10 and 13 = clock pin. Returns {("IOC"|"DI"|"CLK", index): pin}."""
    data = Path(path).read_bytes()
    pins = {}
    for m in re.finditer(rb"\x05(\d{1,2})\x00", data):
        kind, _cls, index, _mb, _a, _b = struct.unpack_from(">6h", data, m.end())
        pin = int(m.group(1))
        if kind == 1:
            pins[("IOC", index)] = pin
        elif kind in (3, 12):
            pins[("DI", index)] = pin
        elif kind in (2, 10, 13):
            pins[("CLK", index)] = pin
    return pins


class OscillationError(RuntimeError):
    pass


def bus_wires(m, N):
    """The fixed buses of the device file: (group, bus, wire) -> [(cell index, pin)]."""
    out = {}
    for g, grp in enumerate(m["buses"]):
        for b in grp:
            for w in b["wires"]:
                out[(g, b["i0"], w["i0"])] = [(p["i4"], N[p["name"]]) for p in w["pins"]]
    return out


def complemented_outputs(lpr_path, names):
    """GLB outputs (loc, k) that pDS stores complemented, read from the router's .lpr
    (output pin flag 0x800, set by _lf_Add_Cell_Output): the chip holds the complement of
    the source's signal there. The .lpr, not the .lif: the router may move a signal to
    another output of its GLB, and only the .lpr has the moved position (the .lif keeps
    the fitter's). names: the device file's name table (Chip.mr.N), which gives the
    template pin of each pin id (P_LC_O0..P_LC_O3). Empty when there is no .lpr."""
    if not Path(lpr_path).exists():
        return set()
    import lif as L
    d = L.read(lpr_path)
    out = set()
    for c in d["cells"][0]:
        name = c["s0c"]
        if len(name) != 2 or name[0] not in "AB":
            continue
        loc = (0 if name[0] == "A" else 8) + int(name[1])
        for i in c["pins_out"]:
            p = d["pins"][i - 1]
            pin = names[p["i0"]]
            if p["i4"] & 0x800 and pin.startswith("P_LC_O") and pin[-1].isdigit():
                out.add((loc, int(pin[-1])))
    return out


class Chip:
    """One ispLSI1016 programmed with a fuse map (a list of 15360 fuse values)."""

    def __init__(self, bits, sdf_path=SDF, pkg_path=PKG):
        mr = MapRead(str(sdf_path), bits)
        self.mr = mr
        d = mr.design()
        if mr.unread():
            raise ValueError(f"fuses programmed that the device file does not explain: {mr.unread()[:8]}")
        self.d = d
        N = mr.N
        m = mr.m
        self.glbs = sorted(d["glbs"])
        self.iocs = sorted(d["iocs"])
        self.dis = sorted(mr.di)
        self.clks = sorted(mr.clk)
        # ---- fixed wiring from the device file
        buses = bus_wires(m, N)
        self.id_src = {}          # IOC loc -> (GLB loc, output pin) on P_IO_ID
        self.qfadj_src = {}       # IOC loc -> IOC loc whose QF feeds P_IO_QFADJ
        self.oe_src = {}          # (IOC side group, wire) -> [GLB loc] driving P_IO_OE0/1
        self.in_src = {}          # (GLB loc, "P_LC_IN0"/"P_LC_IN1") -> DI loc
        self.clk_pin = {}         # "P_Y0".."P_Y2" -> CLK loc
        self.oe_wire_of = {}      # (IOC loc, "P_IO_OE0"/"P_IO_OE1") -> (side bus, wire)
        for loc, ins in mr.glb.items():
            for oc in ins["outcons"]:
                pin = N[oc["i0"]]
                for p in oc["pins"]:
                    if N[p["name"]] == "P_IO_ID" and p["i4"] >= 0:
                        self.id_src[p["i4"]] = (loc, pin)
                for cw in oc["conwires"]:
                    if cw["i0"] == 4:
                        dests = buses[(0, cw["i2"], cw["i4"])]
                        self.oe_src.setdefault((cw["i2"], cw["i4"]), []).append(loc)
                        for ioc, name in dests:
                            self.oe_wire_of[(ioc, name)] = (cw["i2"], cw["i4"])
        for loc, ins in mr.ioc.items():
            for oc in ins["outcons"]:
                for p in oc["pins"]:
                    if N[p["name"]] == "P_IO_QFADJ" and p["i4"] >= 0:
                        self.qfadj_src[p["i4"]] = loc
        for loc, ins in mr.di.items():
            for oc in ins["outcons"]:
                for cw in oc["conwires"]:
                    for cell, name in buses[(1, cw["i2"], cw["i4"])]:
                        # GLBs 8-15 name their dedicated inputs IN2/IN3; the template calls
                        # them P_LC_IN0/1
                        self.in_src[(cell, "P_LC_IN" + str(int(name[-1]) % 2))] = loc
        for loc, ins in mr.clk.items():
            for oc in ins["outcons"]:
                self.clk_pin[N[oc["i0"]]] = loc
        # programmable pools
        self.grp_src = {}         # (GLB loc, "P_LC_Ik") -> (kind, cell, pin)
        for src, dests in d["grp"].items():
            for loc, pin in dests:
                if (loc, pin) in self.grp_src:
                    raise ValueError(f"two sources on {loc} {pin}")
                self.grp_src[(loc, pin)] = src
        self.ir_src = {}          # IOC loc -> (kind, cell, pin) on P_IO_IR
        for src, dests in d["orp"].items():
            for loc, pin in dests:
                if pin != "P_IO_IR" or loc in self.ir_src:
                    raise ValueError(f"output routing pool: {src} -> {loc} {pin}")
                self.ir_src[loc] = src
        self.top = {k: v[0] for k, v in d["top"].items()}
        # package pins
        # package pins: the package file numbers dedicated inputs and clock pins by the
        # cell's name (I0..I3, Y0..Y2), I/O cells by their index
        pkg = read_pkg(pkg_path)
        self.pkg = {("IOC", loc): pkg[("IOC", loc)] for loc in self.iocs}
        for kind, cells in (("DI", mr.di), ("CLK", mr.clk)):
            for loc, ins in cells.items():
                self.pkg[(kind, loc)] = pkg[(kind, int(N[ins["def"]][1:]))]
        self.pad_of_pin = {pin: key for key, pin in self.pkg.items()}
        # ---- state
        self.ext = {}             # package pin -> value driven from outside (absent: none)
        self.v = {}               # net values: ("GLB", loc, pin), ("IOC", loc, pin), ...
        self.q = {}               # register states
        self.clk_was = {}
        for loc in self.glbs:
            for k in range(4):
                self.v[("GLB", loc, f"P_LC_O{k}")] = 0
                self.q[("GLB", loc, k)] = 0
            self.v[("GLB", loc, "P_LC_OE")] = 0
        for loc in self.iocs:
            self.v[("IOC", loc, "P_IO_O")] = 0
            self.v[("IOC", loc, "pad")] = 1
            self.q[("IOC", loc, "QF")] = 0
            self.q[("IOC", loc, "QL")] = 0
        self.steps = 0
        self.counting = True

    # ------------------------------------------------ outside world

    def drive(self, pin, value):
        """Drive package pin `pin` from outside (value 0/1, or None to release it)."""
        if value is None:
            self.ext.pop(pin, None)
        else:
            self.ext[pin] = int(value)

    def pin(self, pin):
        """The value on package pin `pin`: what the chip drives, else the outside, else 1."""
        kind, loc = self.pad_of_pin[pin]
        if kind == "IOC":
            return self.v[("IOC", loc, "pad")]
        return self.ext.get(pin, 1)

    def _input_pad(self, kind, loc):
        return self.ext.get(self.pkg[(kind, loc)], 1)

    # ------------------------------------------------ one step

    def _src(self, src, v):
        kind, cell, pin = src
        if kind == "GLB":
            return v[("GLB", cell, pin)]
        if kind == "IOC":
            return v[("IOC", cell, pin)]
        if kind == "DI":
            return self._input_pad("DI", cell)
        if kind == "CLK":
            return self._input_pad("CLK", cell)
        raise ValueError(src)

    def _top(self, name, v):
        """A clock/reset multiplexer output of the top cell (mapread top())."""
        if name == "P_CLK0":
            return self._input_pad("CLK", self.clk_pin["P_Y0"])
        chosen = self.top[name]
        if chosen is None:
            raise ValueError(f"top multiplexer {name}: fuses match no input")
        if chosen in ("P_Y0", "P_Y1", "P_Y2"):
            return self._input_pad("CLK", self.clk_pin[chosen])
        if chosen.startswith("P_LC_O"):
            return v[("GLB", 8, chosen)]          # the clock GLB B0 (top cell inputs, cell 8)
        return {"P_VCC": 1, "P_GND": 0}[chosen]

    def _glb(self, loc, v, new):
        c = self.d["glbs"][loc]
        n = {"P_GND": 0, "P_VCC": 1}
        for i in range(16):
            src = self.grp_src.get((loc, f"P_LC_I{i}"))
            n[f"P_LC_I{i}"] = self._src(src, v) if src is not None else None
        for k in (0, 1):
            di = self.in_src.get((loc, f"P_LC_IN{k}"))
            n[f"P_LC_IN{k}"] = self._input_pad("DI", di) if di is not None else 1
        for k in range(4):
            n[f"P_LC_O{k}"] = v[("GLB", loc, f"P_LC_O{k}")]   # local feedback (I16/I17)
        n["P_CLK0"] = self._top("P_CLK0", v)
        n["P_CLK1"] = self._top("P_CLK1", v)
        n["P_CLK2"] = self._top("P_CLK2", v)
        n["P_RESET"] = self._top("P_RESET", v)

        def val(p):
            if p.endswith("B") and p[:-1] in n:
                x = n[p[:-1]]
                return None if x is None else 1 - x
            return n[p]

        cfg = c["config"]

        def mux(out):
            chosen = cfg[out][0]
            if chosen is None or isinstance(chosen, list):
                raise ValueError(f"GLB {loc} {out}: fuses select {chosen}")
            return chosen

        n["P_LC_I16"] = val(mux("P_LC_I16"))
        n["P_LC_I17"] = val(mux("P_LC_I17"))
        for p in range(20):
            name = f"P_LC_P{p}"
            lits = c["terms"].get(name)
            if lits is None:
                n[name] = 0
                continue
            x = 1
            for lit in lits:
                lv = val(lit)
                if lv is None:
                    raise ValueError(f"GLB {loc} {name} reads unrouted {lit}")
                x &= lv
            n[name] = x
        # A demux passes its product term to the side it selects. The OR side not selected
        # reads 0; the DMX side not selected reads 1: pDS 2.61 inverts an output by feeding
        # its XOR from such a line (_lf_Generate_XORINV_Pin wires the XOR to the DMX pin of
        # a product term it leaves unused, whose demux stays on the OR side), and the
        # source then reads as the complement of the OR sum (simcheck.py, Z1's P1).
        for p, (chosen, _) in c["demux"].items():
            n[p + "DMX"] = n[p] if chosen == p + "DMX" else 1
            n[p + "ORF"] = n[p] if chosen == p + "ORF" else 0
        n["P_LC_F0"] = n["P_LC_P0ORF"] | n["P_LC_P1"] | n["P_LC_P2"] | n["P_LC_P3"]
        n["P_LC_F1"] = n["P_LC_P4ORF"] | n["P_LC_P5"] | n["P_LC_P6"] | n["P_LC_P7"]
        n["P_LC_F2"] = n["P_LC_P8ORF"] | n["P_LC_P9"] | n["P_LC_P10"] | n["P_LC_P11"]
        n["P_LC_F3"] = n["P_LC_P13ORF"] | n["P_LC_P14"] | n["P_LC_P15"] | n["P_LC_P16"]
        n["P_LC_F4"] = n["P_LC_F2"] | n["P_LC_P12ORF"]
        n["P_LC_F5"] = n["P_LC_F3"] | n["P_LC_P17"] | n["P_LC_P18"] | n["P_LC_P19ORF"]
        for g in range(4):
            n[f"P_LC_G{g}"] = int(any(n[f] for f in c["gates"].get(f"P_LC_G{g}", [])))
        n["P_LC_CLKP"] = val(mux("P_LC_CLKP"))
        n["P_LC_CLK"] = val(mux("P_LC_CLK"))
        n["P_LC_RSTMXO"] = val(mux("P_LC_RSTMXO"))
        n["P_LC_RST"] = n["P_LC_RSTMXO"] | (1 - n["P_RESET"])
        clk = n["P_LC_CLK"]
        rising = clk == 1 and self.clk_was.get(("GLB", loc), clk) == 0 and self.counting
        self.clk_was[("GLB", loc)] = clk
        # X(k) / D(k) / register k / O(k): X3 feeds D3 (G0 XOR X3MO), ...
        xor_g = {3: "P_LC_G0", 2: "P_LC_G1", 1: "P_LC_G2", 0: "P_LC_G3"}
        for k in range(4):
            n[f"P_LC_X{k}MO"] = val(mux(f"P_LC_X{k}MO"))
            n[f"P_LC_X{k}O"] = n[xor_g[k]] ^ n[f"P_LC_X{k}MO"]
            n[f"P_LC_D{k}"] = val(mux(f"P_LC_D{k}"))
            key = ("GLB", loc, k)
            if n["P_LC_RST"]:
                self.q[key] = 0
            elif rising:
                self.q[key] = n[f"P_LC_D{k}"]
            n[f"P_LC_Q{k}"] = self.q[key]
        for k in range(4):
            new[("GLB", loc, f"P_LC_O{k}")] = val(mux(f"P_LC_O{k}"))
        oe = cfg.get("P_LC_OE")
        new[("GLB", loc, "P_LC_OE")] = n["P_LC_P19DMX"] if oe and oe[0] == "P_LC_P19DMX" else None

    def _oe_wire(self, wire, v):
        """A megablock output-enable wire: the OE term of whichever of its GLBs drives it."""
        drivers = [v[("GLB", g, "P_LC_OE")] for g in self.oe_src.get(wire, [])]
        drivers = [x for x in drivers if x is not None]
        return int(any(drivers))

    def _ioc(self, loc, v, new):
        c = self.d["iocs"][loc]
        cfg = c["config"]
        n = {"P_GND": 0, "P_VCC": 1}
        n["P_IO_IO"] = v[("IOC", loc, "pad")]
        src = self.ir_src.get(loc)
        n["P_IO_IR"] = self._src(src, v) if src is not None else 0
        g, p = self.id_src[loc]
        n["P_IO_ID"] = v[("GLB", g, p)]
        n["P_IO_CLK0"] = self._top("P_IOCLK0", v)
        n["P_IO_CLK1"] = self._top("P_IOCLK1", v)
        n["P_IO_OE0"] = self._oe_wire(self.oe_wire_of[(loc, "P_IO_OE0")], v)
        n["P_IO_OE1"] = self._oe_wire(self.oe_wire_of[(loc, "P_IO_OE1")], v)
        adj = self.qfadj_src.get(loc)
        n["P_IO_QFADJ"] = self.q[("IOC", adj, "QF")] if adj is not None else 0
        n["P_RESET"] = self._top("P_RESET", v)

        def val(p):
            if p.endswith("B") and p[:-1] in n:
                return 1 - n[p[:-1]]
            return n[p]

        def mux(out):
            chosen = cfg[out][0]
            if chosen is None or isinstance(chosen, list):
                raise ValueError(f"IOC {loc} {out}: fuses select {chosen}")
            return chosen

        n["P_IO_IBUFO"] = n["P_IO_IO"]
        n["P_IO_OEP"] = val(mux("P_IO_OEP"))
        n["P_IO_OE"] = val(mux("P_IO_OE"))
        n["P_IO_OMUXO"] = val(mux("P_IO_OMUXO"))
        n["P_IO_OBUFI"] = val(mux("P_IO_OBUFI"))
        n["P_IO_CLKP"] = val(mux("P_IO_CLKP"))
        n["P_IO_CLK"] = val(mux("P_IO_CLK"))
        dsel = cfg.get("P_IO_D", (None, None))[0]
        n["P_IO_D"] = val(dsel) if isinstance(dsel, str) else 0
        clk = n["P_IO_CLK"]
        rising = clk == 1 and self.clk_was.get(("IOC", loc), clk) == 0 and self.counting
        self.clk_was[("IOC", loc)] = clk
        if n["P_RESET"] == 0:
            self.q[("IOC", loc, "QF")] = 0
            self.q[("IOC", loc, "QL")] = 0
        else:
            # fflreg is a master-slave flip-flop: QL is the master latch, transparent while
            # the clock is 0, and QF the slave, loading on the rising edge. pDS 2.61
            # compiles IL11 (Lattice's latch, open while G is 1) with the cell's clock
            # inverted (P_IO_CLKPB), and ID11 (rising-edge register) with it true.
            if rising:
                self.q[("IOC", loc, "QF")] = n["P_IO_D"]
            if clk == 0:
                self.q[("IOC", loc, "QL")] = n["P_IO_D"]
        n["P_IO_QF"] = self.q[("IOC", loc, "QF")]
        n["P_IO_QL"] = self.q[("IOC", loc, "QL")]
        new[("IOC", loc, "P_IO_O")] = val(mux("P_IO_O"))
        new[("IOC", loc, "drive")] = n["P_IO_OBUFI"] if n["P_IO_OE"] else None

    def step(self):
        """Advance one unit delay; True when any value changed."""
        v = self.v
        new = {}
        for loc in self.glbs:
            self._glb(loc, v, new)
        for loc in self.iocs:
            self._ioc(loc, v, new)
        for loc in self.iocs:
            drive = new.pop(("IOC", loc, "drive"))
            ext = self.ext.get(self.pkg[("IOC", loc)])
            new[("IOC", loc, "pad")] = drive if drive is not None else (ext if ext is not None else 1)
        changed = any(v.get(k) != x for k, x in new.items())
        v.update(new)
        self.steps += 1
        return changed

    def power_up(self, ones=()):
        """Every register 0, the logic settled to the pins with no clock edge counted.
        Lattice documents no power-up state for the 1016 (its 1994 handbook tells designers
        to reset state machines into a known state); this is the emulator's convention
        (ldfsim.py uses the same). The I/O cells first take the pins' values, so the
        logic starts from the inputs as driven rather than from all-zero inputs.
        ones: GLB outputs (loc, k) that start at 1 instead, register and output both. A map
        that stores a signal complemented (complemented_outputs) starts in its source's
        all-zero state that way."""
        for loc, k in ones:
            self.q[("GLB", loc, k)] = 1
            self.v[("GLB", loc, f"P_LC_O{k}")] = 1
        self.counting = False
        new = {}
        for loc in self.iocs:
            ext = self.ext.get(self.pkg[("IOC", loc)])
            self.v[("IOC", loc, "pad")] = ext if ext is not None else 1
        for loc in self.iocs:
            self._ioc(loc, self.v, new)
        self.v.update({k: x for k, x in new.items() if k[2] == "P_IO_O"})
        self.settle()
        self.counting = True

    def settle(self, limit=500):
        """Step until nothing changes; OscillationError after `limit` steps."""
        for _ in range(limit):
            if not self.step():
                return
        raise OscillationError("the logic did not settle")
