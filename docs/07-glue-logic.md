# 07 Glue logic: the four small PLDs, latches and buffers

[Reference index](../README.md) | [Glossary](glossary.md) | [Reference tables](reference/README.md)

Four 20-pin PLDs and seven standard logic chips tie the Apple bus, the Z180 and the VGA
chip together. No fuse dump of the four PLDs exists; their equations here follow from the
board wiring ([netlist](../data/netlist/README.md)) and from what the firmware needs.

## Contents

- [The parts](#the-parts)
- [Latches and buffers](#latches-and-buffers)
- [U4: I/O decode](#u4-io-decode)
- [U15: memory decode, boot overlay, half switch, waits](#u15-memory-decode-boot-overlay-half-switch-waits)
- [U17: the copy controller and resets](#u17-the-copy-controller-and-resets)
- [U12: AppleColor RGB timing](#u12-applecolor-rgb-timing)

## The parts

Each part's role and clock: [logic roles](reference/board-connections.md#logic-roles).
Which package is which: [PLD markings](02-board.md#pld-markings).

U12 and U17 cannot be GAL16V8s as drawn. Their flip-flops force registered mode, in which
pin 11 is /OE; that pin is open on both, and the GAL's pull-up would turn the outputs
off. An 18CV8 has an ordinary input there.
Sources: GAL16V8 registered-mode page and active pull-ups; [netlist](../data/netlist/README.md).

Reading the GAL's marking rotated 180 degrees, U4's rework wires attach at pins 17 and 5.
One reaches the latch clock, so production U4 uses its pins differently from the drawing,
where pin 17 is DIVOE and pin 5 HA4.

## Latches and buffers

```
Apple D0-D7 --> U2 (D) --Q--> Z180 HD0-HD7      clock ADIN (from U7), output enable BEN (from U4)
Z180 HD0-HD7 -> U3 (D) --Q--> Apple D0-D7       clock BCLK (from U4), output enable ADOUT (from U7)
Apple A0-A7 --> U5 (D) --Q--> Z180 HA0-HA7      clock CATCH (from U7), output enable BACK
Apple A8-A15 -> U6 (D) --Q--> Z180 HA8-HA15     clock CATCH (from U7), output enable BACK
```

- The 74HCT574 takes its inputs on the **rising** clock edge. CATCH and ADIN are low during
  the qualifying data phase, so the latches capture at its end.
- BACK is the Z180's /BUSACK. While the Z180 has released its bus, U5/U6 drive the caught
  address onto it.
- U8 (74F125), from the [netlist](../data/netlist/README.md):
  - gate A: input grounded, enable RDY0 (U7) -> Apple RDY. RDY0 low pulls RDY low.
  - gate B: input grounded, enable AIRQ0 (U4) -> Apple /IRQ. AIRQ0 low pulls IRQ low.
  - gate D: input VCLK0 (OTI-068), enable DIVOE (U4), output VCLK1 -> the color chip's pixel
    clock. U12's VCLK1 output joins the same net. So the VGA path buffers VCLK directly,
    and the RGB path turns this gate off and lets U12 drive a divided clock.
  - gate C: not drawn.
- U29 (74ACT32): MRD = /MREQ OR /RD, MWR = /MREQ OR /WR, IORD = /IORQ OR /RD,
  IOWR = /IORQ OR /WR. These feed the SRAM and the OTI-087.

## U4: I/O decode

Pins: inputs HA0-HA7, /HRD, /HWR, /IOE (Z180 /IORQ), /BACK; outputs BCLK, AX, BEN, DIVOE,
VGAIO_SEL, AIRQ0.

U4 sees only the low 8 bits of the I/O address, so the card's ports repeat for every high
byte ($00A0, $01A0, ... all hit port $A0). The VGA chip decodes its own ports fully. The
outputs: [U4 output controls](reference/z180-io-ports.md#u4-output-controls).

Eight product terms are too few for separate set and clear strobes on each full port
address. A feedback latch whose data is HA0 fits: the even port stores 0, the odd port 1,
and the port-pair decode is its enable, so U4 needs no clock. The firmware
confirms the polarity with $A9 (DIVOE high), $AB (linear flag high) and $AD (IRQ released).
Source: [netlist](../data/netlist/README.md).

**Any read or write of $A8-$AD** performs the pair's action: the reset code reads $AA
([`ROM_BEEF.asm:60`](sources.md#s27)), which only makes sense if reads act, and the latch
takes its value from the address, not from the written byte.

Reads of $A1-$A3 return the undriven bus, and $AE/$AF do nothing: U4 has no output left
for them. U4's latches hold no defined value until the firmware's reset writes ($AD, $AA)
and the first mode set. The linear flag reaches Oak pin 71 through U15's VGAIO.

Only Z180 I/O can change the Apple IRQ output; U4 has no Apple-side inputs, so the IRQ
stays asserted until the Z180 clears it. Source: [netlist](../data/netlist/README.md).

During a copy U4 must ignore the bus: /BUSACK gating prevents the caught Apple address
and copy /WR from acting like Z180 port writes (for example $A0 or $A1).

## U15: memory decode, boot overlay, half switch, waits

Pins: inputs HCLK (pin 1, register clock), /BACK, IOCHRDY, VGAIO_SEL, HA16-HA19, RTS0,
/ME (Z180 /MREQ); outputs ROM (EPROM /OE), RAM (SRAM /CE1), WAIT (Z180 /WAIT), VGAIO (OTI-087
LA20), RS1 and RS2 (not connected on the drawing).

What U15 must do:

```
ROM  low  = /ME low and ( HA19-17 = 011                      EPROM at $60000-$7FFFF
                        or (RTS0 high and HA19-17 = 000) )   boot overlay at $00000-$1FFFF
RAM  low  = (/ME low and HA19-18 = 00 and not (RTS0 high and HA17 = 0))
                                                             SRAM at $00000-$3FFFF, mirror at $2xxxx
          or BACK low                                        the copy writes SRAM
half      <= 0 on /ME low with HA19-16 = 0100                register, clocked by HCLK
half      <= 1 on /ME low with HA19-16 = 0101
LA19      = half                                             Oak address bit 19 (rework wire)
VGAIO     = linear flag (VGAIO_SEL) and HA19 = 1             Oak address bit 20 (LA20)
WAIT low  = for /ME low with HA19 = 1 (video memory): from the address decode, for at
            least 2 waits on a read and 3 on a write, then while IOCHRDY is low
```

**Why VGAIO must be gated.** The OTI-087 sees every memory read and write (MRD and MWR
from U29), so it answers any address that falls in its window. The firmware runs its whole
upload loop from SRAM with the linear flag set (`upload_data` writes $AB, runs, then writes
$AA; [`ROM_BEEF.asm:1721-1799`](sources.md#s27)). If VGAIO carried the flag for every access, each SRAM fetch
would land in the Oak's 1 MB aperture at $100000 and collide with the SRAM. Uploads work,
so U15 passes the flag only for $80000-$FFFFF. A replica gates LA19 the same way; the
original's choice shows only to code that reads the SRAM mirror ($20000-$3FFFF) while a VGA
graphics window is mapped, which the firmware never does. Source: [netlist](../data/netlist/README.md).

VGA register I/O has one automatic Z180 wait plus any IOCHRDY delay; SRAM needs no wait
from U15 with fast enough parts. Wait counts and margins: [wait states](05-z180.md#wait-states).

- The EPROM's A16 is HA16, so all 128 KB appear in $60000-$7FFFF, and the boot overlay at
  $00000-$1FFFF shows the same 128 KB (code in the low half, zeros in the high half).
  Source: [netlist](../data/netlist/README.md).
- U15 has no read/write input, so reads and writes to $4xxxx/$5xxxx both flip the half.
  The firmware only reads.
- RS1 and RS2 are unconnected outputs on the drawing; the color chip takes RS0-RS2
  from HA0-HA2. On production RS2 is tied low, because the firmware uses the RS2-free
  command access ([Board](02-board.md#production-changes)).
- VGAIO drives OTI-087 LA20 (pin 71); production adds the half switch on LA19 (pin 70).

## U17: the copy controller and resets

Pins: inputs HCLK, CATCH, CATCH_BANK, /BACK, ARES (Apple /RESET); outputs RES (Z180
/RESET), RESN, INT_RES (not connected), BREQ (Z180 /BUSREQ), HWR (Z180 /WR line), and pin 15
labeled "HA1?" (the last digit is unreadable; transcribed as HA19).

One copy:

```
1. CATCH rises (end of the Apple's data phase). U5/U6 and U2 hold address and data.
2. U17 sees the edge (synchronized to HCLK) and pulls /BUSREQ low.
3. The Z180 finishes its current machine cycle and pulls /BUSACK (BACK) low. It
   floats its address bus, data bus, /MREQ, /IORQ, /RD and /WR.
4. With BACK low: U5/U6 drive HA0-HA15, U2 drives HD0-HD7 (U4 BEN), U15 selects the SRAM,
   and U17 drives SRAM A16 from CATCH_BANK. U17 pulses /WR (HWR) low for at least the
   SRAM's 60 ns minimum write pulse (TC551001-10 datasheet): at least two HCLK
   periods, 111 ns at 18 MHz.
5. U17 releases /WR, then /BUSREQ. The Z180 takes the bus back.
```

- **Every CATCH is a copy.** U17's only inputs are HCLK, CATCH, CATCH_BANK, /BACK and
  ARES: pins 6-9 and 11 are open, and no production rework wire reaches U17. So it
  cannot tell the repeated phases of a cycle that RDY holds from the phase that
  completes it, and copies on each one, also while the Z180 runs its INT1 handler. What
  those copies write: [RDY](04-capture-logic.md#rdy-no-lost-events).
- Pin 15 must carry CATCH_BANK to SRAM A16 during step 4: nothing else drives HA16 then,
  and CATCH_BANK enters only U17. So the pin is **HA16**.
- **Bus strobes:** /MREQ must be low and /RD high during the write. U17 drives them
  through its pins 13 and 14; no other drawn part can.
- **Reset:** ARES produces RES for the Z180, and RESN the OTI-087's active-high reset.
  How the Lattice responds: [Reset and power-on](04-capture-logic.md#reset-and-power-on).

### Copy timing budget

The copy must finish before another captured write replaces the address in U5/U6.
These latches take a new address on every CATCH; copies alone do not stall the Apple.
On a IIgs the next copied write can follow one slow cycle, about 980 ns, later.
Source: [Apple TN #68](sources.md#s43).

The Z180 releases its bus at the end of its current machine cycle: 3 clocks plus waits
for a memory or I/O cycle, or 1 clock otherwise. BUSREQ takes priority over on-chip DMA,
which pauses between its read and write. Source: [Zilog UM0050](sources.md#s39), "BUSREQ/BUSACK Bus Exchange Timing" and "DMAC and BUSREQ, BUSACK".

The delay before a copy starts is at most one machine cycle: about 167 ns for a
zero-wait SRAM access or 222 ns for a card-port access at 18 MHz. An SRAM wait
lengthens that cycle. U17's copy sequence takes 7-10 HCLK periods (about 0.4-0.6 us)
without added VGA waits: synchronization, bus grant, at least two write clocks, then
release. VGA waits can add up to the AT-bus allowance of 2.5 us
([wait states](05-z180.md#wait-states)).

## U12: AppleColor RGB timing

Pins: VCLK0 (pin 1, register clock), DIVOE, HSYNC, VSYNC; outputs VCLK1, XSYNC.

- While DIVOE selects the RGB path: VCLK1 = VCLK0 divided by 2 (a toggle flip-flop), driven
  onto the color chip's pixel clock. U8 gate D is off.
- While DIVOE selects the VGA path: VCLK1 tri-stated, so U8 gate D passes VCLK0.
- XSYNC = composite sync for the AppleColor RGB monitor, HSYNC AND VSYNC in
  negative logic (either low gives low). The AppleColor RGB monitor takes composite sync
  on one pin.

The 80-column and 640-wide RGB modes run at 63 MHz / 2 (sequencer) / 2 (U12) =
15.75 MHz dots, 16.4 kHz lines. The 36 MHz RGB modes ($01/$FB/$FC) give 9 MHz dots
at 15.85-16.54 kHz. RGB $FA uses the VGA path at 15.58 kHz instead.

---

Previous: [06 Video](06-video.md) | [Reference index](../README.md) | Next: [08 Firmware](08-firmware.md)
