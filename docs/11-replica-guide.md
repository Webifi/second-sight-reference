# 11 Replica guide

[Reference index](../README.md) | [Glossary](glossary.md) | [Reference tables](reference/README.md)

What a replica of the whole card needs, the hardware ROM 1.4 never uses included: custom
Z180 and IIgs programs use it. Pins: [prototype netlist](../data/netlist/README.md).
Production parts: [Board connections](reference/board-connections.md#production-parts).

## Reading route

1. Which board: [board revisions](02-board.md#two-revisions-one-schematic),
   [production changes](02-board.md#production-changes).
2. The plan: [architecture options](#architecture-options), [slot signals](reference/slot-pins.md).
3. Capture and copies: [Capture logic](04-capture-logic.md), [Glue logic](07-glue-logic.md),
   [netlist](../data/netlist/README.md).
4. Timing: [slot timing](03-apple-interface.md#iigs-bus-timing-the-card-depends-on),
   [copy budget](07-glue-logic.md#copy-timing-budget), [clocks](14-custom-code.md#clock).
5. Video and firmware: [Video](06-video.md), [Host protocol](09-host-protocol.md),
   [Beyond the firmware](14-custom-code.md).
6. Checks: [emulator checks](10-emulator-guide.md#implementation-checks),
   [details the sources leave open](#decisions-the-sources-leave-to-the-builder).
7. On an A2FPGA: [On an A2FPGA card](#on-an-a2fpga-card),
   [what ROM 1.4 needs from the processor](05-z180.md#what-rom-14-needs-from-the-processor).

Most of the original chips are out of production: the OTI-087X, OTI-068, Bt481 and
ispLSI1016.

## Contents

- [What the replica must reproduce](#what-the-replica-must-reproduce)
- [Architecture options](#architecture-options)
- [The slot side](#the-slot-side)
- [The Apple-side logic](#the-apple-side-logic)
- [The Z180 side](#the-z180-side)
- [The video side](#the-video-side)
- [On an A2FPGA card](#on-an-a2fpga-card)
- [Decisions the sources leave to the builder](#decisions-the-sources-leave-to-the-builder)

## What the replica must reproduce

A replica must match three interfaces:

1. **The Apple slot**, electrically and in timing ([Apple interface](03-apple-interface.md)).
2. **The Z180's view of the world**: the memory map, the ports, the boot overlay, INT1 and
   DMA behavior ([Z180 computer](05-z180.md)), because the firmware is unchanged.
3. **The complete video register set** ([Video](06-video.md)): standard VGA, all documented
   Oak extensions, the Bt481 registers and color modes, and every OTI-068 clock selection.
   Custom code can program these directly, including features never used by the ROM.

The Apple-side logic is U7's design source, [`SecondSight_U7.ldf`](../data/lattice/SecondSight_U7.ldf),
which pDS 2.61 builds back into the original fuse map, plus the [glue logic](07-glue-logic.md).

## Architecture options

```
Option A: real Z180, logic in a CPLD, video in an FPGA

  slot <-> 5 V buffers <-> CPLD (Lattice + U4/U15/U17 logic, latches)
                              |
                         Z8S180 + flash (EPROM image) + 128 KB SRAM
                              |  8-bit bus, /WAIT
                         FPGA: OTI-087 + Bt481 + clocks + video RAM --> DAC --> VGA / RGB

Option B: one FPGA

  slot <-> 5 V buffers <-> FPGA: Lattice logic, Z180 soft core + MMU + DMA, SRAM,
                                 OTI-087, palette, clocks --> DAC --> VGA / RGB
```

- **Option A** keeps the processor real, with its DMA edge sense, MMU and I/O waits. A
  5 V CPLD removes most level shifting on the slot side.
- **Option B** is smaller but needs a Z180 core that implements the MMU (CBR, BBR, CBAR),
  both DMA channels including edge-sensed DREQ1 and I/O-to-memory modes, vectored INT1, and
  the ASCI0 control register bit used for the boot overlay. Those are the ROM's immediate
  requirements; the replica must also implement all documented timers, serial channels,
  clock controls, interrupts, and other on-chip resources. Source: [Zilog UM0050](sources.md#s39).

## The slot side

- **Levels.** The Apple bus is 5 V TTL. A 3.3 V device needs 5 V-tolerant input buffers and
  bus drivers for D0-D7 (driven only on reads of $C0B0-$C0BF).
- **RDY and /IRQ** must be pull-down-only (open-collector style) drivers. The original uses a
  74F125 with its input grounded and the enable as the control.
- **M2B0** needs a pull-down: Apple drives it only for about 140 ns per cycle, and the card
  must see it low the rest of the time. [Apple TN #68](sources.md#s43) asks for no more than one LS TTL load
  on M2B0.
- **Timing to meet** ([TN #68](sources.md#s43) and the decode):
  - take the address and data at the end of the data phase (PHASE 0 high);
  - sample M2B0 140-280 ns after PHASE 0 falls (the original uses a one-period window;
    its clock source is [Lattice clocks](04-capture-logic.md#clocks-and-phase));
  - change RDY only while /M2SEL is low and PHASE 0 is high, stable 60 ns before PHASE 0
    falls.
- Pins the card uses: [Apple slot pins](reference/slot-pins.md).

## The Apple-side logic

Implement the [Lattice equations](04-capture-logic.md) with their event ordering:

- 15 flip-flops: four softswitches on Y0, the bank window on Y2, the event address,
  CATCH_BANK.
- Latches held by their own feedback: COPY_INHIBIT, MODE_D3, the band flags, the
  RUN/IRQ/STALL handshake. The original sets and clears them asynchronously; a clocked
  FPGA version must set and clear them at the same moments.
- The four 74HCT574 latches and the copy controller ([Glue logic](07-glue-logic.md)) can
  live in the same device.
- Optionally, the three corrections of [U7 v2.0](12-lattice-fix.md): the bank rule "B or
  RAMWRT" (E14), an event for $C034 writes (E15), and the Apple's bank rule for writes
  made while 80STORE is on (E28). None changes anything ROM 1.4 relies on.

An FPGA can sample PHASE 0 and M2B0 with a fast clock, for example 4x 14.318 MHz, within
the [slot timing](#the-slot-side) ([Lattice clocks](04-capture-logic.md#clocks-and-phase)).
Source: [TN #68](sources.md#s43).

## The Z180 side

- 18 MHz, 128 KB SRAM, the EPROM image in flash or ROM.
- Memory decode per [Glue logic](07-glue-logic.md#u15-memory-decode-boot-overlay-half-switch-waits),
  including the overlay controlled by /RTS0 and the half switch at $4xxxx/$5xxxx.
- I/O decode on the low 8 address bits: ports $A0-$A7 to the Apple-side logic, the
  $A8-$AD latches, the VGA ranges to the video side
  ([Z180 I/O ports](reference/z180-io-ports.md#port-pairs-a8-ad)).
- The copy: request the bus, write the latched byte into SRAM (bank from CATCH_BANK), with
  /MREQ low and /RD high during it ([copy controller](07-glue-logic.md#u17-the-copy-controller-and-resets)).
- Optionally, a pull-up on /INT0. The original lacks it, so its Oak vertical-retrace
  interrupt is unusable; adding it costs nothing for ROM 1.4:
  [INT0 has no pull-up](reference/board-connections.md#int0-has-no-pull-up).
- /WAIT from the video side when it is busy. The waits must keep the data protocol and
  leave time for a copy before the next Apple slow cycle
  ([copy timing](07-glue-logic.md#copy-timing-budget)).

## The video side

Use the [Oak registers](reference/oti087-registers.md), [Bt481 controls](reference/bt481-modes.md)
and [clock selections](reference/clocks.md). Reproduce the [video-window mapping](06-video.md#the-video-ram-window)
and [output paths](06-video.md#outputs-and-the-monitor-type).

The VGA output needs separate syncs; AppleColor RGB needs composite sync. Use a triple
video DAC or resistor ladders for analog RGB. The monitor-type input can come from
the cable or a switch.

## On an A2FPGA card

The A2FPGA Multicard ([a2fpga_core](sources.md#s102)) is an Apple II, IIe and IIgs slot card
with an FPGA, SDRAM and HDMI output. Its A2N20v2 board already reads every slot signal
the Second Sight uses, so [Option B](#architecture-options) fits on it as new FPGA
logic, with HDMI in place of the analog outputs.

### What the card provides

| The Second Sight needs | A2N20v2 provides |
|---|---|
| Every slow-side cycle: address, data, R/W, /M2SEL or SYNC, M2B0 ([slot pins](reference/slot-pins.md)) | An XC9572XL CPLD (a small programmable logic chip with 5 V-tolerant pins) captures every slot signal and passes it to the FPGA over an 8-bit multiplexed bridge; `hdl/bus/apple_bus.sv` reads the address, data, R/W, /M2SEL and M2B0 each cycle. The card already uses M2B0 for its own IIgs Super Hi-Res display. |
| Data driven onto D0-D7 for reads of $C0B0-$C0BF | Supported: the core drives the data bus for the cards it emulates. |
| RDY pulled low to hold the 65816 ([RDY](04-capture-logic.md#rdy-no-lost-events)) | RDY is wired to CPLD pin 76. The published core never drives it (its control output bit 3 stays 1), and the CPLD's own program is not in the repository; the card's JTAG header J3 reprograms the CPLD. |
| /IRQ (never used by ROM 1.4) and /RESET in | Both supported; the core can also hold the Apple in reset while the FPGA starts. |
| 128 KB SRAM, the 128 KB EPROM image, 512 KB or 1 MB video RAM, the palette | 8 MB of 32-bit SDRAM inside the FPGA package and 103 KB of block RAM ([Tang Nano 20K](sources.md#s103)). The SRAM alone is larger than the block RAM, so the SRAM, the ROM image and the video RAM go in SDRAM; the 256 x 24-bit palette fits in block RAM. |
| VGA and AppleColor RGB outputs | HDMI only: see [HDMI output](#hdmi-output). |
| IIgs ROM 00/01: slot 3, because only slot 3 carries M2B0 | The same rule for the same reason. |

The FPGA has 20,736 logic cells. The published A2FPGA build uses 8,489 of them, 40 of the
46 block RAMs and both PLLs (clock generators), so a Second Sight design is easiest as its
own FPGA image. The A2FPGA's own Apple display logic is not part of it: the Second Sight
draws every Apple mode with ROM 1.4's [renderers](08-firmware.md#renderers) through the
emulated video chip.

The bridge is multiplexed: the FPGA reads the slot signals in turns and writes the
control outputs back through the same 8 lines. A RDY change made through it must still
land while PHASE 0 is high and stay stable 60 ns before PHASE 0 falls
([slot timing](#the-slot-side)).

### What has to be written

- **The Apple-side logic**: the [Lattice equations](04-capture-logic.md) (full text:
  [SecondSight_U7.ldf](../data/lattice/SecondSight_U7.ldf)), the latches U2, U3, U5 and U6,
  and the copy controller U17 ([Glue logic](07-glue-logic.md)). A per-cycle version is in
  the [emulator guide](10-emulator-guide.md#a-per-cycle-model).
- **The Z180.** [What ROM 1.4 needs from the processor](05-z180.md#what-rom-14-needs-from-the-processor)
  lists the instructions and internal registers it uses.
  - [Y80e](sources.md#s104) is a Z80/Z180-compatible Verilog core with every
    Z180 I/O instruction and `MLT`; it used 2,557 logic cells on an Altera Cyclone III.
    Its page lists no MMU, DMA, serial ports or timers.
  - [mmu180](sources.md#s105) is a Z180 MMU in Verilog, small enough for a
    XC95144XL CPLD.
  - Neither core has the Z180's two DMA channels, its ASCI and CSI/O, its timers or its
    interrupt unit; [Zilog UM0050](sources.md#s39) specifies them. The ROM uses
    DMA channel 0 memory to memory and channel 1 between port $A0 and memory, paced by
    DREQ1 edges ([firmware DMA channels](reference/z180-io-ports.md#firmware-dma-channels)).
  - Address decode, the boot overlay on /RTS0, the half switch and the card ports:
    [U15](07-glue-logic.md#u15-memory-decode-boot-overlay-half-switch-waits),
    [port table](reference/z180-io-ports.md#port-table).
- **The OTI-087.** The [ao486](sources.md#s106) project's standard VGA used 2,534
  logic cells on an Altera Cyclone IV E and has no extensions. The Oak extensions, the
  values ROM 1.4 writes, the [video window](06-video.md#the-video-ram-window) and the
  [64-bit latch lane rule](06-video.md#the-64-bit-latch-lane-rule) are in the
  [Oak registers](reference/oti087-registers.md) and [Video](06-video.md).
- **The Bt481** palette and color modes: [Bt481 controls](reference/bt481-modes.md).
- **The OTI-068**: only its frequency table matters, because it sets the emulated mode
  timing: [clock selections](reference/clocks.md).

### HDMI output

- **Keep the emulated timing.** A mode's picture timing comes from its CRTC registers and
  its OTI-068 pixel clock ([video modes](reference/video-modes.md)). ROM 1.4 polls Input
  Status 1 ($3DA) bit 3, vertical retrace, before it draws lores and before it writes the
  flashing-text colors, and custom code times PRT0 from the same bit
  ([Beyond the firmware](14-custom-code.md)). So the emulated CRTC runs at the mode's own
  rates and sets the $3DA bits, and the HDMI side reads the finished picture at its own
  fixed timing.
- **Memory traffic.** The largest pictures are 1024 x 768 in 256 colors (786,432 bytes)
  and 640 x 480 in 24-bit color (921,600 bytes)
  ([additional modes](reference/video-modes.md#additional-modes)). Reading one 60 times a
  second takes up to 55 MB/s. A 32-bit SDRAM at 100 MHz moves 400 MB/s at most, which
  leaves room for the Z180, the video writes and the Apple copies.
- **The HDMI mode.** The published A2FPGA core outputs 720 x 480 at 60 Hz. The 640 x 400 and
  640 x 480 modes fit in it; 800 x 600 and 1024 x 768 need a larger output mode or
  scaling down. 1024 x 768 at 60 Hz needs 650 Mbps per HDMI lane; [NESTang](sources.md#s107) drives
  720p (742.5 Mbps per lane) from a Tang board.
- **The monitor type.** The firmware picks its VGA or AppleColor RGB mode list from $3C2
  bit 4 ([monitor type](06-video.md#outputs-and-the-monitor-type)). On HDMI that bit is a
  setting: 1 selects the VGA list, 0 the RGB list with its 16.4 kHz line rates.

### Checks that test one part at a time

1. **Capture alone.** Compare the copied SRAM bytes with the IIgs's own screen memory,
   using the [per-cycle model](10-emulator-guide.md#a-per-cycle-model).
2. **Z180 and ROM.** After the [boot](05-z180.md#boot), GetStatus must answer `GSVGA`, $06,
   then $14 for ROM 1.4 ([exact reply](reference/host-commands.md#getstatus)).
3. **First picture.** The first main-loop pass selects Apple 40-column text from the SRAM
   copy of text page 1 ([Boot](05-z180.md#boot)).
4. **The rest:** the [implementation checks](10-emulator-guide.md#implementation-checks),
   the [host software](10-emulator-guide.md#6-host-software-to-test-with), and the ROM's
   own [known faults](reference/errata.md), so that a ROM fault is not taken for a logic
   fault.

## Decisions the sources leave to the builder

Details the sources do not fix, and where each is discussed:

| Design detail | Reference |
|---|---|
| Small PLDs | [PLD functions](07-glue-logic.md) |
| Video address bits 19-20 | [video window wiring](06-video.md#the-video-ram-window) |
| Capture clocks | [Lattice clocks](04-capture-logic.md#clocks-and-phase) |
| Reset | [reset wiring](04-capture-logic.md#reset-and-power-on) |
| Monitor detection | [monitor type](06-video.md#outputs-and-the-monitor-type) |
| Video waits and copy timing | [wait states](05-z180.md#wait-states) |
| Connections the drawing leaves out | [Board connections](reference/board-connections.md#connections-the-drawing-leaves-out) |

---

Previous: [10 Emulator guide](10-emulator-guide.md) | [Reference index](../README.md) | Next: [12 Correcting the capture logic](12-lattice-fix.md)
