# Board parts and cable connections

[Reference tables](README.md) | [Board](../02-board.md) | [Glossary](../glossary.md)

The parts on the production card, the cable pins, and the connections the prototype
drawing leaves out. The Prototype part column uses the schematic's names.

Sources: [production photos](../sources.md#s20), [`Second Sight - Pinouts.doc`](../sources.md#s13).

## Production parts

| Ref (schematic) | Production part and marking | Prototype part | Notes |
|---|---|---|---|
| U18 | Zilog Z8S18020VSC "Z180 MPU 9233" | Z180 PLCC | 20 MHz grade, run at 18 MHz |
| (none) | Kyocera KXO-HC1-TS 36.0000 MHz oscillator | not drawn | Z180 clock source on production |
| X1, C1, C2 | not fitted | 20 MHz crystal, 22 pF | |
| R38 | not fitted | 1 ohm, MCLK to Z180 EXTAL | prototype ran the Z180 from the 40 MHz memory clock |
| U10 | 27C1000 EPROM, label "Sequential Systems copyright (c) 1995 rev. 1.4-BEEF" | 27C1000 | dumped: [`ROM_BEEF.bin`](../sources.md#s25) |
| U11 | Toshiba TC551001FL-10 (128K x 8 SRAM, 100 ns) | "431000" | |
| U7 | Lattice ispLSI1016 in a PLCC-44 socket, sticker "BE8C" with a red "2" | pLSI1016 | dumped: [`isplsi1016_BE8C.bin`](../sources.md#s24) |
| U4, U12, U15, U17 | Three AMI 18CV8 parts and one National GAL16V8A | GAL16V8A x 4 | PLCC-20, soldered ([PLD markings](../02-board.md#pld-markings)) |
| U2, U3, U5, U6 | Philips PC74HCT574T | SN74HCT574DW | octal D flip-flops |
| U8 | Philips 74F125D | 74125 | quad tri-state buffer |
| U29 | 74ACT32 | 7432 | quad OR |
| U28 | Oak OTI087X "AA4058EBT0B T9429" | OAK087 | VGA controller |
| U30 | Oak OTI068 "308A M9438 D1-16" | OTI068 | clock synthesizer |
| X2 | 14.31818 MHz crystal | same | OTI-068 reference |
| U31 | Brooktree Bt481AKPJ "9320 PROTO 2" | Bt478 | color chip (RAMDAC), engineering sample |
| U16 | ST serial EEPROM marked "93C466 9518" | NM93C46 | ST93C46, temperature grade 6. ROM 1.4 and the library never use it, so custom code can ([the serial EEPROM](../06-video.md#the-serial-eeprom)). |
| U20-U27 | eight ZIP DRAMs | 44256Z | 256K x 4 each, 1 MB total. The card came with 512 KB and takes 1 MB ([Second.Sight.Info.txt](../sources.md#s40)). Super Hi-Res needs the full 1 MB: ROM 1.4 builds its tables in the upper 512 KB (`build_320_tables`, `build_640_tables` in [superhires.asm](../../firmware/src/superhires.asm)). |
| R2 | Dale "SOMC1603 330G", "DALE 9441" | 22 ohm array | 16-pin isolated network, 33 ohm, 2 percent; series resistors on the DRAM control lines ([production front photo](../sources.md#s20)) |
| R32 | chip resistor marked "202" | 10K | IOCHRDY pull-up, 2.0 kohm on production ([production front photo](../sources.md#s20)) |
| J1, J2 | 2-row headers labeled VGA and RGB | one BERG16 header | cables to DB-15 connectors |
| J3 | 2 x 13 header near the OTI-087 | not drawn | VGA feature connector, mentioned in the [manual](../sources.md#s16) (pp20, 28); no software uses it |

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
| U13, U14, U19 | Unfitted footprints |

### INT0 has no pull-up

The Oak's vertical-retrace interrupt reaches Z180 INT0 over a line with no pull-up
resistor, so it does not work on a stock card. Adding a pull-up (for example 10 kOhm) from
Z180 pin 10 (/INT0) to +5 V makes it work. ROM 1.4 never uses INT0, and polling the
retrace bit ($3DA bit 3) gives the same timing with no change to the card.

- The drawing's /INT0 net joins only Z180 pin 10 and Oak pin 90 (CINT). Source:
  [netlist](../../data/netlist/README.md).
- CINT is an active-low, open-collector output: it can pull the line low but never drives
  it high. The databook's DC table lists it with the chip's other open-drain outputs
  (IOCHRDY, IO16, M16, ZEROWS). The two of those this card uses each have an external
  pull-up: R32 on IOCHRDY and R14 on ZEROWS. CINT has none. Sources:
  [OTI-087 databook](../sources.md#s02) p18 and DC characteristics (printed p57).
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
  - The back carries no parts except the M2B0 pull-down by the slot fingers.
  - Every fitted resistor near either end belongs to another drawn net (R14 ZEROWS, R15
    NMI, R16 RES, R32 IOCHRDY), and the footprints R22 and R33-R37 are empty.

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
