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

The fitted parts: [production parts](reference/board-connections.md#production-parts).

### PLD markings

The photo shows two AMI 18CV8-10 parts marked "9409VAA 18CV810", one AMI 18CV8-15
marked "9504VPR 18CV815", and one National GAL16V8A-15LVC marked
"S9230AD 81466 7001A". Source: [production front photo](sources.md#s20).

U12 and U17 must be 18CV8s, as drawn ([why](07-glue-logic.md#the-parts)). Resistor
positions identify U12 as the 18CV8-10 beside R17 and U17 as the 18CV8-15 beside
R1/R16. Source: [netlist](../data/netlist/README.md).

The reworked GAL16V8A is U4: one of its wires reaches the clock of the 74HCT574 marked
723770ME. The remaining red-dot 18CV8-10 is U15. The rework wires run from U4 to that
latch's clock, from U15 to Oak pin 70 (the half switch), and from 7M to Lattice pin 33
(Y2): [The parts](07-glue-logic.md#the-parts), [video window](06-video.md#the-video-ram-window),
[Lattice clocks](04-capture-logic.md#clocks-and-phase).

## Production changes

1. **Color chip:** Bt481 (15/16/24-bit capable) instead of Bt478 (8-bit only).
2. **Z180 clock:** a 36 MHz oscillator; the crystal parts and R38 are unfitted.
3. **PLDs:** three AMI 18CV8 and one GAL16V8A instead of four GAL16V8A.
4. **Rework**:
   - two blue wires on the GAL16V8A;
   - one blue wire on the Lattice socket;
   - one blue wire on the back near the EPROM;
   - on the back, a resistor and another small part wired near the slot fingers, about
     10 fingers from the front end (pins 34-36, plus or minus one, counting pin 26 at the
     front end);
   - a resistor soldered into the JP1 position near the SRAM. Source: [production photo](sources.md#s20).
5. **Lattice pin 33 (Y2):** a stub on the [prototype drawing](sources.md#s26), but the fuse map uses it as a
   clock, wired to 7M on the production board ([Lattice clocks](04-capture-logic.md#clocks-and-phase)).
6. **M2B0 pull-down:** the Lattice only catches writes while M2B0 is low, and Apple
   tri-states M2B0 outside a 140 ns window. So the line needs a pull-down, and the
   slot-finger resistor is it: 1-10 kOhm holds the line low against input leakage without
   loading Apple's driver; a replica uses 4.7 kOhm. Source: [Apple TN #68](sources.md#s43).
7. **Color chip RS2 grounded:** the firmware reaches Command Register A with the
   "read the pixel mask four times" sequence. That method exists for boards with RS2
   grounded ([Bt481A datasheet](sources.md#s36)), and the firmware also writes the pixel mask at $3C6.
   With RS2 on HA2 as drawn, every $3C6 access would hit Command Register A instead.
8. **VGA address bits:** the firmware reaches both halves of the 1 MB video RAM through
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
  The firmware learns the monitor type from bit 4 of $3C2 (the OTI-087 sense input), and the
  manual says the card detects which cable is attached: the cable header sets the sense
  input ([monitor type](06-video.md#outputs-and-the-monitor-type)).
- **Memory clock select:** two 2-pin footprints next to the OTI-068, with 10K pull-ups (R19,
  R6), drive MS1/MS0. Both are open on the photographed board, which gives 40 MHz.

## Connectors and cables

- The prototype has one 16-pin header J1 (BERG16): red, green and blue on pins 5, 3 and 1,
  HSYNC and VSYNC near pins 10/12, the rest ground. Source: schematic sheet 5.
- Production has two headers labeled VGA and RGB. The manual: "do NOT attach both types of
  cables simultaneously".
- Cable wiring, from [`Second Sight - Pinouts.doc`](sources.md#s13): the
  [VGA cable](reference/board-connections.md#vga-cable), header pin to DB-15HD pin, and the
  [AppleColor RGB cable](reference/board-connections.md#applecolor-rgb-cable), a straight
  ribbon crimped to a DB-15.
- The slot pins the card uses: [Apple slot pins](reference/slot-pins.md).

## Pin-level netlist

[`data/netlist/`](../data/netlist/README.md) holds every pin of all five prototype
sheets: 91 parts, 970 pin positions, 319 nets, each IC pin checked against its datasheet.
The drawing leaves out [17 connections](reference/board-connections.md#connections-the-drawing-leaves-out).

The connections that explain how the card works:

- **Bus hand-off:** BACK (Z180 BUSACK) enables U5/U6 onto the Z180 address bus and goes to
  U4, U15 and U17. U17 drives BREQ and the write strobe HWR.
- **INT1** joins U7 pin 38 to Z180 pins 11 (INT1) and 58 (DREQ1).
- **RTS0** (Z180 pin 45) goes to U15 pin 9: the boot overlay control.
- **WAIT** (Z180 pin 5) comes from U15 pin 15, and U15 takes the OTI-087's IOCHRDY.
- **OTI-087 high address inputs:** pin 70 (LA19) = HA19, pin 71 (LA20) = VGAIO from U15,
  pins 72-74 (LA21-23) = ground.
- **Not connected on the drawing:** the slot's 7M (pin 36) and PHASE 0 (pin 40) are drawn as
  labels that join nothing, and so are U7's CLK (pin 11) and CPU (pin 37) inputs. The OTI-087
  sense input SWSENSE (pin 24) is also a lone label. Clock and sense routes:
  [Lattice clocks](04-capture-logic.md#clocks-and-phase), [monitor type](06-video.md#outputs-and-the-monitor-type).

---

Previous: [01 Overview](01-overview.md) | [Reference index](../README.md) | Next: [03 Apple interface](03-apple-interface.md)
