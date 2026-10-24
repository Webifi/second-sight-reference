"""Read a Lattice pDS 2.61 device file (PLSI16.SDF: one family and its member device) into
Python dicts. Same record stream as the LIF (lif.Reader): type byte, big-endian fields,
NUL-ended strings, lists ended by a type byte 0. Order from _fs_sdf_read_fammem: header (0x17),
family (0x2c), member (0x3c), then the string table (header word +0x210 entries).
Each function names the pDS 2.61 reader it follows (fsrsdf1.c / fsrsdf2.c, decompiled)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lif import Reader, LifError  # noqa: E402


def version(r):  # _fs_r_sdfversion, 0x16
    if r.record(0x16) != 0x16:
        raise LifError("SDF version record missing")
    return (r.i2(), r.i2(), r.i2())


def header(r):  # _fs_r_sdfheader, 0x17
    if r.record(0x17) != 0x17:
        raise LifError("SDF header record missing")
    h = {"version": version(r), "i0": r.i4(), "name": r.string(), "i104": r.i2(), "i10a": r.i4(),
         "text": r.string(), "i20e": r.i2(), "i210": r.i2(), "i212": r.i2()}
    return h


def pin(r):  # _fs_r_sdfpin, 0x18
    return dict(zip(("name", "i2", "i4", "i6"), (r.i2(), r.i2(), r.i2(), r.i2())))


def fusedef(r):  # _fs_r_sdffusedef, 0x19: fuse name, row, column, default, ...
    return dict(zip(("name", "row", "col", "default", "i8"), (r.i2() for _ in range(5))))


def word(r):  # _fs_r_sdffuseval 0x1a, _fs_r_sdffusename 0x1b, gbus/global lists: one word
    return r.i2()


PRIMS = [  # (cell-def field, record type, reader, extra lists after the two pin lists)
    ("and", 0x1c, "_fs_r_sdfandprim", ("fusenames", "fusenames2")),
    ("demux", 0x1d, "_fs_r_sdfdemuxprim", ("fusenames", "fusevals")),
    ("orf", 0x1e, "_fs_r_sdforfprim", ()),
    ("org", 0x1f, "_fs_r_sdforgprim", ("fusenames",)),
    ("config", 0x20, "_fs_r_sdfconfigprm", ("fusenames", "fusevals")),
    ("mux", 0x21, "_fs_r_sdfmuxprim", ("fusenames", "fusevals")),
    ("con", 0x22, "_fs_r_sdfconprim", ()),
    ("xor", 0x23, "_fs_r_sdfxorprim", ()),
    ("dreg", 0x24, "_fs_r_sdfdregprim", ()),
    ("fflreg", 0x25, "_fs_r_sdffflregprim", ()),
    ("or2b1", 0x26, "_fs_r_sdfor2b1prim", ()),
    ("buf", 0x78, "_fs_r_sdfbufprim", ()),
    ("ibuf", 0x27, "_fs_r_sdfibufprim", ()),
    ("tribuf", 0x28, "_fs_r_sdftribuf", ("fusenames", "fusevals")),
    ("splitbuf", 0x29, "_fs_r_sdfsplitbufprim", ()),
    ("inv", 0x2a, "_fs_r_sdfinvprim", ()),
]
LISTS = {"fusenames": (0x1b, word), "fusenames2": (0x1b, word), "fusevals": (0x1a, word)}


def prim_reader(extra):
    def body(r):
        p = {"id": r.i2(), "i2": r.i2(), "i4": r.i2(),
             "inputs": r.items(0x18, pin), "outputs": r.items(0x18, pin)}
        for name in extra:
            t, fn = LISTS[name]
            p[name] = r.items(t, fn)
        return p
    return body


def celldef(r):  # _fs_r_sdfcelldef, 0x2b
    c = {"id": r.i2(), "i2": r.i2(), "inputs": r.items(0x18, pin), "outputs": r.items(0x18, pin),
         "ic": r.i2()}
    for field, t, _, extra in PRIMS:
        c[field] = r.items(t, prim_reader(extra))
    c["fuses"] = r.items(0x19, fusedef)
    c["i56"] = r.i2()
    return c


def family(r):  # _fs_r_sdffamily, 0x2c: four cell-definition lists
    if r.record(0x2c) != 0x2c:
        raise LifError("family record missing")
    return {"i0": r.i4(), "celldefs": [r.items(0x2b, celldef) for _ in range(4)]}


def fusewire(r):  # _fs_r_sdffusewire, 0x31
    return {"i0": r.i2(), "i2": r.i2()}


def switchwire(r):  # _fs_r_sdfswitchwire, 0x32
    return {"i0": r.i2(), "i2": r.i2(), "fuses": r.items(0x31, fusewire)}


def vconn(r):  # _fs_r_sdfverticalconnection, 0x79
    return [r.i2() for _ in range(6)]


def conwire(r):  # _fs_r_sdfconwire, 0x33
    return {"i0": r.i2(), "i2": r.i2(), "i4": r.i2(), "vconns": r.items(0x79, vconn)}


def muxwire(r):  # _fs_r_sdfmuxwire, 0x34
    return {"pins": r.items(0x18, pin), "fusenames": r.items(0x1b, word), "fusevals": r.items(0x1a, word)}


def outcon(r):  # _fs_r_sdfoutcon, 0x35
    return {"i0": r.i2(), "i2": r.i2(), "pins": r.items(0x18, pin), "conwires": r.items(0x33, conwire),
            "switchwires": r.items(0x32, switchwire), "muxwires": r.items(0x34, muxwire), "i14": r.i2()}


def cellins(r):  # _fs_r_sdfcellins, 0x3b: one placed cell (GLB, IOC, ...) of the device
    c = dict(zip(("def", "i2", "i8", "i4", "i6", "ia", "ic", "ie", "i10", "i12"), (r.i2() for _ in range(10))))
    c["inputs"], c["outputs"] = r.items(0x18, pin), r.items(0x18, pin)
    c["outcons"] = r.items(0x35, outcon)
    c["fuses"] = r.items(0x19, fusedef)
    c["i2c"] = r.i2()
    return c


def irpin(r):  # _fs_r_sdfirpin, 0x2d
    return dict(zip(("i0", "i2", "i4", "i6"), (r.i2() for _ in range(4))))


def irwire(r):  # _fs_r_sdfirwire, 0x2e
    return {"i0": r.i2(), "a": r.items(0x2d, irpin), "b": r.items(0x2d, irpin)}


def irfusepat(r):  # _fs_r_sdfirfusepat, 0x7c
    return {"i0": r.i2(), "wires": r.items(0x2e, irwire)}


def wirelist(r):  # _fs_r_sdfwirelist, 0x2f
    return {"i0": r.i2(), "pins": r.items(0x18, pin)}


def buslist(r):  # _fs_r_sdfbuslist, 0x30
    return {"i0": r.i2(), "i2": r.i2(), "wires": r.items(0x2f, wirelist)}


def gconn(r):  # _fs_r_sdfglobalconnection, 0x7a
    return {"i0": r.i2(), "vconns": r.items(0x79, vconn)}


def gbuslist(r):  # _fs_r_sdfgbuslist, 0x7b
    return {"i0": r.i2(), "gconns": r.items(0x7a, gconn)}


def fixed(r, t, n, what):
    if r.record(t) != t:
        raise LifError(f"{what} record missing")
    return [r.i2() for _ in range(n)]


def member(r):  # _fs_r_sdfmember, 0x3c
    if r.record(0x3c) != 0x3c:
        raise LifError("member record missing")
    m = {"i0": r.i4(), "i4": r.i2()}
    m["cellins"] = [r.items(0x3b, cellins) for _ in range(8)]
    m["irfusepats"] = r.items(0x7c, irfusepat)
    m["buses"] = [r.items(0x30, buslist) for _ in range(5)]
    m["gbus"] = r.items(0x7b, gbuslist)
    m["buses2"] = r.items(0x30, buslist)
    m["fuses"] = r.items(0x19, fusedef)
    m["cellins_4e"] = cellins(r) if r.record(0x3b) else None
    m["i52"], m["i54"] = r.i2(), r.i2()
    m["gui"] = r.items(0x3a, lambda rr: [rr.i2() for _ in range(6)])  # _fs_r_sdfgui list
    m["pr"] = fixed(r, 0x37, 10, "pr")
    m["lde_drc"] = fixed(r, 0x36, 36, "lde_drc")
    m["fusegen"] = fixed(r, 0x38, 17, "fusegen")
    return m


def symtab(r, n):  # _fs_r_sdfsymtab: n names, each a 'B' (0x42) record then a NUL-ended string
    names = []
    for _ in range(n):
        if r.byte() != 0x42:
            raise LifError(f"string table entry {len(names)} not a 0x42 record")
        names.append(r.string())
    return names


def read(path):
    r = Reader(open(path, "rb").read())
    s = {"header": header(r)}
    s["family"] = family(r)
    s["member"] = member(r)
    s["names"] = symtab(r, s["header"]["i210"])
    s["rest"] = len(r.d) - r.p
    return s


if __name__ == "__main__":
    s = read(sys.argv[1])
    print(s["header"]["name"], s["header"]["version"], "| cell defs", [len(c) for c in s["family"]["celldefs"]],
          "| cell instances", [len(c) for c in s["member"]["cellins"]], "| names", len(s["names"]),
          "| bytes left", s["rest"])
