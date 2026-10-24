# Building the Lattice fuse map

[Tool index](../README.md) | [Lattice chip versions](../../docs/lattice-versions.md) | [Correcting the capture logic](../../docs/12-lattice-fix.md)

U7's sources, in [data/lattice](../../data/lattice), are Lattice pDS 2.61 design files.
pDS 2.61 builds them into fuse maps; the original source builds into BE8C with every fuse
equal. The checks run a fuse map in a chip emulator (`chipsim.py`) next to its source
(`ldfsim.py`), and `u7_test.py` compares their pins on every bus cycle. Nothing here builds
for the ispLSI1016E ([Do not buy](../../docs/lattice-versions.md#do-not-buy)).

- [What you need](#what-you-need)
- [The files](#the-files)
- [Build with pDS 2.61](#build-with-pds-261)
- [Check a build](#check-a-build)
- [Changing the design](#changing-the-design)
- [The scripts](#the-scripts)

## What you need

- **Lattice pDS 2.61**, the "pLSI/ispLSI Development System" version 2.61 (1994): a
  Windows 3.1 program, the tool that built the original Lattice chip. It runs in Wine on Linux or
  WSL (a 32-bit prefix: Wine runs 16-bit Windows programs there), or on any Windows
  that runs 16-bit programs. pds261_build.sh expects it in `C:\PDS` of the Wine prefix.
- **Python 3** for the checks. No packages.
- For pds261_build.sh: Xvfb and xdotool.

## The files

| File | What it is |
|---|---|
| `data/lattice/Lattice_original-BE8C.ldf` | The original design, commented. With its placement file `.fxp`, pDS 2.61 builds it into the chip Sequential shipped, every fuse equal |
| `data/lattice/Lattice_v2.0.ldf` | The corrected design, v2.0: the original with the E14, E15 and E28 fixes, each marked CORRECTION |
| `data/lattice/Lattice_original-BE8C.jed` | The fuse map read from the original chip (checksum BE8C) |
| `prebuilt/lattice/*.jed` | The two maps these sources build into ([Lattice chip versions](../../docs/lattice-versions.md)) |

## Build with pDS 2.61

By hand, with the design and its placement file in one folder under one name of at most
eight letters (for example `U7.LDF` and `U7.fxp`):

1. File > Import LDF, and pick the `.LDF`. pDS reads the `.fxp` beside it.
2. Design > Verify. pDS compiles, minimizes and fits the design; the report is `U7.rp1`.
3. Design > Route: Strong, run time Extended.
4. Design > Fuse Map > Execute. pDS writes `U7.jed`.

The script does the same steps in Wine on a virtual screen:

```bash
tools/lattice/pds261_build.sh data/lattice/Lattice_original-BE8C.ldf data/lattice/Lattice_original-BE8C.fxp build/lattice/Lattice_original-BE8C_ispLSI1016.jed
```

```bash
tools/lattice/pds261_build.sh data/lattice/Lattice_v2.0.ldf data/lattice/Lattice_v2.0.fxp build/lattice/Lattice_v2.0_ispLSI1016.jed
```

| Source | Result |
|---|---|
| Lattice_original-BE8C | 15,360 fuses, checksum BE8C: every fuse equal to the original chip |
| Lattice_v2.0 | 15,360 fuses, checksum BBB1 |

## Check a build

The checks read pDS 2.61's device file `PLSI16.SDF` and package file `16PLCC44.PKG` from
its install folder: set `PDS_DIR` to it (default: `C:\PDS` of the Wine prefix above).

Compare a built chip with its source, over 3,000 random Apple and Z180 bus cycles, every
output pin after each cycle (a `.jed` runs in the emulator, a `.ldf` is evaluated as
written):

```bash
python tools/lattice/u7_test.py compare data/lattice/Lattice_v2.0.ldf data/lattice/Lattice_v2.0.ldf build/lattice/Lattice_v2.0_ispLSI1016.jed
```

The v2.0 fixes, on an original and a corrected chip:

```bash
python tools/lattice/u7_test.py directed prebuilt/lattice/Lattice_original-BE8C_ispLSI1016.jed prebuilt/lattice/Lattice_v2.0-BBB1_ispLSI1016.jed data/lattice/Lattice_v2.0.ldf
```

It prints each case: copies of bank $E1 writes made while RAMWRT is on (E14), the event
a $C034 write raises (E15), the SRAM bank of a copied bank $00 write against the Apple's
rule for every setting of 80STORE, PAGE2, HIRES and RAMWRT in IIgs and IIe mode (E28),
and the $9000 band flag, which v2.0 leaves as the original has it.

Results for the files in `prebuilt/lattice`: both maps match their sources on every
cycle; the fix checks pass on v2.0 and show the old behavior on the original.

Compare two fuse maps fuse by fuse:

```bash
python tools/lattice/jedec.py data/lattice/Lattice_original-BE8C.jed build/lattice/Lattice_original-BE8C_ispLSI1016.jed
```

## Changing the design

1. Edit `Lattice_v2.0.ldf`, or a copy of it, and keep its comments in step.
2. Put a new output in a block with a free output. Name it on that block's line in the
   `.fxp`, or leave the place `-1` and let pDS choose.
3. Stay inside the chip's limits: each block has four outputs, 20 product terms and 18
   inputs, and two signals on one routing-pool slot can make the route fail
   ([routing slots](../../docs/reference/lattice-source.md#building-and-changing-the-design)).
4. Keep every latch's terms exactly as written (the LATCHES note in the source).
5. Build it, then run `u7_test.py compare` on the result: the chip must match its source
   on every cycle.

## The scripts

| Script | What it does |
|---|---|
| `pds261_build.sh` | Runs pDS 2.61 in Wine on a virtual screen: Import LDF, Verify, Route (Strong, Extended), Fuse Map |
| `chipsim.py` | The emulator: an ispLSI1016 fuse map pin by pin, built only from pDS 2.61's device file |
| `mapread.py` | Reads every select of a fuse map through pDS 2.61's device file, for the emulator |
| `sdf.py`, `lif.py` | Read pDS 2.61's device file (`.SDF`) and design databases (`.lif`, `.lpr`) |
| `ldfsim.py` | Evaluates a pDS design file as written: the reference the emulator is compared with |
| `u7_test.py` | U7's Apple and Z180 bus cycles: the random comparison and the fix checks |
| `simcheck.py` | Any design: a fuse map in the emulator against its source, random pin vectors |
| `mapequiv.py` | Any two ispLSI1016 fuse maps against each other, random pin vectors |
| `jedec.py` | Reads a JEDEC file, checks its fuse checksum, counts differing fuses |

[Method](../../docs/13-method.md) | [Tool index](../README.md)
