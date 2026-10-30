# 04 Capture logic: the Lattice ispLSI1016 (U7)

[Reference index](../README.md) | [Glossary](glossary.md) | [Reference tables](reference/README.md)

U7 controls the Apple-side interface. On every slot bus cycle it decides three things:

1. Is this a write to Apple video memory that the card should **copy** into its own RAM?
2. Is this an access to a video softswitch or to the card's own registers that the Z180
   must be **told about** (an "event")?
3. Must the Apple **wait** (RDY low) because the Z180 has not caught up?

It also gives the Z180 eight read-only status bits ("band flags") and two configuration
bits.

The equations are U7's recovered source, [`Lattice_original-BE8C.ldf`](../data/lattice/Lattice_original-BE8C.ldf).
Lattice's pDS 2.61 builds it back into the chip's fuse map, `isplsi1016_BE8C.bin`, with
every fuse equal ([Lattice design source](reference/lattice-source.md)).

## Contents

- [Signals](#signals)
- [Configuration bits (Z180 port $A1)](#configuration-bits-z180-port-a1)
- [Which cycles count at all](#which-cycles-count-at-all)
- [Copying video writes](#copying-video-writes)
- [Bank tracking](#bank-tracking)
- [Tracked softswitches](#tracked-softswitches)
- [Events: telling the Z180 about softswitch accesses](#events-telling-the-z180-about-softswitch-accesses)
- [Band flags (ports $A4, $A5)](#band-flags-ports-a4-a5)
- [The Z180's view of U7 (ports $A0-$A7)](#the-z180s-view-of-u7-ports-a0-a7)
- [RDY: no lost events](#rdy-no-lost-events)
- [Clocks and phase](#clocks-and-phase)
- [Reset and power-on](#reset-and-power-on)
- [How this was checked](#how-this-was-checked)

## Signals

Pins and nets: [Lattice pins](reference/lattice-pins.md). The names below are those of
the [design source](../data/lattice/Lattice_original-BE8C.ldf):

- `CPU` is PHASE 0 (slot pin 40, U7 pin 37), high during the Apple data phase
  ([Clocks and phase](#clocks-and-phase)).
- `B` is the IIgs bank bit U7 holds ([Bank tracking](#bank-tracking)).
- `RUN` lets a new data byte in while no event is pending; `EVENT_LATCH` holds an event
  until the Z180 acknowledges it at port $A0 ([RDY](#rdy-no-lost-events)).
- `CATCH_pin` and `ADIN_pin` are the active-low pins themselves: 0 means asserted.

## Configuration bits (Z180 port $A1)

Port $A1 holds COPY_INHIBIT and MODE_D3. Their bit positions, effects and access
restrictions are in the [port reference](reference/z180-io-ports.md#configuration-and-open-reads).
The latches have no reset input ([Reset and power-on](#reset-and-power-on)).

## Which cycles count at all

```
VALID    = !MODE_D3 | !M2SEL_n          (IIgs mode: only valid slow-side cycles)
C0_VALID = (address is $C000-$C0FF) & VALID
```

With MODE_D3 set, a cycle that does not assert /M2SEL is ignored completely. On a IIgs
that drops fast-side cycles, whose addresses are not valid Apple II addresses (Apple
[TN #68](sources.md#s43)). On a IIe, pin 39 is SYNC, so the rule drops only opcode fetches.

A valid cycle affects the card in only four ways:
- it is a copied write ([below](#copying-video-writes));
- it is an event ([event addresses](reference/z180-io-ports.md#apple-event-addresses));
- it updates a [tracked softswitch](#tracked-softswitches);
- it is a read of $C0B0-$C0BF, which the card answers from U3.

The only other thing a cycle touches is the bank bit B, and a slow cycle sets B again
from its own M2B0 ([bank tracking](#bank-tracking)), so B carries nothing into a later
copy. Every other access, at any address, leaves the card unchanged whether or not it is
a slow cycle. That includes reads of $C071-$C07F and slot ROM areas set to Internal ROM.

## Copying video writes

```
CAPTURE = write & !COPY_INHIBIT & VALID & (
             address in $0400-$0BFF                              text and lores, pages 1-2
           | address in $2000-$5FFF                              hires, pages 1-2
           | address in $2000-$9FFF & MODE_D3 & (B xor RAMWRT) ) Super Hi-Res (bank $E1)

CATCH_pin = !(CAPTURE & CPU & !M2B0)     (physical pin: low while copying)
```

- **Only writes are copied.** Reads never change the copy.
- **$6000-$9FFF** is copied only when the write goes to the other 64 KB bank from the one
  RAMWRT selects. On a IIgs that means a write to bank $E1, or a shadowed write through
  bank $01, with RAMWRT off. This is the upper part of the Super Hi-Res screen, which lives
  at $E1/2000-$E1/9FFF. Writes to main memory $6000-$9FFF are not copied.
- **M2B0 must read low during the data phase.** Apple drives M2B0 for only 140 ns early in
  the cycle and leaves it undriven otherwise ([TN #68](sources.md#s43)). A write whose data
  phase sees M2B0 high is not copied.
  - The [prototype drawing](sources.md#s26) has no pull-down on M2B0: its net joins only slot
    pin 35 and Lattice pin 14.
  - The resistor soldered to the production card's slot fingers is on pin 36 (7M), not pin
    35 ([production changes](02-board.md#production-changes)).
  - What holds M2B0 low on a production card is not known.

What happens next is outside U7 (see [Glue logic](07-glue-logic.md)):

1. CATCH goes low during the data phase of the write and returns high at its end. The
   rising edge clocks the Apple address into U5/U6.
2. ADIN does the same for U2, so the data byte is captured at the same moment:
   `ADIN_pin = !((CAPTURE & RUN & CPU) | (EVENT_LATCH & CPU & write))`.
3. GAL U17 sees CATCH, requests the Z180 bus (BUSREQ), and when granted writes the byte
   into SRAM at bank CATCH_BANK, offset = the 16-bit Apple address. The Z180 firmware never
   handles the copy itself.

## Bank tracking

The copied byte must land in the right 64 KB SRAM bank: 0 for main memory (IIgs bank $E0),
1 for auxiliary memory ($E1). U7 works this out in two layers.

**Layer 1, the IIgs bank bit B.** Early in each address phase, the Apple drives M2B0 for
about 140 ns. U7 opens a window one Y2 period long, starting at the first falling Y2 edge
after CPU falls, and copies M2B0 into B during it (only while /M2SEL is low). B then holds
its value through the data phase.

```
CPU_DELAY   <= CPU                    (flip-flop, falling Y2)
BANK_WINDOW <= CPU_DELAY & !CPU       (flip-flop, falling Y2)
B = MODE_D3 & ( (B & M2B0) | (B & !BANK_WINDOW) | (BANK_WINDOW & M2B0 & !M2SEL_n) )
```

**Layer 2, the softswitches.** Writes through bank $00 can also go to auxiliary memory,
through RAMWRT, or through 80STORE plus PAGE2 for the text and hires pages. M2B0 does not
reflect those switches ([TN #68](sources.md#s43)), so U7 [tracks them itself](#tracked-softswitches) and combines:

```
CATCH_BANK <= (B & MODE_D3 & !RAMWRT)                 flip-flop, clocked when CAPTURE & CPU falls
            | (!B & PAGE2 & STORE80)
            | (!B & RAMWRT & !STORE80)
            | (!B & MODE_D3 & RAMWRT & !HIRES)
```

Bank 1 if any term is true, otherwise bank 0. Every case:
[capture bank terms](reference/lattice-pins.md#capture-bank-terms), and for IIgs mode the
[capture bank cases](reference/lattice-pins.md#capture-bank-cases).

Why "B xor RAMWRT": a bank $00 write that RAMWRT redirects to auxiliary memory arrives with
M2B0 low, because M2B0 does not show RAMWRT ([TN #68](sources.md#s43)). The xor turns that case into a bank 1
copy. The case it gets wrong is a direct write to $E1 or $01 while RAMWRT is on: B = 1
always means the auxiliary bank, so B or RAMWRT would have been the correct rule
([E14](reference/errata.md#e14-direct-e1-writes-with-ramwrt-on-are-not-copied-above-6000)).
The [corrected fuse map](12-lattice-fix.md) makes that change.

Two edge cases follow from the equations:

- With B and RAMWRT both set (a write to $E1 or $01 while RAMWRT is on), the copy goes to
  bank 0, and $6000-$9FFF is not copied. The IIgs game Rastan does this with its palettes
  ([E14](reference/errata.md#e14-direct-e1-writes-with-ramwrt-on-are-not-copied-above-6000)).
- With B = 0, MODE_D3 = 1, 80STORE on, HIRES on, PAGE2 off and RAMWRT on, writes to
  $4000-$9FFF are copied into bank 0. For $6000-$9FFF that overwrites the firmware's own
  code, which crashes the card. This and the other cases where U7's bank differs from
  the Apple's rule are [E28](reference/errata.md#e28-with-80store-on-u7-picks-the-copys-bank-without-looking-at-the-address).
  The [corrected fuse map](12-lattice-fix.md) gives U7 the Apple's rule.

### Bank without M2B0

If M2B0 is never driven (a ROM 01 IIgs outside slot 3, or a IIe), copying works only while
the line reads low. B then stays 0, and:

- text, lores and hires copies still work, banked by the tracked softswitches;
- the $6000-$9FFF Super Hi-Res term needs `B xor RAMWRT`, which reduces to RAMWRT. IIgs
  Super Hi-Res writes arrive in bank $E1 without RAMWRT, so the lower half of the SHR
  screen ($2000-$5FFF) lands in bank 0 and the upper half is not copied at all.

That is why the manual says a ROM 01 IIgs must use slot 3.

## Tracked softswitches

Four flip-flops follow the Apple's own softswitches on falling Y0 edges. HIRES loads for
a qualifying $C056/$C057 address (C0_VALID), without a CPU/data-phase term; PAGE2, RAMWRT
and STORE80 require CPU high as well. Source: [design source](../data/lattice/Lattice_original-BE8C.ldf), blocks A7, B5 and B7.

The address is stable through a normal bus cycle, so the missing data-phase term does not
change what HIRES ends up holding. Every switch:
[tracked softswitches](reference/z180-io-ports.md#tracked-softswitches).

- Reads of $C068 run on the IIgs fast side and do not assert /M2SEL ([TN #68](sources.md#s43)), so in
  practice only **writes** to $C068 reach these bits.
- RAMRD and ALTZP are not tracked; they only affect reads.
- These bits clear at power-up and keep their values through an Apple reset; later
  softswitch accesses update them ([Reset and power-on](#reset-and-power-on)).

## Events: telling the Z180 about softswitch accesses

An event is raised for the $C0xx accesses in
[Apple event addresses](reference/z180-io-ports.md#apple-event-addresses), each with C0_VALID.

No event for: $C000/$C001 (80STORE is tracked in U7 instead; the firmware's handler for
them is never called), $C054/$C055 while 80STORE is on (they switch memory, not the
display), $C0B8-$C0BF, $C068.

What happens on an event:

1. During the data phase, EVENT_LATCH sets (if no earlier event is still pending).
2. Its rising edge stores the low address byte AA0-AA7 in eight flip-flops. The Z180 reads
   them as two nibbles: port $A6 = A3-A0, port $A7 = A7-A4.
3. For a write, ADIN also clocks the data byte into U2 (Z180 port $A0).
4. In the following address phase, IRQ_PENDING sets and INT1 goes low.
5. The Z180's handler reads $A7, $A6 and $A0. Any Z180 access to port $A0 is the
   **acknowledge**: it clears IRQ_PENDING and EVENT_LATCH.

For a read event, U2 is not clocked, so $A0 returns the last byte latched into U2:
the last copied write or write event.
The firmware's handlers ignore the data byte for read-type switches.

INT1 is also wired to the Z180's DREQ1 (schematic sheet 2). When the firmware pulls a
block of command parameters, it points DMA channel 1 at port $A0 with DREQ1 edge-triggered,
so each Apple write to $C0B1 raises INT1, which requests one DMA read of $A0, which is the
acknowledge. Source: [`ROM_BEEF.asm`](sources.md#s27) command dispatch.

## Band flags (ports $A4, $A5)

Eight flags mark which 4 KB block of $2000-$9FFF has had a copied write since the Z180
last read them. See [band flag layout](reference/z180-io-ports.md#band-flag-layout).

- A flag sets on any CAPTURE in its block, in either bank, including hires copies.
- Any Z180 access to the port returns its four flags and clears them. (U7 has no Z180
  read/write input. The firmware only reads.)
- The Super Hi-Res renderer uses them to redraw only changed bands of the screen
  ([`ROM_BEEF.asm:9036-9160`](sources.md#s27)).

## The Z180's view of U7 (ports $A0-$A7)

U7 sees Z180 address bits 0-2 plus AX from U4 ([port table](reference/z180-io-ports.md#port-table)).

U7 drives HD0-HD3 whenever `AX & HA2` selects ports $A4-$A7, including on a write.
The Z180 then drives the same lines, losing the write data in bus contention. On reads,
bits 7-4 float; U2 must stay disabled or it would fight U7 on bits 0-3 ([Z180 I/O ports](reference/z180-io-ports.md)).

The firmware writes port $A9 with 0 when it selects AppleColor RGB output. If AX also
covered $A8-$AF, that write would land on port 1 and clear MODE_D3, turning off Super
Hi-Res copying in every RGB mode. So U4 asserts AX only for $A0-$A7.

## RDY: no lost events

While an event is unacknowledged, the next qualifying copy or event pauses the Apple, so
no event is lost. Whether every copy finishes before the next write depends on U17 and on
VGA waits ([copy timing](07-glue-logic.md#copy-timing-budget)).

```
IRQ_PENDING = !ACK & (IRQ_PENDING | (EVENT_LATCH & !CPU))
RUN         = (RUN & !IRQ_PENDING) | (RUN & !CAPTURE & !EVENT) | (RUN & !CAPTURE & !CPU)
            | (!ACK & !IRQ_PENDING & !CPU)
STALL       = !RUN | (STALL & !CPU)
RDY0 pin    = !STALL                   (low pulls Apple RDY low)
ACK         = AX & !HA0 & !HA1 & !HA2  (a Z180 access to port $A0)
```

Sequence:

1. An event is pending (INT1 low).
2. The Apple starts another qualifying copy or event. In its data phase RUN drops.
3. STALL sets, RDY0 goes low, the 65816 holds the cycle (same address, same data).
4. The Z180 acknowledges through port $A0. IRQ_PENDING clears.
5. After the next low phase RUN returns; after the next high phase STALL clears and RDY
   is released. The held cycle then completes and is processed normally.

These are asynchronous latches, so the stall length depends on how fast the Z180 answers,
not on a fixed count.

- Why copies also stall: U2 still holds the pending event's data byte, which the Z180 has
  not read yet. ADIN is gated by RUN so a copy cannot overwrite it.
- CATCH is not gated by RUN. During a stall the held cycle repeats: each repeated data
  phase relatches the same address into U5/U6 while U2 keeps the event byte. U17 has no
  RUN or RDY input, so it cannot tell a repeated phase from the final one. Whether each
  repeated CATCH makes a write depends on U17's busy-state logic, which is not recovered
  ([U17](07-glue-logic.md#u17-the-copy-controller-and-resets)). A write made during the
  stall stores the event byte at the held address; the final phase latches the right
  byte into U2, and its copy stores it over the same address.
- Copies alone never stall: they do not set IRQ_PENDING.
- For a softswitch event the INT1 handler reads ports $A7, $A6 and then $A0. The $A0 read
  acknowledges the event; the next low and high CPU phases restore RUN and release RDY.
  Source: ROM `handle_event`.

## Clocks and phase

- **CPU** (pin 37) is PHASE 0 (slot pin 40): the equations need a signal that is high during
  the data phase and falls at its end, and PHASE 0 is that signal.
- **Y2** (pin 33), falling edge: CPU_DELAY and BANK_WINDOW. BANK_WINDOW is high for one Y2
  period after CPU falls, the time M2B0 is valid (about 140 ns, [Apple TN #68](sources.md#s43)). That fixes
  Y2 at 7M (slot pin 36), whose period is about 140 ns. The [prototype drawing](sources.md#s26) leaves pin 33
  a stub. On the production card a rework wire carries 7M from the slot finger to the
  Lattice socket; its end is hidden under the socket ([production changes](02-board.md#production-changes)).
- **Y0** (pin 11), falling edge: HIRES, PAGE2, RAMWRT, STORE80. PAGE2, RAMWRT and STORE80
  load only while CPU is high; HIRES needs only the address. Any slot clock that falls in
  each phase meets that, so 7M and Q3 both work; a replica uses 7M.
- EVENT_LATCH (rising) clocks the event address; the end of `CAPTURE & CPU` clocks
  CATCH_BANK.

## Reset and power-on

The 15 flip-flops (four softswitches, the bank window, eight event-address bits and
CATCH_BANK) have no product-term reset. Lattice's global reset clears the registers at
power-up, so they start at 0, with 80STORE off. Source: [Lattice 1992 Data Book](sources.md#s75) p4-7.

Pin 35 is the global reset input only if the design leaves Lattice's `Y1_AS_RESET` option
on; otherwise it is the Y1 clock input and no register can be reset after power-up.
Source: [Lattice pDS+ Fitter User Manual](sources.md#s76) p3-22.

On the drawn board pin 35 shares a net with the OTI-087X's active-high reset. In reset
mode that net would always hold one of the two chips in reset (high resets the Oak, low
resets the Lattice), but the card runs both. The fuse map agrees: BE8C's reset multiplexer
takes the constant, not pin 35, which is what pDS 2.61 writes for `OPTION Y1_AS_RESET
OFF`, the option the recovered [source](../data/lattice/Lattice_original-BE8C.ldf) has.

So pin 35 is the Y1 clock input, unused, and an Apple reset leaves the Lattice registers
alone. The IIgs reset code rewrites HIRES, PAGE2 and RAMWRT itself.
Sources: [netlist](../data/netlist/README.md); [OTI-087 databook](sources.md#s02) p18.

COPY_INHIBIT, MODE_D3, the band flags and the RUN/IRQ handshake are feedback latches with
no reset. Their power-on values never reach software: the firmware writes $A1 in its
first instructions and $A0 during boot, which acknowledges any pending event; with ACK
and IRQ_PENDING low, the next low CPU phase sets RUN. The first Super Hi-Res render
ORs the band flags it reads with $FF, so their starting values do not change that
redraw. Source: [`ROM_BEEF.asm:9036-9044`](sources.md#s27).

## How this was checked

Lattice pDS 2.61 builds the recovered source,
[`Lattice_original-BE8C.ldf`](../data/lattice/Lattice_original-BE8C.ldf), into BE8C with all 15,360
fuses equal. Every equation, register, clock and pin of the source is therefore the
chip's, including the copy rule (CAPTURE), the bank equation (CATCH_BANK) and the event
decode (EVENT_DECODE) that errata
[E14](reference/errata.md#e14-direct-e1-writes-with-ramwrt-on-are-not-copied-above-6000),
[E15](reference/errata.md#e15-the-iigs-border-color-does-not-show) and
[E28](reference/errata.md#e28-with-80store-on-u7-picks-the-copys-bank-without-looking-at-the-address)
rest on.

The firmware, which the source was never fitted to, agrees with it:

- The eight band flags match the SHR redraw boundaries: lines 24, 50, 75, 101, 127,
  152, 178 and 198 are the last whole lines in the eight 4 KB blocks.
- COPY_INHIBIT matches SetShadow's values 0 and 4.
- The firmware writes its 80STORE variable but never reads it; U7 tracks 80STORE and
  sends no $C000/$C001 events.
- PAGE2 loads from STATEREG bit 6 through pin 2, AD6.

Reproducing it: [Method](13-method.md#6-decode-the-lattice-isplsi1016).

---

Previous: [03 Apple interface](03-apple-interface.md) | [Reference index](../README.md) | Next: [05 Z180 computer](05-z180.md)
