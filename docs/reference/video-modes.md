# Video mode records

[Reference tables](README.md) | [Glossary](../glossary.md)

The clock, timing and register values of every mode record in ROM 1.4 and the
`ss.source.082395.po` mode files, as the 1.4 mode loader programs them. A file's name says
the mode it was meant to set; the values say what it sets.

- The firmware uses its VGA list when `$3C2` bit 4 is 1, otherwise its AppleColor RGB list
  ([mode codes](#built-in-mode-codes)).
- The clock select shown is the final one. The firmware writes misc output after extended
  register 6, so the misc byte can change the clock that register 6 asked for.
- Timing values are calculated from the programmed registers. H visible is a programmed
  count: packed color and double-width timing can make it differ from the picture width.
- What each register does: [OTI-087 registers](oti087-registers.md),
  [Bt481 modes](bt481-modes.md), [Clock selections](clocks.md).
- Building a new mode from these records: [SetUserMode byte layout](host-commands.md#setusermode),
  [Bt481 pixel formats](bt481-modes.md), [24-bit mode width](../14-custom-code.md#24-bit-mode-width).

Sources: [`ROM_BEEF.bin`](../sources.md#s25) and the [`SECOND/MISC/...`](../sources.md#s06)
files, decoded by `tools/mode_files.py` ([firmware output](../../data/tables/firmware-modes.txt),
[mode-file output](../../data/tables/mode-files.txt)); [ROM_BEEF.asm:900-930](../sources.md#s27);
[OTI-087 databook](../sources.md#s02) p35.

## Contents

- [Built-in VGA records](#built-in-vga-records)
- [Built-in AppleColor RGB records](#built-in-applecolor-rgb-records)
- [SECOND/MISC/RGB](#secondmiscrgb)
- [SECOND/MISC](#secondmisc)
- [SECOND/MISC/FUNKY.MODES](#secondmiscfunkymodes)
- [SECOND/MISC/VGA](#secondmiscvga)
- [Notes on individual records](#notes-on-individual-records)
- [Built-in mode codes](#built-in-mode-codes)
- [Additional modes](#additional-modes)
- [True-color horizontal timing](#true-color-horizontal-timing)
- [Mode 13 addressing registers](#mode-13-addressing-registers)
- [Firmware renderer selection](#firmware-renderer-selection)
- [Machine-readable outputs](#machine-readable-outputs)

## Built-in VGA records

These records come from the named monitor list in the ROM.

### Clock and output path

| Record | Final clock select (CSEL) | MHz | Output path | Clock bits overridden (ext $06 -> misc output) |
|---|---|---|---|---|
| `$01` | $1 | 28.322 | VGA (port $A8) | no |
| `$03` | $1 | 28.322 | VGA (port $A8) | no |
| `$13` | $0 | 25.175 | VGA (port $A8) | no |
| `$53` | $0 | 25.175 | VGA (port $A8) | no |
| `$61` | $0 | 25.175 | VGA (port $A8) | no |
| `$FA` | $0 | 25.175 | VGA (port $A8) | no |
| `$FB` | $0 | 25.175 | VGA (port $A8) | no |
| `$FC` | $1 | 28.322 | VGA (port $A8) | no |
| `$FD` | $1 | 28.322 | VGA (port $A8) | no |
| `$FE` | $0 | 25.175 | VGA (port $A8) | no |

### Timing counts and rates

| Record | H total (dots) | Hi/true-color factor (ext $21) | H visible (dots) | V total (lines) | V visible (lines) | Scan lines per row | Double scan | Line rate (kHz) | Frame rate (Hz) |
|---|---|---|---|---|---|---|---|---|---|
| `$01` | 450 | x1 | 360 | 449 | 400 | 16 | no | 31.47 | 70.1 |
| `$03` | 900 | x1 | 720 | 449 | 400 | 16 | no | 31.47 | 70.1 |
| `$13` | 800 | x1 | 640 | 449 | 400 | 2 | no | 31.47 | 70.1 |
| `$53` | 800 | x1 | 640 | 525 | 480 | 1 | no | 31.47 | 59.9 |
| `$61` | 808 | x1 | 640 | 449 | 400 | 1 | no | 31.16 | 69.4 |
| `$FA` | 800 | x1 | 640 | 449 | 400 | 1 | yes | 31.47 | 70.1 |
| `$FB` | 400 | x1 | 320 | 449 | 400 | 1 | yes | 31.47 | 70.1 |
| `$FC` | 450 | x1 | 360 | 449 | 384 | 16 | no | 31.47 | 70.1 |
| `$FD` | 900 | x1 | 720 | 449 | 384 | 16 | no | 31.47 | 70.1 |
| `$FE` | 808 | x1 | 640 | 449 | 400 | 1 | yes | 31.16 | 69.4 |

### Register values

| Record | Sequencer 1 | Bt481 Command A | Ext $05 mapping | Ext $20 FIFO | Ext $21 mode | Ext $22 features |
|---|---|---|---|---|---|---|
| `$01` | $08 | $00 | $00 | $01 | $00 | $08 |
| `$03` | $00 | $00 | $00 | $01 | $00 | $08 |
| `$13` | $01 | $00 | $00 | $01 | $04 | $08 |
| `$53` | $01 | $00 | $00 | $05 | $04 | $0C |
| `$61` | $21 | $00 | $00 | $05 | $04 | $08 |
| `$FA` | $21 | $00 | $00 | $05 | $00 | $08 |
| `$FB` | $09 | $00 | $00 | $01 | $00 | $08 |
| `$FC` | $08 | $00 | $00 | $01 | $00 | $08 |
| `$FD` | $00 | $00 | $00 | $01 | $00 | $08 |
| `$FE` | $21 | $00 | $00 | $05 | $04 | $08 |

## Built-in AppleColor RGB records

These records come from the named monitor list in the ROM.

### Clock and output path

| Record | Final clock select (CSEL) | MHz | Output path | Clock bits overridden (ext $06 -> misc output) |
|---|---|---|---|---|
| `$01` | $5 | 36.0 | RGB (port $A9, divided by 2) | no |
| `$03` | $C | 63.0 | RGB (port $A9, divided by 2) | no |
| `$61` | $C | 63.0 | RGB (port $A9, divided by 2) | no |
| `$FA` | $0 | 25.175 | VGA (port $A8) | $01 -> $63 |
| `$FB` | $5 | 36.0 | RGB (port $A9, divided by 2) | no |
| `$FC` | $5 | 36.0 | RGB (port $A9, divided by 2) | no |
| `$FD` | $C | 63.0 | RGB (port $A9, divided by 2) | no |
| `$FE` | $C | 63.0 | RGB (port $A9, divided by 2) | no |

### Timing counts and rates

| Record | H total (dots) | Hi/true-color factor (ext $21) | H visible (dots) | V total (lines) | V visible (lines) | Scan lines per row | Double scan | Line rate (kHz) | Frame rate (Hz) |
|---|---|---|---|---|---|---|---|---|---|
| `$01` | 568 | x1 | 320 | 264 | 200 | 8 | no | 15.85 | 60.0 |
| `$03` | 960 | x1 | 640 | 264 | 200 | 8 | no | 16.41 | 62.1 |
| `$61` | 960 | x1 | 640 | 264 | 200 | 1 | no | 16.41 | 62.1 |
| `$FA` | 808 | x1 | 560 | 222 | 192 | 1 | no | 15.58 | 70.2 |
| `$FB` | 544 | x1 | 320 | 258 | 192 | 1 | no | 16.54 | 64.1 |
| `$FC` | 567 | x1 | 360 | 264 | 192 | 8 | no | 15.87 | 60.1 |
| `$FD` | 960 | x1 | 640 | 264 | 192 | 8 | no | 16.41 | 62.1 |
| `$FE` | 960 | x1 | 640 | 264 | 200 | 1 | no | 16.41 | 62.1 |

### Register values

| Record | Sequencer 1 | Bt481 Command A | Ext $05 mapping | Ext $20 FIFO | Ext $21 mode | Ext $22 features |
|---|---|---|---|---|---|---|
| `$01` | $29 | $00 | $00 | $01 | $00 | $08 |
| `$03` | $29 | $00 | $00 | $01 | $00 | $08 |
| `$61` | $29 | $00 | $00 | $05 | $04 | $08 |
| `$FA` | $29 | $00 | $00 | $05 | $00 | $08 |
| `$FB` | $29 | $00 | $00 | $05 | $00 | $08 |
| `$FC` | $28 | $00 | $00 | $01 | $00 | $08 |
| `$FD` | $29 | $00 | $00 | $01 | $00 | $08 |
| `$FE` | $29 | $00 | $00 | $05 | $04 | $08 |

## SECOND/MISC/RGB

Every filename in this group is relative to [`SECOND/MISC/RGB/`](../sources.md#s06) on `ss.source.082395.po`.

### Clock and output path

| Record | Final clock select (CSEL) | MHz | Output path | Clock bits overridden (ext $06 -> misc output) |
|---|---|---|---|---|
| `M640X400X32K` | $C | 63.0 | VGA (port $A8) | no |
| `M640X200.1575M` | $C | 63.0 | RGB (port $A9, divided by 2) | no |
| `M640X200.18M` | $4 | 28.322 | VGA (port $A8) | $05 -> $63 |
| `M640X200.14M` | $0 | 25.175 | VGA (port $A8) | $01 -> $63 |
| `M640X400.1575M` | $C | 63.0 | RGB (port $A9, divided by 2) | no |
| `M320X200X32K` | $C | 63.0 | RGB (port $A9, divided by 2) | no |
| `M80X25.1575M` | $D | 72.0 | RGB (port $A9, divided by 2) | $0C -> $67 |
| `M80X24.1575M` | $D | 72.0 | RGB (port $A9, divided by 2) | $0C -> $67 |
| `M560X192` | $1 | 28.322 | VGA (port $A8) | no |

### Timing counts and rates

| Record | H total (dots) | Hi/true-color factor (ext $21) | H visible (dots) | V total (lines) | V visible (lines) | Scan lines per row | Double scan | Line rate (kHz) | Frame rate (Hz) |
|---|---|---|---|---|---|---|---|---|---|
| `M640X400X32K` | 960 | x2 | 640 | 264 | 200 | 1 | no | 16.41 | 62.1 |
| `M640X200.1575M` | 960 | x1 | 640 | 264 | 200 | 1 | no | 16.41 | 62.1 |
| `M640X200.18M` | 1064 | x1 | 640 | 222 | 200 | 1 | no | 13.31 | 60.0 |
| `M640X200.14M` | 824 | x1 | 640 | 222 | 200 | 1 | no | 15.28 | 68.8 |
| `M640X400.1575M` | 960 | x1 | 640 | 264 | 200 | 1 | no | 16.41 | 62.1 |
| `M320X200X32K` | 960 | x1 | 640 | 264 | 200 | 1 | no | 16.41 | 62.1 |
| `M80X25.1575M` | 960 | x1 | 640 | 264 | 200 | 8 | no | 18.75 | 71.0 |
| `M80X24.1575M` | 960 | x1 | 640 | 264 | 192 | 8 | no | 18.75 | 71.0 |
| `M560X192` | 856 | x1 | 560 | 222 | 192 | 1 | no | 16.54 | 74.5 |

### Register values

| Record | Sequencer 1 | Bt481 Command A | Ext $05 mapping | Ext $20 FIFO | Ext $21 mode | Ext $22 features |
|---|---|---|---|---|---|---|
| `M640X400X32K` | $29 | $A0 | $00 | $05 | $05 | $08 |
| `M640X200.1575M` | $29 | $00 | $00 | $05 | $04 | $08 |
| `M640X200.18M` | $29 | $00 | $00 | $05 | $04 | $08 |
| `M640X200.14M` | $29 | $00 | $00 | $05 | $04 | $08 |
| `M640X400.1575M` | $29 | $00 | $00 | $05 | $04 | $08 |
| `M320X200X32K` | $29 | $A0 | $00 | $05 | $04 | $08 |
| `M80X25.1575M` | $29 | $00 | $00 | $01 | $00 | $08 |
| `M80X24.1575M` | $29 | $00 | $00 | $01 | $00 | $08 |
| `M560X192` | $29 | $00 | $00 | $05 | $00 | $08 |

## SECOND/MISC

Every filename in this group is relative to [`SECOND/MISC/`](../sources.md#s06) on `ss.source.082395.po`.

### Clock and output path

| Record | Final clock select (CSEL) | MHz | Output path | Clock bits overridden (ext $06 -> misc output) |
|---|---|---|---|---|
| `M80X24.1` | $0 | 25.175 | RGB (port $A9, divided by 2) | $01 -> $63 |
| `M40X25.9M` | $4 | 28.322 | RGB (port $A9, divided by 2) | $05 -> $63 |
| `M40X24.9M` | $4 | 28.322 | RGB (port $A9, divided by 2) | $05 -> $63 |
| `M280X192` | $1 | 28.322 | RGB (port $A9, divided by 2) | no |
| `MLLLL` | $1 | 28.322 | RGB (port $A9, divided by 2) | no |
| `M320X200` | $5 | 36.0 | RGB (port $A9, divided by 2) | no |
| `M40X24` | $5 | 36.0 | RGB (port $A9, divided by 2) | no |
| `M40` | $5 | 36.0 | RGB (port $A9, divided by 2) | no |
| `XX` | $5 | 36.0 | RGB (port $A9, divided by 2) | no |
| `XXX` | $5 | 36.0 | RGB (port $A9, divided by 2) | no |

### Timing counts and rates

| Record | H total (dots) | Hi/true-color factor (ext $21) | H visible (dots) | V total (lines) | V visible (lines) | Scan lines per row | Double scan | Line rate (kHz) | Frame rate (Hz) |
|---|---|---|---|---|---|---|---|---|---|
| `M80X24.1` | 448 | x1 | 320 | 264 | 196 | 8 | no | 14.05 | 53.2 |
| `M40X25.9M` | 568 | x1 | 320 | 264 | 200 | 8 | no | 12.47 | 47.2 |
| `M40X24.9M` | 568 | x1 | 320 | 264 | 192 | 8 | no | 12.47 | 47.2 |
| `M280X192` | 456 | x1 | 280 | 262 | 193 | 1 | no | 15.53 | 59.3 |
| `MLLLL` | 568 | x1 | 320 | 255 | 193 | 1 | no | 12.47 | 48.9 |
| `M320X200` | 544 | x1 | 320 | 258 | 193 | 1 | no | 16.54 | 64.1 |
| `M40X24` | 567 | x1 | 360 | 264 | 192 | 8 | no | 15.87 | 60.1 |
| `M40` | 567 | x1 | 360 | 264 | 192 | 8 | no | 15.87 | 60.1 |
| `XX` | 544 | x1 | 320 | 258 | 193 | 1 | no | 16.54 | 64.1 |
| `XXX` | 558 | x1 | 360 | 258 | 193 | 1 | no | 16.13 | 62.5 |

### Register values

| Record | Sequencer 1 | Bt481 Command A | Ext $05 mapping | Ext $20 FIFO | Ext $21 mode | Ext $22 features |
|---|---|---|---|---|---|---|
| `M80X24.1` | $09 | $00 | $00 | $01 | $00 | $08 |
| `M40X25.9M` | $29 | $00 | $00 | $01 | $00 | $08 |
| `M40X24.9M` | $29 | $00 | $00 | $01 | $00 | $08 |
| `M280X192` | $29 | $00 | $00 | $05 | $00 | $08 |
| `MLLLL` | $29 | $00 | $00 | $05 | $00 | $08 |
| `M320X200` | $29 | $00 | $00 | $05 | $00 | $08 |
| `M40X24` | $28 | $00 | $00 | $01 | $00 | $08 |
| `M40` | $28 | $00 | $00 | $01 | $00 | $08 |
| `XX` | $29 | $00 | $00 | $05 | $00 | $08 |
| `XXX` | $28 | $00 | $00 | $05 | $00 | $08 |

## SECOND/MISC/FUNKY.MODES

Every filename in this group is relative to [`SECOND/MISC/FUNKY.MODES/`](../sources.md#s06) on `ss.source.082395.po`.

### Clock and output path

| Record | Final clock select (CSEL) | MHz | Output path | Clock bits overridden (ext $06 -> misc output) |
|---|---|---|---|---|
| `M108X25.20M` | $5 | 36.0 | VGA (port $A8) | $06 -> $67 |
| `M120X25.22M` | $1 | 28.322 | VGA (port $A8) | $03 -> $67 |
| `M132X25.25M` | $1 | 28.322 | VGA (port $A8) | $00 -> $67 |
| `M96X25.18M` | $5 | 36.0 | VGA (port $A8) | no |
| `M80X25.18M` | $5 | 36.0 | VGA (port $A8) | no |

### Timing counts and rates

| Record | H total (dots) | Hi/true-color factor (ext $21) | H visible (dots) | V total (lines) | V visible (lines) | Scan lines per row | Double scan | Line rate (kHz) | Frame rate (Hz) |
|---|---|---|---|---|---|---|---|---|---|
| `M108X25.20M` | 1176 | x1 | 872 | 222 | 200 | 8 | no | 15.31 | 68.9 |
| `M120X25.22M` | 1320 | x1 | 960 | 222 | 200 | 8 | no | 10.73 | 48.3 |
| `M132X25.25M` | 1456 | x1 | 1056 | 222 | 200 | 8 | no | 19.45 | 87.6 |
| `M96X25.18M` | 1064 | x1 | 776 | 222 | 200 | 8 | no | 16.92 | 76.2 |
| `M80X25.18M` | 1064 | x1 | 640 | 222 | 200 | 8 | no | 16.92 | 76.2 |

### Register values

| Record | Sequencer 1 | Bt481 Command A | Ext $05 mapping | Ext $20 FIFO | Ext $21 mode | Ext $22 features |
|---|---|---|---|---|---|---|
| `M108X25.20M` | $29 | $00 | $00 | $01 | $00 | $08 |
| `M120X25.22M` | $29 | $00 | $00 | $01 | $00 | $08 |
| `M132X25.25M` | $01 | $00 | $00 | $01 | $00 | $08 |
| `M96X25.18M` | $29 | $00 | $00 | $01 | $00 | $08 |
| `M80X25.18M` | $29 | $00 | $00 | $01 | $00 | $08 |

## SECOND/MISC/VGA

Every filename in this group is relative to [`SECOND/MISC/VGA/`](../sources.md#s06) on `ss.source.082395.po`.

### Clock and output path

| Record | Final clock select (CSEL) | MHz | Output path | Clock bits overridden (ext $06 -> misc output) |
|---|---|---|---|---|
| `M640X48032K.50M` | $F | 50.0 | VGA (port $A8) | no |
| `M40X24.VGA` | $1 | 28.322 | VGA (port $A8) | no |
| `M560X192.VGA` | $0 | 25.175 | VGA (port $A8) | no |
| `M640X48016M` | $A | 78.0 | VGA (port $A8) | no |
| `M640X40032K.50M` | $F | 50.0 | VGA (port $A8) | no |
| `M320X40032K` | $C | 63.0 | RGB (port $A9, divided by 2) | no |
| `M1280X480.50M` | $F | 50.0 | VGA (port $A8) | no |
| `M800X600.36M` | $7 | 36.0 | VGA (port $A8) | no |

### Timing counts and rates

| Record | H total (dots) | Hi/true-color factor (ext $21) | H visible (dots) | V total (lines) | V visible (lines) | Scan lines per row | Double scan | Line rate (kHz) | Frame rate (Hz) |
|---|---|---|---|---|---|---|---|---|---|
| `M640X48032K.50M` | 1600 | x1 | 1280 | 525 | 480 | 1 | no | 31.25 | 59.5 |
| `M40X24.VGA` | 450 | x1 | 360 | 449 | 384 | 16 | no | 31.47 | 70.1 |
| `M560X192.VGA` | 800 | x1 | 560 | 449 | 384 | 1 | yes | 31.47 | 70.1 |
| `M640X48016M` | 824 | x3 | 632 | 525 | 480 | 1 | no | 31.55 | 60.1 |
| `M640X40032K.50M` | 1600 | x1 | 1280 | 449 | 400 | 1 | no | 31.25 | 69.6 |
| `M320X40032K` | 960 | x1 | 640 | 264 | 200 | 1 | no | 16.41 | 62.1 |
| `M1280X480.50M` | 1600 | x1 | 1280 | 525 | 480 | 1 | no | 31.25 | 59.5 |
| `M800X600.36M` | 1024 | x1 | 800 | 625 | 600 | 1 | no | 35.16 | 56.2 |

### Register values

| Record | Sequencer 1 | Bt481 Command A | Ext $05 mapping | Ext $20 FIFO | Ext $21 mode | Ext $22 features |
|---|---|---|---|---|---|---|
| `M640X48032K.50M` | $01 | $A0 | $00 | $05 | $04 | $0C |
| `M40X24.VGA` | $08 | $00 | $00 | $01 | $00 | $08 |
| `M560X192.VGA` | $21 | $00 | $00 | $05 | $00 | $08 |
| `M640X48016M` | $01 | $00 | $00 | $05 | $06 | $0C |
| `M640X40032K.50M` | $01 | $A0 | $00 | $05 | $04 | $0C |
| `M320X40032K` | $29 | $A0 | $00 | $05 | $04 | $08 |
| `M1280X480.50M` | $01 | $00 | $00 | $05 | $04 | $0C |
| `M800X600.36M` | $01 | $00 | $00 | $05 | $04 | $0C |

## Notes on individual records

### Records and transfer sizes

A decoded mode record is 81 bytes. Some mode files contain a 111-byte
`vga_mode_rec`, consisting of the same 81 bytes and 30 unused bytes; older files can be
bare 81-byte records. SetUserMode transfers 84 bytes and uses the first 81.
Sources: `tools/mode_files.py`:3-19; [ROM_BEEF.asm:1483-1493](../sources.md#s27).

Four 939-byte files, [`SECOND/MISC/M40`](../sources.md#s06), `XX`, `XXX` and `VGA/M800X600.36M`, hold the 81
bytes as assembler source: `db` lines of hexadecimal values with comments. `M40` and
`XX` are the same records as `M40X24` and `M320X200`; `XXX` is a 360-pixel variant of
`M320X200`.

### RGB list does not force the RGB clock path

Built-in RGB `$FA` selects the VGA path and its ext06 `$01` is overridden by misc `$63`.
Its final 25.175 MHz clock, sequencer division, and timing counts give 15.58 kHz lines ([Video: built-in modes](../06-video.md#built-in-modes)).

The same holds for files in [`SECOND/MISC/RGB/`](../sources.md#s06): the feature byte
chooses the path, not the directory or the file name.

### Names and clock overrides

The 1.4 firmware writes misc output after extended register 6. So a file with an
override runs at the clock after the override, whatever frequency its name says.

### True-color file

[`SECOND/MISC/VGA/M640X48016M`](../sources.md#s06) uses x3 timing at 78 MHz but sets Bt481 Command Register A
to `$00`, leaving palette mode selected. It cannot show 24-bit color as written. The
settings that fix it: [24-bit mode width](../14-custom-code.md#24-bit-mode-width).

## Built-in mode codes

| Code | VGA monitor (31.5 kHz) | AppleColor RGB (15.6-16.5 kHz) | Used by |
|---|---|---|---|
| $01 | 40 x 25 text, 9-dot | 40 x 25 text | |
| $03 | 80 x 25 text, 9-dot | 80 x 25 text | |
| $13 | 320 x 200 x 256 | (none) | |
| $53 | 640 x 480 x 256 | (none) | |
| $61 | 640 x 400 x 256 | 640 x 200 x 256 | |
| $FA | 560 x 192 x 16, double-scanned | 560 x 192 | double hires |
| $FB | 280 x 192 x 16, double-scanned | 280 x 192 | hires |
| $FC | 40 x 24 text | 40 x 24 text | 40-column text |
| $FD | 80 x 24 text | 80 x 24 text | 80-column text |
| $FE | 640 x 200, double-scanned to 400 lines | 640 x 200 | lores and Super Hi-Res |

$FF is the SetUserMode record. The library also names $54 (800x600), $56 (1024x768),
$4F (132x60) and $51 (132x43). These are absent from ROM 1.4 tables; programs supply
them with SetUserMode and mode files. Source: [VGA.H](../sources.md#s30).

## Additional modes

| Mode | Memory needed | How | Status |
|---|---|---|---|
| 640 x 480, 24-bit (16.7 million colors) | 921,600 bytes | `M640X48016M` timing at 78 MHz, ext $21 = $06; Bt481 CR A = $F0 and CRTC $01 = $4F | Needs the [24-bit mode width](../14-custom-code.md#24-bit-mode-width) settings |
| 640 x 480, 16-bit (5:6:5, 65,536 colors) | 614,400 bytes | Same timing as the 32K mode files, Command Register A = $E0 | No library mode file |
| 640 x 480, 15-bit (32,768 colors) | 614,400 bytes | The library's 32K mode files | Library mode files |
| 800 x 600, 256 colors | 480,000 bytes | VCLK 36, 40 or 50 MHz (OTI-068 codes 5/7, 6/E, F) | `VGA/M800X600.36M`: code 7 (36 MHz), ext $21 = $04, 35.16 kHz, 56.2 Hz. |
| 1024 x 768, 256 colors | 786,432 bytes | VCLK 65 MHz (codes 2, B) | The FAQ lists it; no mode file decodes. |

## True-color horizontal timing

| Mode record | CRTC $00-$05 values (hexadecimal) |
|---|---|
| Standard VGA 640 x 480 | 5F 4F 50 82 54 80 |
| `M640X48016M` | 62 4E 50 85 54 80 |

## Mode 13 addressing registers

Sources: [Oak VGA87 BIOS TEv1.02](../sources.md#s58), standard table at BIOS offset $1172,
packed tables at $1472 and $1B72, extended-register entries at $2C4A and later (byte 6 =
ext $21); [Paradise TBv1.01B](../sources.md#s57).

| Mode table | CRTC $14 / $17 | Attribute mode | Ext $21 |
|---|---|---|---|
| [Oak BIOS](../sources.md#s58), mode 13h | $40 / $A3 (doubleword, word mode) | $41 | $00 (standard VGA) |
| [Oak BIOS](../sources.md#s58), packed 640 x 480 and 640 x 400 x 256 | $00 / $C3 (byte mode) | $01 | $04 (packed) |
| ROM 1.4 modes $53, $61, $FE (640 wide) | $00 / $C3 | $01 | $04, the same as Oak's packed modes |
| ROM 1.4 mode $13 | $40 / $A3 | $41 | $04 |

## Firmware renderer selection

| Condition | Setup / render | VGA mode |
|---|---|---|
| Emulation off (SetMode with flag 1) | Set the host's mode; render nothing | host's choice |
| NEWVIDEO bit 7 set (Super Hi-Res) | `set_videomode_superhires` / `emulate_superhires` | $FE |
| TEXT on, 80VID on | text80 | $FD |
| TEXT on, 80VID off | text40 | $FC |
| HIRES on, AN3 double-width and 80VID on | double hires | $FA |
| HIRES on, otherwise | hires | $FB |
| HIRES off | lores (the code says "Double Lores support is missing") | $FE |

## Machine-readable outputs

The [firmware-mode output](../../data/tables/firmware-modes.txt) and
[mode-file output](../../data/tables/mode-files.txt) are generated by
[`tools/mode_files.py`](../../tools/mode_files.py).

---

[Reference tables](README.md) | [Video chapter](../06-video.md)
