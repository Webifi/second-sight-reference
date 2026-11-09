# Board parts and cable connections

[Reference tables](README.md) | [Board](../02-board.md) | [Glossary](../glossary.md)

The prototype schematic omits some connections present on production cards. In the
parts table, the Prototype part column uses the schematic's names.

The cards identified below appear in a [photo of a 1995 production card (s20)](../sources.md#s20),
owner photos posted in [2021 (s108)](../sources.md#s108) and [2026 (s109)](../sources.md#s109),
and [ReactiveMicro scans (s128)](../sources.md#s128). Cable pinouts come from
[`Second Sight - Pinouts.doc`](../sources.md#s13).

## Contents

- [Production parts](#production-parts)
- [VGA cable](#vga-cable)
- [AppleColor RGB cable](#applecolor-rgb-cable)
- [J3 feature connector](#j3-feature-connector)
- [Connections the drawing leaves out](#connections-the-drawing-leaves-out)
- [Logic roles](#logic-roles)

## Production parts

| Ref (schematic) | Production part and marking | Prototype part | Notes |
|---|---|---|---|
| U18 | Z8S18020VSC on s20/s108/s109; Z8S18016VSC "9509 ZB" on s128 | Z180 PLCC | 20 MHz and 16 MHz grades respectively; each card has a 36 MHz can, giving 18 MHz after reset. That exceeds the s128 CPU grade. |
| (none in drawing) | Kyocera KXO-HC1-TS on s20/s108/s128; KXO-01-1 on s109; each marked 36.0000 MHz | not drawn | Production Z180 clock source; reset divide-by-two gives 18 MHz. |
| X1, C1, C2 | not fitted | 20 MHz crystal, 22 pF | |
| R38 | not fitted on s20/s108/s109 | MCLK-to-EXTAL link | Production uses the separate 36 MHz oscillator. No fitted R38 value enters production clock timing. |
| U10 | 27C1000 EPROM, label "Sequential Systems copyright (c) 1995 rev. 1.4-BEEF" | 27C1000 | dumped: [`ROM_BEEF.bin`](../sources.md#s25) |
| U11 | Toshiba TC551001FL-10 on s20/s108/s109; NEC "ES / D431000AGW-70L / 9035K9301" on s128 | "431000" | 128K x 8 SRAM; marked 100 ns and 70 ns grades respectively. NEC package also says ES; do not apply Toshiba timing guarantees to it. |
| U7 | Lattice 1016 in a PLCC-44 socket; s20 sticker "BE8C" with a red "2" hides its type; s128 label "ZORRO / BE8C / W6" also hides type/speed; s108/s109 read "pLSI 1016-60LJ" | pLSI1016 | The photos do not establish an ispLSI1016-90LJ on s20. The dump is [`isplsi1016_BE8C.bin`](../sources.md#s24); its filename is not a package-marking read. |
| U4, U12, U15, U17 | Three AMI 18CV8 on s20/s108/s109 or ICT 18CV8 on s128, plus National GAL16V8A | GAL16V8A x 4 | PLCC-20, soldered; per-card speed grades in [PLD markings](../02-board.md#pld-markings). |
| U2, U3, U5, U6 | Philips PC74HCT574T on s20/s108/s109; DV74HCT574A on s128 | SN74HCT574DW | Octal D flip-flops; preserve the actual part marking when selecting timing data. |
| U8 | Philips 74F125D on s20/s108/s109; F125 marking on s128 | 74125 | Quad tri-state buffer; the full manufacturer and package suffix on s128 are unknown. |
| U29 | 74ACT32 | 7432 | quad OR |
| U28 | Oak OTI087X "AA4058EBT0B T9429" | OAK087 | VGA controller |
| U30 | Oak OTI068 "308A M9438 D1-16" | OTI068 | clock synthesizer |
| X2 | Fitted crystal; 14.31818 MHz functional nominal | 14.318 MHz | The OTI-068 frequency table requires this nominal reference. The crystal's frequency/tolerance marking is not readable in s20, s108 or s109. |
| U31 | Bt481AKPJ "9320 PROTO 2" on s20/s108; Bt481AKPJ80 on s109; Bt481AKPJ110 on s128 | Bt478 | Production color chip (RAMDAC). PROTO 2 is a marking on the chip; the photographed PCB is a production board. |
| U16 | ST "93C466 9518" on s20/s108; ST "93C46M6 0720" on s109; ST "C46CM1 / 495" on s128 | NM93C46 | 93C46-family serial EEPROM. Keep the literal package markings with their photos. ROM 1.4 and the library never use it, so custom code can ([the serial EEPROM](../06-video.md#the-serial-eeprom)). |
| U20-U27 | eight ZIP DRAMs | 44256Z | 256K x 4 each, 1 MB total. The card came with 512 KB and takes 1 MB ([Second.Sight.Info.txt](../sources.md#s40)). Super Hi-Res needs the full 1 MB: ROM 1.4 builds its tables in the upper 512 KB (`build_320_tables`, `build_640_tables` in [superhires.asm](../../firmware/v1.4/src/superhires.asm)). |
| R2 | Dale "SOMC1603 330G", "DALE 9441" on s20/s108/s109; BI "9544 / 8A330 / UK MADE" on s128 | 22 ohm array | Dale: 33 ohm, 2 percent. BI 628A330: eight isolated 33 ohm resistors; the [BI marking table](../sources.md#s132) p4 maps 8A330 to that part. Standard tolerance is 2 percent, with 1 percent optional; the individual tolerance is unknown. The six Oak-bound traces and two unused lower terminals establish R2 identity on each card. |
| R32 | "202" on s20/s108; "103" on s109; unreadable blue face on s128 | 10K | IOCHRDY pull-up: 2.0 kohm on the [mirror](../sources.md#s20) and [2021](../sources.md#s108) cards; 10 kohm on [s109](../sources.md#s109); unverified on [s128](../sources.md#s128). Use the value for the card being modeled. |
| R3 | Apparent `103` on s109; covered on s20/s108 | [Value] | The marking beside the R3 silk supports 10 kohm on s109, at medium optical confidence. It is not the separate R22. |
| R22 | Fitted; `103` on s109, consistent but softer on s20 | not drawn | 10 kohm. Its lower pad visibly reaches Oak pin 24, SWSENSE; the opposite terminal enters a via whose destination is not visible. |
| JP1 (production silk) | Axial resistor across top and middle of a three-pad footprint; 47 ohm bands on s20 | not the clock JP1 | Beside SRAM. Other cards hide the bands; do not assign the drawing's MS1/GND endpoints to it. |
| TP1, TP2 | Open on s20/s108/s109; R19/R6 marked `103` | JP1, JP2 | Memory-clock straps; both high select 40 MHz. |
| C8 | s20: 22 uF/20 V; s108: 10 uF/25 V; s109: 22 uF/25 V | 22 uF | Own C8 silk beside the capacitor below X2; these are production variations. |
| C35 | 10 uF/25 V on s20/s108/s109 | not drawn | Bulk capacitor below the Lattice socket. |
| C37 | s20: 10 uF/25 V; s108: 22 uF/20 V; s109 marking unreadable | C33 is the schematic's DAC reservoir; its relation to C37 is unknown | C37 is marked beside the lower-left bulk capacitor. Do not assume it is C33. |
| R17, R26, C13, C32 | No bodies fitted where clearly visible | 22 ohm, 10K, .1uF, .1uF respectively | The circuit may still have another route; do not populate these from the drawing alone. |
| J1, J2 | 2-row headers labeled VGA and RGB | one BERG16 header | cables to DB-15 connectors |
| J3 | Right-angle 2 x 13 header at the lower board edge, below the OTI-087X | not drawn | VGA feature connector with IBM's pinout ([J3 feature connector](#j3-feature-connector)); the [manual](../sources.md#s16) mentions it (p28); no software uses it |

## VGA cable

| Header pin | Signal | DB-15HD pin |
|---|---|---|
| 1 | Blue | 3 |
| 2 | Monitor ID2 | 4 |
| 3 | Green | 2 |
| 4 | Green ground | 7 |
| 5 | Red | 1 |
| 6 | Red ground | 6 |
| 9 | Ground | 5 |
| 10 | HSYNC | 13 |
| 11 | Monitor ID0 | 11 |
| 12 | VSYNC | 14 |

## AppleColor RGB cable

| Header pin | DB-15 pin | Header pin | DB-15 pin | Header pin | DB-15 pin |
|---|---|---|---|---|---|
| 1 | 1 | 6 | 11 | 11 | 6 |
| 2 | 9 | 7 | 4 | 12 | 14 |
| 3 | 2 | 8 | 12 | 13 | 7 |
| 4 | 10 | 9 | 5 | 14 | 15 |
| 5 | 3 | 10 | 13 | 15 | 8 |

Header pin 5 carries composite sync to DB-15 pin 3. Inside the AppleColor RGB monitor,
this signal passes through a 2.2 kohm resistor (R6H2) to sync input transistor Q605
([A2M6014 schematic](../sources.md#s137), sheet 1). On the [ReactiveMicro card](../sources.md#s128),
the trace from J2 pin 5 runs up the back of the board, along the top edge past the EPROM,
and through a via just left of R39. On the front it runs under the EPROM socket. The trace
from U12 XSYNC (pin 18) runs under U8. The copper between these points is hidden by the
socket and U8, and the [bare-board photo](../sources.md#s21) is too blurry to resolve it.

## J3 feature connector

J3 is a VGA feature connector with IBM's pinout, the one VESA later adopted as the VESA
Feature Connector (VFC). It carries the 8-bit pixel bus, dot clock, blanking and both
syncs to an add-on board. The pixel bus also goes to the color chip. The manual
mentions it only once, in its FAQ: an overlay product "could be added via the Second Sight
card's 'feature connector'" (p28). The pin assignments below come from the production
board and IBM's pinout; Sequential's documents do not list them.

IBM's pinout names the two rows Y1-Y13 and Z1-Z13. On this card the Y row runs along
the board edge. Its left-end pad, seen from the front, is square; this table calls it card
pin 1 and gives the edge row the odd numbers, so Y13 is card pin 1 and Y1 is card pin 25,
at the right end. The Z row takes the even numbers the same way: Z13 is card pin 2 and Z1
is card pin 26.

| Card pin | IBM pin | Signal | On this card |
|---|---|---|---|
| 1 | Y13 | Ground | No trace on the back |
| 2 | Z13 | Not used | No trace on the back |
| 3 | Y12 | VSYNC | Back trace to J1 pin 12, the VGA header's VSYNC |
| 4 | Z12 | Not used | No trace on the back |
| 5 | Y11 | HSYNC | No trace on the back; R13, the HSYNC resistor, sits just left of J3 |
| 6 | Z11 | Ground | No trace on the back |
| 7 | Y10 | Blanking | Short back trace to a via just below R4 |
| 8 | Z10 | Ground | No trace on the back |
| 9 | Y9 | Dot clock | Back trace through a via beside R4, the pixel-clock resistor, on toward the Bt481 |
| 10 | Z9 | Ground | No trace on the back |
| 11 | Y8 | Pixel bit 7 | Via under the OTI-087X |
| 12 | Z8 | Ground | No trace on the back |
| 13 | Y7 | Pixel bit 6 | Via under the OTI-087X |
| 14 | Z7 | Not used | No trace on the back |
| 15 | Y6 | Pixel bit 5 | Via under the OTI-087X |
| 16 | Z6 | EDCLK (external dot clock) | Via under the OTI-087X |
| 17 | Y5 | Pixel bit 4 | Via under the OTI-087X |
| 18 | Z5 | ESYNC (external sync and blanking) | No trace on the back |
| 19 | Y4 | Pixel bit 3 | Via under the OTI-087X |
| 20 | Z4 | EVIDEO (external pixel data) | Via under the OTI-087X |
| 21 | Y3 | Pixel bit 2 | Via under the OTI-087X |
| 22 | Z3 | Ground | No trace on the back |
| 23 | Y2 | Pixel bit 1 | Via under the OTI-087X |
| 24 | Z2 | Ground | No trace on the back |
| 25 | Y1 | Pixel bit 0 | Via under the OTI-087X |
| 26 | Z1 | Ground | No trace on the back |

- Every signal pin in IBM's pinout has a back trace except HSYNC and ESYNC. No ground or
  unused pin has one. Front connections are under the header body, which hides them in
  every photo.
- The ten vias under the OTI-087X sit together inside its ring of pins at the lower-left
  corner, across from pins 33-49. The chip's pixel outputs P0-P7 are pins 25-28 and 30-33
  ([OTI-087 p24](../sources.md#s02)). In the schematic, those pins connect only to the
  Bt481.
- Only the photo of the bare board shows the copper under the chip, at about 0.35 mm per
  pixel. There the solder mask looks lighter, as it does over copper, just inside pads
  30-33, a little lighter inside pads 25-27, and dark inside the bottom pads 42-44 and
  48-49. A via just inside pad 28 hides that pad. The photo cannot show which via joins
  which pin.
- The front-side destinations of the EVIDEO and EDCLK vias are unknown. The OTI-087X
  has no inputs for them ([OTI-087 p24](../sources.md#s02)); its addendum removes the
  chip's built-in feature connector support.

IBM specifies the following signals for its video extension
([IBM VGA XGA reference](../sources.md#s68) pp2-110, 2-111):

- The pixel bits are the color chip's palette address. It latches them on the rising edge
  of the dot clock. Blanking low makes it output black.
- EVIDEO, ESYNC and EDCLK each enable a buffer on the VGA side and are pulled up to +5 V.
  An add-on that pulls one low drives that group itself: the pixel bits, the syncs and
  blanking, or the clock. An add-on that drives the clock must also drive the pixel bits.
- Timing: dot clock period at least 28 ns, high at least 7 ns and low at least 9 ns;
  pixel and blanking setup and hold at least 4 ns.

The OTI-087X pixel pins connect directly to the Bt481 in the drawing, with no buffer
that EVIDEO could switch off. J3's outputs follow IBM's pinout. Whether an add-on can
replace the pixel data is unknown.

Sources: back and front of [s128](../sources.md#s128); the bare board
[s21](../sources.md#s21); the [netlist](../../data/netlist/README.md); IBM's pinout as
quoted by [ePanorama](../sources.md#s135) and named VFC by
[AllPinouts](../sources.md#s136).

## Connections the drawing leaves out

Source: [netlist](../../data/netlist/README.md).

| Part or net | On the card |
|---|---|
| U8 gate C (pins 8-10) | Unused |
| Z180 serial, handshake, clock and E pins (46-49, 51-53, 55-57, 64) | Unused; the firmware writes only trace characters to ASCI0 |
| EPROM pin 1 (VPP) | VCC, for reading |
| Oak pins 19 and 20 | Unused in AT-bus mode; the EEPROM runs on CSEL2-0 |
| INT2 (Z180 pin 12) | Unused; the firmware never enables it |
| Bt481 RS2 | Tied low; the firmware uses the RS2-free command access |
| INT0 | No pull-up, so the Oak's retrace interrupt does not work as shipped ([INT0 has no pull-up](#int0-has-no-pull-up)) |
| R3 | Pull-up on the color chip's pin 23 |
| U16 | 93C46, 64 words of 16 bits |
| +5V and VCC | One supply; VAA is filtered through L6 |
| U13, U14, U19 | No ICs fitted; short blue wires bridge the center pads across these footprints on the photographed production cards. |

### INT0 has no pull-up

The Oak's vertical-retrace interrupt reaches Z180 INT0 over a line with no pull-up
resistor, so it does not work on a stock card. Adding a pull-up (for example 10 kOhm) from
Z180 pin 10 (/INT0) to +5 V makes it work. ROM 1.4 never uses INT0, and polling the
retrace bit ($3DA bit 3) gives the same timing with no change to the card.

- The drawing's /INT0 net joins only Z180 pin 10 and Oak pin 90 (CINT). Source:
  [netlist](../../data/netlist/README.md).
- CINT is an active-low, open-collector output: it can pull the line low but never drives
  it high. When it is not pulling low it is off, with at most 10 uA of leakage, and the
  databook describes no internal pull-up on any pin. The DC table lists it with the
  chip's other open-drain outputs (IOCHRDY, IO16, M16, ZEROWS). The two of those this card
  uses each have an external pull-up: R32 on IOCHRDY and R14 on ZEROWS. CINT has none.
  Sources: [OTI-087 databook](../sources.md#s02) p18 and DC characteristics (printed p57).
- The Z8S180's /INT0 is a plain input; neither the product specification nor the user
  manual describes an internal pull-up. Sources: [Z8S180 specification](../sources.md#s62)
  pin description; [Zilog UM0050](../sources.md#s39) pin description.
- Without a pull-up the line floats whenever CINT is idle, so an enabled INT0 can fire at
  random or stay low after the first interrupt.
- The firmware disables INT0. The Z180 comes out of reset with INT0 enabled (ITE0 = 1);
  ROM 1.4's first instructions clear it (ITC bits 0-2,
  [ROM_BEEF.asm:72-77](../sources.md#s27)). The ROM also contains `enable_int0` and
  `disable_int0` (lines 712-726), which nothing calls. Source:
  [Zilog UM0050](../sources.md#s39), INT0 after reset.
- The production board has no pull-up either:
  - Z180 pin 10 runs straight from its pad to a via with nothing on it. R15 beside it
    connects to pin 9 (NMI), as drawn.
  - At the Oak, no trace leaves pin 90 outward. The net runs inward under the chip, where
    the board without chips shows the footprint full of vias, and on to the back.
  - The back carries no parts except the 7M rework at the slot fingers
    ([production changes](../02-board.md#production-changes)).
  - R14 is ZEROWS, R15 NMI, R16 RES and R32 IOCHRDY. R22 is fitted: the front trace
    from its lower pad runs around C18 to Oak pin 24, SWSENSE. CINT is at pin 90.
    R22 reads `103` (10 kohm) on s109; its other end enters a via whose supply route
    is not shown. The R33-R37 footprints are empty where visible.

  Sources: [production front photo](../sources.md#s20) and
  [the board without chips](../sources.md#s21).
- A replica can include the pull-up with no effect on ROM 1.4. An emulator that delivers
  CINT on INT0 behaves like a card with the resistor added.

## Logic roles

| Ref | Clock | Role |
| --- | --- | --- |
| U4 | none (latches by feedback) | Z180 I/O decode for the card ports |
| U15 | HCLK = Z180 PHI, 18 MHz | Z180 memory decode, boot overlay, VRAM half switch, wait states |
| U17 | HCLK | Copy controller (bus request, SRAM write), resets |
| U12 | VCLK | AppleColor RGB: pixel clock divide, composite sync |
| U2 | ADIN | Apple data in: holds the byte the Apple wrote |
| U3 | BCLK | Apple data out: what $C0B0-$C0BF return |
| U5, U6 | CATCH | Caught Apple address, low and high byte |
| U8 |  | Open-collector style drivers for Apple RDY and IRQ; VCLK path |
| U29 |  | Combines Z180 /MREQ, /IORQ, /RD, /WR into memory and I/O strobes |
