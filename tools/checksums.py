"""Verify the two dumps' internal checksums.

- ROM_BEEF.bin: the EPROM label says "rev. 1.4-BEEF"; the 16-bit byte sum of the whole
  128 KB image is $BEEF.
- isplsi1016_BE8C.bin: a JEDEC text file. Its fuse checksum (the 16-bit sum of the fuse
  bytes, fuse 0 in bit 0 of the first byte) must equal the C field, BE8C, which is also
  written on the chip's sticker.

Usage:
    python tools/checksums.py
        uses the files fetched into sources/
    python tools/checksums.py <ROM_BEEF.bin> <isplsi1016_BE8C.bin>
"""

import re
import sys
from pathlib import Path


def rom_sum(path):
    return sum(open(path, "rb").read()) & 0xFFFF


def jedec_sum(path):
    text = open(path, "rb").read().decode("latin1")
    fuse_count = int(re.search(r"QF(\d+)\*", text).group(1))
    default = re.search(r"\bF([01])\*", text)
    fuses = [int(default.group(1)) if default else 0] * fuse_count
    for match in re.finditer(r"L(\d+)\s+([01\s]+)\*", text):
        start = int(match.group(1))
        for i, bit in enumerate(re.sub(r"\s", "", match.group(2))):
            fuses[start + i] = int(bit)
    total = 0
    for i in range(0, fuse_count, 8):
        total += sum(bit << j for j, bit in enumerate(fuses[i:i + 8]))
    stated = re.search(r"\*\s*C([0-9A-Fa-f]{4})\*", text)
    return fuse_count, total & 0xFFFF, stated.group(1).upper() if stated else None


def main():
    if len(sys.argv) == 3:
        rom, jed = sys.argv[1], sys.argv[2]
    elif len(sys.argv) == 1:
        dumps = Path(__file__).resolve().parent.parent / "sources" / "mirror" / "ROM Images"
        rom, jed = dumps / "ROM_BEEF.bin", dumps / "isplsi1016_BE8C.bin"
    else:
        print(__doc__)
        return 1
    print(f"ROM byte sum: ${rom_sum(rom):04X} (label says BEEF)")
    count, computed, stated = jedec_sum(jed)
    print(f"JEDEC: {count} fuses, computed checksum {computed:04X}, file says {stated}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
