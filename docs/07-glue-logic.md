# 07 Glue logic: the four small PLDs, latches and buffers

[Reference index](../README.md) | [Glossary](glossary.md) | [Reference tables](reference/README.md)

Four 20-pin PLDs and seven standard logic chips tie the Apple bus, the Z180 and the VGA
chip together. No fuse dump of the four small PLDs has been found. The board wiring
([netlist](../data/netlist/README.md), drawn from the prototype) and what the firmware
needs fix each PLD's job, but not its exact equations or clock timing.

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
  IOWR = /IORQ OR /WR. These feed the SRAM and the OTI-087X.

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
/ME (Z180 /MREQ); outputs ROM (EPROM /OE), RAM (SRAM /CE1), WAIT (Z180 /WAIT), VGAIO (OTI-087X
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
WAIT low  = for /ME low with HA19 = 1 (video memory): from the address decode, for a
            fixed number of waits, then while IOCHRDY is low
```

**Why VGAIO must be gated.** The OTI-087X sees every memory read and write (MRD and MWR
from U29), so it answers any address that falls in its window. The firmware runs its whole
upload loop from SRAM with the linear flag set (`upload_data` writes $AB, runs, then writes
$AA; [`ROM_BEEF.asm:1721-1799`](sources.md#s27)). If VGAIO carried the flag for every access, each SRAM fetch
would land in the Oak's 1 MB aperture at $100000 and collide with the SRAM. Uploads work,
so U15 passes the flag only for $80000-$FFFFF; gating it with HA19 is one way, and U15's
exact equation is not recovered.

**Copies must not reach video memory either.** During a copy the Oak still receives MWR,
while the Z180's HA16-HA19 float. Holding LA19 and LA20 low during the copy keeps the
Oak's address below its video windows, and U15 has /BACK to do it, but what the
production card does is not traced. Floating address lines cannot be assumed low.
Sources: [OTI-087 databook](sources.md#s02) pp17-18; [netlist](../data/netlist/README.md).

A replica gates LA19 the same way; the original's choice shows only to code that reads the
SRAM mirror ($20000-$3FFFF) while a VGA graphics window is mapped, which the firmware
never does. Source: [netlist](../data/netlist/README.md).

VGA register I/O has one automatic Z180 wait plus any IOCHRDY delay; SRAM needs no wait
from U15 with fast enough parts. Wait counts and margins: [wait states](05-z180.md#wait-states).

- U15 has no /RD or /WR input, so it forces the same number of waits on video memory reads
  and writes; the Oak's IOCHRDY can still make their totals differ. A read needs at least
  2 waits at 18 MHz and a write 3 for the Oak's worst-case timing
  ([VGA bus timing](reference/clocks.md#vga-bus-timing)). The count U15 forces is not
  recovered. Registered designs forcing 3 or 4 fit the PLD's resources, but the complete
  U15/Oak/U17 timing must also pass the consecutive-capture budget below. /WAIT may
  follow IOCHRDY combinationally; the HCLK input alone does not prove a registered
  /WAIT output. Source: [netlist](../data/netlist/README.md) U15.
- The EPROM's A16 is HA16, so all 128 KB appear in $60000-$7FFFF, and the boot overlay at
  $00000-$1FFFF shows the same 128 KB (code in the low half, zeros in the high half).
  Source: [netlist](../data/netlist/README.md).
- U15 has no read/write input, so reads and writes to $4xxxx/$5xxxx both flip the half.
  The firmware only reads.
- RS1 and RS2 are unconnected outputs on the drawing; the color chip takes RS0-RS2
  from HA0-HA2. On production RS2 is tied low, because the firmware uses the RS2-free
  command access ([Board](02-board.md#production-changes)).
- VGAIO drives OTI-087X LA20 (pin 71); production adds the half switch on LA19 (pin 70).

## U17: the copy controller and resets

Pins on the drawing: inputs HCLK, CATCH, CATCH_BANK, /BACK, ARES (Apple /RESET); outputs
RES (Z180 /RESET), RESN, INT_RES (no external destination), BREQ (Z180 /BUSREQ) and HWR
(Z180 /WR line). Pins 13 and 14 are open stubs; pin 15 is labeled "HA1?" (the last digit
is unreadable). Source: [netlist](../data/netlist/README.md).

One copy has these ordering constraints; the request can begin before CATCH rises:

1. CATCH rising loads U5/U6 with the Apple address. ADIN rising loads U2 with the byte.
2. U17 requests the bus. The Z180 finishes a machine cycle, including its waits, then
   asserts /BUSACK (BACK) and floats its address, data and bus-control outputs.
3. BACK enables the capture latches. The copy write waits for valid bus ownership and
   valid new latch outputs; SRAM is selected and A16 supplies the captured bank.
4. The write ends with the SRAM's setup and hold requirements met. U17 releases its
   request; the Z180 returns the bus at a bus-exchange edge.
5. The controller must also be ready to recognize the next capture. Completing the
   write alone does not establish this.

The Z180 does not sample /WAIT during bus release. U15's waits can delay the grant,
but cannot stretch U17's write after grant. Source: Zilog, March 1994,
[Z180 Family Questions and Answers](sources.md#s129),
p6-3; [UM0050](sources.md#s39) pp25-28.
- **Production drivers not traced.** If production keeps U29's MWR = /MREQ OR /WR,
  /MREQ must be low during the write; the SRAM's /WE overrides /OE, so /RD need not be
  high. Which parts drive /MREQ and SRAM A16 during a copy is not traced on any
  production photo. Pin 15 is the likely bank output; U8 has a third buffer the drawing
  omits, so U17 is not the only part that could drive /MREQ.
- **A second CATCH while a copy is pending.** CATCH clocks U5/U6 directly, so every CATCH
  replaces the saved address, even while U17 is busy; U2 changes only if ADIN also
  rises. U17 has no address or data inputs and cannot keep an older address and byte.
  BACK and BREQ do not reach U7, so a pending copy never holds the Apple. An older
  address and byte replaced before a completed write is lost. A latch change during the
  write can break the SRAM's timing.
- **Whether every CATCH makes its own write** depends on U17's busy-state logic, which is
  not recovered. That includes the repeated phases of a cycle RDY holds
  ([RDY](04-capture-logic.md#rdy-no-lost-events)).
- **Reset:** ARES is the Apple's /RESET; RES drives the Z180's /RESET, and the OTI-087X
  takes an active-high reset. The 18CV8 clears its registers at power-on. The reset
  pulse length and release edge are not known. How the Lattice responds:
  [Reset and power-on](04-capture-logic.md#reset-and-power-on).

### Copy timing budget

U5/U6 take a new address on every CATCH and U2 new data on ADIN. U17 cannot keep an
overwritten address and byte, and a pending copy does not stall the Apple. Two copied
IIgs writes can arrive about 980 ns apart, one slow cycle
([Apple TN #68](sources.md#s43)). So the first SRAM write must finish, with the SRAM's
hold time, before the second CATCH, and U17 must be ready to take the second request.

The Z180 releases its bus only at the end of its current machine cycle: 3 clocks plus
waits for a memory or I/O cycle, or 1 clock otherwise. It samples /BUSREQ at the falling
clock edge before T3, T1 and each bus-release state. That includes the gap between the
read and the write of a DMA transfer, HALT and SLEEP. Source: [Zilog UM0050](sources.md#s39)
pp25-27, "DMAC and BUSREQ, BUSACK", HALT mode and SLEEP mode. /WAIT has no effect during
bus release, so U15's waits can delay the grant but cannot stretch U17's write. Source:
[Zilog, Z180 Family Questions and Answers, March 1994](sources.md#s129),
p6-3. The firmware turns refresh off (RCR = 0), so no refresh cycle delays a copy.

ROM 1.4 sets no automatic memory waits (DCNTL = 0). Each `ldd` of its Super Hi-Res loop
reads a conversion table in video memory and writes video memory in two separate machine
cycles, so a copy waits for one of them, not the whole instruction. Text rendering writes
video memory between SRAM lookups. Masking interrupts does not hold off /BUSREQ. Sources:
`firmware/v1.4/src/superhires.asm` (`shr_high_pal0`), `text.asm`
(`render_text80_line_loop`).

The deadline: with the Toshiba TC551001-10 on s20, s108 and s109 (60 ns write pulse,
databook B-38; the s128 card's NEC -70 has its own figure), the write must start within
920 ns of the first CATCH, or 868.9 ns with a two-clock (111 ns) pulse, before latch, PLD
and gate delays. Two whole 55.6 ns clocks is the shortest registered pulse.

U17's own steps are not known: when it requests the bus (after CATCH rises, or while
CATCH is still low), how many clocks it synchronizes, when the write starts, how long it
lasts, and when it can take the next request. No fuse dump or design file of U17 or U15
has been found. The working card limits them. For example, two late-request controllers
that grant at (W+3)T, end their write at (W+6)T or (W+7)T and are ready again at (W+8)T,
where W is the total waits of the Oak access running at the first CATCH, write the first
byte in time at W = 10 but are ready only at 1000 ns and miss the second CATCH at 981 ns.
A controller that combines finishing and re-arming saves a clock and passes that case.
So if ten-wait Oak accesses occur during ROM 1.4's rendering, those slower designs are
excluded; this does not by itself prove an early request.

At the Oak's documented DRAM minimums, a video read that arrives as 3 or 5 back-to-back
refresh cycles start takes 13-14 or 20 waits
([how long IOCHRDY holds an access](05-z180.md#how-long-iochrdy-holds-an-access)). With
W = 14 the Z180 cannot grant the bus before 944 ns, past the 920 ns deadline, so with any
U17 design a capture that lands at the start of such an access is lost if the Apple writes
again 980 ns later. No Oak document says whether a line's refresh cycles run back to back
ahead of a waiting CPU access. Sequential's owner manual says programs that update Super
Hi-Res faster than the card can follow cause no "problems other than the sometimes jerky
display" ([owner manual](sources.md#s16) p30), and no owner report of a missed copy has
been found. So the card does not hold a waiting video access behind a whole group of
refresh cycles: the Oak serves it between them or ahead of them, and an emulator does the
same.

An emulator keeps U5/U6 and U2 as latches that CATCH and ADIN overwrite, keeps the Z180's
machine cycles and waits, does the SRAM write at a U17 time it names as an approximation,
and checks that two captures 980 ns apart both survive the normal renderer workload
([emulator guide](10-emulator-guide.md)). A grant after the deadline is not an error on
the card. The write stores whatever U5/U6 and U2 hold when it happens: a capture with no
CATCH after it is copied late but intact, and a capture followed by a CATCH before its
write is lost, replaced by the newer one. Whether the newer capture then gets a write of
its own is U17's unrecovered busy logic, so the emulator names its choice.

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
