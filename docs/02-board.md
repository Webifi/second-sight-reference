# 02 Board: parts, revisions, clocks, connectors

[Reference index](../README.md) | [Glossary](glossary.md) | [Reference tables](reference/README.md)

The [prototype schematic](sources.md#s26) and the photographed production card differ in
wiring and parts. Every prototype pin connection is in the [netlist](../data/netlist/README.md).

## Contents

- [Two revisions, one schematic](#two-revisions-one-schematic)
- [Production parts](#production-parts)
- [Production changes](#production-changes)
- [Clocks](#clocks)
- [Jumpers](#jumpers)
- [Connectors and cables](#connectors-and-cables)
- [Pin-level netlist](#pin-level-netlist)

## Two revisions, one schematic

- **Prototype (schematic only).** "discQUEST VGA Board", Rev x, dated 4/28/94, 5 sheets.
  Source: [schematic title block](sources.md#s26).
  - Sheet 1: Apple slot connector, latches U2/U3/U5/U6, Lattice U7, buffer U8.
  - Sheet 2: Z180 (U18), EPROM (U10), SRAM (U11), GALs U4/U15/U17, OR gates U29.
  - Sheet 3: eight 44256 DRAMs and the OTI-087 setup straps.
  - Sheet 4: OTI-087 (U28), OTI-068 (U30), 93C46 EEPROM, GAL U12, clock buffer.
  - Sheet 5: Bt478 color chip (U31) and the video connector.
- **Production (photos only).** Silkscreen "COPYRIGHT 1995". Source:
  [production photos](sources.md#s20).

## Production parts

For the fitted parts, see [production parts](reference/board-connections.md#production-parts).

### PLD markings

Labeled resistors and the bare-board layout identify the PLD positions on the
photographed production cards.

| Position | [1995 production card (s20)](sources.md#s20) | [Photo posted 2021 (s108)](sources.md#s108) | [Photo posted 2026 (s109)](sources.md#s109) | [ReactiveMicro scan (s128)](sources.md#s128) |
|---|---|---|---|---|
| U12, beside R17 | AMI 9409VAA 18CV810 (-10) | AMI 18CV8-10 | AMI 9504VPR 18CV815 (-15) | ICT 18CV8, 06771 / 631FA-15 |
| U15, red dot between SRAM/latches and oscillator | AMI 9409VAA 18CV810 (-10) | AMI 18CV8-10 | AMI 9504VPR 18CV815 (-15) | ICT PEEL18CV8J-15 |
| U17, beside R1/R16/R15 | AMI 9504VPR 18CV815 (-15) | AMI 18CV8-10 | AMI 9327VA? / 18CV8; speed suffix under white paint | ICT PEEL18CV8J-15 |
| U4, reworked GAL below oscillator | National GAL16V8A-15LVC | National GAL16V8A-15LVC | GAL16V8A; suffix partly obscured | National GAL16V8A-15LVC |

The s20 card has PLDs of different speed grades. On s109, U12 and U15 are from lot
9504VPR, while U17 is from a different lot, marked 9327VA?. U17's speed grade is
unknown. The [AMI PEEL18CV8 datasheet](sources.md#s131) (February 1993, printed
pp11, 20-21) specifies 5, 7.5, 10, 15 and 25 ns grades, but does not relate the lot
suffix to speed. Whether U17 is a 15 ns or slower part is unknown. The PREVIEW table
lists specifications rather than shipments. Use the grades for the particular card when
modeling its timing.

U12 and U17 must be 18CV8s, as drawn ([why](07-glue-logic.md#the-parts)). Resistor
positions identify U12 beside R17 and U17 beside R1/R16; use the per-card speed
grades above. Source: [netlist](../data/netlist/README.md).

The reworked GAL16V8A is U4. One wire connects it to the clock of the 74HCT574 marked
723770ME on s20. The remaining red-dot 18CV8 is U15; its grade varies by card. Other
rework wires connect U15 to Oak pin 70 (the half switch) and the 7M slot finger to the
Lattice socket: [The parts](07-glue-logic.md#the-parts), [video window](06-video.md#the-video-ram-window),
[Lattice clocks](04-capture-logic.md#clocks-and-phase).

## Production changes

1. **Color chip:** Bt481 (15/16/24-bit capable) instead of Bt478 (8-bit only).
2. **Z180 clock:** a 36 MHz oscillator; the crystal parts and R38 are unfitted.
3. **PLDs:** three AMI or ICT 18CV8 parts and one GAL16V8A instead of four GAL16V8A; see the per-card [markings](#pld-markings).
4. **Rework**:
   - two blue wires on the GAL16V8A;
   - one blue wire on the back near the EPROM;
   - a resistor across the top and middle pads of the three-pad JP1 position near the
     SRAM; its yellow-violet-black bands read 47 ohm on s20, while the bands are hidden
     on s108, s109 and s128; this is not the drawing's two-pad clock jumper JP1;
   - the 7M wire to the Lattice socket:
     - On the back, a resistor and a part in a heat-shrink sleeve are soldered in series
       to the finger for slot pin 36 (7M), the 11th finger from the Lattice end of the
       card. A blue wire runs from them to a via at that end of the card.
     - On the front, a blue wire runs from that via along the side of the Lattice socket
       that faces the end of the card. It goes under the socket's rim beside pins 25-27,
       near the corner where the pin 29-39 side begins. The solder point is hidden under
       the socket in the photographs.

   Sources: production photos [back](sources.md#s18) and [front](sources.md#s20), the
   [2021 owner's photos](sources.md#s108), the [2026 Applefritter photo](sources.md#s109).
5. **Lattice pin 33 (Y2):** a stub on the [prototype drawing](sources.md#s26), but the fuse
   map clocks the M2B0 sampling window on it, and only 7M fits that window's timing
   ([Lattice clocks](04-capture-logic.md#clocks-and-phase)). Pin 33 is the 5th pin in from the
   corner where the 7M wire goes under the socket, and the only pin on that side that
   needs 7M.
6. **Color chip RS2 grounded:** the firmware reaches Command Register A with the
   "read the pixel mask four times" sequence. That method exists for boards with RS2
   grounded ([Bt481A datasheet](sources.md#s36)), and the firmware also writes the pixel mask at $3C6.
   With RS2 on HA2 as drawn, every $3C6 access would hit Command Register A instead.
7. **VGA address bits:** the firmware reaches both halves of the 1 MB video RAM through
   one 512 KB window. Production wires Oak LA19 to the half switch and LA20 to the linear
   flag; see [Video](06-video.md#the-video-ram-window).

## Clocks

The clock wiring and the OTI-068 selections are in
[Clock selections](reference/clocks.md#board-clock-connections). The "20 MHz processor" in
Sequential's documents matches the prototype (40 MHz MCLK through R38, divided by 2); the
production board runs at 18 MHz.

## Jumpers

- **TP3 (monitor type):** the manual says "set jumper TP3 appropriately. For an AppleColor
  RGB monitor, the jumper should be removed. For a VGA monitor, the jumper should be in
  place." On the [prototype drawing](sources.md#s26), TP3 grounds the color chip's SETUP pin (blank pedestal).
  The firmware reads the monitor type from $3C2 bit 4, the OTI-087X sense input. The
  cable header sets this input, allowing the card to detect which cable is attached ([monitor type](06-video.md#outputs-and-the-monitor-type)).
- **Memory clock select:** TP1 and TP2 beside the OTI-068 drive MS1 and MS0. R19 and R6
  are marked `103` (10 kohm). Both clock straps are open on the s20, s108, s109 and s128 cards,
  selecting 40 MHz. On the prototype schematic the straps are JP1 and JP2. The production JP1
  beside the SRAM is a separate three-pad footprint with a resistor across its top
  and middle pads; it is not a memory-clock shunt.

## Connectors and cables

- The prototype has one 16-pin header J1 (BERG16): red, green and blue on pins 5, 3 and 1,
  HSYNC and VSYNC near pins 10/12, the rest ground. Source: schematic sheet 5.
- Production has two headers labeled VGA and RGB. The manual warns: "do NOT attach both types of
  cables simultaneously".
- The production board adds J3, a right-angle 2 x 13 header on the bottom edge below the
  OTI-087X. It is a VGA feature connector with IBM's standard pinout
  ([J3 feature connector](reference/board-connections.md#j3-feature-connector)).
- Cable wiring, from [`Second Sight - Pinouts.doc`](sources.md#s13): the
  [VGA cable](reference/board-connections.md#vga-cable), header pin to DB-15HD pin, and the
  [AppleColor RGB cable](reference/board-connections.md#applecolor-rgb-cable), a straight
  ribbon crimped to a DB-15.
- The card's slot connections are listed in [Apple slot pins](reference/slot-pins.md).

## Pin-level netlist

[`data/netlist/`](../data/netlist/README.md) holds every pin of all five prototype
sheets: 91 parts, 970 pin positions, 319 nets, each IC pin checked against its datasheet.
The drawing leaves out [17 connections](reference/board-connections.md#connections-the-drawing-leaves-out).

- **Bus hand-off:** BACK (Z180 BUSACK) enables U5/U6 onto the Z180 address bus and goes to
  U4, U15 and U17. U17 drives BREQ and the write strobe HWR.
- **INT1** joins U7 pin 38 to Z180 pins 11 (INT1) and 58 (DREQ1).
- **RTS0** (Z180 pin 45) goes to U15 pin 9: the boot overlay control.
- **WAIT** (Z180 pin 5) comes from U15 pin 15, and U15 takes the OTI-087X's IOCHRDY.
- **OTI-087X high address inputs:** pin 70 (LA19) = HA19, pin 71 (LA20) = VGAIO from U15,
  pins 72-74 (LA21-23) = ground.
- **Not connected on the drawing:** the slot's 7M (pin 36) and PHASE 0 (pin 40) are drawn as
  labels that join nothing, and so are U7's CLK (pin 11) and CPU (pin 37) inputs. The OTI-087X
  sense input SWSENSE (pin 24) is also a lone label. Clock and sense routes:
  [Lattice clocks](04-capture-logic.md#clocks-and-phase), [monitor type](06-video.md#outputs-and-the-monitor-type).

---

Previous: [01 Overview](01-overview.md) | [Reference index](../README.md) | Next: [03 Apple interface](03-apple-interface.md)
