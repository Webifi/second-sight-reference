# 06 Video: OTI-087 VGA chip, video RAM window, clocks, Bt481, outputs, modes

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

Tables: [OTI-087 registers](reference/oti087-registers.md),
[Clock selections](reference/clocks.md),
[Bt481 modes](reference/bt481-modes.md),
[Video mode records](reference/video-modes.md).

## Contents

- [OTI-087X: how it is attached](#oti-087x-how-it-is-attached)
- [The video RAM window](#the-video-ram-window)
- [Extended registers the firmware uses](#extended-registers-the-firmware-uses)
- [The 64-bit latch lane rule](#the-64-bit-latch-lane-rule)
- [Pixel formats the chip displays](#pixel-formats-the-chip-displays)
- [Hardware cursor](#hardware-cursor)
- [How the firmware sets a mode](#how-the-firmware-sets-a-mode)
- [OTI-068 clock chip](#oti-068-clock-chip)
- [Bt481 color chip](#bt481-color-chip)
- [Outputs and the monitor type](#outputs-and-the-monitor-type)
- [The serial EEPROM](#the-serial-eeprom)

## OTI-087X: how it is attached

The card carries the OTI-087X. Oak's one-page addendum lists only pin and DRAM-type
changes from the OTI-087, so the [OTI-087 databook](sources.md#s02) describes its registers.

The OTI-087 answers Z180 memory cycles in the
[video window](#the-video-ram-window) and I/O cycles at its ports.
It alone drives its 1 MB of DRAM. It never requests the bus: U17's copy controller is the only
other bus requester (the BREQ net joins only U17 and the Z180). So the OTI-087 cannot
reach the Z180's SRAM, and the Apple capture writes only SRAM
([Capture logic](04-capture-logic.md#copying-video-writes)).

Every byte in video RAM gets there through a Z180 instruction or DMA channel 0
([firmware DMA channels](reference/z180-io-ports.md#firmware-dma-channels)), and the
picture changes only when the firmware redraws it from the SRAM copy
([Renderers](08-firmware.md#renderers)). Source: [netlist](../data/netlist/README.md).

- The OTI-087 can sit on a 386/486 local bus or on the AT (ISA) bus. Straps on its memory
  data lines, read at reset, choose. This card is strapped as an **AT-bus add-on card**
  (Configuration Register 1 bits 2-1 = 11). Sources: schematic sheet 3; [databook p36](sources.md#s02).
- As an add-on card the chip starts disabled. The firmware enables it with the databook's
  sequence: write $10 to I/O $46E8, $01 to $102, then $08 to $46E8 (`enable_oak_add_on_mode`,
  [databook p29-30](sources.md#s02)). An emulator must ignore VGA accesses until this is done.
- Standard VGA I/O ports ($3B0-$3DF) and the Oak extended registers (index at $3DE, data
  at $3DF) are reached with Z180 I/O cycles. The OTI-087 sees every I/O read and write
  strobe with the full address and decodes its own ports (its ENVGA pin is tied high).
  Source: [netlist](../data/netlist/README.md).
- The Z180 data bus is 8 bits. The firmware sets Oak index $13 = $C8, which enables 16-bit
  memory and I/O cycles on the chip's side; on an 8-bit host the cycles stay 8-bit.
- The strap values: [register $07](reference/oti087-registers.md#reg-07). Nothing reads
  the unstrapped bits; their working values: [register behavior](reference/oti087-registers.md#register-behavior).

## The video RAM window

The Z180 sees video RAM through its physical window **$80000-$FFFFF (512 KB)**. The OTI-087
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
- **Speed.** Every video RAM access takes at least two wait states
  ([wait states](05-z180.md#wait-states)). [Second.Sight.Info.txt](sources.md#s40) (1995)
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

In packed-pixel mode (ext $21 = $04) the OTI-087 stores one byte per 256-color pixel in a
linear layout. Every contemporary Oak packed mode programs the standard VGA registers the same
way: CRTC $14 bit 6 = 0 (doubleword off), CRTC $17 bit 6 = 1 (byte mode), attribute mode
$01, sequencer memory mode $0E (chain-4). The line pitch is then **16 bytes per CRTC
offset unit**: offset $28 gives 640 bytes, $32 gives 800, $40 gives 1,024. Sources: Oak BIOS [TEv1.02](sources.md#s58); [XFree86](sources.md#s63) 3.3.2.3a and [svgalib 1.4.3](sources.md#s67) Oak drivers.

ROM 1.4's 640-wide modes ($53, $61, $FE) follow that pattern. Its mode $13 instead keeps
IBM's mode 13h settings (doubleword and word mode, attribute $41) together with ext $21 =
$04. No Oak source uses that mix; it gives a broken picture
([Mode $13 addressing and display](08-firmware.md#mode-13-packed-pixel-note)).

## The 64-bit latch lane rule

The ROM's address patterns and period Oak driver code imply the following rule for
packed-pixel mode (ext $21 bits 3-2 = 01), chain-4, and ext $22 bit 4 = 1: reads load
the latch. Writes in write mode 1 with the pixel mask on (ext $30 bit 3 = 1) store four
bytes, and A0 selects the four-byte destination half. Ordinary writes (write mode 0,
pixel mask off) still store one byte, even with the latch enabled: the Super Hi-Res setup
turns the latch on, builds its lookup tables with plain byte writes, and only then turns
on the pixel mask and write mode 1 for drawing. Sources: [XFree86 3.3.6 Oak driver](sources.md#s63);
[ROM_BEEF.asm:8585-8628](sources.md#s27).

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
rule, and so do the latch accesses in [XFree86 3.3.6](sources.md#s63) `oti87_fill.c` and `oak_colexp.s`.
Source: [XFree86 3.3.6 Oak driver](sources.md#s63).

Accesses ROM 1.4 never makes follow the same chip: address bits 1-2 are ignored by the
four-byte store rule, write mode 1 with the pixel mask off is standard VGA write mode 1,
and a latched read returns the addressed byte. Content-addressable operation (ext $22
bit 4 = 0 and bit 0 = 1) lets the low CPU address bits pick the latch byte written out,
as the latch index $35 does; no Oak software sets bit 0.
Source: [databook p42](sources.md#s02), [Oak's 087X drivers](sources.md#s69).

### Pixel-mask bit order

Ext $30 bit 4 sets which mask bit (ext $34) belongs to which pixel of an 8-pixel group:

| Ext $30 bit 4 | Mask bit 7 is | Mask bit 0 is |
|---|---|---|
| 0 (default) | pixel 7 | pixel 0, the first pixel |
| 1 | pixel 0, the first pixel | pixel 7 |

([databook p43](sources.md#s02); p44 describes the default order). [Oak's own Windows driver](sources.md#s69)
(`STD8_HC.DRV`) sets bit 4 and builds its edge masks with bit 7 as the leftmost pixel,
exactly as p43 says. Source: [Oak Windows driver](sources.md#s69). [XFree86 3.3.6](sources.md#s63)
(`oti87_fill.c`) also sets bit 4 but builds its masks for the default order, so its
accelerated fill draws mirrored edges on this chip. ROM 1.4
always uses mask $FF.

## Pixel formats the chip displays

Which layouts of video memory the OTI-087X turns into pixels by itself, from Oak's own
databook, BIOS and drivers. Anything else the Z180 must convert first, which is what
limits the Super Hi-Res redraw ([E13](reference/errata.md#e13-fast-animation-is-choppy)).

| Format | Layout | Evidence |
|---|---|---|
| Oak packed pixel: ext $21 bits 3-2 = 01 | One byte per pixel for 256 colors; two or three bytes per pixel for 32K, 64K and 16M colors (ext $21 bits 0-1) | [Databook](sources.md#s02) p41: "Used for 256, 32K, 64K and 16M color modes" |
| VGA modes or Oak planar modes: ext $21 bits 3-2 = 00 | The 16-color modes are planar: each pixel takes one bit from each of the four planes | Databook p41; p1 lists a "16-bit graphics latch for true 16-bit operations in planar modes" |
| Standard VGA modes | The chip "implements all registers and data paths" of the IBM VGA. Oak's BIOS sets mode 13h (320 x 200, one byte per pixel) with Graphics Mode $40 and Attribute Mode $41, and modes 4 and 5 (320 x 200, four 2-bit pixels per byte) with Graphics Mode $30, Attribute Mode $01 and Color Plane Enable $03 | Databook p1; mode tables in [TEv1.02](sources.md#s58) at $0B72, $0BB2 and $1172, and in [TBv1.01B](sources.md#s57) at $0B69, $0BA9 and $1169 |
| Packed 4-bit, two pixels per byte | None. Ext $21 values 10 and 11 are reserved, and no Oak document, BIOS mode or driver describes or uses a 4-bit packed layout | Databook p41 |

For Super Hi-Res this means 320-mode lines have no matching format: every 4-bit pixel
must be turned into an 8-bit or planar pixel before it reaches video memory, as ROM 1.4
does with its conversion tables. 640-mode lines store their pixels the way modes 4 and 5
do, four 2-bit pixels per byte with the leftmost in bits 7-6, but ROM 1.4 converts them
with tables too.

## Hardware cursor

The cursor is a 64 x 64 two-plane bitmap: 64 rows of 16 bytes, 1,024 bytes total.
Each row holds eight bytes of plane A followed by eight of plane B. Oak's own Windows
driver stores its cursor exactly so, as two 1-bit masks per row, and turns the cursor on
by writing ext $4C = $15 and off with $14. Sources: [Oak Windows driver](sources.md#s69); [OAK.TXT](sources.md#s35):190-196 agrees.

Ext $4C bit 2 sets only the bit order inside each byte: with 0, bit 0 of a byte is its
leftmost pixel; with 1, bit 7 is. Byte 0 of each plane always holds the leftmost eight
pixels, and plane A always comes first in the row. The later Spitfire specification names
the two settings "Intel format" and "Motorola format", the two byte-order conventions,
both of which start at byte 0. Sources: [databook p46](sources.md#s02); [Spitfire specification](sources.md#s64) p7-27.

| Plane A | Plane B | Pixel result |
|---|---|---|
| 0 | 0 | Cursor color 0, ext $4A |
| 0 | 1 | Cursor color 1, ext $4B |
| 1 | 0 | Transparent: show screen |
| 1 | 1 | Invert screen |

This is how [Oak's own Windows driver](sources.md#s69) uses the cursor. Windows hands a driver an AND mask
followed by an XOR mask; `STD8_HC.DRV` copies the AND mask into plane A and the XOR mask
into plane B, and sets color 0 ($4A) to $00 (black) and color 1 ($4B) to $FF (white). For
Windows cursors to look right (AND 0/XOR 0 black, 0/1 white, 1/0 transparent, 1/1 invert),
the chip must apply those plane-A/plane-B pixel results. Sources: Oak's own driver and the Windows 3.0 driver kit; [Oak Windows driver](sources.md#s69). [OAK.TXT](sources.md#s35) gives a different table
(00 transparent, 01 color 0, 10 invert, 11 color 1), with which the cursors of Oak's own
driver would show wrong pixels. [XFree86 3.3.6](sources.md#s63) only saves and restores $40-$4C
(`oak_driver.c:912-935,1058-1081`).

Position, pattern address, preset, overscan and blink: [register reference](reference/oti087-registers.md#reg-40-41).

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
- **Monitor type:** the firmware reads $3C2 bit 4, the OTI-087's sense input (SWSENSE,
  pin 24). 1 = VGA, 0 = AppleColor RGB. The manual says the card detects which cable is
  attached: the cable header pulls SWSENSE high for the VGA cable and low for the
  AppleColor RGB cable. An emulator offers it as a setting.
- **TP3:** the manual's jumper "should be removed" for AppleColor RGB and fitted for VGA.
  On the drawing, R3 pulls the color chip's SETUP pin to +5 V and jumper JP3 grounds it.
  So fitted gives no blanking pedestal (0 IRE, VGA practice) and removed gives the 7.5 IRE
  pedestal. JP3 is the manual's TP3. Source: [netlist](../data/netlist/README.md).
- **Timing runs free of the IIgs.** The OTI-087 makes HSYNC (pin 35) and VSYNC (pin 34) as
  outputs from its own pixel clock and has no sync input; the OTI-087X addendum drops the
  feature connector's external-sync support. No hardware ties the card's picture to the
  IIgs beam: Super Hi-Res on VGA runs at about 70 Hz against the IIgs's 60 Hz. Custom code
  can hold the two in step in software: [Matching the IIgs frame](14-custom-code.md#matching-the-iigs-frame).
  Sources: [OTI-087 databook](sources.md#s02) pin list and addendum; [Video mode records](reference/video-modes.md).

## The serial EEPROM

**What it is for.** On a PC video card the VGA BIOS needs a few configuration settings at
power-up, such as the monitor type. Cards usually took them from DIP switches. Oak gave
the OTI-087 an interface to a small serial EEPROM instead, so that setup software could
store those settings and no switches were needed ("EEPROM support provides switchless
configurations"). Source: [databook p6](sources.md#s02).

**Why this card has one.** The Second Sight copies Oak's reference circuit: the databook's
application schematic draws the same 1,024-bit EEPROM beside the dual clock generator,
sharing the Oak's three clock-select lines (CSEL2-0). Sources: databook application schematic; [netlist](../data/netlist/README.md) sheet 4.

**What uses it.** Only software: the OTI-087 never reads the EEPROM on its own ("the
configuration is done through software", [databook p6](sources.md#s02)). On a PC, Oak's VGA BIOS does: it contains a 93C46 driver that switches
the CSEL lines to EEPROM duty, reads all 64 16-bit words, accepts them only if they add
up to zero, and takes configuration bits from word 0. Sources: [Oak VGA87 BIOS TEv1.02](sources.md#s58), offsets $05B3-$069F; [Paradise TBv1.01B](sources.md#s57) BIOS has the same code. Oak's MONITOR.EXE
utility also saves the chosen refresh rates there. Source: [Oak 87XUTIL READ.ME](sources.md#s79).

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
