"""Read any ispLSI1016 fuse map into pDS's own terms: the exact inverse of pDS 2.61's fuse
generator, over its own device file (PLSI16.SDF). Nothing here is
specific to one design.

What it returns (MapRead.design()):
  glbs[loc]   every primitive select of the GLB at location loc (0-7 = A0-A7, 8-15 = B0-B7):
              terms (P name -> literal pins), gates (G -> F sums), demux (P -> chosen output),
              config (output -> chosen input; None when the fuses match no template value)
  iocs[loc]   the I/O cell's config selects, slew, pull-up fuse
  dis, clks   dedicated input and clock pin pull-up fuses
  top         the clock/reset multiplexers (CLK1, CLK2, IOCLK0, IOCLK1, RESET)
  grp         routing pool: (source cell, source pin) -> [(GLB loc, GLB input pin)]
  orp         output routing pool: (GLB loc, output pin) -> [(IOC loc, IOC input pin)]
  power_down  the fusegen record fuse
Every fuse the generator can set is read exactly once; unread() lists the rest, which must
all hold their erased value 1 (the check that nothing in the map is unexplained)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import sdf as S  # noqa: E402


class MapRead:
    def __init__(self, sdf_path, bits):
        self.s = S.read(sdf_path)
        self.N = self.s["names"]
        m = self.s["member"]
        self.m = m
        self.rows, self.cols = m["i52"], m["i54"]
        self.M = [[0] * self.cols for _ in range(self.rows)]
        for r in range(self.rows):
            for c in range(self.cols):
                line = 2 * r + (c & 1)
                pos = (self.cols - 2 - c) // 2 if c % 2 == 0 else (self.cols - 1 - c) // 2
                self.M[r][c] = bits[line * (self.cols // 2) + pos]
        self.read = set()
        self.defs = {d["i56"]: d for lst in self.s["family"]["celldefs"] for d in lst}
        self.glb = {c["i2"]: c for c in m["cellins"][0]}
        self.ioc = {c["i2"]: c for c in m["cellins"][1]}
        self.di = {c["i2"]: c for c in m["cellins"][2]}
        self.clk = {c["i2"]: c for c in m["cellins"][3]}
        self.fgw = m["fusegen"]

    # ---- one fuse
    def f(self, r, c):
        self.read.add((r, c))
        return self.M[r][c]

    @staticmethod
    def ic_row(flags, base, r):
        if flags & 0x10:
            return base + r
        if flags & 0x20:
            return base - r
        raise ValueError("cell instance with neither row direction")

    def pos(self, ins, d, name):
        for fd in d["fuses"]:
            if fd["name"] == name:
                return self.ic_row(ins["ie"], ins["i10"], fd["row"]), ins["i12"] + fd["col"]
        raise KeyError(self.N[name])

    def fuse(self, ins, d, name):
        return self.f(*self.pos(ins, d, name))

    def default(self, d, name):
        return next(fd["default"] for fd in d["fuses"] if fd["name"] == name)

    def value(self, ins, d, names):
        return sum(self.fuse(ins, d, fn) << k for k, fn in enumerate(names))

    # ---- one cell instance, every primitive of its template
    def cell(self, ins):
        d = self.defs[ins["i2c"]]
        N = self.N
        out = {"terms": {}, "gates": {}, "demux": {}, "config": {}, "tribuf": {}, "mux": {}}
        for t in d["and"]:
            name = N[t["outputs"][0]["name"]]
            sa = self.fuse(ins, d, t["fusenames2"][0])
            lits = [N[p["name"]] for p, fn in zip(t["inputs"], t["fusenames"])
                    if self.fuse(ins, d, fn) != self.default(d, fn)]
            if sa == 0:
                out["terms"][name] = lits
            elif lits:
                out.setdefault("dead_terms", {})[name] = lits
        for t in d["org"]:
            out["gates"][N[t["outputs"][0]["name"]]] = [
                N[p["name"]] for p, fn in zip(t["inputs"], t["fusenames"])
                if self.fuse(ins, d, fn) != self.default(d, fn)]
        for kind, pins_key in (("demux", "outputs"), ("config", "inputs"), ("tribuf", "inputs"),
                               ("mux", "inputs")):
            for t in d[kind]:
                if not t.get("fusenames"):
                    continue
                v = self.value(ins, d, t["fusenames"])
                pins = t[pins_key]
                chosen = [N[p["name"]] for p, val in zip(pins, t["fusevals"]) if val == v]
                key = N[t["inputs"][0]["name"]] if kind == "demux" else N[t["outputs"][0]["name"]]
                out[kind][key] = (chosen[0] if len(chosen) == 1 else chosen or None, v)
        # template fuses not used by any primitive (pull-up and the like)
        used = set()
        for kind in ("and", "org", "demux", "config", "tribuf", "mux"):
            for t in d[kind]:
                used |= set(t.get("fusenames", [])) | set(t.get("fusenames2", []))
        out["other"] = {N[fd["name"]]: self.fuse(ins, d, fd["name"]) for fd in d["fuses"]
                        if fd["name"] not in used}
        return out

    # ---- the top cell: clock and reset multiplexers
    def top(self):
        top = self.m["cellins_4e"]
        res = {}
        for oc in top["outcons"]:
            for mw in oc["muxwires"]:
                v = 0
                for k, fn in enumerate(mw["fusenames"]):
                    fd = next(x for x in top["fuses"] if x["name"] == fn)
                    v |= self.f(fd["row"], fd["col"]) << k
                chosen = [self.N[p["name"]] for p, val in zip(mw["pins"], mw["fusevals"]) if val == v]
                res[self.N[oc["i0"]]] = (chosen[0] if chosen else None, v)
        return res

    # ---- the routing pool into GLB inputs, and the output routing pool to I/O cells
    def pools(self):
        m, fgw = self.m, self.fgw
        irtab = {(p["i0"], w["i0"]): w for p in m["irfusepats"] for w in p["wires"]}
        grp, orp = {}, {}
        sources = [("GLB", c) for c in m["cellins"][0]] + [("IOC", c) for c in m["cellins"][1]] + \
                  [("DI", c) for c in m["cellins"][2]] + [("CLK", c) for c in m["cellins"][3]]
        for kind, sins in sources:
            for oc in sins["outcons"]:
                key = (kind, sins["i2"], self.N[oc["i0"]])
                for cw in (c for c in oc["conwires"] if c["i0"] == 1):
                    irw = irtab[(cw["i2"], cw["i4"])]
                    for loc, gins in self.glb.items():
                        dests = irw["b"] if not gins["ie"] & 0x10 else irw["a"]
                        colbase = fgw[2] if not gins["ie"] & 0x200 else fgw[4]
                        for dd in dests:
                            row = fgw[3] - fgw[6] * cw["i2"] - dd["i2"]
                            col = colbase + gins["ic"] * fgw[1] + dd["i4"]
                            if self.f(row, col) == 0:
                                grp.setdefault(key, []).append((loc, self.N[dd["i0"]]))
                for sw in oc["switchwires"]:
                    bus = next(b for b in m["buses2"] if b["i0"] == sw["i2"])
                    for w in bus["wires"]:
                        fw = next((x for x in sw["fuses"] if x["i0"] == w["i0"]), None)
                        if fw is None:
                            continue
                        fd = next(x for x in m["fuses"] if x["name"] == fw["i2"])
                        for lins in [self.ioc[w["pins"][0]["i4"]]]:
                            colbase = fgw[2] if not lins["ie"] & 0x200 else fgw[4]
                            row, col = fd["row"], colbase + sins["ic"] * fgw[1] + fd["col"]
                            if self.f(row, col) == 0:
                                orp.setdefault(key, []).append((w["pins"][0]["i4"],
                                                                self.N[w["pins"][0]["name"]]))
        return grp, orp

    def design(self):
        fgw = self.fgw
        d = {"glbs": {loc: self.cell(ins) for loc, ins in self.glb.items()},
             "iocs": {loc: self.cell(ins) for loc, ins in self.ioc.items()}}
        d["dis"] = {loc: self.f(ins["i10"], ins["i12"]) for loc, ins in self.di.items()}
        d["clks"] = {loc: self.f(ins["i10"], ins["i12"]) for loc, ins in self.clk.items()}
        d["top"] = self.top()
        d["grp"], d["orp"] = self.pools()
        d["power_down"] = self.f(fgw[11], fgw[12])
        return d

    def unread(self):
        """Fuses never read that are not 1 (erased): unexplained programming."""
        return [(r, c) for r in range(self.rows) for c in range(self.cols)
                if (r, c) not in self.read and self.M[r][c] != 1]


if __name__ == "__main__":
    from jedec import read_jed
    mr = MapRead(sys.argv[1], read_jed(sys.argv[2]))
    des = mr.design()
    print("fuses read:", len(mr.read), "of", mr.rows * mr.cols, "; unexplained programmed fuses:",
          mr.unread()[:20], len(mr.unread()))
    print("top:", des["top"], "power_down fuse:", des["power_down"])
    print("dedicated input pull-ups:", des["dis"], "clock pull-ups:", des["clks"])
    print("I/O cell 0:", des["iocs"][0])
