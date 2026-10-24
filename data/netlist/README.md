# Second Sight schematic pin-level reference

Every pin on all five sheets of the [prototype schematic](../../docs/sources.md#s26): 91
parts, 970 pin positions and 319 nets, with hidden supplies, omitted pins and the DRAM key
position. The drawing leaves out
[17 connections](../../docs/reference/board-connections.md#connections-the-drawing-leaves-out).
Production changes: [Board](../../docs/02-board.md#production-changes).

## Contents

- [Files](#files)
- [How to read the data](#how-to-read-the-data)
- [Unresolved and blurred connections](#unresolved-and-blurred-connections)
- [Datasheet comparison and every type of disagreement](#datasheet-comparison-and-every-type-of-disagreement)
- [Oak address and DRAM wiring](#oak-address-and-dram-wiring)
- [Production differences](#production-differences)
- [Netlist verification](#netlist-verification)

## Files

| File | Contents |
|---|---|
| [netlist.csv](netlist.csv) | One row per part pin, with printed symbol name, net, confidence, and qualifications |
| [nets.csv](nets.csv) | Exact inverse: net to semicolon-separated `refdes.pin` members |
| [bom.csv](bom.csv) | All schematic parts, packages, and photo-based production identifications |
| [pinout_checks.csv](pinout_checks.csv) | All 756 pins of the 26 schematic ICs compared with datasheet package pinouts |
| [pinout_differences.csv](pinout_differences.csv) | Every nonmatching, omitted, unnamed, or differently notated symbol pin |
| [bt478_bt481_pin_changes.csv](bt478_bt481_pin_changes.csv) | All 44 RAMDAC positions compared between the prototype and production device families |
| [uncertain_pins.csv](uncertain_pins.csv) | All medium- and low-confidence entries, including conventional passive numbering and hidden power |
| [singleton_nets.csv](singleton_nets.csv) | Named nets with just one pin; useful for locating unrepresented connections |
| [SOURCES.md](SOURCES.md) | Datasheets used for the pinout comparison, with links and pages |
| [audit.json](audit.json) | Machine-readable verification results and output hashes |

Three scripts make these files. They use only the Python standard library and write into
this folder:

- [build_netlist.py](../../tools/netlist/build_netlist.py) holds the transcription and
  writes the netlist.
- [check_pinouts.py](../../tools/netlist/check_pinouts.py) holds datasheet pin maps,
  entered separately, and compares every IC pin with them.
- [audit_netlist.py](../../tools/netlist/audit_netlist.py) checks the exported files and
  writes the review lists.

Run them from the repository root:

```text
python tools/netlist/build_netlist.py
python tools/netlist/check_pinouts.py
python tools/netlist/audit_netlist.py
```

## How to read the data

Identical signal labels join across schematic sheets. A thick bus outline groups
signals visually; each individual label defines its electrical net. Datasheets supply
package functions for pins omitted from the drawing.

- `pin_name` keeps the symbol text as printed, older names included. Blank means no name
  is printed or the pin is omitted; the datasheet name is in `pinout_checks.csv`. The CSV
  names carry no polarity; the drawing's bubbles and overbars show it.
- `N_<ref>_<pin>` identifies an unlabeled wire shared by the listed endpoints; it does not name the signal's function.
- `NC_<ref>_<pin>` identifies one open symbol stub or a datasheet NC/key position; the
  note says which. It says nothing about copper on the production board. Open pins are
  never joined into one common `NC` net.
- `UNRESOLVED_<ref>_<pin>` means the drawing leaves the connection out or its label
  cannot be read. Each is a separate net: not ground, and not a proven no-connect.
- Confidence: `high` is a connection read straight off the drawing. `medium` is a hard
  label reading, a hidden supply rail, a photo reading, or an assigned passive pin number.
  `low` is an unresolved connection. The totals are 763 high, 190 medium and 17 low.
- Two-terminal passives and jumpers have no printed pad numbers. Their `1`/`2` are
  assigned here, not read from the board. Polarized C8/C33 use `1` for positive; D1 uses
  `1` for the cathode. Crystal pin numbers are arbitrary.
- Hidden digital supplies use `VCC`/`GND`; hidden DAC supplies use `VAA`/`GND`, all at
  medium confidence. `+5V` and `VCC` are separate printed names; they are one supply
  ([connections the drawing leaves out](../../docs/reference/board-connections.md#connections-the-drawing-leaves-out)). `VAA` follows ferrite L6.
- Resistors, ferrites, crystals and capacitors stay components between nets; the inverse
  table does not short their ends. No jumper setting is assumed.
- The gates of U8 and U29 are combined into one package each. U8's sheet field is `1;4`.
  The eight ZIP DRAMs have 20 numbered positions; position 10 is the package's NC/key
  position, so 970 positions are not 970 metal leads.

The schematic's own corrections are included: **U10 pin 32 is VCC** (sheet 2 says it was forced into the original netlist), and **U31 pin 20 is VAA** (sheet 5 explicitly requests that connection despite the omitted symbol pin).

## Unresolved and blurred connections

These labels are blurred or hard to read. The last column says what confirms each
reading. Connections the drawing leaves out entirely:
[Board connections](../../docs/reference/board-connections.md#connections-the-drawing-leaves-out).

| Pin | Transcribed label | Confirmed by |
|---|---|---|
| U2.1 | BEN | Matches U4.16 |
| U7.2 | AD6 | PAGE2 loads from C068 bit 6 |
| U7.35 | RESET | [reset wiring](../../docs/04-capture-logic.md#reset-and-power-on) |
| U17.12 | RESN | Separate from RESET on the drawing |
| U17.15 | HA19 | The scan's last digit is blurred; the [copy path](../../docs/07-glue-logic.md#u17-the-copy-controller-and-resets) requires HA16 |
| U28.71 | VGAIO | Matches U15.19 |

Thirteen named nets have only one endpoint. What they connect to on the card:
[connections the drawing leaves out](../../docs/reference/board-connections.md#connections-the-drawing-leaves-out).

Render the schematic with `tools/pdf_pages.py` (see [13 Method](../../docs/13-method.md)). The `source` column in `pinout_checks.csv` names local copies of the datasheets; [SOURCES.md](SOURCES.md) maps each name to its download address.

## Datasheet comparison and every type of disagreement

The pin comparison contains 469 normalized matches, 179 aliases/notation differences, 81 omitted symbol names, 21 unnamed symbol pins, one substantive label disagreement, one legacy CPU name and four Oak alternate-function label differences. Comparison ignores punctuation and case; the netlist preserves the printed names.

| Device / pins | Difference and treatment |
|---|---|
| U30.6, OTI-068 | Symbol says `STROBE`; April 1993 pinout says `NC`. The drawing leaves the stub open. |
| U18.65 | Prototype Z180 symbol says `LIR`; Z8S180 PLCC pinout says `M1`. The drawing leaves it open. |
| U28.19, .20, .23 | Symbol `SSA(19)/GA20`, `SSA(18)/SRDY1`, `SSA(17)/-LBSEL` differs from the checked OTI-087 descriptions `EPCLK/GA20`, `EPDATA/SRDYI`, `MXPCLK/LBSEL`. The active function depends on the selected bus mode. |
| U28.47 | Symbol alternate text is read `-EEPCS/-ATDEN`; databook says `EEPCS/ATOEH`. The alternate text is blurred, so it is not evidence of a different chip. |
| U28.68-74 | Schematic calls these `SA17`-`SA23`; ISA pin diagram calls them `LA17`-`LA23`. They are the same numbered high-address inputs. |
| U2/U3/U5/U6.1 | `OC` versus `OE`, same active-low output-enable pin. |
| U7.14, .24, .33, .36 | Symbol uses IN0, IN1, Y2, IN2; datasheet also lists SDI, SDO, SCLK, MODE alternate functions respectively. |
| U18.33, .50, .54, .62, .63 | A18/TOUT, CKA0/DREQ0, CKA1/TEND0, IORQ, MREQ versus shortened A18, DREQ0, TEND0, IOE, ME. |
| U4/U12/U15/U17 | I0/CK, I1-I9, F0-F7 versus datasheet I/CLK, I, I/OE, I/O/Q. Same numbered GAL16V8 package positions. This does not establish AMI fuse or timing equivalence. |
| U10 data pins | `IO0`-`IO7` versus Macronix `Q0`-`Q7`. Checked **27C1000**, not 27C1001/27C010: OE is pin 2 and A16 is pin 24. |
| U11 data/control | Symbol `431000`, IO0-IO7 and WE; checked production-compatible Toshiba TC551001FL has IO1-IO8 and R/W on the same ordered pins. |
| U20-U27 data/control | Schematic IO0-IO3 and WE versus Toshiba IO1-IO4 and WRITE. ZIP position 10 is NC/key. |
| U28 other labels | BD0-BD7 include local-bus alternates in the symbol; the ISA diagram lists BD0-BD7. HLDA also has MASTER, CSEL0-2 have EEPROM functions, MA01(0) has CASB, CASA has WE, and WEA-D have CAS0-3 alternates. `VSS00`-`VSS06`, `VSS0/1`, and `-ROMEN/PROCLK` use different spelling from VSSO0-6, VSSI0/1, ROMENL/PROCLK. |
| U30.3, .10 | Symbol distinguishes AVSS/DVSS; checked pinout labels both VSS. |
| Hidden/unnamed positions | For hidden supplies, DRAM key positions, EEPROM NCs, omitted CPU pins and nameless gate/header terminals, a blank pin_name means no name is printed; the datasheet function is in `pinout_checks.csv`. |

Two source documents contradict themselves: the Bt481A COMP/SENSE* pins and the
SN74HCT574 pin-function table. [SOURCES.md](SOURCES.md) gives the pages and the reading
used.

## Oak address and DRAM wiring

Sheet 4 connects these Oak high-address inputs:

| U28 pin | Printed name | Transcribed net |
|---|---|---|
| 70 | SA19 | HA19 |
| 71 | SA20 | VGAIO, medium-confidence label; agrees with U15.19 |
| 72-74 | SA21-SA23 | GND |

The DRAM data mapping is not monotonic by reference designator:

| DRAM | Data bits in IO0-IO3 order | Address bus | Write enable |
|---|---|---|---|
| U20 | MD0-MD3 | MA0-MA8 | WEA |
| U21 | MD8-MD11 | MA0-MA8 | WEA |
| U22 | MD16-MD19 | MA0-MA8 | WEC |
| U23 | MD20-MD23 | MA0-MA8 | WEC |
| U24 | MD4-MD7 | MA0A-MA8A | WEB |
| U25 | MD12-MD15 | MA0A-MA8A | WEB |
| U26 | MD24-MD27 | MA0A-MA8A | WED |
| U27 | MD28-MD31 | MA0A-MA8A | WED |

All eight DRAMs use CASA, RASL, and grounded OE. Oak MA01 feeds MA0-MA8; MA23 feeds
MA0A-MA8A.

R2 has isolated resistor pairs 1-16, 2-15, 3-14, 4-13, 5-12, 6-11, 7-10, and 8-9.
Its first two pairs are unused; the others carry CASA, RASL, WEB, WEA, WED, and WEC.

The configuration pull resistors are:

- R39: MD1/2/4 high, with two spare branches.
- R21: MD3/5/10/11/15 low.
- R27: MD8 high.
- R26: MD9 low.

Unstrapped bits get no default value here.

## Production differences

The schematic is the 1994 prototype; the photograph shows the later production board.
The CSV files describe the prototype. What production changes:
[Board](../../docs/02-board.md#production-changes).

- [RAMDAC U31](#ramdac-u31)
- [RS2 / U31.19](#rs2--u3119)
- [CPU clock](#cpu-clock)
- [U7 Y2 / pin 33](#u7-y2--pin-33)
- [M2B0 bodge](#m2b0-bodge)
- [GALs](#gals)
- [J2 / J3](#j2--j3)
- [U11 SRAM](#u11-sram)
- [U16 EEPROM](#u16-eeprom)
- [Logic families](#logic-families)
- [R2 / R32 / JP1](#r2--r32--jp1)
- [Other footprints](#other-footprints)

### RAMDAC U31

Photo: **Bt481AKPJ PROTO2**, replacing the drawn Bt478. Datasheet pin 1 changes from NC to
SENSE*; pin 20 changes from VAA to TRUECOL*.

A replica with a Bt481 must not tie pin 20 to VAA as the prototype drawing says: on the
Bt481 that pin is TRUECOL*. The other pins have the same functions
([bt478_bt481_pin_changes.csv](bt478_bt481_pin_changes.csv)), but the chips work
differently. The card's engineering sample:
[Bt481 color modes](../../docs/reference/bt481-modes.md).

### RS2 / U31.19

The prototype connects HA2. Production RS2 is grounded, as required by the firmware's
four-read command sequence and ordinary pixel-mask writes ([DAC access](../../docs/06-video.md#bt481-color-chip)).

### CPU clock

Photo markings identify Z8S18020VSC and a 36.000 MHz KXO-HC1 oscillator. X1/C1/C2/R38 are
unfitted.

The production oscillator feeds EXTAL; the Z180 divides it to 18 MHz after reset ([clock path](../../docs/05-z180.md#processor-and-clock)).

### U7 Y2 / pin 33

The prototype shows a stub. On production it is wired to 7M
([Lattice clocks](../../docs/04-capture-logic.md#clocks-and-phase)).

### M2B0 bodge

The resistor and wire on the back are the M2B0 pull-down. Why the card needs it:
[Copying video writes](../../docs/04-capture-logic.md#copying-video-writes). Its value:
[production changes](../../docs/02-board.md#production-changes).

### GALs

Production uses three AMI 18CV8s and one National GAL16V8A
([PLD markings](../../docs/02-board.md#pld-markings),
[what each PLD does](../../docs/07-glue-logic.md)).

### J2 / J3

Production has an additional RGB header J2 (2x8 in photo) and a 2x13 J3 header. Neither is
drawn.

The VGA and RGB outputs: [outputs and the monitor type](../../docs/06-video.md#outputs-and-the-monitor-type).
J3: [production parts](../../docs/reference/board-connections.md#production-parts). Pin by
pin: [connectors and cables](../../docs/02-board.md#connectors-and-cables).

### U11 SRAM

Photo reads **TC551001FL-10**, whereas the symbol says 431000. Toshiba's 32-pin map
agrees with the transcribed address/data/control positions.

### U16 EEPROM

Photo reads **93C466**, ST logo, and **9518**: an ST93C46, temperature grade 6, 64 words
of 16 bits. What it holds and how custom code can use it:
[the serial EEPROM](../../docs/06-video.md#the-serial-eeprom).

### Logic families

Photo identifies PC74HCT574T latches, 74F125, and ACT32; symbols use SN74HCT574DW, 74125, and
7432. Pin agreement does not establish equal thresholds, drive, or delay.

### R2 / R32 / JP1

Front photo: R2 reads `SOMC1603 330G`, `DALE 9441`, a Dale 16-pin isolated network, 33 ohm, 2
percent, versus drawn 22 ohm. R32 reads `202`, 2.0 kohm versus drawn
10K.

JP1 contains an axial resistor on the production board. Source: [production photo](../../docs/sources.md#s20).

### Other footprints

Production footprints near the headers are absent from the [prototype schematic](../../docs/sources.md#s26).

## Netlist verification

The scripts check:

- Complete numbered package positions, unique pin identities and BOM membership.
- Exact agreement between pin-to-net and net-to-pin tables.
- Separate nets for no-connect and omitted pins.
- Datasheet comparisons for every IC pin and UTF-8 text integrity.

Results and output hashes are in [audit.json](audit.json). Connections the drawing leaves out:
[Board connections](../../docs/reference/board-connections.md#connections-the-drawing-leaves-out).

[Board chapter](../../docs/02-board.md) | [Data index](../README.md) | [Reference index](../../README.md)
