# 06 Video: OTI-087X VGA chip, video RAM window, clocks, Bt481, outputs, modes

[Reference index](../README.md) | [Glossary](glossary.md) | [Reference tables](reference/README.md)

The picture comes from a standard PC VGA chain driven by the Z180 instead of a PC:

```
 Z180 bus ---> OTI-087X VGA controller ---> 1 MB DRAM (8 x 256K x 4, 32 bits wide)
  (8 bits)       |  CSEL3-0                      |
                 v                               | pixel data P7-P0
              OTI-068 clock chip -- VCLK ------> Bt481 color chip (RAMDAC) --> R, G, B
              (14.318 MHz crystal)    |                                         |
                                      +--> GAL U12: /2 for AppleColor RGB, ------+--> VGA and RGB headers
                                           composite sync                          (HSYNC, VSYNC, sync)
```

Tables: [OTI-087X registers](reference/oti087-registers.md),
[Clock selections](reference/clocks.md),
[Bt481 modes](reference/bt481-modes.md),
[Video mode records](reference/video-modes.md).

## Contents

- [Which Oak chip](#which-oak-chip)
  - [Revision differences](#where-the-oti-087x-differs-from-earlier-oti-087s)
  - [Sources by revision](#which-sources-speak-for-the-oti-087x)
- [OTI-087X: how it is attached](#oti-087x-how-it-is-attached)
- [The video RAM window](#the-video-ram-window)
- [Extended registers the firmware uses](#extended-registers-the-firmware-uses)
- [The 64-bit latch lane rule](#the-64-bit-latch-lane-rule)
- [Pixel formats the chip displays](#pixel-formats-the-chip-displays)
- [Hardware cursor](#hardware-cursor)
  - [Pattern placement](#where-oaks-driver-puts-the-pattern)
  - [Positioning](#how-oaks-driver-positions-it)
  - [Probably: some X positions draw wrongly](#probably-some-x-positions-draw-wrongly)
  - [256-color modes only](#256-color-modes-only)
  - [Interlaced modes](#interlaced-modes)
- [How the firmware sets a mode](#how-the-firmware-sets-a-mode)
- [OTI-068 clock chip](#oti-068-clock-chip)
- [Bt481 color chip](#bt481-color-chip)
- [Outputs and the monitor type](#outputs-and-the-monitor-type)
- [The serial EEPROM](#the-serial-eeprom)

## Which Oak chip

The card carries Oak's OTI-087X. Every production card photographed from the front shows
that part number:

| Card | Marking | Source |
|---|---|---|
| Sequential's 1995 photo; a 2021 owner's card | OTI087X, OAK TECHNOLOGY, INC AA4058EBT0B, T9429 | [s20](sources.md#s20); [s108](sources.md#s108) |
| A 2026 owner's card | OTI087X, OAK TECHNOLOGY, INC AA2569EBT0B, T9422 | [s109](sources.md#s109) |

Oak sold two versions of the OTI-087, the OTI-087B and the OTI-087X, with a separate
driver set for each, because the 87X has "several significant enhancements"
([Oak FAQ](sources.md#s60); [driver page](sources.md#s112)). Oak tells them apart by the
video BIOS version: 1.0 to 1.03 is the 87B, 2.0 and up is the 87X. This card has no PC
BIOS; the Z180 firmware sets the chip up itself.

### What the OTI-087X's own specification is

The February 1993 [OTI-087 databook](sources.md#s02) together with its one-page OTI-087X
addendum, which "describes changes to the OTI-087 February 1993 databook for OTI-087X
parts". Where the addendum changes the book, the addendum wins.

### Where the OTI-087X differs from earlier OTI-087s

Oak's own DOS installers know four revisions, told apart by ext $01 bits 7-4: 087B (0),
087D (1), 087X (2) and 089 (3). They install a Windows package for each: WIN31B for the
087B, WIN31D for the 087B and 087D, WIN31E for the 087X and WIN31F for the 089. Oak's 87X
Windows kit is "DISTev2.2, rev d, e"; its 87B kit is "DISTbv1.6, rev b, d"
([87X DOS kit](sources.md#s79) `INSTALL.EXE` offsets $54F1-$557C).

Oak's Windows installer, `OAK.EXE` (the same file in both Windows kits), holds the lowest ext $01 value
for each revision letter its INF files name: B 0, C 1, D 1, E 2, F 3 (file offset $7260).
So the 087X is Oak's revision E, and the 87X drivers' "rev.C or later" means bits 7-4 are
not 0 ([87X drivers](sources.md#s69)).

Every known difference, with its evidence. Nothing else in these docs is known to differ.
Earlier OTI-087 below covers 087B, 087D, Rev A and Rev B.

#### DRAM

**OTI-087X:** No RAS-only refresh; no "260" 256K x 16 interface (p13); CAS0n-CAS3n do not
apply (p8, p16). The card's 256K x 4 interface (p11) is not affected.

**Earlier OTI-087:** Oak's August 1992 overview lists 256K x 16 DRAMs without naming a
type, and no refresh types. The February 1993 databook lists RAS-only refresh and both
256K x 16 interfaces ("260" and "270").

Source: [Addendum](sources.md#s02); [1992 overview](sources.md#s59) p1.

#### Feature connector

**OTI-087X:** No integrated feature connector support. Ext $08 bits 6, 1, 0 take only 101
and 110, both with EPCLK on pin 19 and EPDATA on pin 20; pin 99 does not apply. Card
header J3: [board connections](reference/board-connections.md).

**Earlier OTI-087:** Oak's August 1992 overview does not list it. The February 1993
databook lists "Integrated feature connector support" (p1) and the p37 table.

Source: [Addendum](sources.md#s02); [1992 overview](sources.md#s59) p1.

#### Ext $08 bit 7

**OTI-087X:** Reserved.

**Earlier OTI-087:** DRAM WE/CAS pin choice (p37).

Source: [Addendum](sources.md#s02).

#### 386/486 local-bus pinout

**OTI-087X:** EPDATA (p25) and pin 99 (p28) become DCn; new local-bus schematics (p60).
This card uses the AT-bus pinout.

**Earlier OTI-087:** the pinout in the databook.

Source: [Addendum](sources.md#s02).

#### Ext $04 bit 4, turbo local bus

**OTI-087X:** May be set.

**Earlier OTI-087:** Must stay 0 on "OTI-087 Rev A and OTI-087 Rev B".

Source: [Databook p34](sources.md#s02).

#### Ext $00, ext $01

**OTI-087X:** Ext $00 = 1 and ext $01 bits 7-4 = 2. Oak's DOS installers name each value
of those bits: 0 = 087B, 1 = 087D, 2 = 087X, 3 = 089. Oak's 87X Windows drivers
("OTI-087C") refuse an 087B, one whose bits read 0 ("OTI-087 (rev.C or later)").

**Earlier OTI-087:** 087B: ext $01 bits 7-4 = 0; 087D: 1. Oak's 87B Windows drivers accept
ext $00 = 1, 2 or 3 and never read ext $01.

Source: [87X DOS kit](sources.md#s79) `INSTALL.EXE`; [87X drivers](sources.md#s69); [87B
drivers](sources.md#s113).

#### Ext $30 bit 4, pixel-mask order

**OTI-087X:** Oak's 87X drivers set it to 1 and write each bitmap byte straight into the
pixel mask, bit 7 as the first pixel.

**Earlier OTI-087:** Oak's 87B drivers keep it 0, reverse each bitmap byte through a
256-entry table first, and build edge masks the other way round.

Source: [87X drivers](sources.md#s69) and [87B drivers](sources.md#s113), `STD8_SC.DRV`
and `LIN8_SC.DRV`.

#### 24-bit (true-color) pixels

**OTI-087X:** Oak's true-color driver, the same file in both kits, picks the byte order of
each 24-bit pixel from ext $01 bits 7-4, for all 13 color chips it knows.

With a Bt481 (its color-chip class 4) it stores R, G, B at rising addresses on later
chips, the 087X included, and sends the same color-chip command, $F0, on both. So the 087B
and later chips hand a pixel's three bytes to the color chip in a different order.

For one chip (DAC ID $82, a MUSIC MU9C4910) it also writes DAC command $9F instead of $9E.

**Earlier OTI-087:** 087B: G, B, R at rising addresses with a Bt481, and command $9E.

Source: [87X drivers](sources.md#s69) `8ETRU640.DRV` file offsets $FCAB-$FCC7, tables
$16E50 (later) and $16E9E (087B), byte order code $C7CA-$C806, pixel stores $1D226-$1D228.

#### Hardware cursor availability

**OTI-087X:** Oak's 87X kit has hardware-cursor drivers ("OTI Hard Cursor (Y-1)"); its INF
notes a "y-1 driver INF file for the BD h/c".

**Earlier OTI-087:** Oak's 87B kit has none, and Oak's Windows installer leaves the
hardware-cursor drivers out of its list when ext $01 bits 7-4 are 0 or 1, an 087B or 087D
(`OAK.EXE` file offsets $AD6-$AF1 and $15AC-$15B9). Oak's August 1992 overview does not
list a cursor.

EDN's report of the OTI-087 launch names "a 64 x 64-pixel hardware cursor with 2
bits/pixel", and the February 1993 databook's feature list (p1) has it.

Source: [87X drivers](sources.md#s69); [87B drivers](sources.md#s113); [1992
overview](sources.md#s59) p1; [EDN](sources.md#s115).

#### Other driver differences

Every other file in Oak's two Windows kits is byte-for-byte the same. Apart from the differences
above, the two kits' 256-color drivers differ only in their banners, their data addresses
and one write: in one drawing-setup routine the 87X driver sets ext $22 to $1C, where the
87B driver ORs $1C into the value it read (`STD8_SC.DRV` segment 1, 87X offset $744C).

### Which sources speak for the OTI-087X

- **The OTI-087X itself:** the databook with its addendum; Oak's [87X drivers](sources.md#s69)
  and [87X DOS kit](sources.md#s79); ROM 1.4, which runs on production OTI-087X cards.
- **The 087B and later chips, the 087X included:** Oak's [TEv1.02 BIOS](sources.md#s58). It
  reads ext $01 and runs a few extra steps only on an 087B; its other code serves every
  revision.
- **The OTI-087B:** Oak's Paradise [TBv1.01B BIOS](sources.md#s57) and
  [87B drivers](sources.md#s113). These docs mark every fact that rests on them.
- **The OTI-087 with no revision named:** the [August 1992 overview](sources.md#s59), the
  [Programmer's Guide](sources.md#s61), [OAK.TXT](sources.md#s35), and the third-party
  [XFree86](sources.md#s63) and [svgalib](sources.md#s67) drivers. They apply to the
  OTI-087X except where the comparison above says otherwise; these docs mark every fact that
  rests on them.

Register details: [OTI-087X registers](reference/oti087-registers.md).

## OTI-087X: how it is attached

The OTI-087X answers Z180 memory cycles in the
[video window](#the-video-ram-window) and I/O cycles at its ports.
It alone drives its 1 MB of DRAM. It never requests the bus: U17's copy controller is the only
other bus requester (the BREQ net joins only U17 and the Z180). So the OTI-087X cannot
reach the Z180's SRAM, and the Apple capture writes only SRAM
([Capture logic](04-capture-logic.md#copying-video-writes)).

Every byte in video RAM gets there through a Z180 instruction or DMA channel 0
([firmware DMA channels](reference/z180-io-ports.md#firmware-dma-channels)), and the
picture changes only when the firmware redraws it from the SRAM copy
([Renderers](08-firmware.md#renderers)). Source: [netlist](../data/netlist/README.md).

- The OTI-087X can sit on a 386/486 local bus or on the AT (ISA) bus. Straps on its memory
  data lines, read at reset, choose. This card is strapped as an **AT-bus add-on card**
  (Configuration Register 1 bits 2-1 = 11). Sources: schematic sheet 3; [databook p36](sources.md#s02).
- As an add-on card the chip starts disabled. The firmware enables it with the databook's
  sequence: write $10 to I/O $46E8, $01 to $102, then $08 to $46E8 (`enable_oak_add_on_mode`,
  [databook p29-30](sources.md#s02)). An emulator must ignore VGA accesses until this is done.
- Standard VGA I/O ports ($3B0-$3DF) and the Oak extended registers (index at $3DE, data
  at $3DF) are reached with Z180 I/O cycles. The OTI-087X sees every I/O read and write
  strobe with the full address and decodes its own ports (its ENVGA pin is tied high).
  Source: [netlist](../data/netlist/README.md).
- The Z180 data bus is 8 bits. The firmware sets Oak index $13 = $C8, which enables 16-bit
  memory and I/O cycles on the chip's side; on an 8-bit host the cycles stay 8-bit.
- The strap values: [register $07](reference/oti087-registers.md#reg-07). Nothing reads
  the unstrapped bits; their working values: [register behavior](reference/oti087-registers.md#register-behavior).

## The video RAM window

The Z180 sees video RAM through its physical window **$80000-$FFFFF (512 KB)**. The OTI-087X
decodes it in one of two ways, chosen by Oak extended register 5
([Oak window selection](reference/z180-memory-map.md#oak-window-selection)).

The Z180 window is only 512 KB, so two board-level controls supply the missing address
bits:

1. **The half switch.** Any access to physical $40000-$4FFFF selects half 0, any access to
   $50000-$5FFFF selects half 1. Reads and writes have the same selection effect because
   U15 has no read/write input; reads return a floating bus. Source: [netlist](../data/netlist/README.md).
2. **The linear flag.** Port $AB is written right before every switch to ext reg 5 = $19,
   and port $AA right after every switch back to $00 (12 places, without exception; reset
   also reads $AA). Source: [ROM_BEEF.asm:287](sources.md#s27), 362, 1724, 1799, 1923, 2031, 2152, 2216, 2281, 4905, 5005, 8580.

The video address:

```
Oak address bit 20   = linear flag      ($AB sets it, $AA clears it; only for $80000-$FFFFF)
Oak address bit 19   = half switch      ($4xxxx -> 0, $5xxxx -> 1)
Oak address 18-0     = Z180 A18-A0      (Z180 address $80000-$FFFFF)
```

- Linear mode: VRAM offset = half x $80000 + (Z180 address - $80000). The uploader picks
  half 0 for offsets below $80000 and half 1 above ([`ROM_BEEF.asm:1807-1840`](sources.md#s27)).
- Standard mode: the firmware always leaves the switch in half 1 and the flag clear, so
  Z180 $A0000 reaches Oak $A0000, the normal VGA window.
- Z180 code sees 64 KB at a time, so the firmware points part of that space at the window
  with its MMU registers and restores them afterwards ([MMU](05-z180.md#mmu)).
- **Speed.** Every video RAM access takes at least two wait states, and in practice 3 to 5
  or more ([wait states](05-z180.md#wait-states)). [Second.Sight.Info.txt](sources.md#s40) (1995)
  gives eight 20 MHz clocks per copied byte, about 2.5 MB/s, and about 5 MB/s when the VGA
  chip's read-modify-write cycles help; at the card's 18 MHz eight clocks are 2.25 MB/s.
  ROM 1.4's own Super Hi-Res redraw runs at most about 10 full screens a second
  ([redraw speed](08-firmware.md#super-hi-res)).
- The [prototype drawing](sources.md#s26) wires the Oak's high address inputs as LA19 = Z180 HA19 and
  LA20 = U15 "VGAIO", LA21-23 = ground ([netlist](../data/netlist/README.md)). With LA19 tied to HA19, which is always 1
  inside the window, the lower half of video RAM is unreachable in linear mode. The
  firmware reaches it, so **production wiring differs**: Oak pin 71 (LA20) carries the
  $AA/$AB linear flag, U4's VGAIO_SEL latch passed through U15's VGAIO, and pin 70
  (LA19) carries the $4xxxx/$5xxxx half switch through a rework wire. That is the only
  wiring that fits the firmware.

## Extended registers the firmware uses

Which registers the firmware sets, to what, and where:
[register index](reference/oti087-registers.md#register-index).

### Packed-pixel mode and the CRTC

In packed-pixel mode (ext $21 = $04) the OTI-087X stores one byte per 256-color pixel in a
linear layout. Every contemporary Oak packed mode programs the standard VGA registers the same
way: CRTC $14 bit 6 = 0 (doubleword off), CRTC $17 bit 6 = 1 (byte mode), attribute mode
$01, sequencer memory mode $0E (chain-4). The line pitch is then **16 bytes per CRTC
offset unit**: offset $28 gives 640 bytes, $32 gives 800, $40 gives 1,024. Sources: Oak's
[TEv1.02 BIOS](sources.md#s58); the third-party [XFree86](sources.md#s63)
3.3.2.3a and [svgalib 1.4.3](sources.md#s67) drivers, which name no 087 revision. On this
card's OTI-087X, ROM 1.4's 640-wide modes use the same settings (next paragraph).

ROM 1.4's 640-wide modes ($53, $61, $FE) follow that pattern. Its mode $13 instead keeps
IBM's mode 13h settings (doubleword and word mode, attribute $41) together with ext $21 =
$04. No Oak source uses that mix; it gives a broken picture
([Mode $13 addressing and display](08-firmware.md#mode-13-packed-pixel-note)).

## The 64-bit latch lane rule

The ROM's address patterns and period driver code for Oak chips imply the following rule for
packed-pixel mode (ext $21 bits 3-2 = 01), chain-4, and ext $22 bit 4 = 1: reads load
the latch. Writes in write mode 1 with the pixel mask on (ext $30 bit 3 = 1) store four
bytes, and A0 selects the four-byte destination half. Ordinary writes (write mode 0,
pixel mask off) still store one byte, even with the latch enabled: the Super Hi-Res setup
turns the latch on, builds its lookup tables with plain byte writes, and only then turns
on the pixel mask and write mode 1 for drawing. Sources: [ROM_BEEF.asm:8585-8628](sources.md#s27)
(runs on the OTI-087X); the third-party [XFree86 3.3.6 Oak driver](sources.md#s63), which
names no 087 revision.

Why four bytes: the two latch halves are the chip's 16-bit path ("true 16-bit move
operations", [databook p6](sources.md#s02)), where one 16-bit write stores both. The Z180
gives the chip only 8-bit cycles, so one write stores one half, four bytes; the firmware's
renderers work on production cards this way. The prototype drawing shows the wiring: SD8-SD15
open and -BHE (pin 100) tied to +5 V ([netlist](../data/netlist/README.md) U28). How to use the latch, the mask and color expansion, and what each
costs: [Drawing with the OTI-087X](15-oak-drawing.md).

Packed-pixel modes always run with chain-4 on, so this is the packed-mode behavior
software relies on: ROM 1.4's packed records set sequencer register 4 to $0E or $0A,
and all 20 256-color mode tables in Oak's BIOS set $0E. No ROM, BIOS or driver combines
packed pixels with chain-4 off. Sources: ROM mode records ([Video mode records](reference/video-modes.md));
[Paradise TBv1.01B](sources.md#s57) BIOS, Oak's BIOS with the same tables, at $1169 and $1469-$1B69.
Every case: [latch access rules](reference/oti087-registers.md#latch-access-rules).

The SHR loop at ROM $A4A1 reads a source byte (`ld a,(bc)`), forms a four-byte lookup
entry (`ld l,a; add hl,hl; add hl,hl`), then uses `ldd` with destination offsets 9, 8,
7, 6. `make_320_table` (`sub_AE92` in s27) builds the table at $FC00. These four-byte entries and destination
offsets require four-byte stores for the intended eight-pixel output.
Source: [ROM_BEEF.asm:9552-9944](sources.md#s27), generated SHR loop.

The lores renderer's writes at offsets 0, 1, 8, 9 and the text renderer's writes of the
same font byte at offsets 0 and 1 (`render_text80_row`, `sub_69BD` in s27, around [ROM_BEEF.asm:5483](sources.md#s27)) fit the same
rule, and so do the latch accesses in the third-party [XFree86 3.3.6](sources.md#s63)
driver's `oti87_fill.c` and `oak_colexp.s`.

Accesses ROM 1.4 never makes follow the same chip: address bits 1-2 are ignored by the
four-byte store rule, write mode 1 with the pixel mask off is standard VGA write mode 1,
and a latched read returns the addressed byte. Content-addressable operation (ext $22
bit 4 = 0 and bit 0 = 1) lets the low CPU address bits pick the latch byte written out,
as the latch index $35 does.
Source: [databook p42](sources.md#s02), [Oak's 87X drivers](sources.md#s69).

### Pixel-mask bit order

Ext $30 bit 4 sets which mask bit (ext $34) belongs to which pixel of an 8-pixel group:

| Ext $30 bit 4 | Mask bit 7 is | Mask bit 0 is |
|---|---|---|
| 0 (default) | pixel 7 | pixel 0, the first pixel |
| 1 | pixel 0, the first pixel | pixel 7 |

([databook p43](sources.md#s02); p44 describes the default order). [Oak's 87X Windows driver](sources.md#s69)
(`STD8_HC.DRV`) sets bit 4 and builds its edge masks with bit 7 as the leftmost pixel,
exactly as p43 says. The third-party [XFree86 3.3.6](sources.md#s63) driver
(`oti87_fill.c`) also sets bit 4 but builds its masks for the default order, so its
accelerated fill draws mirrored edges on this chip. ROM 1.4
always uses mask $FF.

## Pixel formats the chip displays

Which layouts of video memory the OTI-087X turns into pixels by itself, from the databook,
Oak's 87X drivers and Oak's TEv1.02 BIOS. Anything else the Z180 must convert first, which is what
limits the Super Hi-Res redraw ([E13](reference/errata.md#e13-fast-animation-is-choppy)).

| Format | Layout | Evidence |
|---|---|---|
| Oak packed pixel: ext $21 bits 3-2 = 01 | One byte per pixel for 256 colors; two or three bytes per pixel for 32K, 64K and 16M colors (ext $21 bits 0-1) | [Databook](sources.md#s02) p41: "Used for 256, 32K, 64K and 16M color modes" |
| VGA modes or Oak planar modes: ext $21 bits 3-2 = 00 | The 16-color modes are planar: each pixel takes one bit from each of the four planes | Databook p41; p1 lists a "16-bit graphics latch for true 16-bit operations in planar modes" |
| Standard VGA modes | The chip "implements all registers and data paths" of the IBM VGA. Oak's TEv1.02 BIOS sets mode 13h (320 x 200, one byte per pixel) with Graphics Mode $40 and Attribute Mode $41, and modes 4 and 5 (320 x 200, four 2-bit pixels per byte) with Graphics Mode $30, Attribute Mode $01 and Color Plane Enable $03 | Databook p1; mode tables in [TEv1.02](sources.md#s58) at $0B72, $0BB2 and $1172, and in [TBv1.01B](sources.md#s57) at $0B69, $0BA9 and $1169 |
| Packed 4-bit, two pixels per byte | None. Ext $21 values 10 and 11 are reserved | Databook p41 |

For Super Hi-Res this means 320-mode lines have no matching format: every 4-bit pixel
must be turned into an 8-bit or planar pixel before it reaches video memory, as ROM 1.4
does with its conversion tables. 640-mode lines store their pixels the way modes 4 and 5
do, four 2-bit pixels per byte with the leftmost in bits 7-6, but ROM 1.4 converts them
with tables too.

## Hardware cursor

The cursor is a 64 x 64 two-plane bitmap: 64 rows of 16 bytes, 1,024 bytes total.
Each row holds eight bytes of plane A followed by eight of plane B. Oak's 87X Windows
driver stores its cursor exactly so, as two 1-bit masks per row, and turns the cursor on
by writing ext $4C = $15 and off with $14. Sources: [Oak 87X Windows driver](sources.md#s69); the third-party [OAK.TXT](sources.md#s35):190-196 agrees.

Ext $4C bit 2 sets the bit order inside each byte: with 0, bit 0 is the first pixel; with
1, bit 7 is ([databook p46](sources.md#s02)). Oak's driver runs with bit 2 = 1 and the
layout above. Probably bit 2 changes only the bit order: p46 describes nothing else, so the
byte and plane order stay as above with either value.

| Plane A | Plane B | Pixel result |
|---|---|---|
| 0 | 0 | Cursor color 0, ext $4A |
| 0 | 1 | Cursor color 1, ext $4B |
| 1 | 0 | Transparent: show screen |
| 1 | 1 | Invert screen |

This is how [Oak's 87X Windows driver](sources.md#s69) uses the cursor. Windows hands a driver an AND mask
followed by an XOR mask; `STD8_HC.DRV` copies the AND mask into plane A and the XOR mask
into plane B, and sets color 0 ($4A) to $00 (black) and color 1 ($4B) to $FF (white). For
Windows cursors to look right (AND 0/XOR 0 black, 0/1 white, 1/0 transparent, 1/1 invert),
the chip must apply those plane-A/plane-B pixel results. Sources: Oak's own driver and the Windows 3.0 driver kit; [Oak 87X Windows driver](sources.md#s69).

The third-party [OAK.TXT](sources.md#s35) gives a different table
(00 transparent, 01 color 0, 10 invert, 11 color 1), with which the cursors of Oak's own
driver would show wrong pixels. The third-party [XFree86 3.3.6](sources.md#s63) driver only saves and restores $40-$4C
(`oak_driver.c:912-935,1058-1081`).

Position, pattern address, preset, overscan and blink: [register reference](reference/oti087-registers.md#reg-40-41).

### Where Oak's driver puts the pattern

On a 1 MB card it writes the pattern into the last 64 KB bank (ext $25 = 15, the bank
number it derives from ext $02's memory size) at offset $F400, video address $FF400, and
sets ext $47-$49 to $01, $FE, $80. $01FE80 x 8 = $FF400, so the pattern address counts
8-byte units. It draws the 32 x 32 Windows cursor into rows 31-62 and columns 32-63 of the
pattern, and starts the display there with presets ext $44 = $20 and $45 = $1F. Source:
[Oak 87X Windows driver](sources.md#s69), `STD8_HC.DRV` offsets $53D2-$541B and
$87A9-$87E7 (sizes from $83E5-$83FE).

### How Oak's driver positions it

`STD8_HC.DRV` takes the mouse position minus the cursor's hot spot as the top-left corner,
then:

- X goes to ext $40/$41 as a 16-bit two's-complement number, so a cursor partly off the
  left edge gets a negative X. A negative odd X is first moved one pixel right, and -14 is
  never written: it becomes -12, or -16 when it came from -15.
- Y goes to ext $42/$43 as the row above the corner (top - 1) whenever that is 0 or more;
  a top of 0 or less is written unchanged, also as two's complement.

So Oak's driver treats the chip as drawing the cursor's first row one line below the value
in ext $42/$43, and as accepting negative positions. Source: [Oak 87X Windows driver](sources.md#s69),
`STD8_HC.DRV` offsets $56AD-$56C6 (corner = position minus hot spot) and $5537-$557A
(register writes).

### Probably: some X positions draw wrongly

WHATVGA, written by testing real Oak cards, writes only multiples of 4 to ext $40/$41 (`x
and $FFFC`), and its change log says the Oak cursor "Looks a bit weird sometimes" when
that support began ([WHATVGA](sources.md#s117), `BITBLT.PAS` lines 783-787; `WHATVGA.VER`
version 1.71). Oak's 87X driver shows the positions it trusts: any X of 0 or more, and
even negative X except -14.

Code that keeps to those values, or to WHATVGA's multiples of 4, stays clear of the fault.

WHATVGA also multiplies the cursor's Y by the mode's line repeat (`BITBLT.PAS` line 693),
so Y counts scan lines, not doubled rows.

### The only hardware sprite

No OTI-087 or OTI-087X document describes another cursor size, more than two colors, a
second cursor, zoom, an overlay window or color keying. Oak's later Spitfire chips
(OTI-64105 and OTI-64107) add a video window beside the cursor, but they are a different
design, "not downwardly compatible to any other Oak chips" ([Programmer's
Guide](sources.md#s61) 25.1.2), so none of that exists on this card's chip.

### 256-color modes only

WHATVGA 2.00 tested the hardware cursor of a real 1 MB OTI-087
card in each display mode and reports: "The hardware cursor only works in 256color modes"
([WHATVGA](sources.md#s117), adapters table and notes; the card's revision is not named).
Ext $4A and $4B are 8-bit color numbers ([databook p46](sources.md#s02)), so the cursor's two
colors are palette entries, looked up through the color chip like every 256-color pixel.
Oak's 87X driver sets them to $00 and $FF.

### Interlaced modes

Oak's 87X hardware-cursor drivers refuse to run when ext $14 bit 7
(interlace) is set: `STD8_HC.DRV` (file offsets $89B7-$89C6) and `LIN8_HC.DRV`
($8AF1-$8B00) stop with "This (hard-cursor) driver for this resolution requires
non-interlaced mode." Oak ships the chip's only interlaced 256-color resolution, 1280 x 1024,
with software-cursor drivers only ([87X drivers](sources.md#s69)). This card's AppleColor RGB
modes are interlaced.

### Probably: twice as tall in interlace

In interlace the CRTC counts lines per field ([video modes](reference/video-modes.md)). A
cursor that compares Y with that count draws the same pattern rows in both fields, so each
row shows on two neighboring lines of the frame and the cursor is 128 lines tall.
WHATVGA's register notes say exactly this of another 64 x 64 cursor of the period, the
Avance Logic ALG2101/2201/2228: "in interlaced modes the cursor is shown double height"
([AVANCE.TXT](sources.md#s118)). A cursor that splits its rows between the fields needs
extra logic: IBM's XGA sprite has the CRT controller fetch the cursor line two ahead in
interlace instead of one ([IBM patent EP0422300B1](sources.md#s119)). Software can still
use the cursor in interlace: a pattern drawn half as tall shows at the intended height.

## How the firmware sets a mode

Each mode is one 81-byte record. The byte layout is documented in
[`tools/mode_files.py`](../tools/mode_files.py). `set_video_mode` ([`ROM_BEEF.asm:900-1210`](sources.md#s27)):

1. Read $3C2 bit 4 (monitor sense). 1 = VGA monitor: search the VGA list. 0 = AppleColor
   RGB: search the RGB list. Mode $FF uses the record SetUserMode stored at $179A.
2. DMA-copy the 81-byte record into RAM.
3. Enable add-on mode; put the sequencer in reset.
4. Write ext $06 (clock select), then $3C2 (misc output), then ext $21 (mode select) and
   sequencer register 1. The misc write sets clock-select bits 1-0 again, so **the misc
   byte decides CSEL1-0** and ext $06 only contributes CSEL3-2.
5. Feature byte bit 0: write port $A9 (AppleColor RGB path) if 1, port $A8 (VGA path) if 0.
6. Set the Bt481 Command Register A to the feature byte's high nibble ([command-register access](reference/bt481-modes.md#access-with-rs2-grounded)).
   Write the feature byte's bits 3-1 to $3DA.
7. Sequencer 2-4, release reset, wait about 32,000 loops, unlock and write CRTC 0-$18,
   graphics 0-8, attribute 0-$14, then the Oak extended registers.
8. Give the palette back to the display (attribute index bit 5).

### Built-in modes

The codes: [built-in mode codes](reference/video-modes.md#built-in-mode-codes).

- Super Hi-Res is shown as a 640 x 200 mode with each line drawn twice on VGA, which is why
  [Second.Sight.Info.txt](sources.md#s40) says SHR has "no black lines running through graphics".
- The RGB record for $FA is built differently from the other RGB modes: it selects the VGA
  path (no divide by 2), and its misc byte overrides its ext $06 value, giving 25.175 MHz.
  With the sequencer's divide by 2 that is 12.6 MHz dots and 15.6 kHz lines, inside the
  AppleColor RGB range. Source: [databook p35](sources.md#s02).

### Library mode files

[`ss.source.082395.po`](sources.md#s06) holds more modes as files, sent with SetUserMode
([Video mode records](reference/video-modes.md)). Examples:

- **32K-color (15-bit)**: `M640X48032K.50M` and `M640X40032K.50M` on VGA run the pixel clock at
  50 MHz with 1,600 clocks per line (1,280 visible). Ext $21 = $04 (packed pixel) and the
  Bt481 in 5:5:5 single-edge mode take two bytes per pixel, low byte first.
- **True color**: `M640X48016M` sets ext $21 = $06 (x3 timing) at 78 MHz but leaves the Bt481
  in 8-bit mode, so it cannot show 24-bit color as written. The
  [mode-width correction](14-custom-code.md#24-bit-mode-width) follows from the Bt481A
  mode definition and VGA horizontal display-end count.
- Several files carry an ext $06 value whose low bits disagree with their misc byte. Their
  names match the ext $06 clock (for example `M108X25.20M`: 40 MHz / 2), but under the 1.4
  firmware the misc byte is written last and decides, so they run at a different clock
  (see the per-mode overrides in [Video mode records](reference/video-modes.md)).

## OTI-068 clock chip

- A 14.31818 MHz crystal is the reference.
- **VCLK** (pixel clock): selected by FS3-FS0 = Oak CSEL3-CSEL0 (ext reg 6). Sixteen
  frequencies from 25.175 to 78 MHz: [Clock selections](reference/clocks.md).
- **MCLK** (video memory clock): selected by MS1-MS0 straps. On the production board both are
  open with pull-ups, giving **40 MHz**.
- Changing the clock select needs an Oak software reset; the firmware does it inside the
  sequencer reset.

## Bt481 color chip

The prototype drew a Bt478 (8-bit only). Production fits a **Bt481AKPJ marked "PROTO 2"**,
which adds 15-, 16- and 24-bit modes. Source: [Bt481A datasheet](sources.md#s36) L481A_C.

Command-register access and pixel modes: [Bt481 reference](reference/bt481-modes.md).
The card starts with 8-bit palette components
([palette controls](reference/bt481-modes.md#remaining-bits-and-power-on-value)), and
every palette in the firmware uses 8-bit values ($FF, $94, $D0, ...); the Super Hi-Res
code turns each 4-bit Apple color into 8 bits by multiplying by $11. So the palette ports
$3C7/$3C8/$3C9 take full 8-bit values, 256 entries. Source: [netlist](../data/netlist/README.md), [Bt481A datasheet](sources.md#s36) "Command Register B".
- The 1.4 firmware never writes Command Register B. Its power-up value also enables sync on all three
  color outputs, but the SYNC* input is tied high, so no sync is added to the video.
- **Pins that changed** from the Bt478: pin 1 is SENSE* on the Bt481 (NC on the Bt478), and
  pin 20 is TRUECOL* (VAA on the Bt478, and the prototype sheet explicitly ties it to VAA).
  A replica built from the drawing must not copy that tie. Source: [netlist](../data/netlist/README.md) pin comparison.

## Outputs and the monitor type

- The color chip's analog R, G, B go to both production headers, labeled VGA and RGB. The
  manual says never to attach both cables.
- **VGA path (port $A8):** the pixel clock goes straight to the chip. Separate HSYNC and
  VSYNC.
- **AppleColor RGB path (port $A9):** GAL U12 (clocked by VCLK) divides the pixel clock by 2
  (DIVOE) and makes a composite sync (XSYNC) from HSYNC and VSYNC. The 80-column and
  640-wide RGB modes use VCLK 63 MHz, the sequencer's divide by 2, and this divide by 2:
  15.75 MHz dot clock, 16.4 kHz lines. Source: schematic U12 pins.
- **Monitor type:** the firmware reads $3C2 bit 4, the OTI-087X's sense input (SWSENSE,
  pin 24). 1 = VGA, 0 = AppleColor RGB. The manual says the card detects which cable is
  attached: the cable header pulls SWSENSE high for the VGA cable and low for the
  AppleColor RGB cable. An emulator offers it as a setting.
- **TP3:** the manual's jumper "should be removed" for AppleColor RGB and fitted for VGA.
  On the drawing, R3 pulls the color chip's SETUP pin to +5 V and jumper JP3 grounds it.
  So fitted gives no blanking pedestal (0 IRE, VGA practice) and removed gives the 7.5 IRE
  pedestal. JP3 is the manual's TP3. Source: [netlist](../data/netlist/README.md).
- **Timing runs free of the IIgs.** The OTI-087X makes HSYNC (pin 35) and VSYNC (pin 34) as
  outputs from its own pixel clock and has no sync input; the OTI-087X addendum withdraws
  the chip's integrated feature connector support. No hardware ties the card's picture to the
  IIgs beam: Super Hi-Res on VGA runs at about 70 Hz against the IIgs's 60 Hz. Custom code
  can hold the two in step in software: [Matching the IIgs frame](14-custom-code.md#matching-the-iigs-frame).
  Sources: [OTI-087 databook](sources.md#s02) pin list and addendum; [Video mode records](reference/video-modes.md).

## The serial EEPROM

**What it is for.** On a PC video card the VGA BIOS needs a few configuration settings at
power-up, such as the monitor type. Cards usually took them from DIP switches. Oak gave
the OTI-087X an interface to a small serial EEPROM instead, so that setup software could
store those settings and no switches were needed ("EEPROM support provides switchless
configurations"). Source: [databook p6](sources.md#s02).

**Why this card has one.** The Second Sight copies Oak's reference circuit: the databook's
application schematic draws the same 1,024-bit EEPROM beside the dual clock generator,
sharing the Oak's three clock-select lines (CSEL2-0). Sources: databook application schematic; [netlist](../data/netlist/README.md) sheet 4.

**What uses it.** Only software: the OTI-087X never reads the EEPROM on its own ("the
configuration is done through software", [databook p6](sources.md#s02)). On a PC, Oak's VGA BIOS does: TEv1.02 contains a 93C46 driver that switches
the CSEL lines to EEPROM duty, reads all 64 16-bit words, accepts them only if they add
up to zero, and takes configuration bits from word 0. Sources: [Oak VGA87 BIOS TEv1.02](sources.md#s58), offsets $05B3-$069F; [Paradise TBv1.01B](sources.md#s57) BIOS has the same code. Oak's MONITOR.EXE
utility in the 87X DOS kit also saves the chosen refresh rates there. Source: [Oak 87XUTIL READ.ME](sources.md#s79).

The Second Sight has no PC BIOS. The Z180 firmware takes its place and gets the monitor type from the
SWSENSE input ($3C2 bit 4) instead. ROM 1.4 and the Sequential library never touch ext
$18, so neither uses the EEPROM, and its contents do not affect them.

**How it is wired and driven.**

- Part: 93C46-type, 1,024 bits as 64 words of 16 bits (ST93C46, marked "93C466").
- Ext $18 bit 2 = 1 switches CSEL2-0 from clock select to the EEPROM. Then bit 1 is chip
  select, bit 3 the shift clock (on CSEL2), bit 0 the data out to the EEPROM (on CSEL1);
  reading bit 0 returns the EEPROM's data (from CSEL0). Oak says to toggle the clock no
  faster than every 4 microseconds. Source: [databook p40](sources.md#s02).
- The OTI-068 clock chip listens to the same lines, so the pixel clock follows the EEPROM
  signals while they toggle: the picture glitches during an access. Clear ext $18 bit 2
  afterwards to restore the clock.

Custom code can use it as 128 bytes that survive power-off
([Beyond the firmware](14-custom-code.md#storage-the-serial-eeprom)).

---

Previous: [05 Z180 computer](05-z180.md) | [Reference index](../README.md) | Next: [07 Glue logic](07-glue-logic.md)
