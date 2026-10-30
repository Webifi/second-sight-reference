# Apple slot pins

[Reference tables](README.md) | [Glossary](../glossary.md) | [Apple interface](../03-apple-interface.md)

Which of the 50 slot pins the card uses, and for what. Where the production board needs an
added wire, the pin's entry names it.

- The card **reads** the address bus, the data bus, R/W, /M2SEL, M2B0, /RESET and (on the
  production board) two clocks.
- The card **drives** the data bus (only when the Apple reads $C0B0-$C0BF), RDY and /IRQ.
- The card **ignores** the slot's own select lines (/IOSELECT, /DEVSELECT, /IOSTROBE). It
  decodes full addresses itself, so it answers at the same addresses in any slot.
- It passes the two slot "daisy chains" straight through, so it never blocks interrupt or
  DMA priority for other cards.

Sources: the [prototype schematic](../sources.md#s26) sheet 1 ([netlist](../../data/netlist/README.md),
connector U1) for the connections; the [comp.sys.apple2 FAQ part 13](../sources.md#s42) and
[Apple IIgs Technical Note #68](../sources.md#s43) for the pin meanings.

## Contents

- [Pin table](#pin-table)
- [Notes on individual pins](#notes-on-individual-pins)
- [Machine and slot compatibility](#machine-and-slot-compatibility)
- [Machine-readable copy](#machine-readable-copy)

## Pin table

Pins 1-25 are on the component side of the card edge and 26-50 on the solder side; pin 1
faces pin 50 and pin 25 faces pin 26.

<!-- csv: data/tables/apple-slot-signals.csv -->
| Pin | Signal | What the card does with it | Connected to (prototype drawing) |
|---|---|---|---|
| 1 | /IOSELECT | Not used. The card has no slot ROM. | No connection drawn |
| 2-17 | A0-A15 | Read. The Lattice decodes every address; latches U5/U6 hold the address of a copied write. | U5, U6, U7 |
| 18 | R/W | Read. 1 = the Apple is reading. | U7 |
| 19 | (IIe/IIgs slot 7: composite sync) | Not used. | No connection drawn |
| 20 | /IOSTROBE | Not used. | No connection drawn |
| 21 | RDY | **Driven low** to pause the Apple's processor ([RDY and /IRQ](#rdy-and-irq)). | U8 gate A output |
| 22 | /DMA | Not used. The card never takes over the Apple bus. | Signal label with no connected part |
| 23 | INT OUT | Joined to pin 28 ([daisy chains](#daisy-chains)). | pin 28 |
| 24 | DMA OUT | Joined to pin 27 ([daisy chains](#daisy-chains)). | pin 27 |
| 25 | +5 V | Powers the card. | all logic |
| 26 | Ground | Ground reference for the card. | all logic |
| 27 | DMA IN | Joined to pin 24. | pin 24 |
| 28 | INT IN | Joined to pin 23. | pin 23 |
| 29 | /NMI | Not used. | No connection drawn |
| 30 | /IRQ | **Can be driven low**, but the 1.4 firmware never does ([RDY and /IRQ](#rdy-and-irq)). | U8 gate B output |
| 31 | /RESET | Read. An Apple reset restarts the card's Z180. | U17 (reset logic) |
| 32 | /INH | Not used. | No connection drawn |
| 33 | -12 V | The drawing shows C32 to ground. The C32 footprint is unfitted on s20, s108 and s109; do not list a fitted 0.1 uF production capacitor here. | C32 on prototype |
| 34 | -5 V | Not used. | No connection drawn |
| 35 | M2B0 (IIgs) | Read. Tells which 64 KB bank a IIgs write goes to ([M2B0](#m2b0-pin-35)). | U7 |
| 36 | 7M (7 MHz clock) | Clocks the Lattice's bank-sampling window; the production card adds a wire for it ([production changes](../02-board.md#production-changes), [Lattice clocks](../04-capture-logic.md#clocks-and-phase)). | Signal label with no connected part |
| 37 | Q3 | No use drawn. It can clock Lattice Y0 instead of 7M ([Lattice clocks](../04-capture-logic.md#clocks-and-phase)). | No connection drawn |
| 38 | PHASE 1 | Not used. | No connection drawn |
| 39 | /M2SEL (IIgs) or SYNC (IIe) | Read. Marks a bus cycle the card should look at ([pin 39](#pin-39-m2sel-or-sync)). | U7 |
| 40 | PHASE 0 | The Lattice's "data phase" input on the production board ([Lattice clocks](../04-capture-logic.md#clocks-and-phase)). | Signal label with no connected part |
| 41 | /DEVSELECT | Not used. | No connection drawn |
| 42-49 | D7-D0 | Read (latch U2) and driven (latch U3, only on reads of $C0B0-$C0BF). | U2, U3; D4 and D6 also go to U7 |
| 50 | +12 V | The drawing shows C34 to ground. A ceramic is fitted at C34, but its capacitance is unmarked in the photos; 0.1 uF is a drawing value. | C34 on prototype |

## Notes on individual pins

### RDY and /IRQ

The card pulls these lines low through a 74F125 buffer whose input is tied to ground. When
the buffer is enabled, it pulls the line low; when disabled, it lets go. That is the
open-collector style connection Apple requires for both lines ([TN #68](../sources.md#s43)).

- **RDY:** the Lattice enables the buffer when a new softswitch access or copy arrives
  while the Z180 has not yet answered the previous softswitch access. The Apple's
  processor then holds its current cycle until the Z180 catches up. Details:
  [Capture logic: RDY](../04-capture-logic.md#rdy-no-lost-events).
- **/IRQ:** see [Apple IRQ control](z180-io-ports.md#apple-irq).

### Daisy chains

The Apple II passes interrupt priority and DMA priority from slot to slot. Each card gets
the "chain" on its IN pin and hands it on through its OUT pin. A card that does not take
part must connect IN to OUT, or every card in a lower-priority slot loses its interrupts
or DMA.

The Second Sight uses neither, so the drawing joins pin 28 (INT IN) to pin 23 (INT OUT) and
pin 27 (DMA IN) to pin 24 (DMA OUT). Source: [netlist](../../data/netlist/README.md).

### M2B0 (pin 35)

On a IIgs, M2B0 is the low bit of the bank for slow (Mega II) cycles: 1 for bank $E1, or a
shadowed write through bank $01. The Apple drives it only for about 140 ns early in each
cycle and leaves it floating the rest of the time ([TN #68](../sources.md#s43)).

- The card copies a write only if M2B0 reads **low** during the data phase, after the
  Apple stops driving it ([copying video writes](../04-capture-logic.md#copying-video-writes)).
- Which slots have it: a ROM 03 IIgs in slots 1-6; a ROM 01 IIgs in slot 3 only. That is
  why the manual requires slot 3 on a ROM 01 machine.
- On a IIe, pin 35 is unused in slots 2-6, the active-low keyboard enable in slot 1 and
  the driven color reference in slot 7: [IIe slots](../03-apple-interface.md#iie-differences).

### Pin 39: /M2SEL or SYNC

- **IIgs:** /M2SEL is low when the address on the bus is a valid Apple II address in a slow
  (Mega II) cycle. The card ignores every cycle where it is high, which filters out the
  IIgs's fast cycles.
- **IIe:** the same pin carries the 6502's SYNC, high during an opcode fetch. Low means
  "not an opcode fetch", which is true for every data read and write, so the card still sees
  every write it needs.

The firmware always sets the card's "IIgs mode" bit, which makes this check active on both
machines. Details: [Capture logic: which cycles count](../04-capture-logic.md#which-cycles-count-at-all).

## Machine and slot compatibility

Sources: [manual](../sources.md#s16); [comp.sys.apple2 FAQ part 13](../sources.md#s42).

| Machine | Allowed slots | Why |
|---|---|---|
| IIgs ROM 03 | 1-6 | M2B0 (pin 35) is on every slot 1-6 |
| IIgs ROM 01 | 3 only | M2B0 is only on slot 3 ([Apple TN #68](../sources.md#s43) also says so) |
| IIe | Manual: 1-7; use 1-6 | The card does not need M2B0 on a IIe. Slot 7 drives the color reference on pin 35, which stops reliable copying ([IIe differences](../03-apple-interface.md#iie-differences)) |

## Machine-readable copy

[`apple-slot-signals.csv`](../../data/tables/apple-slot-signals.csv) is the pin table as
CSV.

---

[Reference tables](README.md) | [Apple interface](../03-apple-interface.md)
