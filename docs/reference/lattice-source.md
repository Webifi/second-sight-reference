# Lattice design source (U7)

[Reference tables](README.md) | [Capture logic](../04-capture-logic.md) | [Correcting the capture logic](../12-lattice-fix.md)

U7's design as Lattice pDS 2.61 source: every equation, register, clock and pin. pDS 2.61
builds the original file back into the original fuse map with every fuse equal.

## Contents

- [The original tools and language](#the-original-tools-and-language)
- [The source files](#the-source-files)
- [How to read the source](#how-to-read-the-source)
- [Building and changing the design](#building-and-changing-the-design)
- [The full source](#the-full-source)

## The original tools and language

Lattice sold **pDS** (pLSI/ispLSI Development System) for the ispLSI 1000 family: a
Windows 3.1, 95 and NT program protected by a key on the parallel port (product code
pDS1101-PC1). A designer writes an **LDF design file**, Boolean equations grouped by logic
block (GLB) and by I/O cell, either in pDS's edit windows or in any text editor. pDS
checks and minimizes the logic, places and routes it, and writes the JEDEC fuse map that a
programmer loads. Source: [Lattice 1996 Data Book](../sources.md#s85) pp6-7 to 6-11.

Sequential built U7 with pDS 2.61 from an LDF file. pDS 2.61 builds `SecondSight_U7.ldf`
into the original fuse map with all 15,360 fuses equal. The details that takes are pDS
2.61's own: the text order, the STRONGMIN outputs, two outputs nothing reads, and the
router's copies of two signals.

The LDF language, as this source uses it:

| Element | Meaning |
|---|---|
| `SYM GLB A7 1 A7;` ... `END; END;` | One logic block: its outputs, then `EQUATIONS` |
| `SIGTYPE X Out;` | X is a combinational output of the block |
| `SIGTYPE X Reg;` | X is a register output |
| `SIGTYPE X OE;` | X is the enable for the three-state pins of the block's megablock |
| `STRONGMIN` after `Out` or `Reg` | pDS minimizes X with its stronger method instead of the default (FASTMIN) |
| `&`, `#`, `!` | AND, OR, NOT (Lattice also lists `$` XOR, `!$` XNOR and `$$` the block's hardware XOR) |
| `X.CLK = ...;` | X loads on a global clock (a dedicated clock pin); `!` takes its falling edge |
| `X.PTCLK = ...;` | X loads on a product-term clock (any logic) |
| `X.PIN` | Combinational output X of the same block, fed back into it |
| `X.RE`, `X.OE`, `X.D`, `X.Q` | Product-term reset, output enable, register input, register output |
| `OPTION Y1_AS_RESET OFF;` | Pin 35 (Y1/RESET) is not the global reset |
| `SYM IOC IO9 1 name;` ... `END;` | One I/O cell |
| `XPIN IO XNAME LOCK 26;` | The cell's pin, locked to package pin 26 (`I` for a dedicated input, `CLK` for a clock pin) |
| `IB11(NET,XPIN)` | Input buffer: the pin drives NET |
| `OB11(XPIN,NET)` | Output buffer: NET drives the pin; `!NET` drives it through the cell's inverter |
| `OT11(XPIN,NET,OE)` | Three-state output enabled by OE |
| `BI11(IN,XPIN,OUT,OE)` | Bidirectional pin: read as IN, driven from OUT when OE is high |
| `//` | Comment to the end of the line |

Sources: [Lattice 1996 Data Book](../sources.md#s85) p6-8 (keywords, operators, dot
extensions); pDS 2.61's macro library `LATSYSM.LIB` (I/O cell macros).

## The source files

| File | Contents |
|---|---|
| [`SecondSight_U7.ldf`](../../data/lattice/SecondSight_U7.ldf) | The original design (fuse checksum BE8C), with comments on what every block, signal and term does |
| [`SecondSight_U7.fxp`](../../data/lattice/SecondSight_U7.fxp) | Its placement file: the block and block output of every signal, the I/O cell of every pin |
| [`SecondSight_U7_fixed.ldf`](../../data/lattice/SecondSight_U7_fixed.ldf), [`.fxp`](../../data/lattice/SecondSight_U7_fixed.fxp) | The [corrected design](../12-lattice-fix.md) for errata E14, E15 and E28: the original with three equations changed and one output added, each marked `CORRECTION` with its reason |
| [`SecondSight_U7.jed`](../../data/lattice/SecondSight_U7.jed) | The original fuse map (checksum BE8C), the dump the design was recovered from |

Every place the corrected design differs from the original:

```text
CAPTURE (E14)
             - # MODE_D3 & !ARW & !RAMWRT & !COPY_INHIBIT & !M2SEL_N & BANK_HELD & RANGE_2000_9FFF
             + # MODE_D3 & !ARW & !COPY_INHIBIT & !M2SEL_N & BANK_HELD & RANGE_2000_9FFF
BANK_Q (E14, E28)
             - = !BANK_HELD & RAMWRT & !STORE80
             -   # !BANK_HELD & STORE80 & PAGE2
             -   # BANK_HELD & !RAMWRT & MODE_D3
             -   # !BANK_HELD & RAMWRT & MODE_D3 & !HIRES
             + = !BANK_HELD & RAMWRT & !STORE80
             +   # BANK_HELD
             +   # !BANK_HELD & STORE80 & PAGE2 & RANGE_0400_0BFF & AA10
             +   # !BANK_HELD & STORE80 & PAGE2 & HIRES & HIRES1_ADDR
             +   # !BANK_HELD & STORE80 & RAMWRT & RANGE_0400_0BFF & !AA10
             +   # !BANK_HELD & STORE80 & RAMWRT & !RANGE_0400_0BFF & !HIRES1_ADDR
             +   # !BANK_HELD & STORE80 & RAMWRT & !RANGE_0400_0BFF & !HIRES
A2_FIT (E28)
             - (an unused output that steered block A2's layout)
HIRES1_ADDR (E28)
             + RANGE_2000_5FFF & AA13 (new output, block A2, on A2_FIT's output)
EVENT_DECODE (E15)
             + # AA2 & AA4 & AA5 & C0_VALID & MODE_D3 & !AA0 & !AA1 & !AA3 & !AA6 & !AA7 & !ARW
```

## How to read the source

- **Blocks.** Each `SYM GLB` section is one of the chip's 16 logic blocks, with up to four
  outputs, named by its place in the chip as pDS names it: A0-A7 and B0-B7. Each signal's
  comment says what it does; [Capture logic](../04-capture-logic.md) explains the logic as
  a whole.
- **Order.** The order of the lines, of the terms and of the names inside each term is
  the order that makes pDS 2.61 put every term where the original chip has it. Logic
  written in another order behaves the same and builds into other fuses.
- **Latches.** An output whose equation names itself, such as `RUN` or `COPY_INHIBIT`, is
  an asynchronous latch held by its own feedback, not a clocked register. Its equation
  must stay exactly as written: rewriting it into a different but equal sum of products
  can open a glitch while the latch holds.
- **Copies.** pDS's router copies `COPY_INHIBIT` and `BANK_HELD` into a second output of
  their blocks, for the blocks that read them; the placement file names each twice.
  `FLAGS_ACCESS_ALIAS` is a separate output with the same equation as `FLAGS_ACCESS`.
- **Unused outputs.** `A2_FIT` and `B0_FIT` feed nothing. The original build had them:
  pDS fits them, which puts the other outputs of their blocks on the OR gates the original
  uses, and its router then deletes them. The corrected design keeps `B0_FIT`; its new
  output `HIRES1_ADDR` takes A2_FIT's place.
- **Clocks.** `CLK_Y0` is pin 11 and `CLK_Y2` pin 33. `X.CLK = !CLK_Y0;` takes the clock's
  falling edge (the block's clock-inversion fuse).
- **Pins.** The I/O cell sections lock every signal to its PLCC pin, matching
  [Lattice pins](lattice-pins.md). Y1/RESET (pin 35) and ispEN (pin 13) are unused, so
  they have no section. `OB11(XPIN, !NET)` drives a pin through its I/O cell's inverter
  (the pins ADOUT_N, CATCH_N, ADIN_N, INT1_N and RDY0).

## Building and changing the design

pDS 2.61 builds a design file and its placement file into an ispLSI1016 fuse map.
Builds, source comparisons and design changes:
[Building the Lattice fuse map](../../tools/lattice/README.md).

**What one logic block holds:**

- Four outputs.
- 20 product terms, shared through four OR groups. The outputs' OR gates take whole groups.
- 18 inputs: 16 from the routing pool and 2 special inputs. The special inputs take
  dedicated input pins first, then the block's own outputs.

**Routing slots.** Every other input, including an own output that finds no special
input free, comes through the routing pool. Each signal reaches a block at one fixed pool
slot, and some signals share a slot: Apple address A8 shares with CPU, and A11 with
CAPTURE, in every block.

- A block that reads two signals on one slot needs a copy of one of them. pDS's router
  puts the copy on a free output of the block that makes it, as it does for
  `COPY_INHIBIT` and `BANK_HELD`.
- When that block has no free output, the route fails. The route report (`.rp7`) names
  the "unplaced inputs".
- An address pin cannot be copied.
- A design too big for the chip fails earlier, in the Verify report (`.rp1`).

## The full source

The original design, `SecondSight_U7.ldf`, comments included:

<!-- ldf:begin -->
```text
// SecondSight_U7.ldf: the source of U7, the Second Sight's Lattice ispLSI1016, as
// Sequential shipped it (fuse checksum BE8C).
//
// WHAT THIS CHIP DOES
// U7, a Lattice ispLSI1016 in a 44-pin PLCC, is the Second Sight's Apple-side logic. On
// each Apple slot bus cycle it decides:
//   1. Copy:  is this a write to Apple video memory that the card copies into its own
//             SRAM? (CAPTURE, CATCH_N, ADIN_N, CATCH_BANK)
//   2. Event: is this an access to a video softswitch or to the card's registers that
//             the Z180 must handle?               (EVENT_DECODE, EVENT_LATCH, INT1_N)
//   3. Wait:  must the Apple pause (RDY low) because the Z180 has not yet read the last
//             event?                                  (RUN, STALL, RDY0)
// It also keeps eight "band flags" (which 4 KB parts of $2000-$9FFF had a copied write
// since the Z180 last read them) and two configuration bits the Z180 writes through port
// $A1 (COPY_INHIBIT, MODE_D3). Details: docs/04-capture-logic.md.
//
// REBUILDING THE ORIGINAL FUSE MAP
// Lattice's pDS 2.61 builds this file, with its placement file SecondSight_U7.fxp, into
// the fuse map of the chip Sequential shipped: all 15,360 fuses the same, fuse checksum
// BE8C. Sequential's design used pDS 2.61 and this source structure. The recovered file
// preserves the features that determine pDS's result:
//   - The order of the SIGTYPE lines, of the equations, of the product terms, and of the
//     names inside each term. pDS numbers the signals of a block in the order the text
//     first mentions them, and that numbering decides the order of each output's product
//     terms, which decides where each term goes in the chip.
//   - STRONGMIN on some outputs. pDS minimizes those with its stronger method instead of
//     the default (FASTMIN), and that changes the order of their product terms.
//   - A2_FIT and B0_FIT are unused outputs present in the original build. pDS fits them
//     to place the block's other outputs on the original OR gates. Its router then
//     deletes the unused outputs.
//   - SecondSight_U7.fxp, pDS's placement file: which block and which block output each
//     signal uses, and which I/O cell each pin uses. COPY_INHIBIT and BANK_HELD appear
//     twice in it: pDS's router copied each into a second output of its block, for the
//     block that reads it.
// The same logic written in another order gives a chip that behaves the same, with other
// fuses. Changed designs (SecondSight_U7_fixed.ldf) start from this file.
//
// BUILDING
// Lattice pDS 2.61 (the "pLSI/ispLSI Development System" for DOS and Windows 3.1, 1994)
// builds this file. tools/lattice/README.md gives the steps by hand and the script that
// runs them (tools/lattice/pds261_build.sh): Import the LDF, Verify, Fit Strong with the
// placement file, Fuse Map. The chip is the ispLSI1016; the ispLSI1016E is a different
// chip that this design is not built for.
//
// SYNTAX (Lattice pDS design file)
//   &  AND        #  OR        !  NOT        // a comment, to the end of the line
//   SYM GLB A7 1 A7; ... END; END;    one logic block (GLB), with up to four outputs
//   SIGTYPE X Out;    X is combinational
//   SIGTYPE X Reg;    X is a flip-flop
//   SIGTYPE X OE;     X enables the three-state Z180 data pins of its megablock
//   STRONGMIN         after Out or Reg: minimize X with pDS's stronger method
//   X.CLK = CLK_Y0;   X loads on a rising edge of a clock pin
//   X.CLK = !CLK_Y0;  X loads on a falling edge (the block's clock-inversion fuse)
//   X.PTCLK = expr;   X loads on a rising edge of a product-term clock (any logic)
//   X.PIN             the output X of this same block, fed back (a combinational output
//                     used in its own block); a flip-flop is named plainly
//   SYM IOC IO9 1 NAME; XPIN ... LOCK 26;   one I/O cell, locked to package pin 26
//   IB11 input, OB11 output, OT11 three-state output, BI11 bidirectional pin
//   OB11(XPIN, !NET)  the pin is driven through the I/O cell's inverter
//   OPTION Y1_AS_RESET OFF;   pin 35 (Y1/RESET) is not the global reset
//
// LATCHES
// An output whose equation names itself (RUN, COPY_INHIBIT, the band flags, the HIRES
// hold terms, ...) is an asynchronous latch held by its own feedback, not a clocked
// register. Its terms are written here exactly as the chip has them, and pDS keeps them:
// rewriting a latch into a different but equal sum of products can open a glitch while
// it holds.
//
// SIGNAL NAMES
//   Apple side (the slot bus):
//     AA0-AA15  Apple address A0-A15
//     ARW       Apple R/W: 1 = read, 0 = write (so !ARW means "a write")
//     CPU       PHASE 0 (slot pin 40): low in the address phase, high in the data phase
//     M2SEL_N   /M2SEL (slot pin 39): low on a valid IIgs slow-side cycle (SYNC on a IIe)
//     M2B0      IIgs bank bit 0 (slot pin 35): driven only early in the address phase,
//               pulled low by a resistor the rest of the time
//     AD4, AD6  Apple data bits 4 and 6, for STATEREG ($C068) writes
//   Z180 side:
//     AX        from U4: the Z180 is accessing one of its I/O ports $A0-$A7
//     HA0-HA2   Z180 address bits 0-2: which port of $A0-$A7
//     HD0-HD3   Z180 data bits 0-3
//   Clocks:
//     CLK_Y0    pin 11: falling edges load the four tracked softswitches
//     CLK_Y2    pin 33: 7M (about 140 ns period); falling edges time the bank window
//   B in the comments is the IIgs bank bit the card holds (BANK_HELD): 1 means bank $E1
//   or $01, the auxiliary 64 KB.
//   FLAGS_ACCESS_ALIAS is a second output with the same equation as FLAGS_ACCESS, for
//   blocks A1 and B6.

// pDS file header: the file format, the design's name and the part. Every speed grade of
// the ispLSI1016 has the same fuse layout, so the grade named here changes nothing.
LDF 1.00.00 DESIGNLDF;
DESIGN SSU7;
PART ispLSI1016-60LJ44;
OPTION Y1_AS_RESET OFF;

// No global declarations: every signal is declared in its block below.
DECLARE
END;

// ====================================================================================
// Block A7: the tracked HIRES switch, and the strobes for the data latches U3 and U2.
// ====================================================================================
SYM GLB A7 1 A7;
SIGTYPE HIRES                Reg STRONGMIN;         // tracked HIRES switch ($C056/$C057)
SIGTYPE ADOUT_ACTIVE         Out;                   // $C0B0-$C0BF read: U3 drives data
SIGTYPE ADIN_ACTIVE          Out;                   // U2 clock: copy or write event
EQUATIONS

// An Apple read of the card's registers $C0B0-$C0BF, in the data phase: latch U3 (the
// byte the Z180 left for the Apple) drives the Apple data bus. ADOUT_N is its inverse.
ADOUT_ACTIVE = ARW & C0_VALID & AA7 & !AA6 & AA5 & AA4 & CPU;
HIRES.CLK = !CLK_Y0;

// Clocks latch U2, which hands the Apple's data byte to the Z180 (port $A0). Pin ADIN_N
// is its inverse; U2 latches on its rising edge, at the end of the data phase.
ADIN_ACTIVE = CPU & CAPTURE & RUN                   // a copied write, but only while no
                                                    // event waits (RUN), so a copy cannot
                                                    // overwrite an event's data byte
            # CPU & !ARW & EVENT_LATCH;             // a write that raised an event

// HIRES follows the Apple's HIRES softswitch: a valid access to $C057 sets it and one to
// $C056 clears it, read or write. The first eight terms keep the old value on every
// other cycle, one term per way to miss $C056/$C057: A3, A5 or A7 is 1; A1, A2, A4 or A6
// is 0; or the cycle is not a valid $C0xx cycle. The last term loads a 1 for $C057.
// Unlike PAGE2, RAMWRT and STORE80 it needs no CPU (data phase) term.
HIRES = !C0_VALID & HIRES
      # AA7 & HIRES
      # !AA6 & HIRES
      # AA5 & HIRES
      # !AA4 & HIRES
      # HIRES & AA3
      # HIRES & !AA2
      # HIRES & !AA1
      # C0_VALID & AA1 & AA2 & !AA3 & AA4 & !AA5 & AA6 & !AA7 & AA0; // $C057: set
END;
END;

// ====================================================================================
// Block A6: event address bit 3, the band flags for $5000 and $9000, and Z180 data bit 3.
// ====================================================================================
SYM GLB A6 1 A6;
SIGTYPE EVENT_A3             Reg;                   // event A3 at $A6/$A7
SIGTYPE HD3_DRIVE            Out STRONGMIN;         // Z180 bit 3 out ($A4-$A7)
SIGTYPE DIRTY_9000           Out;                   // band flag $9000-$9FFF
SIGTYPE DIRTY_5000           Out;                   // band flag $5000-$5FFF
EQUATIONS

// A3 of the event's Apple address, stored when EVENT_LATCH rises. Port $A6 bit 3.
EVENT_A3 = AA3;
EVENT_A3.PTCLK = EVENT_LATCH;

// Band flag for $9000-$9FFF: set by a copied write there; any Z180 access to port $A5
// clears it (U7 has no Z180 read/write input, so a read clears it too).
DIRTY_9000 = !HA0 & DIRTY_9000.PIN                  // hold: port $A4, not $A5
           # DIRTY_9000.PIN & !FLAGS_ACCESS         // hold: not port $A4/$A5
           # AA12 & WRITE_8000_9FFF;                // set: a copy into $9000-$9FFF

// Band flag for $5000-$5FFF: set by a copied write there; port $A4 access clears it.
DIRTY_5000 = !FLAGS_ACCESS & DIRTY_5000.PIN         // hold: not port $A4/$A5
           # HA0 & DIRTY_5000.PIN                   // hold: port $A5, not $A4
           # AA12 & WRITE_4000_5FFF;                // set: a copy into $5000-$5FFF

// What U7 drives on Z180 data bit 3 while the Z180 reads ports $A4-$A7. HA1 and HA0 pick
// the port. The last term holds a 1 through an $A4/$A5 access, so a band flag that
// clears during the access is still read as set.
HD3_DRIVE = !HA0 & DIRTY_5000.PIN & !HA1            // $A4 bit 3: band flag $5000
          # EVENT_A3 & !HA0 & HA1                   // $A6 bit 3: event address A3
          # HA0 & !HA1 & DIRTY_9000.PIN             // $A5 bit 3: band flag $9000
          # HA0 & HA1 & EVENT_A7                    // $A7 bit 3: event address A7
          # FLAGS_ACCESS & HD3_DRIVE.PIN;           // hold a 1 through an $A4/$A5 access
END;
END;

// ====================================================================================
// Block A5: the COPY_INHIBIT configuration bit, and the two flip-flops that time the
// M2B0 sampling window.
// ====================================================================================
SYM GLB A5 1 A5;
SIGTYPE COPY_INHIBIT         Out;                   // port $A1 bit 2: stop all copying
SIGTYPE CPU_DELAY            Reg;                   // PHASE 0 delayed one falling Y2 edge
SIGTYPE BANK_WINDOW          Reg;                   // the M2B0 sampling window
EQUATIONS

// CPU (PHASE 0), one falling 7M edge late.
CPU_DELAY = CPU;

// High for one 7M period, from the first falling 7M edge after CPU falls: the start of
// the address phase, the roughly 140 ns when the IIgs drives M2B0 (Apple TN #68).
BANK_WINDOW = !CPU & CPU_DELAY;
CPU_DELAY.CLK = !CLK_Y2;
BANK_WINDOW.CLK = !CLK_Y2;

// Port $A1 bit 2. While it is 1, nothing is copied. A Z180 access to port $A1 (AX, HA0
// set, HA1 and HA2 clear) loads it from HD2; every other cycle holds it (first four
// terms). A read of $A1 loads it too, from whatever is on the data bus: never read $A1.
// It is a latch with no reset; the firmware writes $A1 in its first instructions.
// pDS's router puts a copy of COPY_INHIBIT on a second output of this block, for block
// A4's CAPTURE (SecondSight_U7.fxp names it twice).
COPY_INHIBIT =COPY_INHIBIT.PIN & !HA0
             # COPY_INHIBIT.PIN & HA1
             # COPY_INHIBIT.PIN & HA2
             # COPY_INHIBIT.PIN & !AX
             # !HA2 & HA0 & !HA1 & AX & HD2;        // port $A1: load data bit 2
END;
END;

// ====================================================================================
// Block A4: which cycles count, which writes are copied, and the Z180 data enable.
// ====================================================================================
SYM GLB A4 1 A4;
SIGTYPE C0_VALID             Out STRONGMIN;         // a valid $C0xx access
SIGTYPE HOST_DATA_OE         Out;                   // Z180 read of ports $A4-$A7
SIGTYPE CAPTURE              Out;                   // Apple write copied into SRAM
SIGTYPE HDOE_A               OE;                    // Z180 data enable for this megablock
EQUATIONS

// The Z180 is accessing ports $A4-$A7: U7 drives HD0-HD3. It does so on a write too,
// fighting the Z180's own data, so the Z180 must never write $A4-$A7.
HOST_DATA_OE = AX & HA2;

// Output enable of the three-state Z180 data pins in megablock A (HD1 and HD3).
HDOE_A = HOST_DATA_OE.PIN;

// This Apple cycle is a write that the card copies into its SRAM. Every term needs a
// write (!ARW), copying allowed (!COPY_INHIBIT) and a valid cycle (IIe mode, or /M2SEL
// low), which is why each address range appears twice. The last two terms add
// $6000-$9FFF in IIgs mode: the upper part of Super Hi-Res, for writes to the auxiliary
// bank. Together they are "B xor RAMWRT": a write with B = 1 (bank $E1 or $01), or a
// bank $00 write that RAMWRT sends to auxiliary memory. Erratum E14: a write with B = 1
// while RAMWRT is on is lost.
CAPTURE = !ARW & !COPY_INHIBIT & !M2SEL_N & RANGE_2000_5FFF // hires pages 1-2, /M2SEL low
        # !ARW & !COPY_INHIBIT & !M2SEL_N & RANGE_0400_0BFF // text/lores 1-2, /M2SEL low
        # !ARW & !COPY_INHIBIT & RANGE_0400_0BFF & !MODE_D3 // text/lores 1-2, IIe mode
        # !MODE_D3 & !ARW & !COPY_INHIBIT & RANGE_2000_5FFF // hires pages 1-2, IIe mode
        # MODE_D3 & !ARW & !COPY_INHIBIT & !M2SEL_N & RAMWRT & !BANK_HELD & RANGE_2000_9FFF
                                                    // IIgs: bank $00 to aux via RAMWRT
        # MODE_D3 & !ARW & !RAMWRT & !COPY_INHIBIT & !M2SEL_N & BANK_HELD & RANGE_2000_9FFF;
                                                    // IIgs: B=1, RAMWRT loses it (E14)

// A valid access to $C000-$C0FF. In IIe mode (MODE_D3 = 0) every cycle counts. In IIgs
// mode only cycles with /M2SEL low count: the IIgs's fast-side cycles do not assert
// /M2SEL, and their addresses are not real Apple II addresses (Apple TN #68).
C0_VALID = !M2SEL_N & RANGE_C000_C0FF
         # !MODE_D3 & RANGE_C000_C0FF;
END;
END;

// ====================================================================================
// Block A3: Apple address decoding (A10-A15) for the copy and event logic.
// ====================================================================================
SYM GLB A3 1 A3;
SIGTYPE RANGE_0400_0BFF      Out;                   // text/lores address decode
SIGTYPE RANGE_2000_5FFF      Out;                   // address decode: hires pages
SIGTYPE RANGE_C000_C0FF      Out;                   // address decode: $C0xx
SIGTYPE RANGE_2000_9FFF      Out;                   // address decode: Super Hi-Res
EQUATIONS

RANGE_C000_C0FF = !AA9 & !AA8 & AA15 & AA14 & !AA13 & !AA12 & !AA11 & !AA10;

RANGE_2000_5FFF = !AA13 & AA14 & !AA15              // $4000-$5FFF
                # AA13 & !AA14 & !AA15;             // $2000-$3FFF

RANGE_0400_0BFF = !AA10 & AA11 & !AA12 & !AA13 & !AA14 & !AA15 // $0800-$0BFF
                # AA10 & !AA11 & !AA12 & !AA13 & !AA14 & !AA15; // $0400-$07FF

RANGE_2000_9FFF = !AA13 & !AA14 & AA15              // $8000-$9FFF
                # AA13 & !AA15                      // $2000-$3FFF, $6000-$7FFF
                # AA14 & !AA15;                     // $4000-$7FFF
END;
END;

// ====================================================================================
// Block A2: the held IIgs bank bit B, and the copy strobe CATCH.
// ====================================================================================
SYM GLB A2 1 A2;
SIGTYPE BANK_HELD            Out;                   // IIgs bank B: M2B0 in bank window
SIGTYPE CATCH_ACTIVE         Out;                   // Apple video write copy active
SIGTYPE A2_FIT               Out;
EQUATIONS

// A copy is under way: CAPTURE in the data phase, with M2B0 low. The Apple leaves M2B0
// undriven in the data phase, so the card copies only because a pull-down resistor (on
// the production board, bodged onto the slot fingers near pin 35) holds it low. Pin
// CATCH_N is the inverse: its rising edge, at the end of the data phase, latches the
// Apple address into U5/U6, and GAL U17 then writes the byte from U2 into SRAM.
CATCH_ACTIVE = CAPTURE & CPU & !M2B0;

// B, the IIgs bank bit. During BANK_WINDOW it follows M2B0: a 1 is taken only on a valid
// cycle (/M2SEL low), and M2B0 low clears it. Outside the window it holds, through the
// data phase that follows. In IIe mode (MODE_D3 = 0) it is always 0. pDS's router puts a
// copy of BANK_HELD on a second output of this block, for block B0's BANK_Q
// (SecondSight_U7.fxp names it twice).
BANK_HELD =M2B0 & BANK_HELD.PIN & MODE_D3          // hold while M2B0 is 1
          # MODE_D3 & BANK_HELD.PIN & !BANK_WINDOW  // hold outside the window
          # MODE_D3 & BANK_WINDOW & M2B0 & !M2SEL_N; // set: M2B0 = 1 in the window

// Nothing reads A2_FIT. The original build had this output: pDS fits it, which puts
// BANK_HELD and CATCH_ACTIVE on the OR gates the original chip uses, then its router
// deletes it. Keep it, or this block's fuses change.
A2_FIT = MODE_D3 & BANK_WINDOW & M2SEL_N
       # !MODE_D3 & !BANK_WINDOW & M2SEL_N
       # !MODE_D3 & BANK_WINDOW & !M2SEL_N
       # MODE_D3 & !BANK_WINDOW & !M2SEL_N;
END;
END;

// ====================================================================================
// Block A1: event address bit 1, the band flags for $3000 and $7000, and Z180 data bit 1.
// ====================================================================================
SYM GLB A1 1 A1;
SIGTYPE EVENT_A1             Reg;                   // event A1 at $A6/$A7
SIGTYPE DIRTY_3000           Out;                   // band flag $3000-$3FFF
SIGTYPE DIRTY_7000           Out;                   // band flag $7000-$7FFF
SIGTYPE HD1_DRIVE            Out STRONGMIN;         // Z180 bit 1 out ($A4-$A7)
EQUATIONS

// A1 of the event's Apple address, stored when EVENT_LATCH rises. Port $A6 bit 1.
EVENT_A1 = AA1;
EVENT_A1.PTCLK = EVENT_LATCH;

// Band flag for $7000-$7FFF: set by a copied write there; port $A5 access clears it.
DIRTY_7000 = !HA0 & DIRTY_7000.PIN                  // hold: port $A4, not $A5
           # DIRTY_7000.PIN & !FLAGS_ACCESS_ALIAS   // hold: not port $A4/$A5
           # AA12 & WRITE_6000_7FFF;                // set: a copy into $7000-$7FFF

// Band flag for $3000-$3FFF: set by a copied write there; port $A4 access clears it.
DIRTY_3000 = !FLAGS_ACCESS_ALIAS & DIRTY_3000.PIN   // hold: not port $A4/$A5
           # DIRTY_3000.PIN & HA0                   // hold: port $A5, not $A4
           # AA12 & WRITE_2000_3FFF;                // set: a copy into $3000-$3FFF

// What U7 drives on Z180 data bit 1 for ports $A4-$A7; the last term holds a 1 through
// an $A4/$A5 access, as for HD3_DRIVE.
HD1_DRIVE = DIRTY_3000.PIN & !HA0 & !HA1            // $A4 bit 1: band flag $3000
          # !HA0 & HA1 & EVENT_A1                   // $A6 bit 1: event address A1
          # DIRTY_7000.PIN & HA0 & !HA1             // $A5 bit 1: band flag $7000
          # HA0 & HA1 & EVENT_A5                    // $A7 bit 1: event address A5
          # FLAGS_ACCESS_ALIAS & HD1_DRIVE.PIN;     // hold a 1 through an $A4/$A5 access
END;
END;

// ====================================================================================
// Block A0: Z180 port decoding, and the MODE_D3 configuration bit.
// ====================================================================================
SYM GLB A0 1 A0;
SIGTYPE FLAGS_ACCESS         Out;                   // Z180 access to ports $A4/$A5
SIGTYPE ACK_A0               Out;                   // $A0 access: Z180 acknowledge
SIGTYPE MODE_D3              Out;                   // port $A1 bit 3: IIgs mode
SIGTYPE FLAGS_ACCESS_ALIAS   Out;                   // second copy of FLAGS_ACCESS
EQUATIONS

// A Z180 access to port $A0, read or write: the acknowledge. It clears IRQ_PENDING and
// EVENT_LATCH, which lets RUN return and releases a stalled Apple.
ACK_A0 = !HA0 & !HA1 & !HA2 & AX;

// A Z180 access to port $A4 or $A5, the band flag ports.
FLAGS_ACCESS = HA2 & !HA1 & AX;

// The same decode again, for blocks A1 and B6.
FLAGS_ACCESS_ALIAS = HA2 & !HA1 & AX;

// Port $A1 bit 3, IIgs mode. While it is 1: a cycle counts only with /M2SEL low, B is
// tracked, Super Hi-Res $6000-$9FFF is copied, and the IIgs-only events are raised. It
// loads from HD3 on any access to port $A1 and holds otherwise, like COPY_INHIBIT.
MODE_D3 = !AX & MODE_D3.PIN
        # MODE_D3.PIN & HA2
        # MODE_D3.PIN & HA1
        # MODE_D3.PIN & !HA0
        # !HA2 & HA0 & !HA1 & AX & HD3;             // port $A1: load data bit 3
END;
END;

// ====================================================================================
// Block B0: CATCH_BANK, the SRAM bank (0 = main, 1 = auxiliary) a copied byte goes to.
// ====================================================================================
SYM GLB B0 1 B0;
SIGTYPE BANK_Q               Reg;                   // copy's SRAM bank (CATCH_BANK)
SIGTYPE B0_FIT               Out;
EQUATIONS

// Loads when CAPTURE & CPU falls: at the end of each copy's data phase, the moment
// CATCH_N rises and U5/U6 latch the address.
BANK_Q.PTCLK = !(CAPTURE & CPU);

// Bank 1 if any term is true, otherwise bank 0. B comes from M2B0 (layer 1); the
// softswitch terms cover bank $00 writes that RAMWRT or 80STORE send to auxiliary memory,
// which M2B0 does not show (layer 2). See docs/04-capture-logic.md, Bank tracking.
BANK_Q = !BANK_HELD & RAMWRT & !STORE80             // RAMWRT, 80STORE off
       # !BANK_HELD & STORE80 & PAGE2               // 80STORE with PAGE2
       # BANK_HELD & !RAMWRT & MODE_D3              // IIgs write to bank $E1 or $01;
                                                    // E14: misses B = 1 with RAMWRT on
       # !BANK_HELD & RAMWRT & MODE_D3 & !HIRES;    // IIgs mode: RAMWRT, HIRES off

// Nothing reads B0_FIT. As A2_FIT in block A2: the original build had it, pDS fits it,
// which puts BANK_Q on the OR gates the original chip uses, then its router deletes it.
B0_FIT = HIRES & BANK_HELD
       # !HIRES & !BANK_HELD;
END;
END;

// ====================================================================================
// Block B1: the event handshake with the Z180, and RDY.
// The cycle of one event:
// 1. In the data phase of an event cycle, EVENT_LATCH sets (if no event is pending).
// 2. Its rising edge stores the Apple address A0-A7 in EVENT_A0-EVENT_A7.
// 3. In the next address phase IRQ_PENDING sets and INT1_N goes low.
// 4. The Z180 reads ports $A7, $A6 and $A0; the $A0 access (ACK_A0) clears both.
// If another copy or event arrives while one is pending, RUN drops and STALL holds the
// Apple on RDY until the Z180 acknowledges, so no event and no event data byte is lost.
// ====================================================================================
SYM GLB B1 1 B1;
SIGTYPE RUN                  Out STRONGMIN;         // the Apple may run (low stalls it)
SIGTYPE IRQ_PENDING          Out;                   // INT1 to the Z180 (pin INT1_N)
SIGTYPE STALL                Out;                   // hold Apple RDY low (pin RDY0)
SIGTYPE EVENT_LATCH          Out;                   // an event is latched
SIGTYPE HDOE_B               OE;                    // Z180 data enable for this megablock
EQUATIONS

// Output enable of the three-state Z180 data pins in megablock B (HD0 and HD2).
HDOE_B = HOST_DATA_OE;

// The event interrupt to the Z180 (pin INT1_N is its inverse; INT1 also drives the Z180's
// DREQ1). It sets in the address phase after EVENT_LATCH and holds until the acknowledge.
IRQ_PENDING = !ACK_A0 & IRQ_PENDING.PIN             // hold until port $A0
            # !ACK_A0 & !CPU & EVENT_LATCH.PIN;     // set: address phase after the event

// Holds the Apple: set while RUN is low, held through the address phase, cleared in the
// first data phase after RUN returns. Pin RDY0 is its inverse; low pulls the Apple's RDY
// low through a 74F125, and the 65816 repeats the same cycle until it is released.
STALL = !RUN.PIN
      # !CPU & STALL.PIN;

// Sets in the data phase of an event cycle when RUN is high and no event is pending. It
// holds until the acknowledge; once IRQ_PENDING has set, it also clears at the next data
// phase. Its rising edge clocks the event address flip-flops EVENT_A0-EVENT_A7.
EVENT_LATCH = EVENT_LATCH.PIN & !ACK_A0 & !CPU      // hold: address phase
            # EVENT_LATCH.PIN & !IRQ_PENDING.PIN & !ACK_A0 // hold: not yet signalled
            # !IRQ_PENDING.PIN & RUN.PIN & CPU & EVENT_DECODE; // set: event data phase

// RUN falls when an event is pending and a copy arrives, or an event cycle reaches its
// data phase. It returns in an address phase once the event has been acknowledged.
RUN = !IRQ_PENDING.PIN & !ACK_A0 & !CPU             // set: address phase, nothing pending
    # !IRQ_PENDING.PIN & RUN.PIN                    // hold: no event pending
    # !EVENT_DECODE & RUN.PIN & !CAPTURE            // hold: neither a copy nor an event
    # RUN.PIN & !CAPTURE & !CPU;                    // hold: address phase of a non-copy
END;
END;

// ====================================================================================
// Block B2: event address bits 4-7, read at port $A7.
// ====================================================================================
SYM GLB B2 1 B2;
SIGTYPE EVENT_A5             Reg;                   // event A5 at $A6/$A7
SIGTYPE EVENT_A4             Reg;                   // event A4 at $A6/$A7
SIGTYPE EVENT_A7             Reg;                   // event A7 at $A6/$A7
SIGTYPE EVENT_A6             Reg;                   // event A6 at $A6/$A7
EQUATIONS

// A4-A7 of the event's Apple address, stored when EVENT_LATCH rises. A value of $B at
// port $A7 means the event was an access to the card's registers $C0Bx.
EVENT_A5 = AA5;

EVENT_A4 = AA4;

EVENT_A7 = AA7;

EVENT_A6 = AA6;
EVENT_A5.PTCLK = EVENT_LATCH;
EVENT_A4.PTCLK = EVENT_LATCH;
EVENT_A7.PTCLK = EVENT_LATCH;
EVENT_A6.PTCLK = EVENT_LATCH;
END;
END;

// ====================================================================================
// Block B3: event address bit 2, the band flags for $4000 and $8000, and Z180 data bit 2.
// ====================================================================================
SYM GLB B3 1 B3;
SIGTYPE EVENT_A2             Reg;                   // event A2 at $A6/$A7
SIGTYPE DIRTY_4000           Out;                   // band flag $4000-$4FFF
SIGTYPE DIRTY_8000           Out;                   // band flag $8000-$8FFF
SIGTYPE HD2_DRIVE            Out STRONGMIN;         // Z180 bit 2 out ($A4-$A7)
EQUATIONS

// A2 of the event's Apple address, stored when EVENT_LATCH rises. Port $A6 bit 2.
EVENT_A2 = AA2;
EVENT_A2.PTCLK = EVENT_LATCH;

// Band flag for $8000-$8FFF: set by a copied write there; port $A5 access clears it.
DIRTY_8000 = !HA0 & DIRTY_8000.PIN                  // hold: port $A4, not $A5
           # DIRTY_8000.PIN & !FLAGS_ACCESS         // hold: not port $A4/$A5
           # !AA12 & WRITE_8000_9FFF;               // set: a copy into $8000-$8FFF

// Band flag for $4000-$4FFF: set by a copied write there; port $A4 access clears it.
DIRTY_4000 = !FLAGS_ACCESS & DIRTY_4000.PIN         // hold: not port $A4/$A5
           # HA0 & DIRTY_4000.PIN                   // hold: port $A5, not $A4
           # !AA12 & WRITE_4000_5FFF;               // set: a copy into $4000-$4FFF

// What U7 drives on Z180 data bit 2 for ports $A4-$A7; the last term holds a 1 through
// an $A4/$A5 access, as for HD3_DRIVE.
HD2_DRIVE = !HA0 & DIRTY_4000.PIN & !HA1            // $A4 bit 2: band flag $4000
          # HA1 & !HA0 & EVENT_A2                   // $A6 bit 2: event address A2
          # !HA1 & DIRTY_8000.PIN & HA0             // $A5 bit 2: band flag $8000
          # HA1 & HA0 & EVENT_A6                    // $A7 bit 2: event address A6
          # FLAGS_ACCESS & HD2_DRIVE.PIN;           // hold a 1 through an $A4/$A5 access
END;
END;

// ====================================================================================
// Block B4: a copied write, split by 8 KB block, for the band flags. Each output is
// CAPTURE in the data phase with A13-A15 naming the block; the flag equations split it
// into 4 KB halves with A12.
// ====================================================================================
SYM GLB B4 1 B4;
SIGTYPE WRITE_2000_3FFF      Out;                   // copied write into $2000-$3FFF
SIGTYPE WRITE_8000_9FFF      Out;                   // copied write into $8000-$9FFF
SIGTYPE WRITE_6000_7FFF      Out;                   // copied write into $6000-$7FFF
SIGTYPE WRITE_4000_5FFF      Out;                   // copied write into $4000-$5FFF
EQUATIONS

WRITE_2000_3FFF = AA13 & !AA14 & !AA15 & CAPTURE & CPU;

WRITE_8000_9FFF = AA15 & !AA14 & !AA13 & CAPTURE & CPU;

WRITE_6000_7FFF = !AA15 & AA14 & AA13 & CAPTURE & CPU;

WRITE_4000_5FFF = !AA15 & AA14 & !AA13 & CAPTURE & CPU;
END;
END;

// ====================================================================================
// Block B5: the tracked PAGE2, RAMWRT and 80STORE switches. Block B7 decides when each
// one loads (LOAD_PAGE2, LOAD_RAMWRT, LOAD_STORE80); here each holds its value otherwise.
// All three load on falling CLK_Y0 edges, start at 0 at power-up, and keep their values
// through an Apple reset.
// ====================================================================================
SYM GLB B5 1 B5;
SIGTYPE PAGE2                Reg STRONGMIN;         // PAGE2: $C054/$C055, STATEREG bit 6
SIGTYPE RAMWRT               Reg STRONGMIN;         // RAMWRT: $C004/$C005, STATEREG bit 4
SIGTYPE STORE80              Reg;                   // 80STORE: $C000/$C001
EQUATIONS
PAGE2.CLK = !CLK_Y0;
RAMWRT.CLK = !CLK_Y0;
STORE80.CLK = !CLK_Y0;

STORE80 = STORE80 & !LOAD_STORE80                   // hold
        # LOAD_STORE80 & AA0;                       // $C000/$C001: A0, $C001 = on

PAGE2 = PAGE2 & !LOAD_PAGE2                         // hold
      # LOAD_PAGE2 & AA0 & !AA5                     // $C054/$C055 (A5=0): A0, $C055=on
      # AA5 & LOAD_PAGE2 & AD6;                     // $C068 (A5 = 1): STATEREG bit 6

RAMWRT = !AA5 & AA0 & LOAD_RAMWRT                   // $C004/$C005 (A5=0): A0, $C005=on
       # !LOAD_RAMWRT & RAMWRT                      // hold
       # LOAD_RAMWRT & AA5 & AD4;                   // $C068 (A5 = 1): STATEREG bit 4
END;
END;

// ====================================================================================
// Block B6: event address bit 0, the band flags for $2000 and $6000, and Z180 data bit 0.
// ====================================================================================
SYM GLB B6 1 B6;
SIGTYPE EVENT_A0             Reg;                   // event A0 at $A6/$A7
SIGTYPE DIRTY_2000           Out;                   // band flag $2000-$2FFF
SIGTYPE DIRTY_6000           Out;                   // band flag $6000-$6FFF
SIGTYPE HD0_DRIVE            Out STRONGMIN;         // Z180 bit 0 out ($A4-$A7)
EQUATIONS

// A0 of the event's Apple address, stored when EVENT_LATCH rises. Port $A6 bit 0.
EVENT_A0 = AA0;
EVENT_A0.PTCLK = EVENT_LATCH;

// Band flag for $6000-$6FFF: set by a copied write there; port $A5 access clears it.
DIRTY_6000 = !HA0 & DIRTY_6000.PIN                  // hold: port $A4, not $A5
           # DIRTY_6000.PIN & !FLAGS_ACCESS_ALIAS   // hold: not port $A4/$A5
           # !AA12 & WRITE_6000_7FFF;               // set: a copy into $6000-$6FFF

// Band flag for $2000-$2FFF: set by a copied write there; port $A4 access clears it.
DIRTY_2000 = !FLAGS_ACCESS_ALIAS & DIRTY_2000.PIN   // hold: not port $A4/$A5
           # HA0 & DIRTY_2000.PIN                   // hold: port $A5, not $A4
           # !AA12 & WRITE_2000_3FFF;               // set: a copy into $2000-$2FFF

// What U7 drives on Z180 data bit 0 for ports $A4-$A7; the last term holds a 1 through
// an $A4/$A5 access, as for HD3_DRIVE.
HD0_DRIVE = !HA0 & DIRTY_2000.PIN & !HA1            // $A4 bit 0: band flag $2000
          # HA1 & !HA0 & EVENT_A0                   // $A6 bit 0: event address A0
          # !HA1 & HA0 & DIRTY_6000.PIN             // $A5 bit 0: band flag $6000
          # HA1 & HA0 & EVENT_A4                    // $A7 bit 0: event address A4
          # FLAGS_ACCESS_ALIAS & HD0_DRIVE.PIN;     // hold a 1 through an $A4/$A5 access
END;
END;

// ====================================================================================
// Block B7: $C0xx decoding: which accesses load the tracked switches, and which raise an
// event. Every term needs C0_VALID; the loads also need the data phase (CPU).
// ====================================================================================
SYM GLB B7 1 B7;
SIGTYPE EVENT_DECODE         Out;                   // this $C0xx access raises an event
SIGTYPE LOAD_PAGE2           Out;                   // load PAGE2 on this access
SIGTYPE LOAD_RAMWRT          Out;                   // load RAMWRT on this access
SIGTYPE LOAD_STORE80         Out;                   // load 80STORE on this access
EQUATIONS

// Read or write. Reads of $C068 run on the IIgs fast side and never assert /M2SEL, so in
// IIgs mode only writes to $C068 reach this term.
LOAD_PAGE2 = CPU & C0_VALID & !AA7 & !AA5 & AA2 & AA6 & AA4 & !AA1 & !AA3 // $C054-$C055
           # !AA7 & AA6 & AA5 & !AA4 & AA3 & !AA2 & !AA1 & C0_VALID & CPU & !AA0; // $C068

// A write to $C000/$C001 (80STORE off/on).
LOAD_STORE80 = !AA7 & !AA6 & !AA5 & !AA4 & !AA3 & !AA2 & !AA1 & C0_VALID & CPU & !ARW;

// $C068 (STATEREG, read or write), or a write to $C004/$C005 (RAMWRT off/on).
LOAD_RAMWRT = !AA7 & !AA6 & !AA5 & !AA4 & !AA3 & AA2 & !AA1 & !ARW & C0_VALID & CPU // $C004-$C005
            # !AA7 & AA6 & AA5 & !AA4 & AA3 & !AA2 & !AA1 & !AA0 & C0_VALID & CPU; // $C068

// The accesses the Z180 hears about (docs/reference/z180-io-ports.md, Apple event
// addresses). No event for $C000/$C001 (80STORE is tracked here instead), for
// $C054/$C055 while 80STORE is on (then they switch memory, not the display), for
// $C0B8-$C0BF, or for $C068.
EVENT_DECODE = !AA7 & AA6 & AA4 & AA3 & AA2 & AA1 & !ARW & C0_VALID // $C05E-$C05F, $C07E-$C07F
             # !AA7 & !AA6 & !AA5 & !AA4 & AA3 & AA2 & !ARW & C0_VALID // $C00C-$C00F: 80VID, ALTCHAR
             # AA7 & !AA6 & AA5 & AA4 & !AA3 & C0_VALID // $C0B0-$C0B7: card registers
             # !AA7 & AA6 & !AA5 & AA4 & !AA3 & !AA2 & C0_VALID // $C050-$C053 TEXT, MIXED
             # !AA7 & AA6 & !AA5 & AA4 & AA2 & AA1 & C0_VALID // $C056-$C057 LORES/HIRES, $C05E-$C05F AN3
             # !AA7 & AA6 & !AA5 & AA4 & !AA3 & C0_VALID & !STORE80 // $C050-$C057, !80STORE
             # !AA7 & !AA6 & AA5 & !AA4 & !AA3 & !AA2 & AA1 & !AA0 & !ARW & C0_VALID & MODE_D3 // IIgs writes: $C022 text colors
             # !AA7 & !AA6 & AA5 & !AA4 & AA3 & !AA2 & AA0 & !ARW & MODE_D3 & C0_VALID; // IIgs writes: $C029 NEWVIDEO, $C02B
END;
END;

// ====================================================================================
// I/O cells: one section per pin. "I" pins are dedicated inputs, "CLK" pins clock inputs,
// "IO" pins general I/O cells. Unused: pin 35 (Y1/RESET, left as the Y1 clock input, so
// no register can be reset after power-up) and pin 13 (ispEN, unconnected on the card,
// so the chip runs normally and is programmed only out of the card). Pins 14, 24, 33
// and 36 double as the programming pins SDI, SDO, SCLK and MODE while ispEN is low.
// ====================================================================================
// Apple address A8-A15, pins 15-22.
SYM IOC IO0 1 AA8;
XPIN IO XAA8 LOCK 15;
IB11(AA8,XAA8)
END;

SYM IOC IO1 1 AA9;
XPIN IO XAA9 LOCK 16;
IB11(AA9,XAA9)
END;

SYM IOC IO2 1 AA10;
XPIN IO XAA10 LOCK 17;
IB11(AA10,XAA10)
END;

SYM IOC IO3 1 AA11;
XPIN IO XAA11 LOCK 18;
IB11(AA11,XAA11)
END;

SYM IOC IO4 1 AA12;
XPIN IO XAA12 LOCK 19;
IB11(AA12,XAA12)
END;

SYM IOC IO5 1 AA13;
XPIN IO XAA13 LOCK 20;
IB11(AA13,XAA13)
END;

SYM IOC IO6 1 AA14;
XPIN IO XAA14 LOCK 21;
IB11(AA14,XAA14)
END;

SYM IOC IO7 1 AA15;
XPIN IO XAA15 LOCK 22;
IB11(AA15,XAA15)
END;

SYM IOC IO8 1 M2SEL_N;                      // slot 39: IIgs /M2SEL, IIe SYNC
XPIN IO XM2SEL_N LOCK 25;
IB11(M2SEL_N,XM2SEL_N)
END;

SYM IOC IO9 1 ADOUT_N;                      // low: latch U3 drives the Apple data bus
XPIN IO XADOUT_N LOCK 26;
OB11(XADOUT_N,!ADOUT_ACTIVE)
END;

SYM IOC IO10 1 CATCH_N;                     // copy low; rise latches address in U5/U6
XPIN IO XCATCH_N LOCK 27;
OB11(XCATCH_N,!CATCH_ACTIVE)
END;

SYM IOC IO11 1 ADIN_N;                      // rise latches Apple data in U2
XPIN IO XADIN_N LOCK 28;
OB11(XADIN_N,!ADIN_ACTIVE)
END;

SYM IOC IO12 1 HA0;                         // Z180 address A0
XPIN IO XHA0 LOCK 29;
IB11(HA0,XHA0)
END;

SYM IOC IO13 1 HD3;                         // Z180 bit 3: MODE_D3 in; $A4-$A7 out
XPIN IO XHD3 LOCK 30;
BI11(HD3,XHD3,HD3_DRIVE,HDOE_A)
END;

SYM IOC IO14 1 HA1;                         // Z180 address A1
XPIN IO XHA1 LOCK 31;
IB11(HA1,XHA1)
END;

SYM IOC IO15 1 HD1;                         // Z180 data bit 1: driven for ports $A4-$A7
XPIN IO XHD1 LOCK 32;
OT11(XHD1,HD1_DRIVE,HDOE_A)
END;

SYM IOC IO16 1 CPU;                         // PHASE 0, slot pin 40
XPIN IO XCPU LOCK 37;
IB11(CPU,XCPU)
END;

SYM IOC IO17 1 INT1_N;                      // Z180 INT1/DREQ1: event pending low
XPIN IO XINT1_N LOCK 38;
OB11(XINT1_N,!IRQ_PENDING)
END;

SYM IOC IO18 1 CATCH_BANK;                  // copy bank: 0 = main, 1 = auxiliary
XPIN IO XCATCH_BANK LOCK 39;
OB11(XCATCH_BANK,BANK_Q)
END;

SYM IOC IO19 1 HD0;                         // Z180 data bit 0: driven for ports $A4-$A7
XPIN IO XHD0 LOCK 40;
OT11(XHD0,HD0_DRIVE,HDOE_B)
END;

SYM IOC IO20 1 HA2;                         // Z180 address A2
XPIN IO XHA2 LOCK 41;
IB11(HA2,XHA2)
END;

SYM IOC IO21 1 ARW;                         // Apple R/W: 1 = read
XPIN IO XARW LOCK 42;
IB11(ARW,XARW)
END;

SYM IOC IO22 1 RDY0;                        // low: Apple RDY via 74F125 (stall)
XPIN IO XRDY0 LOCK 43;
OB11(XRDY0,!STALL)
END;

SYM IOC IO23 1 HD2;                         // Z180 bit 2: COPY_INHIBIT in; $A4-$A7 out
XPIN IO XHD2 LOCK 44;
BI11(HD2,XHD2,HD2_DRIVE,HDOE_B)
END;

// Apple address A0-A7, pins 3-10.
SYM IOC IO24 1 AA0;
XPIN IO XAA0 LOCK 3;
IB11(AA0,XAA0)
END;

SYM IOC IO25 1 AA1;
XPIN IO XAA1 LOCK 4;
IB11(AA1,XAA1)
END;

SYM IOC IO26 1 AA2;
XPIN IO XAA2 LOCK 5;
IB11(AA2,XAA2)
END;

SYM IOC IO27 1 AA3;
XPIN IO XAA3 LOCK 6;
IB11(AA3,XAA3)
END;

SYM IOC IO28 1 AA4;
XPIN IO XAA4 LOCK 7;
IB11(AA4,XAA4)
END;

SYM IOC IO29 1 AA5;
XPIN IO XAA5 LOCK 8;
IB11(AA5,XAA5)
END;

SYM IOC IO30 1 AA6;
XPIN IO XAA6 LOCK 9;
IB11(AA6,XAA6)
END;

SYM IOC IO31 1 AA7;
XPIN IO XAA7 LOCK 10;
IB11(AA7,XAA7)
END;

SYM IOC I0 1 M2B0;                          // IIgs bank bit, slot 35; needs pull-down
XPIN I XM2B0 LOCK 14;
IB11(M2B0,XM2B0)
END;

SYM IOC I1 1 AX;                            // from U4: Z180 access to ports $A0-$A7
XPIN I XAX LOCK 24;
IB11(AX,XAX)
END;

SYM IOC I2 1 AD4;                           // Apple data bit 4
XPIN I XAD4 LOCK 36;
IB11(AD4,XAD4)
END;

SYM IOC I3 1 AD6;                           // Apple data bit 6
XPIN I XAD6 LOCK 2;
IB11(AD6,XAD6)
END;

SYM IOC Y0 1 CLK_Y0;                        // softswitch clock (falling edges)
XPIN CLK XCLK_Y0 LOCK 11;
IB11(CLK_Y0,XCLK_Y0)
END;

SYM IOC Y2 1 CLK_Y2;                        // 7M, the bank-window clock (falling edges)
XPIN CLK XCLK_Y2 LOCK 33;
IB11(CLK_Y2,XCLK_Y2)
END;

END;  //LDF DESIGNLDF
```
<!-- ldf:end -->

---

[Reference tables](README.md) | [Capture logic](../04-capture-logic.md) | [Correcting the capture logic](../12-lattice-fix.md)
