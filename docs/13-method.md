# 13 Method: reproduce the reference data

[Reference index](../README.md) | [Glossary](glossary.md) | [Reference tables](reference/README.md)

How to rebuild the reference tables, the [netlist](../data/netlist/README.md) and the U7
source from the original files.

## Contents

- [Before you start](#before-you-start)
- [1. Get the sources](#1-get-the-sources)
- [2. Check the dumps](#2-check-the-dumps)
- [3. Read the schematic and the databooks](#3-read-the-schematic-and-the-databooks)
- [4. Transcribe the board](#4-transcribe-the-board)
- [5. Read the firmware](#5-read-the-firmware)
- [6. Decode the Lattice ispLSI1016](#6-decode-the-lattice-isplsi1016)

## Before you start

Run the commands from the repository root. You need Python 3, Pillow for `pdf_pages.py`,
and network access to download the sources. Building U7 needs Lattice's own tools
([What you need](../tools/lattice/README.md#what-you-need)). Every tool and its options:
[tool index](../tools/README.md).

## 1. Get the sources

```bash
python tools/fetch_sources.py
```

It downloads every entry of [`sources/manifest.json`](../sources/manifest.json) that has a
SHA-256 into `sources/`, and checks the hash. The apple2.org.za mirror's HTTPS certificate
has expired, so the script falls back to HTTP and relies on the hash. An entry without a
hash is a link only ([Sources](sources.md)).

## 2. Check the dumps

```bash
python tools/checksums.py
```

- [`ROM_BEEF.bin`](sources.md#s25): byte sum $BEEF, as the label says.
- [`isplsi1016_BE8C.bin`](sources.md#s24): the JEDEC file's own checksum field and the
  recomputed fuse checksum are both $BE8C, as the sticker says.

## 3. Read the schematic and the databooks

The schematic and most databooks are scans. `tools/pdf_pages.py` pulls the page images out
of a PDF (CCITT fax, JPEG 2000 and JPEG streams), and can rotate and scale them:

```bash
python tools/pdf_pages.py "sources/mirror/Schematics/Second Sight - Schematics.pdf" build/schematic --rotate -90
```

```bash
python tools/pdf_pages.py sources/mirror/Datasheets/OTI-087.pdf build/oti087
```

`tools/pdf_text.py` dumps the text of a PDF that has a text layer, such as the
[Bt481A datasheet](sources.md#s36).

Databook citations use **printed** page numbers. In the apple2.org.za OTI-087 scan, printed
pages 29, 30 and 33 are PDF pages 39, 40 and 41. Printed pages 31-32 are missing.

## 4. Transcribe the board

The [pin-level netlist](../data/netlist/README.md) is a transcription of the five
schematic pages. A net named `UNRESOLVED_...` is a connection the drawing does not show.
Read [how to read the data](../data/netlist/README.md#how-to-read-the-data) before using it.

```bash
python tools/netlist/build_netlist.py
python tools/netlist/check_pinouts.py
python tools/netlist/audit_netlist.py
```

- `build_netlist.py` writes the transcription out.
- `check_pinouts.py` compares all 756 IC pins with their datasheets.
- `audit_netlist.py` checks the exported connections.

## 5. Read the firmware

- [`ROM_BEEF.asm`](sources.md#s27) is the annotated disassembly. The reset vector, the
  references to $0208, the command table at $1C0F and the mode records can each be checked
  in the bytes of [`ROM_BEEF.bin`](sources.md#s25).
- [`firmware/`](../firmware/README.md) holds the whole disassembly as source.
  `python tools/build_rom.py --check` assembles it and compares the result with the dump,
  byte for byte.
- `tools/mode_files.py` decodes the firmware's mode tables and the library's mode files
  ([How the firmware sets a mode](06-video.md#how-the-firmware-sets-a-mode)).
- The `.po` disk images are ProDOS images. `tools/prodos.py ls|cat` lists and extracts
  their files.

```bash
python tools/mode_files.py --firmware "sources/mirror/ROM Images/ROM_BEEF.bin"
```

```bash
python tools/prodos.py ls "sources/mirror/Disk Images/ss.source.082395.po"
```

## 6. Decode the Lattice ispLSI1016

[`data/lattice/SecondSight_U7.ldf`](../data/lattice/SecondSight_U7.ldf) is U7's logic,
written for Lattice pDS 2.61, the tool that built the original chip. pDS 2.61 builds the
original fuse map (`isplsi1016_BE8C.bin`, 15,360 fuses) from it with every fuse equal.
How the source was made:

1. **Read the map through Lattice's own chip description.** pDS 2.61's device file
   (`PLSI16.SDF`) names every fuse of the ispLSI1016 and the logic it selects: product
   terms, OR gates, routing pool, clock and output options. Every programmed fuse in BE8C
   has a meaning there. `tools/lattice/mapread.py` refuses a map with a fuse it cannot
   explain.
2. **Write the logic as pDS 2.61 source.** The logic alone does not fix the fuses. pDS
   numbers a block's signals in the order its text first names them. That number sets the
   order of each output's product terms, and so where each term goes. So these were chosen
   from a model of pDS 2.61's compiler, minimizer and fitter:
   - the order of signals, equations, terms and names
   - which outputs use STRONGMIN (pDS's stronger minimizer)
   - two unused outputs that steer the placement, A2_FIT and B0_FIT
3. **Build with pDS 2.61** ([Building U7](../tools/lattice/README.md)). The source and its
   placement file give BE8C, all 15,360 fuses equal.
4. **Name and comment.** Signal names come from the schematic's pin labels. Every block,
   signal and term has a comment.
5. **Check against the firmware**, which the source was never fitted to:
   - The band flags match the Super Hi-Res renderer's redraw splits.
   - The copy-inhibit bit matches SetShadow's values.
   - The 80STORE tracking explains why the firmware ignores its own 80STORE flag.
   - The STATEREG bit positions identify the AD6 input.
6. **Check a build of a changed design** against its source:
   [Check a build](../tools/lattice/README.md#check-a-build).

---

Previous: [12 Correcting the capture logic](12-lattice-fix.md) | [Reference index](../README.md) | Next: [14 Beyond the firmware](14-custom-code.md)
