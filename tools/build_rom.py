"""Build a Second Sight ROM image from firmware assembly source, and compare it with ROM 1.4.

The source is ASxxxx assembler syntax (asz80 with .hd64 for the Z180 instructions). This
script assembles and links it, turns the linker's Intel HEX output into the 128 KB EPROM
image, and reports what differs from ROM 1.4:

    python tools/build_rom.py firmware/v1.4/ROM_BEEF.asm
        builds build/firmware/ROM_BEEF.bin; it must equal original/ROM_BEEF.bin byte for byte
    python tools/build_rom.py firmware/v1.5/SecondSight_v1_5.asm
        builds build/firmware/SecondSight_v1_5.bin (firmware v1.5) and lists
        every byte range that differs from ROM 1.4; the same for
        firmware/v2.0/SecondSight_v2_0.asm (firmware v2.0)
    python tools/build_rom.py --check
        builds the three committed sources, checks their SHA-256 against EXPECTED, and
        checks that prebuilt/firmware/ holds exactly the current ready-built images
    python tools/build_rom.py --prebuilt
        builds the two changed sources and writes their ready-built images (PREBUILT)

A ready-built image is named like Sequential's EPROM labels, version and 16-bit byte sum:
ROM 1.4 is "rev 1.4-BEEF", the changed builds are SecondSight_firmware_v1.5-<sum>.bin and
SecondSight_firmware_v2.0-<sum>.bin. The SHA-256 the tool prints
identifies the image exactly.

The image is the assembled low 64 KB followed by 64 KB of zero bytes, as in ROM 1.4.
Bytes the source does not define (the FREE SPACE blocks skipped with .org) are zero. The
build stops if a FREE SPACE block overlaps the code that follows it.

Needs ASxxxx 6.10 (asz80 and aslink): put them on PATH, or set the environment variable
ASXXXX to the folder that holds them. See firmware/README.md.
"""

import hashlib
import os
import shutil
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "build" / "firmware"
ORIGINAL = REPO / "firmware" / "v1.4" / "ROM_BEEF.asm"

# SHA-256 each committed source must build, by its path in the repository. The
# original's is the hash of original/ROM_BEEF.bin, the published EPROM dump.
EXPECTED = {
    "firmware/v1.4/ROM_BEEF.asm": "bd29e30ebf004e205609112a3c21a26eb28504115e047862fbd27f641f784d61",
    "firmware/v1.5/SecondSight_v1_5.asm": "45d6fb82f92b5e9ca2c5d9e03b1f9d0b8faaf0a73f7c2d52c9a3743ab06aa562",
    "firmware/v2.0/SecondSight_v2_0.asm": "675f38252930c0cfef3e5d20de5358df07f433386066150d7e0dd74014be7337",
}

# The ready-built EPROM images kept in the repository, by the source that builds them.
# --check stops when one no longer equals its build; --prebuilt writes them.
PREBUILT = {
    "firmware/v1.5/SecondSight_v1_5.asm": "1.5",
    "firmware/v2.0/SecondSight_v2_0.asm": "2.0",
}
PREBUILT_DIR = REPO / "prebuilt" / "firmware"


def prebuilt_path(version, image):
    """Return the ready-built image's path: SecondSight_firmware_v<version>-<byte sum>.bin."""
    return PREBUILT_DIR / f"SecondSight_firmware_v{version}-{sum(image) & 0xFFFF:04X}.bin"


def tool(name):
    """Return the path of an ASxxxx program, or stop with instructions."""
    folder = os.environ.get("ASXXXX")
    candidates = []
    if folder:
        candidates += [Path(folder) / name, Path(folder) / (name + ".exe")]
    found = shutil.which(name)
    if found:
        candidates.append(Path(found))
    for path in candidates:
        if path.is_file():
            return str(path)
    sys.exit(f"{name} not found: install ASxxxx 6.10 and put it on PATH, or set ASXXXX "
             f"to its folder (firmware/README.md)")


def assemble(source):
    """Assemble and link one source file; return the 128 KB image as bytes.

    The assembler runs in the source file's folder, because ASxxxx looks for .include
    files relative to the folder it runs in; its output goes to build/firmware/<name>/.
    """
    work = OUT / source.stem
    work.mkdir(parents=True, exist_ok=True)
    steps = [
        ([tool("asz80"), "-l", "-s", f"-o+{work / source.stem}", source.name], source.parent),
        ([tool("aslink"), "-n", "-i", "-m", source.stem], work),
    ]
    for command, folder in steps:
        run = subprocess.run(command, cwd=folder, capture_output=True, text=True)
        output = (run.stdout + run.stderr).strip()
        if run.returncode != 0 or "?ASxxxx-Error" in output:
            sys.exit(f"{Path(command[0]).stem} failed on {source.name}:\n{output}")

    image = {}
    upper = 0
    for row in (work / (source.stem + ".hex")).read_text().splitlines():
        record = bytes.fromhex(row[1:])
        count, high, low, kind = record[:4]
        if kind == 4:
            upper = int.from_bytes(record[4:6], "big") << 16
        elif kind == 0:
            for offset, value in enumerate(record[4 : 4 + count]):
                address = upper + (high << 8) + low + offset
                if address in image:
                    sys.exit(f"{source.name}: address ${address:04X} is written twice. New code "
                             f"in a FREE SPACE block probably runs past the block's end.")
                image[address] = value
    if any(address > 0xFFFF for address in image):
        sys.exit(f"{source.name}: code beyond $FFFF; the low 64 KB is the whole source")
    low = bytes(image.get(address, 0) for address in range(0x10000))
    return low + bytes(0x10000)


def ranges(addresses, gap=16):
    """Group sorted addresses into (first, last) runs.

    Runs closer than `gap` bytes are joined, so a block of new code whose bytes happen to
    match ROM 1.4 here and there reads as one range; the joined bytes keep their values.
    """
    runs = []
    for address in addresses:
        if runs and address <= runs[-1][1] + gap:
            runs[-1][1] = address
        else:
            runs.append([address, address])
    return runs


def report(name, image, original):
    """Print the image summary and every byte range that differs from ROM 1.4; return the SHA-256."""
    digest = hashlib.sha256(image).hexdigest()
    print(f"{name}: {len(image)} bytes, byte sum ${sum(image) & 0xFFFF:04X}, SHA-256 {digest}")
    changed = [a for a in range(len(image)) if image[a] != original[a]]
    if not changed:
        print("  identical to ROM 1.4")
        return digest
    print(f"  {len(changed)} bytes differ from ROM 1.4:")
    for first, last in ranges(changed):
        size = last - first + 1
        print(f"    ${first:05X}-${last:05X} ({size} byte{'s' if size > 1 else ''})")
    return digest


def main():
    args = sys.argv[1:]
    check = "--check" in args
    prebuilt = "--prebuilt" in args
    if check:
        sources = [REPO / path for path in EXPECTED]
    elif prebuilt:
        sources = [REPO / path for path in PREBUILT]
    else:
        sources = [Path(a).resolve() for a in args if not a.startswith("--")]
    if not sources:
        sys.exit(__doc__)
    OUT.mkdir(parents=True, exist_ok=True)
    current = set()
    original = assemble(ORIGINAL)
    if hashlib.sha256(original).hexdigest() != EXPECTED["firmware/v1.4/ROM_BEEF.asm"]:
        sys.exit(f"{ORIGINAL.relative_to(REPO)} no longer builds ROM 1.4 byte for byte")
    for source in sources:
        image = original if source == ORIGINAL else assemble(source)
        binary = OUT / (source.stem + ".bin")
        binary.write_bytes(image)
        digest = report(source.name, image, original)
        print(f"  wrote {binary.relative_to(REPO)}")
        name = source.relative_to(REPO).as_posix()
        if check and EXPECTED.get(name) not in (None, digest):
            sys.exit(f"{source.name}: SHA-256 differs from EXPECTED in tools/build_rom.py")
        if name not in PREBUILT:
            continue
        copy = prebuilt_path(PREBUILT[name], image)
        current.add(copy.name)
        if prebuilt:
            copy.parent.mkdir(parents=True, exist_ok=True)
            copy.write_bytes(image)
            print(f"  wrote {copy.relative_to(REPO)}")
        elif check:
            if not copy.is_file() or copy.read_bytes() != image:
                sys.exit(f"{copy.relative_to(REPO)} is missing or differs from the build of {name}; "
                         f"run python tools/build_rom.py --prebuilt")
            print(f"  {copy.relative_to(REPO)}: same as the build")
    if check:
        # Reject prebuilt images whose names do not match a current build.
        stale = sorted(p.name for p in PREBUILT_DIR.glob("*.bin") if p.name not in current)
        if stale:
            sys.exit(f"prebuilt/firmware/ holds images no current source builds: {', '.join(stale)}")


if __name__ == "__main__":
    main()
