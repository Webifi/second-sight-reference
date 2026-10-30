# 08 Firmware: EPROM rev. 1.4-BEEF

[Reference index](../README.md) | [Glossary](glossary.md) | [Reference tables](reference/README.md)

The Z180 firmware is one 27C1000 EPROM labeled "Sequential Systems copyright (c) 1995
rev. 1.4-BEEF". The dump [`ROM_BEEF.bin`](sources.md#s25) sums to $BEEF and GetStatus reports version $14.

Line references are to the annotated disassembly [`ROM_BEEF.asm`](sources.md#s27). Its
comments are its author's reading of the code, not Sequential's source.

## Contents

- [ROM layout and runtime SRAM](#rom-layout-and-runtime-sram)
- [Main loop](#main-loop)
- [The event handler (INT1)](#the-event-handler-int1)
- [Renderers](#renderers)
  - [Text](#text-40-and-80-columns), [lores](#lores-and-mixed-mode) and [hires](#hires)
  - [Double hires](#double-hires) and [Super Hi-Res](#super-hi-res)
  - [Redraw speed](#redraw-speed)
- [Known defects and oddities](#known-defects-and-oddities): [double hires](#double-hires-setup-defect), [SHR band pointer](#super-hi-res-band-pointer), [mixed text colors](#mixed-mode-text-colors), [border color](#border-color), [mode $13](#mode-13-packed-pixel-note)
- [Changing and building the firmware](#changing-and-building-the-firmware)
- [Other ROM revisions](#other-rom-revisions)

## ROM layout and runtime SRAM

The EPROM's low 64 KB holds the code and data; its high 64 KB is zero. The boot code
copies selected ranges into SRAM bank 0 and runs from there ([Boot](05-z180.md#boot)).
Where each routine and table sits:
[ROM layout](reference/z180-memory-map.md#rom-14-routine-and-data-locations). Sources:
[ROM_BEEF.bin](sources.md#s25); [ROM_BEEF.asm:100-204](sources.md#s27).

## Main loop

```
main ($1E01):
  if "mode change pending":
      pick the setup and render routines for the current Apple mode
      clear the flag; run the setup routine (sets the VGA mode, palette, fonts)
  else if a SetMode command is waiting for its completion byte:
      write $A5 to port $A0
  jump to the render routine; it draws, then jumps back to main
```

`get_emulation_routine` ([`ROM_BEEF.asm:3150-3220`](sources.md#s27)) chooses a renderer
in the [selection order](reference/video-modes.md#firmware-renderer-selection).

Mixed mode (four text lines at the bottom) is handled inside the lores and hires renderers.

Each render routine draws the whole screen several times (text40 and hires: 8 passes)
before returning to the main loop. That is how often a mode change is noticed. The Super
Hi-Res renderer instead loops until a mode change is pending.

## The event handler (INT1)

```
handle_event:
  hi = port $A7 & $0F;  lo = port $A6 & $0F          address bits 7-4, 3-0
  if hi = $B:                                         $C0Bx
      if lo != 0: read port $A0 (acknowledge), return   ($C0B1-$C0B7 outside a command)
      command = port $A0                              $C0B0: a command byte
      if command >= $0F: return
      pull the command's parameter bytes with DMA channel 1 (see 09)
      run the command, still inside the interrupt
  else:
      jump through the handler table entry for (hi << 4 | lo), with A = port $A0
  ei; return
```

The handlers at [`ROM_BEEF.asm:2879-3085`](sources.md#s27) update one flag each and request a mode
change when needed ([ROM softswitch handlers](reference/z180-io-ports.md#rom-softswitch-handlers)).
Some of them never run, because U7 raises no event for their address
([Apple event addresses](reference/z180-io-ports.md#apple-event-addresses)).

Every other address goes to a default handler that only acknowledges. Several handlers
also write a trace character to the Z180 serial port (port 6).

## Renderers

All renderers read the Apple screen copy from SRAM (bank 0 = main, bank 1 = aux) and write
the VGA memory through the standard $A0000 window, using the Oak's write modes, color
expansion and 64-bit latch where it helps.

### Text: 40 and 80 columns

Characters use built-in fonts: 8x16 for VGA and 8x8 for AppleColor RGB. These include
MouseText and the international sets selected by $C02B (`remap_charset_for_language`).
Colors come from $C022.

Flashing characters use palette entries 2 and 3. Every sixth pass, the firmware swaps
their foreground and background colors during vertical retrace
(`setup_textmode_palette`, [`ROM_BEEF.asm:7998-8056`](sources.md#s27)). The pair it swaps
never comes from $C022, and 80 columns undo the swap at once:
[E26](reference/errata.md#e26-flashing-text-ignores-the-c022-colors). In the 8x16 font
four language characters sit one row low:
[E27](reference/errata.md#e27-four-language-characters-sit-one-row-low-in-the-8x16-font).

### Lores and mixed mode

Lores uses 4-bit colors from a 16-entry palette. In mixed mode, the bottom four rows use
the text code.

### Hires

The 280 x 192 display uses a six-color palette: black, white, violet, green, orange,
and blue ([`ROM_BEEF.asm:4701-4716`](sources.md#s27)). Lookup tables supply each line.

### Double hires

The 560 x 192 display combines main and auxiliary memory. The firmware picks it when
HIRES, double width (AN3 off, $C05E) and 80-column video are all on, and NEWVIDEO
($C029) bit 5 chooses monochrome (1) or color (0)
([`ROM_BEEF.asm:3186-3198, 7306-7311`](sources.md#s27)).

In ROM 1.4 this mode does not work: its setup routine hangs the card
([Double hires setup defect](#double-hires-setup-defect)).

#### How a row is drawn

Lookup tables (`dhr_table_*`) repack each row's seven-dot Apple
bytes, auxiliary and main in turn, into eight-dot bytes; the leftmost dot becomes bit 7,
the VGA's leftmost pixel. In monochrome each eight-dot byte is written to all four VGA
planes, so a lit dot is color 15 (white) and an unlit dot color 0.

In color the eight-dot byte X selects one of 256 entries of `colour_dhr_lookup_table`,
which the setup copies into VGA memory as one 256-byte page per plane in segment 1. The
renderer reads VGA address X, which loads entry X's four plane bytes into the VGA latches,
then writes the screen in write mode 1, which stores the latches: eight 16-color pixels
per byte ([`ROM_BEEF.asm:7169-7190, 7437-7540, 7596-7640, 11397`](sources.md#s27)).

In the firmware source the color path is `colour_dhires_line` and the monochrome path
`mono_dhires_line` ([`src/dhires.asm`](../firmware/v1.4/src/dhires.asm)); the s27
disassembly has the two labels the other way round (`dhires_scan_mono` is its color path).

#### The color rule, and how it differs from the IIgs

The table works on groups of eight dots counted from the left edge of the line, each group
two 4-dot cells. A cell's color number is its four dots read left to right as 8, 4, 2 and
1, Apple's numbering ([IIgs Hardware Reference](sources.md#s78) Table 4-16, p88). For all
256 entries:

1. When both cells of a group hold the same pattern, all eight dots show that color.
2. Otherwise each lit dot shows its own cell's color, and each unlit dot is black.
3. A run of lit dots that joins a fully lit cell shows white.

```text
dots        0001 0001   0001 0000   0000 1011   0001 1111
card shows  1111 1111   ...1 ....   .... B.BB   ...F FFFF    (. = black)
```

The IIgs instead colors every dot from the four dots around it, a window that moves one
dot at a time, so its colors cover unlit dots and blend across cell and group edges
(Hardware Reference p88). The two agree inside areas filled with one repeating pattern;
at color edges, on lone cells and in fine detail the card shows black dots where the
IIgs shows color.

**The 16 colors** are the card's own 8-bit DAC values (`double_hires_palette`,
[`ROM_BEEF.asm:6622-6631, 6733-6735`](sources.md#s27)), not the IIgs's. Only black,
yellow and white equal Apple's master color values ([IIgs Technical Note #63](sources.md#s98)):

| Number | Apple's name | Card (R, G, B) | IIgs master color |
|---|---|---|---|
| 0 | Black | 0, 0, 0 | $000 |
| 1 | Deep red | 255, 0, 0 | $D03 |
| 2 | Brown | 128, 64, 16 | $850 |
| 3 | Orange | 255, 132, 0 | $F60 |
| 4 | Dark green | 0, 128, 0 | $072 |
| 5 | Dark gray | 64, 64, 64 | $555 |
| 6 | Green | 0, 255, 0 | $1D0 |
| 7 | Yellow | 255, 255, 0 | $FF0 |
| 8 | Dark blue | 0, 0, 192 | $009 |
| 9 | Purple | 255, 0, 255 | $D2D |
| 10 | Light gray | 192, 192, 192 | $AAA |
| 11 | Pink | 255, 128, 128 | $F98 |
| 12 | Medium blue | 0, 0, 255 | $22F |
| 13 | Light blue | 0, 255, 255 | $6AF |
| 14 | Aquamarine | 0, 255, 128 | $4F9 |
| 15 | White | 255, 255, 255 | $FFF |

A master color is 4 bits per component: $D03 is red 13, green 0, blue 3 of 15.

### Super Hi-Res

The VGA runs at 640 x 200, double-scanned. The 16 Apple palettes at $E1/9E00 become the
256-entry VGA palette: palette n, color c maps to entry n x 16 + c. Each 4-bit component
is multiplied by $11 for the 8-bit DAC.

The renderer reads band flags at ports $A4/$A5 and redraws only changed 4 KB bands
([`ROM_BEEF.asm:9036-9160`](sources.md#s27)); it skips unchanged bands. The $9000 band's
flag also sets on writes to the control bytes and palettes at $9D00-$9FFF, so a program
that only changes palettes still has lines 179-199 redrawn on every pass
([band flags](04-capture-logic.md#band-flags-ports-a4-a5)).

Each pass also compares 128 of the 256 palette colors with the copy it last sent to the
DAC and sends any color that changed (`check_palettes`, `sub_AC39` in s27, lines
9273-9349, called twice per pass), so every color is checked once in two passes. The
scan-line control bytes are compared the same way (`check_lower_scbs`, `sub_ACBD`
in s27, lines 9355-9460).

Of each scan-line control byte the renderer uses bit 7 (640 mode) and bits 3-0 (palette)
only (`select_line_tables`, `sub_AA08` in s27, lines 8925-8950). Two IIgs features therefore do not show on the card:
color fill mode, bit 5 ([E11](reference/errata.md#e11-super-hi-res-color-fill-mode-is-ignored)), and palettes rewritten
during each frame, because the card's display does not follow the IIgs beam
([E12](reference/errata.md#e12-palettes-rewritten-during-each-frame-show-wrong-colors)).

#### Redraw speed

Each source byte runs `LD A,(BC)` / `LD H,n` / `LD L,A` / `ADD HL,HL` /
`ADD HL,HL` / `LDD`: 42 clocks, plus the waits of the two VGA accesses `LDD` makes through
the latch (the pixel loops at $A15C and $A5B2). Drawing runs with ext $22 = $38, read cache
off and write cache on, so each `LDD` makes a read the Oak must fetch from its DRAM and a
cached write: 5 and 3 waits with the reference's
[fixed counts](05-z180.md#a-functional-timing-estimate). SRAM adds none. One 4 KB band
then takes about 228,000 Z180 clocks (12.7 ms at 18 MHz), and the whole screen (seven 4 KB
bands and the 3,328-byte $9000 band, 32,000 bytes) about 1.79 million clocks (99 ms).
Display fetch, refresh and interrupt service only add
([wait states](05-z180.md#wait-states)).

So the card redraws the whole Super Hi-Res screen at most about 10 times a second, and at
most one changed band fits in one IIgs frame (1/60 s, 300,000 clocks). Source: [Zilog
UM0050](sources.md#s39) instruction states.

The time goes into the conversion, not into memory speed. Each source byte becomes four
VGA bytes: the 640 x 200 screen of 8-bit pixels is 128,000 bytes, against the IIgs's
32,000. Of each byte's 42 clocks, the 8-bit Z180 spends 24 finding the byte's table
entry before `LDD` makes the two VGA accesses. The IIgs's own video hardware does that
conversion without using its processor.

The [manual](sources.md#s16) (June 1995, p28) says the card "can only do 15 full-screen
updates per second". ROM 1.4's loop cannot reach that even at 20 MHz: the same clock count
takes at least 89 ms per screen there, about 11 a second, and the waits only grow in clocks
at the faster clock. So the manual's figure does not describe this ROM's renderer. A
renderer that takes about 75 ms a screen is in
[E13](reference/errata.md#e13-fast-animation-is-choppy).

## Known defects and oddities

Workarounds from the IIgs side: [Errata](reference/errata.md).

In `upload_chunk` ([`ROM_BEEF.asm:1807-1840`](sources.md#s27), ROM $1342) the flag-0 ("Z180 memory")
path jumps to the add-8 step while the A register still holds the flag (0), so every
flag-0 upload goes to bank $08, the first 64 KB of the VGA window, whatever bank was
asked for; only the low 16 bits of the destination are used. Flag 1 with bank $10-$13
reaches SRAM: [Loading Z180 code](09-host-protocol.md#loading-z180-code).

Two more oddities: the boot picture routine at $0208, which nothing calls
([fixed EPROM mapping](reference/z180-memory-map.md#fixed-eprom-mapping)), and the
reason U4 decodes AX only for $A0-$A7: a write to port $A9 would otherwise clear MODE_D3
([the Z180's view of U7](04-capture-logic.md#the-z180s-view-of-u7-ports-a0-a7)).

### Double hires setup defect

ROM 1.4's double hires cannot work: its code and its lookup tables need the same
addresses. Owners saw it at once: a December 1995 report says that with the new
"v1.4-BEEF" chips "the Double Hi-Res display causes a freeze". Source: [GenieLamp report](sources.md#s70).

**The memory layout it sets.** Both `set_videomode_double_hires` (ROM $8D7E) and
`emulate_double_hires` (ROM $8E14) set CBAR = $C9, BBR = $08, CBR = $94:

| Logical | Physical | Holds |
|---|---|---|
| $0000-$8FFF | $00000-$08FFF (bank 0, no translation) | Firmware code; main double-hires data at $2000-$3FFF |
| $9000-$9DFF | $11000-$11DFF (bank 1) | The renderer's 14 lookup tables, A1-A7 and B1-B7, one 256-byte page each |
| $A000-$BFFF | $12000-$13FFF (bank 1) | Auxiliary double-hires data |
| $C000-$FFFF | $A0000-$A3FFF | Video memory |

**Where the code actually is.** The firmware's code from $9000 up sits in bank 0, so
under this layout every instruction at logical $9000 or above is fetched from the tables
in bank 1 instead:

| Routine | ROM address | Effect |
|---|---|---|
| `mono_dhires_line` (monochrome rows) | $8FCD-$902B | Called from $8F93; runs correctly to $8FFF, then executes table A1 as code |
| `colour_dhires_line` (color rows) | $902C-$90A8 | Called from $8FB2; runs entirely from table A1 |
| `copy_double_hires_a_b_lookup_tables` | $90A9 | Called from $8DB5 during setup; never runs, so the tables stay empty |
| `copy_double_hires_colour_lookup_tables` | $90E8 | Called from $8DE2 during setup; never runs |

Table A1 occupies logical $9000-$90FF, the same addresses as the scan routines, so no
choice of bytes can serve both. The firmware therefore hangs or draws garbage as
soon as double hires is selected. Nothing in the hardware hides the fault: SRAM A16 is
wired to HA16, so $11000 is a different SRAM cell from $09000, and the Z180 MMU applies
a new mapping from the next memory cycle. Source: [netlist](../data/netlist/README.md) U11 and U15.

The disassembly says the same: "This code is buggy and hangs the card" (disassembler
comment, line 7090).

Sequential's [v1.1 notes](sources.md#s06) announce double-hires support in color and monochrome, yet the
shipped v1.1 EPROM (rev 1.4-BEEF) freezes in double hires:
[Other ROM revisions](#other-rom-revisions).

### Super Hi-Res band pointer

Each 4 KB band loads IX with a pointer into the **scan-line control byte (SCB)** table
at $9D00. In [`ROM_BEEF.asm:9092`](sources.md#s27) (ROM $AB11), the $6000-$6FFF band loads $9D7F; the
pattern of the other seven bands gives $9D7E. Lines 102-127 therefore take the SCB of the
line below, with its palette and its 320/640 setting. This is visible only where
neighboring lines differ in either.

The ROM bytes at $AB11 are `DD 21 7F 9D`. The eight IX values in lines 9050-9156 are
$9DC6, $9DB2, $9D98, $9D7F, $9D65, $9D4B, $9D32 and $9D18.

### Mixed-mode text colors

Text cells use fixed DAC entries (`get_text_colour`, line 5827): normal 1 on 0,
inverse 0 on 1, flashing 3 on 2.

`set_textmode_palette` (line 6512) loads entries 0 and 1 from $C022 for text and
lores. Unused screen lines show entry 0, the $C022 background. Hires instead calls
`setup_hires_palette` (line 4723), which loads black and white. Its mixed text therefore
ignores $C022, and unused lines are black.

A IIgs shows all text, the text lines of mixed modes included, in the $C022 colors, so
the card's mixed-hires text differs from the IIgs: [E6](reference/errata.md#e6-mixed-hires-text-ignores-the-c022-colors).
Source: [Apple IIgs Hardware Reference](sources.md#s78), Screen Color register.

### Border color

The card never shows the IIgs border color on its own:

- The IIgs sets its border with the low nibble of $C034. That address is not one of the
  card's [event addresses](reference/z180-io-ports.md#apple-event-addresses), and the
  capture logic copies only screen memory, so the card never learns the value
  ([E15](reference/errata.md#e15-the-iigs-border-color-does-not-show)). Firmware alone
  cannot change this. With [Lattice v2.0](lattice-versions.md), a $C034 write is an event:
  U7 latches the byte the IIgs writes into U2 and interrupts the Z180, as for $C022, and
  [firmware 2.0](firmware-versions.md) reads it from port $A0 and shows the color.
- The card's border is the VGA overscan color: attribute controller register $11, which
  names one palette entry. Every mode record sets it: entry $10 in the text modes, except
  the AppleColor RGB 40-column records for modes $01 and $FC, which use entry 0; entry 0 in
  every graphics mode, so in Super Hi-Res the border takes color 0 of palette 0. Source:
  [`ROM_BEEF.bin`](sources.md#s25) mode records, attribute $11 byte at offset $39 of each
  ([Video mode records](reference/video-modes.md)).
- SetBorder ($08) writes register $11 with the palette index it is given
  (`set_border`, [ROM_BEEF.asm:2196-2208](sources.md#s27)). The next mode change, including
  every switch of Apple display mode, rewrites register $11 from the mode record, so a
  program that wants the IIgs border on the card sends SetBorder again after each change,
  with an index whose palette color matches. A 1998 list of card-aware software names a
  CDA that does this ([GEnie message](sources.md#s74)).
- On VGA the overscan is a narrow band around the picture, far smaller than the IIgs
  border.

### Mode $13 packed-pixel note

The `vga_regs_13` record (mode $13; `vga_320x200x256` in s27, line 10282) is IBM's
standard mode 13h register set plus Oak ext $21 = $04 (packed pixel), a mix no Oak source
or other driver uses ([mode $13 addressing registers](reference/video-modes.md#mode-13-addressing-registers)).
Sources: Oak's [VGA87 BIOS TEv1.02](sources.md#s58), standard table at BIOS offset $1172,
packed tables at $1472 and $1B72, extended-register entries at $2C4A and later (byte 6 =
ext $21); [Paradise TBv1.01B](sources.md#s57) BIOS matches.

- The [OTI-087 databook](sources.md#s02) (printed p41) defines ext $21 bits 3-2 = 01 as packed pixel, and
  Oak's TEv1.02 BIOS packed modes use offset $28 for 640 pixels: 16 bytes per
  offset unit in byte mode, as ROM 1.4's 640-wide modes do on this card's OTI-087X.
  Sources: [Oak BIOS](sources.md#s58); [Video mode records](reference/video-modes.md).
- [GView 0.25c's README](sources.md#s04) (February 1996), under "Known Errors", reports that 320x200x256
  "does not work" on the card, so 8-bit pictures need 640 x 480 or 640 x 400. The ROM
  version is not named.
- The disassembly marks the ext $21 value "should be 00", which matches Oak's own mode 13h.
- On the AppleColor RGB monitor, ROM 1.4 refuses mode $13: its RGB table holds only $01,
  $03, $61 and $FA-$FE ([`ROM_BEEF.asm:862`](sources.md#s27) onward, `set_video_mode` lines 900-933).

So mode $13 gives a wrong picture. Oak's packed modes address memory a
byte at a time, so packed mode ignores the doubleword and word shifts: the line pitch
becomes 640 bytes, and the card shows every other line of the 320-byte picture in the
top half of the screen. Source: Oak's packed-mode tables.

## Changing and building the firmware

ROM 1.4 is the last firmware Sequential shipped, and no source code for it survives. This
repository holds it as assembly source that builds the dump byte for byte, and two changed
versions of that source that fix the [errata](reference/errata.md) firmware can fix:
firmware 1.5 for a card with the original Lattice chip, and 2.0 for a card with Lattice v2.0. Every fix
is a change to the source, and the firmware is built from it. Each version's fixes and
ready-built image: [Firmware versions](firmware-versions.md).

| Source | Builds |
|---|---|
| [`firmware/v1.4/ROM_BEEF.asm`](../firmware/v1.4/ROM_BEEF.asm) and [`firmware/v1.4/src`](../firmware/v1.4/src) | ROM 1.4, byte for byte (SHA-256 `bd29e30e...4d61`); each known fault is marked `BUG (En)` |
| [`firmware/v1.5`](../firmware/v1.5/SecondSight_v1_5.asm) | Firmware 1.5: the errata fixes firmware alone can make, each marked `CHANGE (En)` |
| [`firmware/v2.0`](../firmware/v2.0/SecondSight_v2_0.asm) | Firmware 2.0: the same plus E15, the IIgs border color, which needs [Lattice v2.0](lattice-versions.md) |

The two changed sources differ only in E15 and the version byte; a fix other than E15 goes
into both.

### Building

`tools/build_rom.py` assembles a source with the ASxxxx assembler (`asz80`,
whose `.hd64` mode adds the Z180 instructions `IN0`, `OUT0` and `MLT`, then `aslink`) into
the 128 KB EPROM image and lists every byte range that differs from ROM 1.4.
`python tools/build_rom.py --check` builds all three sources, checks their SHA-256, and
checks that the ready-built images equal fresh builds. Installing the assembler, the
source layout and the free space: [firmware/README.md](../firmware/README.md).

The program is the disassembly [`ROM_BEEF.asm`](sources.md#s27) with names, comments and
plain data rows; the mode records, the double hires tables and the language glyphs come
from files on the disk image [`ss.source.082395.po`](sources.md#s06). The header of the
source's `ROM_BEEF.asm` lists every change from the disassembly, none of which alters a
byte. ZMAC on that disk is a plain Z80 assembler and lacks the Z180 instructions. Source:
ASxxxx Z80/Z180 assembler, <https://shop-pdp.net/ashtml/asz80.htm>.

### Putting it on a card

Program the image into a 27C1000 (128 KB) EPROM for socket U10
([Firmware versions](firmware-versions.md)). Nothing in the firmware checks a checksum:
the image's 16-bit sum only names the build ($BEEF for ROM 1.4). GetStatus reports the
version: $14 for ROM 1.4, $15 for 1.5, $20 for 2.0.

### Addresses

In the low 64 KB, the EPROM offset, the SRAM address in bank 0 and the
firmware's logical address are the same number. All addresses in the errata are of this
kind. Data the firmware reads straight from the EPROM at run time is not in SRAM:
`set_video_mode` copies the built-in mode records by DMA from physical $6xxxx (the EPROM)
into its buffer at $0D2E, so a changed record needs a new EPROM.

### Room for added code

- The 316 bytes $1EC4-$1FFF are zero, follow the last command handler, and nothing in
  ROM 1.4 refers to them. They are copied at boot and always mapped.
- The bytes $0003-$0037 and $003B-$007F are zero and never run: ROM 1.4 executes no RST
  other than RST $38 (its handler starts with `JP $0C4A` at $0038), and NMI is held
  inactive by its pull-up ([Z180 interrupt inputs](reference/z180-io-ports.md#z180-interrupt-inputs)).
  They lie in the common area that is always mapped: 122 bytes for small hooks.
- The 2,186 bytes $9776-$9FFF are zero, and the disassembly marks them free space. They
  are copied at boot, but logical $9776-$9FFF shows them only in the firmware's usual
  layout (BBR = 0); the double-hires and Super Hi-Res renderers map other memory there,
  so code they call goes in $1EC4-$1FFF instead.
- Larger code goes in SRAM bank 1 $C000-$FFFF, which the [firmware documentation](sources.md#s15) marks free. With
  the firmware's usual mapping (CBAR = $F2), code in the common area reaches
  $1C000-$1EFFF with interrupts disabled: save BBR, set it to $10, which maps logical
  $2000-$EFFF to physical $12000-$1EFFF, call the code at its logical address ($C000 =
  physical $1C000), then restore the saved BBR. Logical $F000-$FFFF stays in common area
  1, so the last 4 KB, $1F000-$1FFFF, is out of reach this way. Interrupts stay off
  meanwhile because the INT1 handler expects the firmware's mapping.
- In a new EPROM that code can sit in the unused upper 64 KB (all $00, physical
  $70000-$7FFFF), copied into bank 1 by one more DMA transfer in the boot code.

### Checking a build on a card

GetStatus answers with the build's version, and each fixed erratum behaves as its entry
describes.

## Other ROM revisions

Only one ROM image is public: rev 1.4-BEEF, which reports version $14 in GetStatus. It is
the v1.1 firmware update. No other image is in the Apple II Documentation Project mirror,
the Asimov archive and its apple2.org.za mirror, archive.org, Brutal Deluxe or the
jawaidbazyar2/secondsight repository.

- **First release (mid-1995):** no 32K-color modes (`SS.MODES` on [`sslib082696.po`](sources.md#s07)), and uploads could not reach the upper 512 KB of video RAM
  ([E20](reference/errata.md#e20-uploads-above-512-kb-crashed-the-card)).
- **v1.1:** Sequential's "Second Sight Firmware Update v1.1" notes ([`SECOND/SVIEW/SS.NOTES`](sources.md#s06)
  on `ss.source.082395.po`) list the additions and fixes in [E21](reference/errata.md#e21-faults-fixed-in-v11). Sequential shipped
  the update by November 1995 as two replacement chips, free if the old chips came back,
  or $15 to keep them (overseas). Source: [comp.sys.apple2, February 1996](sources.md#s71). The
  new EPROM is labeled "rev 1.4-BEEF", and owners reported the double-hires freeze as soon
  as they installed it. Source: [GenieLamp, December 1995](sources.md#s70). So v1.1 and
  the dumped 1.4-BEEF EPROM are the same release. The two chips are the
  EPROM and the Lattice: the [firmware documentation](sources.md#s15) asks for a "V1.1 EPROM and Lattice or
  greater".
- SecondView 1.0a5 (July 1995) showed 3200-color pictures in the 15/16-bit modes on the RGB
  monitor "if you have the new ROM"; GView 0.25c (February 1996) requires "Roms v1.1 or
  greater". Sources: [SecondView release notes](sources.md#s06); [GView documentation](sources.md#s04).
- SetTextFont ($0F) is documented in the August 1995 [firmware documentation](sources.md#s15) but ignored by ROM 1.4
  ([E10](reference/errata.md#e10-settextfont-is-missing)).
- [SecondSight.Card.INFO.txt](sources.md#s41) (1998) and a 1998 GEnie message name SSRomFix, a startup INIT that fixes "a
  bug in SS ROM"; no copy of it survives in any archive. A startup file can only change
  card SRAM, until the next reset, and the SCB band pointer
  ([E3](reference/errata.md#e3-super-hi-res-lines-102-127-use-the-wrong-palette)) is the
  known fault such a change fixes completely. Source: [GEnie message](sources.md#s74).

**Running another ROM.** The manual's "V1.1 EPROM and Lattice or greater" shows that Lattice
revisions went with ROM revisions, so another ROM may need a matching Lattice or small-PLD
revision. A different ROM may also use hardware details that ROM 1.4 never touches. Source: [firmware documentation](sources.md#s15).

---

Previous: [07 Glue logic](07-glue-logic.md) | [Reference index](../README.md) | Next: [09 Host protocol](09-host-protocol.md)
