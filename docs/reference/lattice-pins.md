# Lattice ispLSI1016 pin reference

[Reference tables](README.md) | [Glossary](../glossary.md)

Every pin of U7 (PLCC-44), with its schematic net name and its job. U7 takes in the Apple
address bus, two Apple data bits and the bank and timing signals. It drives the copy, the
events and RDY, and shares four Z180 data lines for status and configuration.

Sources: schematic sheet 1, the [netlist](../../data/netlist/README.md), and U7's
[design source](lattice-source.md).

## Contents

- [Pin table](#pin-table)
- [Notes on individual signals](#notes-on-individual-signals)
- [Capture bank terms](#capture-bank-terms)
- [Capture bank cases](#capture-bank-cases)
- [Machine-readable copy](#machine-readable-copy)

## Pin table

Directions come from the fuse map, except for the supply and programming pins.

<!-- csv: data/tables/u7-isplsi1016-pins.csv -->
| PLCC pin | Lattice pin name | Net on drawing | Direction | Meaning |
|---|---|---|---|---|
| 1 | GND | GND | power | Ground |
| 2 | IN3 | AD6 | input | Apple data bit 6. The label is blurred; the fuse map loads PAGE2 from this pin on $C068 (STATEREG) writes, and PAGE2 is bit 6 ([AD6 and AD4](#ad6-and-ad4)). |
| 3 | IO24 | AA00 | input | Apple address A0 |
| 4 | IO25 | AA01 | input | Apple address A1 |
| 5 | IO26 | AA02 | input | Apple address A2 |
| 6 | IO27 | AA03 | input | Apple address A3 |
| 7 | IO28 | AA04 | input | Apple address A4 |
| 8 | IO29 | AA05 | input | Apple address A5 |
| 9 | IO30 | AA06 | input | Apple address A6 |
| 10 | IO31 | AA07 | input | Apple address A7 |
| 11 | Y0 | CLK | clock | Softswitch clock, falling edge; 7M or Q3 both meet its timing ([clocks](../04-capture-logic.md#clocks-and-phase)) |
| 12 | VCC | VCC | power | Logic supply |
| 13 | ISPEN | (no connection) | programming | In-system programming enable, not connected on the drawing |
| 14 | IN0 | M2B0 | input | IIgs Mega II bank bit, from slot pin 35. Must read low during the data phase ([bank input](#bank-input)). |
| 15 | IO0 | AA08 | input | Apple address A8 |
| 16 | IO1 | AA09 | input | Apple address A9 |
| 17 | IO2 | AA10 | input | Apple address A10 |
| 18 | IO3 | AA11 | input | Apple address A11 |
| 19 | IO4 | AA12 | input | Apple address A12 |
| 20 | IO5 | AA13 | input | Apple address A13 |
| 21 | IO6 | AA14 | input | Apple address A14 |
| 22 | IO7 | AA15 | input | Apple address A15 |
| 23 | GND | GND | power | Ground |
| 24 | IN1 | AX | input | From U4: selects Z180 card-port accesses ([AX and port selection](#ax-and-port-selection)) |
| 25 | IO8 | M2SEL_n | input | Slot pin 39: /M2SEL on a IIgs, 6502 SYNC on a IIe |
| 26 | IO9 | ADOUT | output | Enables latch U3 onto the Apple data bus (reads of $C0B0-$C0BF) |
| 27 | IO10 | CATCH | output | Clocks address latches U5/U6 and starts the copy into SRAM |
| 28 | IO11 | ADIN | output | Clocks data latch U2 |
| 29 | IO12 | HA00 | input | Z180 address A0 |
| 30 | IO13 | HD3 | bidirectional | Z180 data bit 3 |
| 31 | IO14 | HA01 | input | Z180 address A1 |
| 32 | IO15 | HD1 | bidirectional | Z180 data bit 1 |
| 33 | Y2 | (stub on prototype) | clock | Bank-window clock for M2B0, falling edge: needs 7M ([TN #68](../sources.md#s43)). A production rework wire brings 7M to the socket; its end is hidden under the socket ([production changes](../02-board.md#production-changes), [clocks](../04-capture-logic.md#clocks-and-phase)) |
| 34 | VCC | VCC | power | Logic supply |
| 35 | Y1/RESET | RESET | input | Y1 clock input, unused; not the global reset ([reset](../04-capture-logic.md#reset-and-power-on)) |
| 36 | IN2 | AD4 | input | Apple data bit 4; loaded into RAMWRT from $C068 bit 4 ([AD6 and AD4](#ad6-and-ad4)) |
| 37 | IO16 | CPU | input | PHASE 0 (slot pin 40), high during the data phase ([clocks](../04-capture-logic.md#clocks-and-phase)) |
| 38 | IO17 | INT1 | output | Z180 INT1 and DREQ1; low = event pending |
| 39 | IO18 | CATCH_BANK | output (registered) | SRAM bank of the copied byte: 0 = main/$E0, 1 = aux/$E1 |
| 40 | IO19 | HD0 | bidirectional | Z180 data bit 0 |
| 41 | IO20 | HA02 | input | Z180 address A2 |
| 42 | IO21 | ARW | input | Apple R/W (1 = read) |
| 43 | IO22 | RDY0 | output | Low pulls Apple RDY low through a 74F125 (stall) |
| 44 | IO23 | HD2 | bidirectional | Z180 data bit 2 |

## Notes on individual signals

### AD6 and AD4

On `$C068` accesses the fuse map loads PAGE2 from pin 2. STATEREG bit 6 is PAGE2, so the
blurred label is AD6. Pin 36 supplies AD4, which loads RAMWRT from bit 4.
Source: [design source](../../data/lattice/Lattice_original-BE8C.ldf), block B5 and the I/O cells.

### Bank input

M2B0 arrives at pin 14 from slot pin 35. The CATCH equation needs it low during the data
phase, after the Apple stops driving it ([TN #68](../sources.md#s43)). The drawing has no
pull-down on it ([copying video writes](../04-capture-logic.md#copying-video-writes)).

### AX and port selection

AX comes from U4, which selects U7 only for ports $A0-$A7
([the Z180's view of U7](../04-capture-logic.md#the-z180s-view-of-u7-ports-a0-a7)).
Read and write side effects:
[access limits and aliasing](z180-io-ports.md#access-limits-and-aliasing). What unused
ports read back: [configuration and open reads](z180-io-ports.md#configuration-and-open-reads).

### Capture and event outputs

CATCH and ADIN pulse low; their rising edges latch the address in U5/U6 and the data in
U2. ADOUT enables U3 for Apple reads of `$C0B0-$C0BF`. INT1 low signals a pending event to
both Z180 INT1 and DREQ1. Source: [netlist](../../data/netlist/README.md).

CATCH_BANK is registered and selects SRAM bank 0 or 1. RDY0 low enables a 74F125 with a
grounded input, which pulls Apple RDY low. Source: [netlist](../../data/netlist/README.md).

## Capture bank terms

The original Lattice chip (BE8C) copies a write to SRAM bank 1 when any of these terms is true.
Lattice v2.0 uses Apple's bank rule instead
([what the corrected map changes](../12-lattice-fix.md#what-the-corrected-map-changes)).

| Term | Bank-1 condition |
|---|---|
| a | B = 1, MODE_D3 = 1, RAMWRT = 0 |
| b | B = 0, STORE80 = 1, PAGE2 = 1 |
| c | B = 0, STORE80 = 0, RAMWRT = 1 |
| d | B = 0, MODE_D3 = 1, RAMWRT = 1, HIRES = 0 |

## Capture bank cases

The original Lattice chip in IIgs mode (MODE_D3 = 1):

| Write | Bank |
|---|---|
| To $E1, or shadowed through $01 (B = 1), RAMWRT off | 1 (aux), term a |
| B = 1 and RAMWRT on | 0, and $6000-$9FFF is not copied |
| B = 0, STORE80 off | RAMWRT, term c (term d gives the same result) |
| B = 0, STORE80 on, RAMWRT off | PAGE2, term b |
| B = 0, STORE80 on, RAMWRT on, HIRES on | PAGE2, term b |
| B = 0, STORE80 on, RAMWRT on, HIRES off | 1 regardless of PAGE2, term d |

## Machine-readable copy

[`u7-isplsi1016-pins.csv`](../../data/tables/u7-isplsi1016-pins.csv) is the pin table as
CSV.

---

[Reference tables](README.md) | [Capture logic](../04-capture-logic.md)
