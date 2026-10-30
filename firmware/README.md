# Firmware source

[Reference index](../README.md) | [Firmware versions](../docs/firmware-versions.md) | [08 Firmware](../docs/08-firmware.md) | [Errata](../docs/reference/errata.md)

The Z180 firmware as assembly source. ROM 1.4's source builds the original image byte for
byte; firmware 1.5 (for the original Lattice chip) and 2.0 (for Lattice v2.0) are changed copies of it
([Firmware versions](../docs/firmware-versions.md)).

Each version is a folder with its top file and its `src/` folder:

| Folder | Contents |
|---|---|
| [`v1.4/`](v1.4) | ROM 1.4, Sequential's last release. Top file [`ROM_BEEF.asm`](v1.4/ROM_BEEF.asm); builds ROM 1.4 byte for byte. [`v1.4/src/`](v1.4/src) holds the routines and tables, arranged by address, with each known fault marked `BUG (En)`; [`v1.4/src/hardware.inc`](v1.4/src/hardware.inc) names the I/O ports. |
| [`v1.5/`](v1.5) | Firmware 1.5, for a card with the original Lattice chip (fuse map BE8C): a copy of the ROM 1.4 source with every fix firmware alone can make written in ([the list](../docs/firmware-versions.md#what-each-version-fixes)). Top file [`SecondSight_v1_5.asm`](v1.5/SecondSight_v1_5.asm). Each change is marked `CHANGE (En)` and says what it fixes. |
| [`v2.0/`](v2.0) | Firmware 2.0, for a card with [Lattice v2.0](../docs/lattice-versions.md), the corrected fuse map (BBB1): the 1.5 source plus E15, the IIgs border color, which only Lattice v2.0 makes possible. Top file [`SecondSight_v2_0.asm`](v2.0/SecondSight_v2_0.asm). |
| [`original/`](original) | Files from the disk image [`ss.source.082395.po`](../docs/sources.md#s06): the mode records, the table generators, the fonts. The source uses them where they match ROM 1.4; [original/README.md](original/README.md) lists what each is. |

The source starts from the annotated disassembly
[`ROM_BEEF.asm`](https://github.com/jawaidbazyar2/secondsight/blob/780abcb754ce4ed516980925230ddbb4581107f0/ROM_BEEF.asm)
([Sources](../docs/sources.md#s27)), with its 2,220-byte Super Hi-Res block disassembled,
labels and ports named, and tables written as data rows.

Firmware 1.5 and 2.0 differ only in E15 and the version byte; a fix other than E15 goes
into both.

## Contents

- [Building](#building)
- [Changing the firmware](#changing-the-firmware)
- [Putting it on a card](#putting-it-on-a-card)

## Building

1. Install the ASxxxx assembler, version 6.10. The [download page](https://shop-pdp.net/ashtml/asxget.php)
   has ready-made programs for Windows (for example `6p10_exe_vs22.zip`) and Linux
   (`6p10_exe_linux.zip`), and the source code (`asxs6p10.zip`) for other systems. The
   build needs two of its programs, `asz80` and `aslink`.
2. Put the folder that holds them on your PATH, or name it in the environment variable
   `ASXXXX`.
3. From the repository root, with Python 3, build any of the three top files:

```bash
python tools/build_rom.py firmware/v1.4/ROM_BEEF.asm
```

```bash
python tools/build_rom.py firmware/v1.5/SecondSight_v1_5.asm
```

```bash
python tools/build_rom.py firmware/v2.0/SecondSight_v2_0.asm
```

The tool runs the assembler in the top file's folder, where its `.include "src/..."`
lines resolve. The image goes to `build/firmware/<name>.bin`, 131,072 bytes. For
`ROM_BEEF.asm` the tool checks that the image equals ROM 1.4 (SHA-256 `bd29e30e...4d61`).
For any other source it lists every byte range that differs from ROM 1.4:

```text
SecondSight_v1_5.asm: 131072 bytes, byte sum $CBFC, SHA-256 19e9b6f5...6846
  5439 bytes differ from ROM 1.4:
    ...
```

To check all three builds, and that the ready-built images in `prebuilt/firmware/` are
the same as fresh builds:

```bash
python tools/build_rom.py --check
```

To update the ready-built images after a source change:

```bash
python tools/build_rom.py --prebuilt
```

## Changing the firmware

Make a change in a copy of the source: in `v1.5/` and `v2.0/` for a fix both cards get,
or in a new copy of `v1.4/` for your own version.
Mark each change, and build its top file. The build lists exactly what your change
touches compared with ROM 1.4. The comments marked `;;` explain each routine and point
into the docs: [08 Firmware](../docs/08-firmware.md) for how the firmware works,
[05 Z180](../docs/05-z180.md) for the processor, memory and boot,
[Z180 I/O ports](../docs/reference/z180-io-ports.md) for the card's ports.

Two rules keep the rest of the ROM working:

1. **Keep every routine and table at its address.** The boot code copies fixed address
   ranges into SRAM, some code reaches tables by fixed addresses, and the Super Hi-Res
   renderer is copied to another bank and run there. Anything that moves breaks the card.
   To change a routine, overwrite its instructions with code of the same length: usually
   a `JP` or `CALL` to new code, plus `NOP`s for any bytes left over.
   One exception: $A000-$BFFF, the Super Hi-Res renderer, is copied as one block and
   runs only as a whole, so code inside it that nothing outside calls may move. Labels
   other files use (`set_videomode_superhires`, `emulate_superhires`) and labels with an
   `.assume` line must stay. The E13 converter relies on this.
2. **Put new code in a FREE SPACE block.** Search `src/` for `FREE SPACE`. There are
   five, all copied into SRAM at boot:

### $0003-$0037 (53 bytes)

`src/boot.asm`. Always mapped. ROM 1.4 runs no RST here. Firmware 2.0 uses $0003-$0032
for E15.

### $003B-$007F (69 bytes)

`src/boot.asm`. Always mapped. Covers the NMI entry at $0066; NMI never fires on this
card. Firmware 2.0 uses $003B-$0079 for E15.

### $1EC4-$1FFF (316 bytes)

`src/mainloop.asm`. Always mapped.

Firmware 1.5 and 2.0 use $1EC4-$1ED9 for E26, $1EE6-$1EF6 for `call_in_bank0` (runs a
routine in $9776-$9FFF from any memory layout), $1F00-$1FEB for E5 and E2, and
$1FEC-$1FF7 for E10; 2.0 also uses $1EDA-$1EE5 for E15.

### $9776-$9FFF (2,186 bytes)

`src/text.asm`. Mapped only in the firmware's usual layout (BBR = 0): not from the
double-hires or Super Hi-Res renderers, where logical $9xxx shows other memory;
elsewhere `call_in_bank0` reaches it.

Firmware 1.5 and 2.0 use $9776-$9B6D for E16, E17, E1, E19 and E8-E9, $9B6E-$9B89 and
$9C75-$9CF9 for the UploadData split at 512 KB, $9B8A-$9BB1 for E29, $9C00-$9C74 for E6,
$9D00-$9ECC for E7 and $9ECD-$9FA4 for E10.

### $B025-$B1FF (475 bytes)

`src/superhires.asm`. Copied with the Super Hi-Res renderer to SRAM bank 1 and run
there, so only that renderer's code can use it.

Firmware 1.5 and 2.0 use $B025-$B05C for E13.

E13's renderer also leaves $A3BE-$AA9C (1,759 bytes) free the same way; 2.0 uses
$A3BE-$A472 of it for E15, and both use $A480-$A5A6 for E11 and $A600-$A9FF for E13's
page tables. In the bank 0 copy, which nothing runs, $A600-$A9FF is ScrollScreen's
buffer.

### Using a free-space block

Each block ends with `.org`, which puts the code after it back at its fixed address.
Write your code between the block's label and that `.org`:

```text
free_1EC4:
my_new_routine:
                ld      a, #0xA5
                out0    (CARD_DATA), a
                ret
                .org    0x2000
```

The build stops when something has moved or overflowed:

- `.assume label - 0xNNNN` lines check that important labels stay at their addresses. An
  error on one of them means code before it changed length.
- `address $xxxx is written twice` means new code ran past the end of its FREE SPACE
  block into the code that follows.

For more room, SRAM bank 1 $C000-$FFFF is free while the firmware runs, and the EPROM's
upper 64 KB is zero; code there needs a loader and a bank switch
([Room for added code](../docs/08-firmware.md#changing-and-building-the-firmware) in
08 Firmware).

## Putting it on a card

Program the image into a 27C1000 (128 KB) EPROM and fit it in socket U10 in place of the
original, which stays unchanged for going back. Firmware 2.0 goes with Lattice v2.0, firmware
1.5 with the original Lattice chip. Ready-built images are in
[`prebuilt/firmware/`](../prebuilt/firmware): [Firmware versions](../docs/firmware-versions.md).
