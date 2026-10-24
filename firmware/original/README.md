# Firmware files from ss.source.082395.po

Firmware files copied from the disk image
[`ss.source.082395.po`](../../docs/sources.md#s06), folders `SECOND/FIRM` and `SECOND/MISC`.
They are the disk's text files unchanged, except that the line ends are LF instead of CR.
The disk does not hold the firmware program itself, which comes from the disassembly
[`ROM_BEEF.asm`](../../docs/sources.md#s27).

| File | Disk folder | What it is | Used in |
|---|---|---|---|
| `MODES.S` | `SECOND/MISC` | The mode records, "(From the Second Sight firmware)". 14 of ROM 1.4's 18 records match it byte for byte; `gs_regs_FC` differs in 7 bytes, and `vga_regs_FA`, `gs_regs_FA` and `gs_regs_FB` are missing. | [`src/modes.asm`](../src/modes.asm) |
| `MKTAB.C` | `SECOND/FIRM` | Prints the 14 double hires repack tables `T_A1`-`T_B7`. Its output is ROM 1.4's $D000-$DDFF byte for byte. | [`src/dhrtables.asm`](../src/dhrtables.asm) |
| `MKCTAB.C` | `SECOND/FIRM` | Prints the double hires color table; its comment names the 16 colors. Its output is ROM 1.4's $DE00-$E1FF byte for byte. | [`src/dhrtables.asm`](../src/dhrtables.asm) |
| `FONT.TAB` | `SECOND/FIRM` | The 30 language glyphs, 8x16, drawn with `o` and `.`. ROM 1.4's $8694-$8874 byte for byte; one glyph has 17 rows. | [`src/fonts.asm`](../src/fonts.asm) |
| `FONT8.TAB` | `SECOND/FIRM` | The same glyphs, 8x8. ROM 1.4's $8C85-$8D74 byte for byte. | [`src/fonts.asm`](../src/fonts.asm) |
| `CFONT.C` | `SECOND/FIRM` | The font compiler: turns a `.TAB` file into `db` lines, one per glyph. | |
| `INTL.FONT` | `SECOND/FIRM` | A draft of the language table and glyphs. ROM 1.4's table differs from it for German `#` and Swedish `]` and `}`. | [`src/text.asm`](../src/text.asm) |
| `HIRES.ALGO`, `HIRES.ALGO2`, `DHIRES.ALGO` | `SECOND/FIRM` | Notes on repacking 7-dot Apple bytes into 8-dot VGA bytes, with the table formulas and the inner loop the double hires renderer uses. | [`src/dhires.asm`](../src/dhires.asm) |
| `RC.TXT` | `SECOND/FIRM` | A draft of RunCode, with the names `_command_area` and `_jmpto` and the `z180_out` macro for OUT0. | [`src/events.asm`](../src/events.asm) |

The same disk holds the ZMAC assembler (`SECOND/ZMAC`), the IIgs library (`SECOND/LIB`,
whose low-level routines are [VGALOW.ASM](../../docs/sources.md#s29)) and register and mode-file tools
(`SECOND/MISC`).
