"""Read a JEDEC fuse map (JESD3-C) and check its fuse checksum.

read_jed returns a list of 0/1, one per fuse:

    bits = read_jed("map.jed")

fuse_checksum returns the 16-bit checksum held in the file's C field:

    fuse_checksum(bits)

Usage: python jedec.py A.jed [B.jed]   prints the fuse count and checksum, and with two
files how many fuses differ."""
import re
import sys
from pathlib import Path


def read_jed(path):
    """The fuses of a JEDEC file: QF gives the count, F the default, each L field sets a
    run of fuses. Raises ValueError when a fuse is set twice or the C checksum differs."""
    text = Path(path).read_text(encoding="latin-1")
    count = int(re.search(r"QF(\d+)", text)[1])
    default = re.search(r"\bF([01])", text)
    bits = [int(default[1]) if default else 0] * count
    assigned = set()
    for match in re.finditer(r"L(\d+)\s+([01\s]+)\*", text):
        start = int(match[1])
        values = [int(c) for c in match[2] if c in "01"]
        if start + len(values) > count:
            raise ValueError(f"{path}: L{start} runs past QF{count}")
        for offset, value in enumerate(values, start):
            if offset in assigned:
                raise ValueError(f"{path}: fuse {offset} set twice")
            assigned.add(offset)
            bits[offset] = value
    stated = re.search(r"\bC\s*([0-9A-Fa-f]{4})", text)
    if stated and int(stated[1], 16) != fuse_checksum(bits):
        raise ValueError(f"{path}: checksum C{stated[1]}, fuses sum to {fuse_checksum(bits):04X}")
    return bits


def fuse_checksum(bits):
    """The JEDEC fuse checksum: the 16-bit sum of the fuses packed 8 to a byte, first fuse
    in the low bit."""
    total = 0
    for j in range(0, len(bits), 8):
        total += sum(bits[j + i] << i for i in range(min(8, len(bits) - j)))
    return total & 0xFFFF


if __name__ == "__main__":
    maps = [read_jed(p) for p in sys.argv[1:]]
    for p, b in zip(sys.argv[1:], maps):
        print(f"{Path(p).name}: {len(b)} fuses, checksum {fuse_checksum(b):04X}")
    if len(maps) == 2:
        print(f"{sum(x != y for x, y in zip(*maps))} fuses differ")
