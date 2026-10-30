# 12 Correcting the capture logic

[Reference index](../README.md) | [Glossary](glossary.md) | [Errata](reference/errata.md)

Lattice v2.0 fixes three faults of the capture logic that no firmware change can reach:

- [E14](reference/errata.md#e14-direct-e1-writes-with-ramwrt-on-are-not-copied-above-6000):
  direct $E1 writes made with RAMWRT on are lost.
- [E15](reference/errata.md#e15-the-iigs-border-color-does-not-show): the IIgs border color
  never reaches the card.
- [E28](reference/errata.md#e28-with-80store-on-u7-picks-the-copys-bank-without-looking-at-the-address):
  with 80STORE on, some writes are copied into the wrong SRAM bank, in one case over the
  card's own code.

Everything else in the chip, pins included, stays as the original. Chips and programming:
[Lattice chip versions](lattice-versions.md#getting-a-chip).

## Contents

- [What the corrected map changes](#what-the-corrected-map-changes)
  - [Direct $E1 writes (E14)](#1-direct-e1-writes-e14)
  - [Border writes (E15)](#2-border-writes-e15)
  - [The bank with 80STORE on (E28)](#3-the-bank-with-80store-on-e28)
- [The fuses](#the-fuses)
- [Building the file](#building-the-file)
- [Checking it on a card](#checking-it-on-a-card)

## What the corrected map changes

Three equations change and one output is added; every other output keeps the original's
equation ([both design sources](reference/lattice-source.md)). Names are those of
[Capture logic](04-capture-logic.md); B is the IIgs bank bit the card takes from M2B0.

```text
CAPTURE, the Super Hi-Res upper-half term ($6000-$9FFF in IIgs mode)
  before: B & MODE_D3 & $2000-$9FFF & write & !COPY_INHIBIT & /M2SEL low & !RAMWRT
  after:  B & MODE_D3 & $2000-$9FFF & write & !COPY_INHIBIT & /M2SEL low

CATCH_BANK, the SRAM bank of a copy (register BANK_Q)
  before: B & MODE_D3 & !RAMWRT
          # !B & RAMWRT & !80STORE
          # !B & 80STORE & PAGE2
          # !B & MODE_D3 & RAMWRT & !HIRES
  after:  B
          # !B & RAMWRT & !80STORE
          # !B & 80STORE & PAGE2 & text page 1
          # !B & 80STORE & PAGE2 & HIRES & hires page 1
          # !B & 80STORE & RAMWRT & any other address

HIRES1_ADDR, a new output in block A2 in place of the unused A2_FIT, read by CATCH_BANK
  the address is in hires page 1 ($2000-$3FFF)

EVENT_DECODE, one added term
  $C034 & write & MODE_D3 & C0_VALID
```

### 1. Direct $E1 writes (E14)

With the two RAMWRT conditions gone, U7 picks a write whose bank bit is 1 for copying and
names SRAM bank 1 for it whatever RAMWRT says, the rule "B or RAMWRT" instead of "B xor
RAMWRT". Writes with B = 1 always go to bank $01 or $E1 on the IIgs, so this is the bank
they belong in.

U7 only makes that decision: it pulls CATCH and ADIN low and sets CATCH_BANK, and U5/U6,
U2 and U17 copy the byte as they copy every screen write ([Copying video
writes](04-capture-logic.md#copying-video-writes)). The game Rastan's palettes and
scan-line control bytes then reach the card. Only writes with B = 1 made while RAMWRT is
on change; every other write meets the same terms as in the original map.

### 2. Border writes (E15)

A write to $C034 in IIgs mode (MODE_D3 set) raises an event,
like a write to $C022 or $C029. The IIgs drives the new value on the slot's data bus
during the write, as for every write. U7 pulls ADIN low, which latches that byte into
U2, stores the address's low byte ($34) in its own flip-flops, and pulls INT1 low. The
Z180's event handler reads the address from ports $A7/$A6 and the byte from port $A0
([Events](04-capture-logic.md#events-telling-the-z180-about-softswitch-accesses)).

ROM 1.4 has no handler for $34, so its default handler ignores the byte;
[firmware 2.0](firmware-versions.md) adds one that takes bits 3-0 as the border color
([E15](reference/errata.md#e15-the-iigs-border-color-does-not-show)). Like every event,
it can hold the IIgs on RDY for a moment when another event or screen write arrives
before the Z180 has read port $A0 ([RDY](04-capture-logic.md#rdy-no-lost-events)).

### 3. The bank with 80STORE on (E28)

For a write with B = 0, CATCH_BANK follows the Apple's rule ([Apple IIgs Hardware
Reference](sources.md#s78) p44, Table 3-3; the IIe has the same rule): with 80STORE on,
PAGE2 picks the bank for text page 1 ($0400-$07FF), and for hires page 1 ($2000-$3FFF)
while HIRES is on; RAMWRT picks it for every other address. The original applied PAGE2 to
every address while 80STORE was on, and in IIgs mode RAMWRT too while HIRES was off. With
80STORE off nothing changes.

How it fits in the chip: CATCH_BANK's block, B0, finds text page 1 from the existing
$0400-$0BFF decode and A10. It cannot read A13-A15, because in B0 each shares its
routing-pool slot with a signal the block already reads
([the chip's limits](reference/lattice-source.md#building-and-changing-the-design)).
So a new output in block A2, HIRES1_ADDR, decodes hires page 1 from the existing
$2000-$5FFF decode and A13. It takes the output of A2_FIT, an unused output that only
steered where pDS put block A2's terms, so those terms may sit on other OR gates. The B
term drops MODE_D3, which frees A10's slot in B0; B is always 0 in IIe mode anyway.

CATCH_BANK loads as the copy's data phase ends, at the same moment U5/U6 latch the
address on CATCH_N, which U7 makes from the same signal, so the address is still
valid then.

### Unchanged band flag

The $9000 band flag stays as the factory chip has it: it also sets on palette and
control-byte writes ([E13](reference/errata.md#e13-fast-animation-is-choppy)). Changing it
would take two more outputs and save a few milliseconds a pass, and only for programs
that change palettes without drawing.

## The fuses

A fuse map lists the chip's 15,360 programming bits. Lattice's pDS 2.61 builds the
corrected design, [`Lattice_v2.0.ldf`](../data/lattice/Lattice_v2.0.ldf)
with its placement file, into fuse checksum BBB1. 142 bits differ from the original
BE8C.

They sit in the four blocks that changed, A2 (the new HIRES1_ADDR), A4 (CAPTURE),
B0 (CATCH_BANK's register BANK_Q) and B7 (EVENT_DECODE), and in six routing-pool
connections: B0 replaces MODE_D3 with A10, the $0400-$0BFF decode and HIRES1_ADDR;
A2 takes A13 and the $2000-$5FFF decode.

pDS places each changed block anew, so its product terms move within the block. The twelve
other blocks, the rest of the routing pool and the pins keep every fuse of the original.

`PLSI16.SDF`, the pDS 2.61 device file, defines every ispLSI1016 fuse and the logic it
selects: product terms, OR gates, routing, clocks and outputs. The original source
builds to BE8C with every fuse equal
([Method](13-method.md#6-decode-the-lattice-isplsi1016)).

## Building the file

**Ready-built:** [`Lattice_v2.0-BBB1_ispLSI1016.jed`](../prebuilt/lattice/Lattice_v2.0-BBB1_ispLSI1016.jed),
for the ispLSI1016. It goes with [firmware 2.0](firmware-versions.md)
([Lattice chip versions](lattice-versions.md)).

**From source:** pDS 2.61 builds
[`data/lattice/Lattice_v2.0.ldf`](../data/lattice/Lattice_v2.0.ldf), which
has a comment on every block, signal and term:

```bash
tools/lattice/pds261_build.sh data/lattice/Lattice_v2.0.ldf data/lattice/Lattice_v2.0.fxp build/lattice/Lattice_v2.0_ispLSI1016.jed
```

What it needs, the steps by hand, and the checks of a built file against its source and
the three fixes: [Building the Lattice fuse map](../tools/lattice/README.md).

## Checking it on a card

- **E14:** Rastan's backgrounds, which the card shows black or in the title screen's
  colors, show in the same colors as on the IIgs
  ([Rastan](reference/errata.md#e14-direct-e1-writes-with-ramwrt-on-are-not-copied-above-6000)).
  A short test, with interrupts off and a Super Hi-Res picture on screen: turn RAMWRT on
  (`STA $C005`), store a new value into palette 0, color 1 with a long store to
  $E1:9E02, and turn RAMWRT off again (`STA $C004`). The card shows the new color.
- **E15:** the border color reaches the firmware only through the $C034 event and the
  byte U2 latches with it. With ROM 1.4 or firmware 1.5 the card looks the same as
  before; with [firmware 2.0](firmware-versions.md) the border follows the IIgs border
  color.
- **E28:** in IIgs mode, with a Super Hi-Res picture on screen, shadowing on and
  interrupts off: turn 80STORE on (`STA $C001`), HIRES on (`LDA $C057`), PAGE2 off
  (`LDA $C054`) and RAMWRT on (`STA $C005`); store a byte to $00:6000; then turn RAMWRT
  and 80STORE off again (`STA $C004`, `STA $C000`). The IIgs puts the byte in $E1:6000,
  and the card shows it there. The original card copies it over its own code instead.
- **Everything else:** programs that never write $E1 directly with RAMWRT on and never
  write outside text page 1 and hires page 1 with 80STORE on look exactly as before,
  because no other copy rule changed.

An emulator or a replica can offer these changes as an option, with the original
behavior as the default.

---

Previous: [11 Replica guide](11-replica-guide.md) | [Reference index](../README.md) | Next: [13 Method](13-method.md)
