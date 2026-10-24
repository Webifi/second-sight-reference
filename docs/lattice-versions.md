# Lattice chip versions

[Reference index](../README.md) | [Firmware versions](firmware-versions.md) | [04 Capture logic](04-capture-logic.md) | [Errata](reference/errata.md)

The Lattice chip is the card's capture logic ([04 Capture logic](04-capture-logic.md)): the
square 44-pin chip in a socket at the right end of the card, just above the slot
connector, with a white sticker reading BE8C. The schematic calls it U7. Its program is a
fuse map. A replacement must be an ispLSI1016, not an ispLSI1016E
([Do not buy](#do-not-buy)).

> [!WARNING]
> **Preliminary research, provided as is with no warranty. It may contain errors.**

| Version | What it is | File and SHA-256 |
|---|---|---|
| **BE8C** | The chip Sequential shipped, labeled with its fuse checksum. Read from the chip ([original image](#the-original-image)); pDS 2.61 rebuilds it with every fuse equal. | [`Lattice_original-BE8C_ispLSI1016.jed`](../prebuilt/lattice/Lattice_original-BE8C_ispLSI1016.jed) `f8b2f5429a65acbe3f6c13d6aa6ae3e87e9d83c8d1e3e8bbc1d54977ee626328` |
| **v2.0-BBB1** | Fixes E14 (direct $E1 writes), E15 (the border color reaches the firmware) and E28 (the bank of writes with 80STORE on). Built by pDS 2.61. | [`Lattice_v2.0-BBB1_ispLSI1016.jed`](../prebuilt/lattice/Lattice_v2.0-BBB1_ispLSI1016.jed) `07bb3dd28e1d158158cdfae06f9f7f624b42f132512c8c9c3df99acc1e441fb2` |

Both files are for the ispLSI1016, any speed grade (-60 to -110). Sequential paired its
BE8C chip with the EPROM ("V1.1 EPROM and Lattice or greater",
[firmware documentation](sources.md#s15)); v2.0 is the version [firmware 2.0](firmware-versions.md)
needs. pDS 2.61, the tool that built the original chip, builds both from the sources in
[`data/lattice`](../data/lattice) ([Building a version yourself](#building-a-version-yourself)).

## Contents

- [Which firmware goes with which Lattice chip](#which-firmware-goes-with-which-lattice-chip)
- [What v2.0 changes](#what-v20-changes)
- [Getting a chip](#getting-a-chip)
- [Programming a chip](#programming-a-chip)
- [Going back to the original](#going-back-to-the-original)
- [Building a version yourself](#building-a-version-yourself)
- [The original image](#the-original-image)

## Which firmware goes with which Lattice chip

Lattice v2.0 goes with [firmware 2.0](firmware-versions.md), which shows the IIgs border color
it reports. The original Lattice chip goes with firmware 1.5. Every pairing works: the full table
is on [Firmware versions](firmware-versions.md#which-firmware-goes-with-which-lattice-chip).

## What v2.0 changes

The Lattice chip copies nothing itself. It watches each IIgs bus cycle and decides two things: whether
the card copies a write into its SRAM, and in which SRAM bank; and whether the Z180 is
interrupted to hear about a softswitch access. Latches U5/U6 (the address), U2 (the data
byte) and GAL U17 (the SRAM write) carry out every copy
([Copying video writes](04-capture-logic.md#copying-video-writes)). v2.0 changes three
equations and adds one output; every other output keeps the original's equation, and the
pins are unchanged:

- **E14:** a direct write to bank $E1 or $01 made while RAMWRT is on is selected for
  copying, into SRAM bank 1. The original Lattice chip skipped those writes above $6000 and picked
  bank 0 for them below. U5/U6, U2 and U17 then copy the byte as they copy every other
  screen write. The game Rastan's palettes and control bytes are such writes.
- **E15:** a write to $C034 in IIgs mode raises an event, like a write to $C022 (the text
  colors). During the write the IIgs drives the new value on the slot's data bus, as it
  does for every write. The chip latches that byte into U2, keeps the address's low byte ($34),
  and interrupts the Z180. Firmware 2.0's handler reads the byte from port $A0 and takes
  bits 3-0 as the border color
  ([Events](04-capture-logic.md#events-telling-the-z180-about-softswitch-accesses)).
  ROM 1.4 and firmware 1.5 have no handler for $C034 and ignore the event.
- **E28:** with 80STORE on, a bank $00 write is copied into the bank selected by the
  Apple: PAGE2 picks it for text page 1, and for hires page 1 while HIRES is on; RAMWRT
  picks it for every other address. The original applied PAGE2 to every address, and in
  one IIgs case copied Super Hi-Res writes over the card's own code.

Everything else stays as the factory chip has it, the $9000 band flag included
([E13](reference/errata.md#e13-fast-animation-is-choppy): changing it would save a few
milliseconds a pass, and only for programs that change palettes without drawing).

The equations: [Correcting the capture logic](12-lattice-fix.md#what-the-corrected-map-changes).
142 of the 15,360 fuses differ from BE8C, all in the four blocks that changed (A2 with
the new HIRES1_ADDR, A4 with CAPTURE, B0 with CATCH_BANK, B7 with EVENT_DECODE) and the
six routing-pool connections they add or drop; the other blocks keep every fuse of the
original.

## Getting a chip

The chip is an **ispLSI1016** in the 44-pin PLCC package: part numbers ending in LJ, such
as ispLSI1016-80LJ, or LJI for the industrial-temperature version. The number after the
dash is the speed grade (60, 80, 90 or 110 MHz); all grades share one pinout and one fuse
layout. The original's grade is printed under its BE8C sticker, and the same grade is the
closest match; a faster grade has shorter maximum delays (input to output 20 ns at -60,
15 ns at -80, 12 ns at -90, 10 ns at -110). Source:
[ispLSI and pLSI 1016 data sheet, 1996](sources.md#s86) pp15-18.

- **Where to buy.** Lattice discontinued the family in 2010 (notice PCN09I-10 on its
  [ispLSI 1000 page](https://www.latticesemi.com/en/Support/MatureAndDiscontinuedDevices/ispLSI1000)),
  so parts come from surplus stock. [Mouser](https://www.mouser.com/ProductDetail/Lattice/ispLSI-1016-80LJ?qs=TaOZSEYtRiW0ACsnVsucnw%3D%3D)
  lists the ispLSI1016-80LJ as obsolete and does not sell it. On 22 October 2026 Amazon
  had plain ispLSI1016 parts in PLCC:
  - [ispLSI1016-60LJI, $14.80](https://www.amazon.com/dp/B0DCPQ2R71) (16 in stock) and
    [the same part at $15.00](https://www.amazon.com/dp/B0CQXDDZTQ), seller Xiwangshangwu;
  - [ispLSI1016-90LJ, 2 to 5 pieces, $31.54](https://www.amazon.com/dp/B0FJ7JZ253)
    (18 in stock), seller Jingxiao Trading.

  Other grades come from broker sites: [Findchips](https://www.findchips.com/search/lsi1016)
  collects many sellers, among them Bristol Electronics with -80LJ parts at about $4.50
  to $9 each, and eBay has listings such as an
  [ispLSI1016-80LJ from a US seller](https://www.ebay.com/itm/113753050335).
- **Surplus parts can be used, relabeled or fake.** Every programming route below first
  reads the chip's identifier, which must be $01 for an ispLSI1016, and erases the chip
  before programming it, so a used chip can be reprogrammed and a chip with the wrong
  identifier stops the job.

### Do not buy

- **The ispLSI1016E.** It fits the socket and has the same logic, but it is a different
  chip: its fuse map has 17,600 fuses instead of 15,360
  ([Lattice 1996 Data Book](sources.md#s85) Table 8), so neither file fits it.
  Listings mix the 1016 and the 1016E, so check the part number letter by letter: the
  ispLSI1016E-80LJI, for example, is the E device. Find an ispLSI1016, no E.
- **The ispLSI1016EA.** It cannot work in the card. It is programmed through fixed JTAG
  pins: pins 14, 24, 33 and 36 are TDI, TDO, TCK and TMS, and pin 13 supplies its output
  drivers. The card uses pins 14, 24, 33 and 36 as inputs (M2B0, AX, CLK_Y2 and AD4) and
  leaves pin 13 unconnected ([ispLSI 1016EA data sheet](sources.md#s97), pin table).
- **The pLSI1016** (no "is"), unless your device programmer lists it. It has the same
  logic but no programming pins, so only such a programmer can program it, and Lattice
  rates it for 100 erase-and-program cycles instead of 10,000
  ([data sheet](sources.md#s86) p3).

## Programming a chip

The file for an ispLSI1016 is [`Lattice_v2.0-BBB1_ispLSI1016.jed`](../prebuilt/lattice/Lattice_v2.0-BBB1_ispLSI1016.jed)
(or [`Lattice_original-BE8C_ispLSI1016.jed`](../prebuilt/lattice/Lattice_original-BE8C_ispLSI1016.jed)
to go back). The card does not wire the chip's programming pins (ispEN, pin 13, is
unconnected), so the chip is programmed outside the card. Three routes work from a PC
over USB:

| Route | What it takes | Cost |
|---|---|---|
| [Device programmer](#with-a-device-programmer) | A universal programmer that lists the ispLSI1016, with its PLCC-44 adapter | Highest; used units are common |
| [Lattice USB cable](#with-lattices-usb-cable) | Lattice's HW-USBN-2A cable, Lattice's ispVM System software, and a [programming socket](#the-programming-socket) | Middle |
| [Home-made programmer](#with-a-home-made-programmer) | A 5 V microcontroller board, a programming socket, and a program written from the [protocol](#the-programming-protocol) | Lowest; the program has to be written |

Whichever route programs it, the chip ends up with the same 15,360 bits, and the route's
verify step reads them back and compares them with the file.

### With a device programmer

The programmer loads the file, erases the chip, programs it and verifies it, like any
other PLD. Programmers that list the ispLSI1016 in PLCC-44:

- **Elnec:** BeeProg2AP or BeeHive204AP with the AP1 PLCC44/2 ZIF module (71-1500A);
  BeeProg3 or BeeHive304 with the AP3 PLCC44 module (73-7038); BeeProg4, BeeProg4C or
  BeeHive404 with the DIL44/PLCC44 ZIF adapter (70-0041). Source:
  [Elnec device page](sources.md#s84).
- **Xeltek:** SuperPro 6100 with the DX2044 adapter. Source: [Xeltek Lattice device list](sources.md#s91).
- **Lattice's approved list** (2008) marks the ispLSI and pLSI 1016 as supported by Advin,
  BPM Microsystems, Data I/O and System General programmers. Source:
  [Lattice third-party programmer list](sources.md#s90).
- **Older models,** which turn up second-hand, from Lattice's 1996 list: Advin Pilot-U84,
  Pilot-U40 and Pilot-GUGCE; BP Microsystems PLD-1128 and CP-1128; Data I/O 2900, 3900
  and UniSite 40/48; Logical Devices Allpro 40 and Allpro 88; SMS Sprint Expert; Stag
  ZL30/A; System General TURPRO-1. Source: [Lattice 1996 Data Book](sources.md#s85) p6-10.
- **Not the cheap universal programmers:** XGecu's TL866II, T48 and T56 list no ispLSI
  devices, only Lattice GAL chips. Source: [XGecu T56 device list](sources.md#s92).

The original fuse file was itself read with Max Loader programmer software, as its header
says, so the original chip reads back in a device programmer too.

### With Lattice's USB cable

The ispLSI1016 is in-system programmable: five of its pins accept the program from
Lattice's download cable while the chip sits in a [programming socket](#the-programming-socket).

- **The cable:** Lattice's **HW-USBN-2A** USB cable. It programs 5 V devices; the newer
  HW-USBN-2B does not (it stops at 3.3 V), and Lattice names the HW-USBN-2A and the
  parallel-port HW-DLN-3C as the cables for 5 V devices. Lattice supplies the HW-USBN-2A
  through its sales offices, and used ones are sold online. Sources:
  [Lattice answer 6212](sources.md#s88); [Lattice cable guides](sources.md#s87).
- **The software:** Lattice's ispVM System, the programming program for its cables, a
  download from Lattice's web site; Lattice describes it as generating the programming
  signals for every Lattice device from the JEDEC file. It also comes with ispLEVER
  Classic, whose installation notice lists the ispLSI 1000 family and the USB cable
  drivers. Sources: [Lattice cable guides](sources.md#s87);
  [ispLEVER Classic 1.6 installation notice](sources.md#s93).
- **The steps:** connect the cable's flywires to the socket (colors in
  [The programming socket](#the-programming-socket)) with the socket unpowered, black
  ground wire first; power the socket; in ispVM System, scan the chain, which reads the
  chip's identifier ($01, ispLSI1016); give the device the file `Lattice_v2.0-BBB1_ispLSI1016.jed`;
  run the erase, program and verify operation. Source: [Lattice cable guide](sources.md#s87)
  (connection order).

### With a home-made programmer

Any 5 V microcontroller board with five free I/O pins, such as an Arduino Uno or Nano, can
drive the chip's programming pins directly: four outputs (ispEN, MODE, SDI, SCLK) and one
input (SDO), plus a sixth output or a wire holding RESET low. The board's USB port carries
the file from the PC. The [programming protocol](#the-programming-protocol) below is
everything such a program needs; Lattice published it so that customers could program the
chips from their own equipment, and its own C routines did exactly this
([ispCODE](sources.md#s94)). A 3.3 V board needs level shifting on SDO, which the chip
drives to 5 V.

This repository has no such program. Test one on a new chip, not the original: an
instruction sent most significant bit first turns the data shift DATASHFT (00010) into
the program pulse PRGML (01000).

### The programming socket

The Lattice cable and a home-made programmer both need the chip in a PLCC-44 socket wired
to its programming pins. A PLCC-44 socket on stripboard, or a PLCC-44-to-DIP adapter, does
the job.

| Chip pin (PLCC) | Signal | Lattice cable wire | Notes |
|---|---|---|---|
| 12, 34 | VCC | Red | 4.75-5.25 V, up to 100 mA; a 0.1 uF capacitor to ground at each pin |
| 1, 23 | GND | Black | |
| 13 | ispEN | Yellow | Low selects programming mode; a 0.01 uF capacitor to ground |
| 14 | SDI | Orange | Data and control into the chip |
| 24 | SDO | Brown | Data out of the chip |
| 33 | SCLK | White | Clock; a 4.7 kOhm resistor to ground |
| 36 | MODE | Purple | Control |
| 35 | Y1/RESET | (none) | Held low while programming |

All other pins stay unconnected: in programming mode the chip floats them. Sources:
[ispLSI 1016 data sheet](sources.md#s86) p15 (pins); [Lattice cable guide](sources.md#s87)
Table 2 and its notes (colors, ispEN capacitor, SCLK resistor); [Lattice 1992 data book
supplement](sources.md#s95) pp2-14 to 2-16 (RESET low, 100 kOhm pull-ups on floating pins).

### The programming protocol

This is how Lattice's cable software and its own C routines program the chip. Sources: [Lattice 1996 Data Book](sources.md#s85) section 8, pp8-1 to 8-20 (state
machine, instruction set, device layout, timing); [ispLSI 1016 data sheet](sources.md#s86)
pp13-14 (identifier, shift registers); [Using Proprietary Lattice ISP Devices](sources.md#s89).

**The state machine.** Driving ispEN low puts the chip in programming mode, in the *Idle*
state. MODE and SDI steer a small state machine, and every change happens on a rising edge
of SCLK. SDO changes after the falling edge.

| MODE | SDI | Rising SCLK in Idle | in Shift | in Execute |
|---|---|---|---|---|
| 1 | 0 | Load the identifier | Go to Idle | Go to Idle |
| 1 | 1 | Go to Shift | Go to Execute | Go to Shift |
| 0 | x | Shift the identifier out | Shift one instruction bit in from SDI | One clock of the instruction |

**Registers of the ispLSI1016.** An 8-bit identifier, $01. A 5-bit instruction register.
A 96-bit address register: a 1 in bit r selects row r. A 160-bit data register in two
80-bit halves, high-order bits 0-79 and low-order bits 80-159. Every register takes and
gives its least significant bit first: the bit shifted in first ends up as bit 0, and bit
0 comes out of SDO first. (Lattice states the bit order for the address and data registers
of every ispLSI and for the instruction register of the ispGAL22V10 and ispGDS, which use
the same state machine.)

**The instructions** used here (Lattice also lists partial erases and test instructions):

| Code | Name | In the Execute state |
|---|---|---|
| 00001 | ADDSHFT | 96 clocks: shift the address in from SDI |
| 00010 | DATASHFT | 80 clocks: shift data in from SDI and the old contents out on SDO |
| 00011 | UBE | 1 clock, then wait at least 200 ms: erase the whole chip |
| 00111 | PRGMH | 1 clock, then wait 40-100 ms: program the data into the selected row's high-order bits |
| 01000 | PRGML | 1 clock, then wait 40-100 ms: program the selected row's low-order bits |
| 01010 | VER/LDH | 1 clock, then wait at least 30 us: load the row's high-order bits into the data register |
| 01011 | VER/LDL | 1 clock, then wait at least 30 us: load the row's low-order bits |
| 01001 | PRGMSC | Programs the security cell, which blocks reading; never needed here |

**Rows and the JEDEC file.** Fuse L00000 is row 0, high-order bit 0; the fuses run on in
order, so row r holds fuses 160r to 160r+79 in its high-order half and 160r+80 to 160r+159
in its low-order half. A fuse value of 0 means a programmed cell and is shifted in as it
is.

**The whole job:**

1. Power the socket, wait at least 45 us, and hold RESET low. Set SCLK low, MODE high,
   SDI low. Drive ispEN low and wait 10 us.
2. **Identify:** MODE 1, SDI 0, one clock loads the identifier. Set MODE 0: SDO shows
   bit 0; seven more clocks give bits 1-7. Anything but $01 stops the job.
3. **Run an instruction:** MODE 1, SDI 1, one clock (Idle or Execute to Shift). MODE 0,
   five clocks with the instruction bits on SDI, least significant first. MODE 1, SDI 1,
   one clock into Execute. MODE 0 and the clocks the table gives. For an erase or a
   program pulse, the wait runs from that clock to the next state change; Lattice's own
   routines then set MODE and SDI high and wait 1 ms before that clock.
4. **Erase:** UBE.
5. **Program,** for each row r from 0 to 95: ADDSHFT with a 1 in bit r only; DATASHFT
   with fuses 160r to 160r+79; PRGMH; DATASHFT with fuses 160r+80 to 160r+159; PRGML.
6. **Verify,** for each row: ADDSHFT; VER/LDH; DATASHFT, comparing the 80 bits on SDO
   with fuses 160r to 160r+79; VER/LDL; DATASHFT, comparing with fuses 160r+80 to
   160r+159.
7. **Finish:** MODE 1, SDI 0, one clock to Idle; drive ispEN high.

**Timing** (ispLSI 1000 family): setup and hold of MODE and SDI around a rising SCLK edge
at least 0.1 us; SCLK high and low at least 0.5 us each; SDO valid within 0.5 us of a
falling edge; ispEN takes effect within 10 us. Programming the whole chip takes 10 to 20
seconds, most of it the 192 program pulses of 40-100 ms.

### Fitting the chip

With the card out of the computer, the Lattice chip comes out of its PLCC socket with a PLCC extraction
tool, and the new chip goes in the same way round: its pin-1 mark, a dot or the cut corner,
at the socket's notched corner.

## Going back to the original

Programming a second chip leaves the original chip unwritten, and it can be refitted. Any
ispLSI1016 can also be programmed back to the original map with
[`Lattice_original-BE8C_ispLSI1016.jed`](../prebuilt/lattice/Lattice_original-BE8C_ispLSI1016.jed),
the same bytes as the dump read from Sequential's chip ([The original image](#the-original-image)).
The original's file header has the security fuse off (`G0`), so the original chip can
also be read in a programmer and compared with that file. The data sheet rates the part
for 10,000 erase-and-program cycles and 20 years of data retention.

## Building a version yourself

Both designs are pDS 2.61 source files with a comment on every block, signal and term:
[`data/lattice/Lattice_original-BE8C.ldf`](../data/lattice/Lattice_original-BE8C.ldf) (BE8C) and
[`Lattice_v2.0.ldf`](../data/lattice/Lattice_v2.0.ldf) (v2.0), each with
its placement file (`.fxp`). Build commands and checks:
[Building the Lattice fuse map](../tools/lattice/README.md).

## The original image

The fuse map read from Sequential's chip is
[`original/isplsi1016_BE8C.bin`](../original/isplsi1016_BE8C.bin) ([public copy](sources.md#s24)),
a JEDEC text file despite its name, the same bytes as
[`data/lattice/Lattice_original-BE8C.jed`](../data/lattice/Lattice_original-BE8C.jed). pDS 2.61 builds
[`Lattice_original-BE8C.ldf`](../data/lattice/Lattice_original-BE8C.ldf) and its placement file back
into it with all 15,360 fuses equal:

```bash
tools/lattice/pds261_build.sh data/lattice/Lattice_original-BE8C.ldf data/lattice/Lattice_original-BE8C.fxp build/lattice/Lattice_original-BE8C_ispLSI1016.jed
```

How the fuses are read: [Method](13-method.md#6-decode-the-lattice-isplsi1016).

---

[Reference index](../README.md) | [Firmware versions](firmware-versions.md)
