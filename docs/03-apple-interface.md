# 03 Apple interface: slot signals, host registers, timing

[Reference index](../README.md) | [Glossary](glossary.md) | [Reference tables](reference/README.md)

## Contents

- [What the card does on the slot](#what-the-card-does-on-the-slot)
- [The host registers](#the-host-registers)
- [Which machine, which slot](#which-machine-which-slot)
- [IIgs bus timing the card depends on](#iigs-bus-timing-the-card-depends-on)
- [What the card needs from the IIgs: every slow-side cycle](#what-the-card-needs-from-the-iigs-every-slow-side-cycle)
- [RDY: pausing the Apple](#rdy-pausing-the-apple)
- [IRQ](#irq)
- [Reset](#reset)
- [IIe differences](#iie-differences)

## What the card does on the slot

- It **listens** to every bus cycle: address, data, read/write, and three IIgs timing and
  bank signals.
- It **drives** the Apple data bus only when the Apple reads $C0B0-$C0BF.
- It **drives RDY low** to pause the Apple's processor when the card has not yet handled
  the previous softswitch access or command.
- It is wired to drive IRQ, but the firmware never does.
- It has **no slot ROM** and ignores the slot's own select lines (/IOSELECT, /DEVSELECT,
  /IOSTROBE). It decodes full 16-bit addresses itself.

Pin by pin: [Apple slot pins](reference/slot-pins.md).

## The host registers

The card's command interface sits at the same addresses in every slot, because the
Lattice decodes the full address instead of using the slot's DEVSELECT
([host registers](reference/host-commands.md#host-registers)). Source: [VGALOW.ASM](sources.md#s29).

- Every read of $C0B0-$C0BF returns one 8-bit latch (U3). The Z180 loads it by writing
  port $A0.
- Every write of $C0B0-$C0B7 stores the data byte in latch U2, which the Z180 reads at
  port $A0.
- The Sequential library uses only $C0B0 (command), $C0B1 (data out), $C0B2 (data in) and
  $C0B8 (handshake). Source: [VGALOW.ASM](sources.md#s29).
- The card's host addresses $C0B0-$C0BF are slot 3's DEVSELECT range, so another card
  in slot 3 would clash with them. The manual puts the Second Sight itself in slot 3 on
  a ROM 01 IIgs, which keeps that range free.

The command protocol built on them: [Host protocol](09-host-protocol.md).

## Which machine, which slot

Which machines and slots work: [machine and slot compatibility](reference/slot-pins.md#machine-and-slot-compatibility).
Without M2B0 the card cannot tell a write to bank $E1 from one to bank $E0, so it loses
Super Hi-Res, which lives in $E1 ([bank without M2B0](04-capture-logic.md#bank-without-m2b0)).

## IIgs bus timing the card depends on

The IIgs runs its slots from the 1 MHz "slow side" (the Mega II chip). The key signals,
from Apple IIgs Technical Note #68:

- **PHASE 0** (pin 40): the 1 MHz slot clock. The data phase is PHASE 0 high. A slow cycle
  is 980 ns when cycles run back to back.
- **/M2SEL** (pin 39): low when the processor is synchronized to the slow side and the
  address on the bus is a valid Apple II address in the 128 KB main or auxiliary space.
  [TN #68](sources.md#s43): "/M2SEL can be viewed as an extension of the address bus on the expansion slots."
  - Low for: shadowed video writes, internal I/O and slot accesses, all of banks $E0/$E1.
  - Not low for: fast-side registers $C035, $C036, $C037, and **reads** of $C02D and
    $C068. The card never sees those.
- **M2B0** (pin 35): the low bit of the bank. [TN #68](sources.md#s43): it "is normally tri-stated and goes
  active for 140 nanoseconds, starting 140 nanoseconds after the PH0 clock falls". It is
  high for bank $E1 and for shadowed writes and I/O through bank $01. It does not follow
  RAMRD, RAMWRT, ALTZP, 80STORE or PAGE2.
- **RDY** (pin 21): the 65816 holds the current cycle while RDY is low. [TN #68](sources.md#s43): assert or
  release RDY only while /M2SEL is low and PH0 is high, stable 60 ns before PH0 falls,
  with an open-collector driver.

```
 one slow cycle (about 980 ns): address phase, then data phase

 PHASE0  ~~\_________________________/~~~~~~~~~~~~~~~~~~~~~~~~~~~~\___
              address phase              data phase ("CPU" high)
 M2B0    ------<=140 ns=>------------------------------------------   driven 140-280 ns after PH0 falls,
                                                                      tri-stated (pulled low) otherwise
 /M2SEL  ~~~~~~~~~\________________________________________________   low = valid slow access
                  ^ Lattice samples M2B0         ^ latches take address and data (end of data phase)
```

How the card uses these:

1. Early in the address phase, while M2B0 is driven, the Lattice copies it into its bank
   bit.
2. During the data phase, the Lattice decides whether this cycle is a copy or an event.
3. At the end of the data phase, the latches take the address and data, and the bank
   bit is stored with them, so bank and address belong to the same cycle
   ([bank tracking](04-capture-logic.md#bank-tracking)).

## What the card needs from the IIgs: every slow-side cycle

The card only sees what reaches the slot pins. On a IIgs that is every Mega II cycle,
including:

- writes to banks $E0/$E1;
- writes to banks $00/$01 that the IIgs **shadows** into $E0/$E1 (text, hires, double
  hires, Super Hi-Res), which happen as slow cycles with /M2SEL low;
- reads and writes of the $C0xx I/O space.

Fast-side cycles (bank $00/$01 RAM that is not shadowed, fast ROM, the fast-side
registers) never reach the card. So turning off IIgs shadowing also stops the card's
copy. Source: [TN #68](sources.md#s43).

## RDY: pausing the Apple

- The Lattice output RDY0 drives the enable of a 74F125 buffer whose input is grounded.
  RDY0 low pulls the slot's RDY line low (an open-collector style connection).
- While an event is unacknowledged, the next copy or event stalls the Apple. RDY releases
  after the acknowledge plus one low and one high PHASE 0 period; no event is lost.
  Copies alone never stall.
- How fast a copy completes also depends on the Z180 bus grant and on VGA waits, which can
  reach the AT-bus allowance of 2.5 us ([copy timing](07-glue-logic.md#copy-timing-budget),
  [wait states](05-z180.md#wait-states)).
- The BE8C Lattice implements the RDY handshake. The 1995 library source predates it:
  "When the RDY support in the PAL is done" ([VGALOW.ASM](sources.md#s29) line 677).

## IRQ

- GAL U4 output AIRQ0 drives the slot's /IRQ through the 74F125.
- The 1.4 firmware never raises it. Z180 port $AC raises it and $AD clears it; the reset
  code writes $AD once.
- Only Z180 I/O can change the IRQ latch: U4 sees HA0-HA7, /RD, /WR, /IORQ and /BUSACK.
  The IIgs cannot clear it; it remains asserted until the Z180 clears it. Source: [netlist](../data/netlist/README.md).

## Reset

- Slot /RESET (pin 31) goes into GAL U17 as ARES. U17's RES output drives the Z180's
  /RESET, restarting its firmware.
- The drawing joins the OTI-087's active-high RSET input ([databook p18](sources.md#s02)) and Lattice pin 35
  on the net RESET; U17's RESN is a separate lone label. How the Lattice responds to
  reset: [Reset and power-on](04-capture-logic.md#reset-and-power-on).
- On a IIgs, Control-Reset makes the system assert RESET, which is slot pin 31, so the
  card's Z180 restarts with the IIgs. Source: [Apple IIgs Hardware Reference](sources.md#s78), ADB keyboard reset and slot pin 31.

## IIe differences

On a IIe the same pins carry different signals ([FAQ part 13](sources.md#s42)):

- Pin 39 is the 6502's **SYNC**, high during an opcode fetch. The Lattice reads it as
  /M2SEL. Low means "not an opcode fetch", which is true for every data read and write,
  so copies and events still qualify.
- Pin 35 is unused in slots 2-6 (so the card's pull-down holds it low), the active-low
  keyboard enable ENKBD' in slot 1 (the pull-down leaves the keyboard enabled) and the
  color reference in slot 7. With M2B0 low the bank comes only
  from the tracked softswitches, which is correct on a IIe.
- The firmware sets the same mode bit (MODE_D3) on both machines; it does not tell a IIe
  from a IIgs. Source: [ROM_BEEF.asm:58-59](sources.md#s27).

The card has no separate IIe mode. The manual permits IIe slots 1-7, but slot 7 does not
copy reliably: its pin 35 carries the driven 3.58 MHz color reference, and the copy needs
M2B0 low. Use slots 1-6.

---

Previous: [02 Board](02-board.md) | [Reference index](../README.md) | Next: [04 Capture logic](04-capture-logic.md)
