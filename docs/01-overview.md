# 01 Overview: what the card does

[Reference index](../README.md) | [Glossary](glossary.md) | [Reference tables](reference/README.md)

The Second Sight sits in an Apple IIgs or IIe slot and drives its own monitor. It watches
the slot bus instead of taking over the Apple's video: it copies writes to text, hires,
double hires and Super Hi-Res memory into its own RAM, and notices video softswitch
accesses such as $C050 (TEXT) and $C057 (HIRES). Its Z180 redraws the copied screen
through a VGA chip, so existing software shows on a VGA or AppleColor RGB monitor
unchanged. Sources: [manual](sources.md#s16); [Second.Sight.Info.txt](sources.md#s40).

IIgs programs can also talk to the card through four host addresses, $C0B0, $C0B1, $C0B2
and $C0B8 ([Host protocol](09-host-protocol.md)), and use its own 256-color and
15-bit-color modes, up to 1024 x 768 ([Video mode records](reference/video-modes.md)).

## Three subsystems

```
 Apple II slot                     Z180 computer                     Video
 -------------                     -------------                     -----
 A0-A15, D0-D7, R/W  ---->  U5/U6 address latch  --+
 M2SEL, M2B0, PHASE0        U2 data-in latch       |  U17 asks the Z180 for its bus,
                            U3 data-out latch      |  then writes the caught byte into
           ^                                       v  SRAM at the same address
           |               +--------------------------------+
  RDY <----+-- U7 Lattice  |  Z8S180 CPU, 18 MHz            |      OTI-087X VGA controller
  (stall)      ispLSI1016  |  27C1000 EPROM (firmware)      |----> 1 MB DRAM (8 x 44256)
               decides     |  128 KB SRAM (copies of the    |      OTI-068 clock synthesizer
               what to     |    Apple screens, code)        |      Bt481 color chip (DAC)
               catch  ---->|  INT1: "softswitch or command" |      VGA and AppleColor RGB
                           |  U4/U15/U17 GALs: decode, waits|      outputs
                           +--------------------------------+
```

1. **Apple interface** ([Apple interface](03-apple-interface.md), [Capture logic](04-capture-logic.md)). A Lattice
   ispLSI1016 CPLD watches every slot bus cycle. It decides which writes to copy and which
   softswitch accesses to report. It also answers the IIgs's reads of $C0B0-$C0BF. Four
   74HCT574 latches hold the caught address and data.
2. **Z180 computer** ([Z180 computer](05-z180.md), [Glue logic](07-glue-logic.md), [Firmware](08-firmware.md)). A
   Zilog Z8S180 at 18 MHz runs the firmware from a 27C1000 EPROM, copied into 128 KB of
   static RAM at boot. The same SRAM holds the copies of the Apple screens. Three small
   PLDs (U4, U15, U17) decode its memory and I/O and run the bus hand-off; a fourth, U12,
   makes the AppleColor RGB timing.
3. **Video** ([Video](06-video.md)). An Oak OTI-087X VGA controller with 1 MB of DRAM, an
   Oak OTI-068 clock synthesizer and a Brooktree Bt481 color chip produce the picture, on
   a VGA header and an AppleColor RGB header.

## The four things that happen at run time

### 1. A video write is copied

The Apple writes to, say, $2000 in bank $E1 (Super Hi-Res). The copy follows this path:

1. During the data phase, the Lattice recognizes the write and pulls CATCH low.
2. At the end of that phase, U5/U6 latch the address and U2 latches the data.
3. GAL U17 requests the Z180 bus. When granted, the latches drive the address and data,
   and U17 writes the byte to SRAM at the same address: bank 1 for $E1 or auxiliary
   memory, bank 0 for main memory.
4. The Lattice marks which 4 KB band changed. The firmware sees the resulting SRAM
   contents, not the Apple write itself.

Details and the bank-selection corner cases: [Capture logic](04-capture-logic.md).

### 2. A softswitch access is reported

The Apple reads or writes, say, $C050 (graphics on). The Lattice latches the low
address byte and pulls the Z180's INT1 low. The interrupt
handler reads the address from card ports $A6/$A7, looks it up in a 256-entry table and
updates the firmware's mode flags.

If another event arrives before acknowledgment, the Lattice holds RDY low until the
Z180 reads the pending event. [Capture logic: RDY](04-capture-logic.md#rdy-no-lost-events)

### 3. The main loop redraws

The firmware picks a renderer for the current Apple mode
(Super Hi-Res, 80- or 40-column text, double hires, hires, lores) and keeps converting the
SRAM copy into VGA memory, waiting for vertical retrace between passes.

### 4. A IIgs program sends a command

The program writes a command byte to $C0B0, raising INT1. Parameters and bulk data follow through $C0B1, and results come back through $C0B2.
$C0B8 shows a handshake byte. The commands set modes, upload pictures and palettes, scroll,
clear, poke VGA registers and even run Z180 code ([Host protocol](09-host-protocol.md)).

## Two board revisions

The only schematic is a **1994 prototype**, titled "discQUEST VGA Board". The surviving
photos show the **1995 production board**. They differ: a Bt481 replaces the drawn Bt478,
a 36 MHz oscillator clocks the Z180, the four GALs became three AMI or ICT 18CV8 parts and one
GAL16V8A, and there are rework wires. See [Board](02-board.md).

---

[Reference index](../README.md) | Next: [02 Board](02-board.md)
