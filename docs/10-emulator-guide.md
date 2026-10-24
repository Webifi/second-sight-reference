# 10 Emulator guide

[Reference index](../README.md) | [Glossary](glossary.md) | [Reference tables](reference/README.md)

What an emulator of the whole card needs, the hardware ROM 1.4 never uses included:
custom Z180 and IIgs programs use it.

## Reading route

1. [Overview](01-overview.md).
2. The ROM and the test software: [get the sources](13-method.md#1-get-the-sources),
   [check the dumps](13-method.md#2-check-the-dumps), [software to test with](#6-host-software-to-test-with).
3. The host bus and the Lattice: steps [1](#1-hook-the-host-bus) and
   [2](#2-the-lattice-model), [Capture logic](04-capture-logic.md).
4. The Z180 and its boot: [step 3](#3-the-z180), [boot](05-z180.md#boot), [Firmware](08-firmware.md).
5. The ports and the picture: steps [4](#4-the-cards-ports) and [5](#5-the-video-side),
   [video window](06-video.md#the-video-ram-window).
6. Checking the result: [implementation checks](#implementation-checks), and the ROM's own
   [defects](08-firmware.md#known-defects-and-oddities).
7. Custom software: [Beyond the firmware](14-custom-code.md).

## Contents

- [The hardware to emulate](#the-hardware-to-emulate)
- [1. Hook the host bus](#1-hook-the-host-bus)
- [2. The Lattice model](#2-the-lattice-model)
- [3. The Z180](#3-the-z180)
- [4. The card's ports](#4-the-cards-ports)
- [5. The video side](#5-the-video-side)
- [6. Host software to test with](#6-host-software-to-test-with)
- [Wiring constraints](#wiring-constraints)
- [Implementation checks](#implementation-checks)

## The hardware to emulate

```
host machine (IIgs or IIe emulator)
   | every slow-side bus cycle: address, data, R/W, /M2SEL, M2B0
   v
[1] Lattice model (04)  --- copies -->  SRAM banks 0/1
   |  events, RDY stall                    ^
   v                                       |
[2] Z180 at 18 MHz running ROM_BEEF.bin (05, 08)
   |  I/O and memory window
   v
[3] OTI-087 + OTI-068 + Bt481 (06, 14)    -->  picture
```

## 1. Hook the host bus

The card needs **every slow-side bus cycle**, including:

- writes the IIgs shadows from banks $00/$01 into $E0/$E1 (these are slow cycles with
  /M2SEL low);
- reads and writes to $C000-$C0FF;
- M2B0 for each cycle: 1 for bank $E1 or a shadowed bank $01 access, 0 otherwise.

Fast-side cycles (unshadowed bank $00/$01 RAM, ROM, $C035-$C037, reads of $C02D and $C068)
must not reach the card. If the host emulator cannot separate them, set m2sel_low to
"this access goes through the Mega II".

On a IIe, pin 39 carries SYNC, high during an opcode fetch: pass m2sel_low = "not an
opcode fetch" and m2b0 = 0.

## 2. The Lattice model

For each slow-side bus cycle the Lattice model works out ([per-cycle model](#a-per-cycle-model),
[Capture logic](04-capture-logic.md)):

- the copy decision and SRAM bank;
- the event latch (INT1 to the Z180) with the event address for ports $A6/$A7 and the data
  byte for port $A0;
- the band flags for ports $A4/$A5;
- the read value for $C0B0-$C0BF (the port $A0 output latch);
- the RDY stall.

The stall matters. The library writes command data back to back (16-bit stores to $C0B1),
and expects the card to hold the 65816 until each byte is taken. If the host emulator
cannot stall the CPU, run the Z180 forward until it acknowledges, inside the bus access.

### A per-cycle model

Run it once per slow-side bus cycle. `V2` picks the Lattice version: false for the
original chip (BE8C), true for Lattice v2.0 (BBB1). Each v2.0 difference is marked with
its erratum. The full equations of both versions:
[`Lattice_original-BE8C.ldf`](../data/lattice/Lattice_original-BE8C.ldf) and
[`Lattice_v2.0.ldf`](../data/lattice/Lattice_v2.0.ldf); `tools/lattice/ldfsim.py`
evaluates either file as written, for checking a model against it. U17's timing is in
[wait states](05-z180.md#wait-states).

`is_event` uses the [event table](04-capture-logic.md#events-telling-the-z180-about-softswitch-accesses).
State updates use the [tracked-softswitch table](04-capture-logic.md#tracked-softswitches);
HIRES has no data-phase gate, while PAGE2, RAMWRT, and STORE80 do.

```text
setting: V2   (false: original Lattice chip, BE8C; true: Lattice v2.0, BBB1)
state: HIRES, PAGE2, RAMWRT, STORE80, COPY_INHIBIT, MODE_D3, B, flags[8],
       event_pending, event_addr, u2_data, u3_data

on_bus_cycle(addr, data, is_write, m2sel_low, m2b0):
    valid = (not MODE_D3) or m2sel_low
    if not valid:
        return
    if not MODE_D3:
        B = 0
    elif m2sel_low:
        B = m2b0                     # sampled in this cycle's address phase

    if V2:
        shr_copy = B or RAMWRT                 # E14
    else:
        shr_copy = B xor RAMWRT
    capture = is_write and not COPY_INHIBIT and (
        in(addr, $0400, $0BFF) or in(addr, $2000, $5FFF)
        or (MODE_D3 and in(addr, $2000, $9FFF) and shr_copy))
    event = (addr & $FF00) == $C000 and is_event(addr & $FF, is_write)
    if V2 and MODE_D3 and is_write and addr == $C034:
        event = 1                              # E15: the border color

    if (capture or event) and event_pending:
        stall Apple until Z180 acknowledges (any access to port $A0)

    if capture:
        if V2:                                 # E14, E28: the Apple's own bank rule
            if B:
                bank = 1
            elif not STORE80:
                bank = RAMWRT
            elif in(addr, $0400, $07FF):
                bank = PAGE2                   # text page 1
            elif in(addr, $2000, $3FFF) and HIRES:
                bank = PAGE2                   # hires page 1
            else:
                bank = RAMWRT
        else:
            bank = (B and MODE_D3 and not RAMWRT)
                or (not B and STORE80 and PAGE2)
                or (not B and not STORE80 and RAMWRT)
                or (not B and MODE_D3 and RAMWRT and not HIRES)
        u2_data = data                         # ADIN clocks U2 on copies too
        sram[bank * $10000 + addr] = data      # U17 uses a Z180 bus request
        if in(addr, $2000, $9FFF):
            flags[(addr - $2000) >> 12] = 1

    if event:
        event_addr = addr & $FF
        if is_write:
            u2_data = data
        event_pending = 1                     # INT1 and DREQ1 go low

    if (addr & $FF00) == $C000:
        update HIRES, PAGE2, RAMWRT, STORE80 per the tracked-softswitch table
        if not is_write and $B0 <= (addr & $FF) <= $BF:
            return u3_data
```

A pending event delays a later copy rather than discarding it. U2 takes data on both
memory captures and write events; a read event leaves it unchanged.

Why v2.0 differs, equation by equation:
[Correcting the capture logic](12-lattice-fix.md#what-the-corrected-map-changes).

## 3. The Z180

Connect a Z8S180 core to the [memory map](reference/z180-memory-map.md),
[interrupt inputs](reference/z180-io-ports.md#z180-interrupt-inputs) and
[wait-state logic](05-z180.md#wait-states).

The [boot sequence](05-z180.md#boot) maps the overlay and sets up memory. Implement both
ASCI channels, CSI/O, the timers, the clock controls, the MMU and DMA, and show ASCI0's
output: the firmware writes trace characters there.

Channel 1 must respond to each DREQ1 falling edge, including events raised while the
processor handles INT1. CPU and DMA accesses must share the same port handlers ([DMA handshake](05-z180.md#dma)).

## 4. The card's ports

Implement the [port table](reference/z180-io-ports.md#port-table), including aliases,
acknowledgment and access side effects. Use one input latch and one output latch for
both command handshakes and data transfers.

## 5. The video side

Implement standard VGA and all documented [OTI-087 extensions](reference/oti087-registers.md),
including the cursor, CRT interrupt and EEPROM interface. Connect the
[video address window](06-video.md#the-video-ram-window) and implement the
[latch lane rule](06-video.md#the-64-bit-latch-lane-rule).

Use the [clock selections](reference/clocks.md) for OTI-068 and the
[Bt481 modes and controls](reference/bt481-modes.md) for the color chip. Include
Command Register B and the overlay registers. The [mode-setting sequence](06-video.md#how-the-firmware-sets-a-mode)
explains the shared clock-select bits and register write order.

Offer the [monitor-sense input](06-video.md#outputs-and-the-monitor-type) as a user setting.
The power-up values of Oak registers $00 and $02 and the strap bits:
[register behavior](reference/oti087-registers.md#register-behavior).

## 6. Host software to test with

- The disk image [`ss.source.082395.po`](sources.md#s06) holds the library source, the
  test programs (SETREG, PRINTREG, TSCROLL, T1, UP) and the mode files;
  [`sslib082696.po`](sources.md#s07) holds the 1996 library.
- The viewers on the other disk images (SView, GView, Third View) exercise uploads,
  palettes and the 256-color and 32K modes.
- For Apple video emulation: run anything that uses text, lores, hires, double hires and
  Super Hi-Res, and compare with the IIgs's own output. Known firmware gaps: no double lores,
  and double-hires setup hangs in ROM 1.4 ([cause](08-firmware.md#double-hires-setup-defect)).

Before diagnosing a rendering mismatch as a hardware-model fault, check the ROM's
[Super Hi-Res band pointer](08-firmware.md#super-hi-res-band-pointer),
[mixed-hires text colors](08-firmware.md#mixed-mode-text-colors), and
[mode $13 note](08-firmware.md#mode-13-packed-pixel-note).

## Wiring constraints

- Card ports repeat every 256 I/O addresses, any access to $A1 loads the configuration
  bits, and a write to $A4-$A7 collides with the card's own output
  ([access limits](reference/z180-io-ports.md#access-limits-and-aliasing)).
- A Z180 write to the EPROM area fights the EPROM
  ([EPROM write contention](reference/z180-memory-map.md#eprom-write-contention)).
- Undriven reads return the last value on the bus
  ([undriven reads](reference/z180-io-ports.md#configuration-and-open-reads)).
- The Oak's FIFO and write-cache delays: [wait states](05-z180.md#wait-states).

## Implementation checks

| Check | Expected observation and evidence |
|---|---|
| Boot overlay | EPROM starts at zero; boot copies the listed ranges and lowers /RTS0 to expose SRAM. [Z180: Boot](05-z180.md#boot) |
| GetStatus | Dummy read, 12 returned bytes, and the trailing $18 behavior match the [exact sequence](reference/host-commands.md#getstatus). |
| Capture and event backpressure | U2 changes on captured writes and written events; a second event/copy waits for acknowledgment. [Capture logic](04-capture-logic.md) |
| Banking and shadowing | Captured bytes follow the decoded bank equation; unshadowed fast-side writes do not reach the card. [Apple interface](03-apple-interface.md) |
| Palette and mode loading | 8-bit palette components, mode-record write order, and the RGB $FA clock override match [Video](06-video.md). |
| Features beyond the ROM | Exercise all chip registers/peripherals, cursor, CRT interrupt, EEPROM, and color modes against their databooks and [custom-code inventory](14-custom-code.md). |

---

Previous: [09 Host protocol](09-host-protocol.md) | [Reference index](../README.md) | Next: [11 Replica guide](11-replica-guide.md)
