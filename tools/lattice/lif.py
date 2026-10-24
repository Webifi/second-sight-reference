"""Read a Lattice pDS 2.61 LIF/LPR design database into Python dicts.

The format, from pDS 2.61's own readers (fsrlif1.c/fsrlif2.c, decompiled): a stream of
records, each with a type byte followed by its fields. Integers are big-endian (2 or
4 bytes); strings end with NUL. A "vstring" has a 2-byte size and, when nonzero, a
NUL-ended string. A list contains records of one type and ends with a type byte 0.

_fs_r_lif reads: header, zoom list, net list, pin list, four cell lists, state machine
list, macro list, macro library list, declaration list.
Every function here names the pDS reader it follows."""
import struct
import sys


class LifError(Exception):
    pass


class Reader:
    def __init__(self, data):
        self.d, self.p = data, 0

    def byte(self):
        b = self.d[self.p]
        self.p += 1
        return b

    def i2(self):
        v = struct.unpack_from(">h", self.d, self.p)[0]
        self.p += 2
        return v

    def i4(self):
        v = struct.unpack_from(">i", self.d, self.p)[0]
        self.p += 4
        return v

    def string(self):
        e = self.d.index(b"\0", self.p)
        s = self.d[self.p:e].decode("latin1")
        self.p = e + 1
        return s

    def vstring(self):
        """_fs_read_vstring: a 2-byte buffer size; when nonzero, a NUL-ended string follows."""
        n = self.i2()
        return self.string() if n else ""

    def record(self, want):
        """Type byte of the next record: want = continue, 0 = end of a list; else error."""
        t = self.byte()
        if t not in (0, want):
            raise LifError(f"record type {t} at {self.p - 1:#x}, expected {want}")
        return t

    def items(self, want, body):
        """A list: records of type want until a type 0 (the _fs_r_x loops)."""
        out = []
        while self.record(want):
            out.append(body(self))
        return out


def version(r):  # _fs_r_version, type 1
    if r.record(1) != 1:
        raise LifError("version record missing")
    return (r.i2(), r.i2(), r.i2())


def opt(r):  # _fs_r_opt, type 2 (body)
    return {"name": r.string(), "value": r.string()}


def header(r):  # _fs_r_header, type 3
    if r.record(3) != 3:
        raise LifError("header record missing")
    h = {"version": version(r)}
    if h["version"] != (3, 0, 2):
        raise LifError(f"LIF version {h['version']}, pDS 2.61 reads 3.0.2")
    h["v4"], h["v8"] = version(r), version(r)
    h["tool"] = r.string()                        # +0x0c
    h["i10c"], h["i10e"], h["i112"] = r.i2(), r.i4(), r.i4()
    h["s116"], h["s136"], h["s156"], h["s176"] = r.string(), r.string(), r.string(), r.string()
    h["v196"], h["v19a"] = version(r), version(r)
    h["s19e"] = r.string()
    h["i39e"], h["i3a2"] = r.i4(), r.i4()
    h["counts"] = [r.i2() for _ in range(20)]     # +0x3a6 .. +0x3cc
    h["i3ce"] = [r.i2() for _ in range(4)]
    h["sdf"] = r.string()                         # +0x3d6, device file name
    h["i3f6"], h["i3f8"] = r.i2(), r.i4()
    h["options"] = r.items(2, opt)                # +0x3fc
    h["tail"] = (r.i4(), r.i4())
    return h


def zoom(r):  # _fs_r_zoom, type 0x52
    return {"name": r.string(), "values": [r.i4() for _ in range(10)]}


def pinlist(r):  # _fs_r_pinlist, type 5: one pin index
    return r.i2()


def net(r):  # _fs_r_net, type 6
    n = {"name": r.string(), "i80": r.i4(), "i84": r.i2()}
    n["pins_a"] = r.items(5, pinlist)
    n["pins_b"] = r.items(5, pinlist)
    n["i8e"] = r.i2()
    n["tail"] = (r.i4(), r.i4())
    return n


def pin(r):  # _fs_r_pin, type 4
    return {"i0": r.i2(), "i2": r.i2(), "i4": r.i4(), "i8": r.i2(), "ia": r.i2(), "ic": r.i2(), "i10": r.i2()}


def prmlist(r):  # _fs_r_prmlist, type 10: one primitive index
    return r.i2()


def prm(r):  # _fs_r_prm, type 9
    p = {"type": r.i2(), "i2": r.i2(), "i4": r.i2(), "i6": r.i2()}
    p["inputs"] = r.items(5, pinlist)
    p["outputs"] = r.items(5, pinlist)
    p["prms"] = r.items(10, prmlist)
    return p


def setfamily(r):  # _fs_r_setfamily, type 11
    if r.record(11) != 11:
        raise LifError("set family record missing")
    # five header words; then head[0] * head[2] words (sets x words per set)
    f = {"head": [r.i2() for _ in range(5)]}
    f["values"] = [r.i2() for _ in range(f["head"][0] * f["head"][2])]
    return f


def output(r):  # _fs_r_output, type 12: the fitter's result for one cell
    # type 0: no record (cell + 0x94 stays NULL), as for a cell not yet through the fitter
    if r.record(12) == 0:
        return None
    o = {"m32x7": [[r.i2() for _ in range(7)] for _ in range(32)],
         "m7x32": [[r.i2() for _ in range(32)] for _ in range(7)],
         "l32": [r.i4() for _ in range(32)],
         "l7": [r.i4() for _ in range(7)],
         "s32": [r.i2() for _ in range(32)]}
    n = r.i2()
    o["list870"] = [r.i2() for _ in range(n)] if n > 0 else []
    n = r.i2()
    o["list874"] = [r.i2() for _ in range(n)] if n > 0 else []
    o["prms161"] = [r.i2() for _ in range(0xa1)]   # primitive indexes
    o["pins100"] = [r.i2() for _ in range(100)]    # pin indexes
    o["set878"], o["set87c"] = setfamily(r), setfamily(r)
    return o


def macrolist(r):  # _fs_r_macrolist, type 0x10
    return r.i2()


def lpropt(r):  # _fs_r_lpropt, type 7; type 0 = the cell has none
    if r.record(7) == 0:
        return None
    return [r.i2() for _ in range(0x3c)]


def cell(r):  # _fs_r_cell, type 0xe
    c = {"index": r.i2(), "i": [r.i2() for _ in range(6)]}
    c["s0c"], c["s1c"], c["s64"], c["s3c"], c["s44"] = (r.string() for _ in range(5))
    c["i84"] = r.i4()
    c["pins_in"] = r.items(5, pinlist)
    c["pins_out"] = r.items(5, pinlist)
    c["prms"] = r.items(9, prm)
    c["output"] = output(r)
    c["text"] = r.vstring()
    c["ic0"] = r.i4()
    c["macros"] = r.items(0x10, macrolist)
    c["lpropt"] = lpropt(r)
    c["id0"], c["id4"] = r.i2(), r.i2()
    c["tail"] = (r.i4(), r.i4())
    return c


def statem(r):  # _fs_r_statem, type 0x7d
    s = {"i": [r.i2() for _ in range(4)], "name": r.string(), "text": r.vstring()}
    s["i2c"] = r.i2()
    return s


def celllist(r):  # _fs_r_celllist, type 0xf: one cell index
    return r.i2()


def macro(r):  # _fs_r_macro, type 0xd
    m = {"flags": r.i4(), "i4": r.i2(), "name": r.string(), "usage": r.string(), "text": r.string()}
    if not m["flags"] & 0x20:
        raise LifError(f"macro {m['name']}: macro body records (_fs_r_macmacro) not handled yet")
    m["i12a"] = r.i2()
    m["cells"] = r.items(0xf, celllist)
    return m


def maclib(r):  # _fs_r_maclib, type 0x15
    return {"path": r.string(), "i80": r.i4()}


def constant(r):  # _fs_r_constant, type 0x13
    if r.record(0x13) != 0x13:
        raise LifError("constant record missing")
    return {"name": r.string(), "i22": r.i2(), "i20": r.i2(), "s24": r.string(), "s38": r.string()}


def declaration(r):  # _fs_r_declaration, type 0x11
    if r.record(0x14) != 0x14:  # _fs_r_const_array
        raise LifError("constant array record missing")
    n = r.i2()
    d = {"constants": [constant(r) for _ in range(n)]}
    d["sets"] = r.items(0x12, lambda rr: (_ for _ in ()).throw(LifError("set records not handled yet")))
    return d


def read(path):
    r = Reader(open(path, "rb").read())
    lif = {"header": header(r)}
    lif["zooms"] = r.items(0x52, zoom)
    lif["nets"] = r.items(6, net)
    lif["pins"] = r.items(4, pin)
    lif["cells"] = [r.items(0xe, cell) for _ in range(4)]
    lif["statems"] = r.items(0x7d, statem)
    lif["macros"] = r.items(0xd, macro)
    lif["maclibs"] = r.items(0x15, maclib)
    # one declaration record (or type 0 for none), not a list
    lif["declaration"] = declaration(r) if r.record(0x11) else None
    lif["rest_at"] = r.p
    lif["size"] = len(r.d)
    if r.p != len(r.d):
        raise LifError(f"{len(r.d) - r.p} bytes left after the last list")
    return lif


if __name__ == "__main__":
    lif = read(sys.argv[1])
    h = lif["header"]
    print("tool:", h["tool"], "| sdf:", h["sdf"], "| options:", [(o["name"], o["value"]) for o in h["options"]])
    print("zooms", len(lif["zooms"]), "nets", len(lif["nets"]), "pins", len(lif["pins"]),
          "cells", [len(c) for c in lif["cells"]], "statems", len(lif["statems"]))
    print(f"read up to {lif['rest_at']:#x} of {lif['size']:#x}")
