# Z180 I/O ports

[Reference tables](README.md) | [Glossary](../glossary.md)

Every port on the Z180's I/O bus: the card's ports, the Z180's own registers and the VGA
registers. One access can move data and acknowledge an event at the same time.

- The Z180 uses 16-bit I/O addresses: `out (c)` puts B on A8-A15. Its internal registers
  are at `$00-$3F`.
- The card's ports decode only the low 8 address bits, so `$00A0` and `$01A0` reach the
  same port.
- The OTI-087 decodes its own full I/O address. U4's VGAIO_SEL output does not select it.

Sources: the [netlist](../../data/netlist/README.md), U7's [design source](lattice-source.md),
the firmware's accesses, the [Z8S180 specification](../sources.md#s62), and the port
decoder [U4](../07-glue-logic.md#u4-io-decode).

## Contents

- [Port table](#port-table)
- [Notes on individual ports](#notes-on-individual-ports)
- [Decoder and evidence table](#decoder-and-evidence-table)
- [Band flag layout](#band-flag-layout)
- [Tracked softswitches](#tracked-softswitches)
- [Apple event addresses](#apple-event-addresses)
- [Z180 interrupt inputs](#z180-interrupt-inputs)
- [Firmware DMA channels](#firmware-dma-channels)
- [State observable by Z180 software](#state-observable-by-z180-software)
- [U4 output controls](#u4-output-controls)
- [ROM softswitch handlers](#rom-softswitch-handlers)
- [Machine-readable copy](#machine-readable-copy)

## Port table

**Never read $A1**: the read reloads the configuration from the bus. **Never write
$A4-$A7**: U7 and the Z180 drive the same data lines. Both follow from the wiring
([access limits and aliasing](#access-limits-and-aliasing)). Each port links to its notes.

<!-- csv: data/tables/z180-io-ports.csv -->
| Port | Read | Write | Notes |
|---|---|---|---|
| [$00-$3F](#internal-registers) | Z8S180 internal registers | Z8S180 internal registers | |
| [$A0](#data-and-acknowledge) | U2 input latch; acknowledge event | Load U3 output latch; acknowledge event | U7's ACK_A0 acknowledges on either |
| [$A1](#configuration-and-open-reads) | Reloads configuration from bus bits 2-3; never read | COPY_INHIBIT in bit 2, MODE_D3 in bit 3 | U7 has no read/write input |
| [$A2](#configuration-and-open-reads) | Undriven bus | No effect | No U7 equation uses it |
| [$A3](#configuration-and-open-reads) | Undriven bus | No effect | No U7 equation uses it |
| [$A4](#band-flags-and-event-address) | Lower four band flags, then clear | Bus contention; flags still clear; never write | The read returns the flags before the clear |
| [$A5](#band-flags-and-event-address) | Upper four band flags, then clear | Bus contention; flags still clear; never write | The read returns the flags before the clear |
| [$A6](#band-flags-and-event-address) | Event address bits 3-0 | Bus contention; never write | U7 drives HD0-HD3 on every access |
| [$A7](#band-flags-and-event-address) | Event address bits 7-4 | Bus contention; never write | $B here means the event was at $C0Bx |
| [$A8](#output-path) | DIVOE low: VGA clock path | DIVOE low: VGA clock path | U8 gate D passes the pixel clock |
| [$A9](#output-path) | DIVOE high: AppleColor RGB clock path | DIVOE high: AppleColor RGB clock path | U8 gate D stops driving; U12 supplies the divided clock |
| [$AA](#linear-window-flag) | Clear linear-window flag | Clear linear-window flag | Read once at reset; used after Oak register 5 = $00 |
| [$AB](#linear-window-flag) | Set linear-window flag | Set linear-window flag | Used before Oak register 5 = $19 |
| [$AC](#apple-irq) | AIRQ0 low: raise Apple IRQ | AIRQ0 low: raise Apple IRQ | Never used by the firmware |
| [$AD](#apple-irq) | AIRQ0 high: release Apple IRQ | AIRQ0 high: release Apple IRQ | Written once at reset |
| $AE, $AF | Undriven bus | No effect | Nothing decodes them |
| [$3B0-$3DF, $46E8, $102](#vga-ports) | OTI-087 registers | OTI-087 registers | The Oak decodes the full address itself |

## Notes on individual ports

### Access limits and aliasing

Card ports repeat every 256 I/O addresses. U4 receives only HA0-HA7, and U7 receives only
HA0-HA2 plus U4's AX; neither can tell $00A0 from $01A0. The OTI-087 sees the full
address, so its VGA ports do not repeat this way. Source: [netlist](../../data/netlist/README.md).

U7 cannot tell a read from a write. So a read of $A1 is a configuration write, and a write
to $A4-$A7 still makes U7 drive the low nibble. That write fights the Z180 on the data
bus, and its data is lost. Source: [netlist](../../data/netlist/README.md).

The memory bus has a similar limit: never write the EPROM area, $60000-$7FFFF, or
$00000-$1FFFF while the boot overlay is on. U15 enables the EPROM from the address alone,
so the EPROM drives the bus against the writing CPU
([EPROM write contention](z180-memory-map.md#eprom-write-contention)).
Source: [netlist](../../data/netlist/README.md).

### Data and acknowledge

U4's BEN enables U2 on a read of `$A0`; BCLK loads U3 on a write. U2 holds the byte of a
copied memory write or of a written softswitch or command event; a read event leaves it
unchanged.

U3 is the byte returned on Apple reads of `$C0B0-$C0BF`, including `$C0B2` and `$C0B8`.
Handshake bytes `$00/$01/$A5/$A6` and outgoing data share this latch.
Source: [ROM_BEEF.asm](../sources.md#s27) `get_status`, `copy_api_data_chunk`.

Any `$A0` access with AX asserted acknowledges the pending event and releases INT1/DREQ1,
from the CPU or from the DMA. Source: [ROM_BEEF.asm:2690](../sources.md#s27).

### Configuration and open reads

Port $A1 stores two bits; bits 0 and 1 are not stored.

- **Bit 2, COPY_INHIBIT:** set stops all copying.
- **Bit 3, MODE_D3 (IIgs mode):** requires /M2SEL for copies and events, enables the Super
  Hi-Res range and the bank latch, and enables events for `$C022/$C029/$C02B` (and `$C034`
  in Lattice v2.0).

The firmware writes `$08` at reset and ORs `$08` into every SetShadow value. So SetShadow
0 copies everything and 4 stops copying. Source: [ROM_BEEF.asm:58-59](../sources.md#s27)
and `set_shadow`.

U7 loads port $A1 on any access that AX selects, read or write. AX has to work on reads,
because `$A0` and `$A4-$A7` are read through it. So a read of `$A1` loads whatever is on
the undriven bus, which can turn copying or IIgs mode off at random.
Source: [netlist](../../data/netlist/README.md).

**Open reads.** A read of `$A1-$A3` returns the undriven bus: the last value driven on it.
For `in0 a,(n)` that is the port operand n, fetched just before the I/O cycle, unless an
Apple copy took the bus in between and left its data byte there. The same holds for bits
7-4 at `$A4-$A7` and for reads of `$40000-$5FFFF`.

### Band flags and event address

Each bit of $A4/$A5 marks a 4 KB band of Super Hi-Res memory as written
([band flag layout](#band-flag-layout)). Any access to the port, even a write, clears its
flags; a read returns them first. Never write these ports: U7 drives HD0-HD3 against the
Z180, so the write data is lost even though the flags clear.
Sources: [design source](../../data/lattice/Lattice_original-BE8C.ldf), the DIRTY_ and HDn_DRIVE
equations; [ROM_BEEF.asm:9036-9160](../sources.md#s27), `render_superhires`.

`$A6/$A7` return the caught low Apple address byte, low nibble then high nibble. They also
drive HD0-HD3 on a write, so never write them.

Bits 7-4 of all four ports `$A4-$A7` float; mask them. U2 must stay off at these ports, or
it would fight U7 on bits 0-3. Source: [ROM_BEEF.asm:2636-2651](../sources.md#s27),
`handle_event`, `check_for_api_call`.

### Output path

Any read or write of `$A8/$A9` drives U4's DIVOE low/high. Mode-record byte 2 bit 0 picks
the port: 0 selects VGA; 1 selects AppleColor RGB and U12's divide-by-2 of the pixel
clock. Source: [ROM_BEEF.asm:1006-1016](../sources.md#s27).

The RGB mode tables give 15.5-16.5 kHz lines only with that divide, which confirms it.
The RGB `$FA` record picks the VGA path instead
([RGB list does not force the RGB clock path](video-modes.md#rgb-list-does-not-force-the-rgb-clock-path)).

### Linear-window flag

`$AB` is written before Oak register 5 becomes `$19`. `$AA` is written after it becomes
`$00`, and read once at reset. So the pair is a set/clear flag, and it drives Oak address
bit 20 ([the video RAM window](../06-video.md#the-video-ram-window)).
Source: [ROM_BEEF.asm:60](../sources.md#s27), 287, 362, 1724, 1799, 1923, 2031, 2152, 2216, 2281, 4905, 5005, 8580.

### Apple IRQ

`$AC` raises Apple IRQ and `$AD` releases it. The firmware writes `$AD` once at reset and
never raises IRQ ([IRQ wiring](../03-apple-interface.md#irq)).
Source: [ROM_BEEF.asm:56-57](../sources.md#s27).

### Port pairs $A8-$AD

For each pair, any read or write sets U4's latch from address bit 0: the even port
stores 0 and the odd port 1 ([U4 decode](../07-glue-logic.md#u4-io-decode)).

### VGA ports

The firmware uses `$3C0-$3DF`, plus the `$46E8/$102` add-on enable sequence. Standard VGA
ports span `$3B0-$3DF`; Oak extended registers use index `$3DE` and data `$3DF`.
Sources: [ROM_BEEF.asm](../sources.md#s27); [OTI-087 databook](../sources.md#s02) p30.

U4's VGAIO_SEL goes only to U15. The OTI-087 receives every I/O strobe with the full
address and decodes its own registers. Source: [netlist](../../data/netlist/README.md).

### Internal registers

These include ASCI, CSI/O, timers, DMA (`$20-$32`) and MMU (`$38-$3A`) registers. The
firmware never writes CMR (`$1E`) or CCR (`$1F`). What custom code can use:
[Z180 resources](../14-custom-code.md#z180-resources).
Sources: [Z8S180 specification](../sources.md#s62); [ROM_BEEF.asm](../sources.md#s27).

## Decoder and evidence table

<!-- csv: data/tables/z180-io-decoders.csv -->
| Port | Access | Decoder | Source |
| --- | --- | --- | --- |
| $A0 | write | U4 (BCLK) clocks latch U3 | schematic sheet 1 (U3 CLK=BCLK, OE=ADOUT); [ROM_BEEF.asm](../sources.md#s27) get_status, copy_api_data_chunk |
| $A0 | read | U4 (BEN) enables latch U2; U7 ACK_A0 | schematic sheet 1 (U2); U7 source ACK_A0; [ROM_BEEF.asm:2690](../sources.md#s27) |
| $A1 | any access reloads configuration; never read | U7 port 1 | U7 source COPY_INHIBIT and MODE_D3 (the port $A1 terms); [ROM_BEEF.asm](../sources.md#s27) reset (lines 58-59) and set_shadow; [firmware documentation](../sources.md#s15) SetShadow 0/4 |
| $A2 | any | none | U7 source: no equation decodes port 2 |
| $A3 | any | none | U7 source: no equation decodes port 3 |
| $A4 | read | U7 port 4 | U7 source FLAGS_ACCESS and HDn_DRIVE; render_superhires [ROM_BEEF.asm:9036-9160](../sources.md#s27) |
| $A5 | read | U7 port 5 | U7 source FLAGS_ACCESS and HDn_DRIVE; render_superhires |
| $A6 | read | U7 port 6 | U7 source HDn_DRIVE (EVENT_A0-A3); handle_event [ROM_BEEF.asm:2636-2651](../sources.md#s27) |
| $A7 | read | U7 port 7 | U7 source HDn_DRIVE (EVENT_A4-A7); check_for_api_call |
| $A8 | any read or write | U4 | [ROM_BEEF.asm:1006-1016](../sources.md#s27); all VGA mode tables |
| $A9 | any read or write | U4 | [ROM_BEEF.asm:1006-1016](../sources.md#s27); AppleColor mode tables give 15.5-16.5 kHz only with the divide |
| $AA | any read or write | U4 | [ROM_BEEF.asm:60](../sources.md#s27) (reset read) and 362, 1799, 2031, 2152, 2281, 5005, 8580: each follows the ext reg 5 = $00 write |
| $AB | any read or write | U4 | [ROM_BEEF.asm:287](../sources.md#s27), 1724, 1923, 2216, 4905: each precedes the ext reg 5 = $19 write |
| $AC | any read or write | U4 | [Port-pair pattern](#port-pairs-a8-ad); schematic U4 AIRQ0 and U8 gate B |
| $AD | any read or write | U4 | [ROM_BEEF.asm:56-57](../sources.md#s27); schematic U4 output AIRQ0 |
| $AE, $AF | none | nothing | U4 pin list (all six outputs accounted for) |
| $3B0-$3DF, $46E8, $102 | read/write | OTI-087 itself | [netlist](../../data/netlist/README.md) (U28 IORD/IOWR, ENVGA = VCC); [ROM_BEEF.asm](../sources.md#s27) throughout; [OTI-087 databook](../sources.md#s02) p18, p30 |
| $00-$3F | read/write | Z8S180 internal | [Z8S180 specification](../sources.md#s62); [ROM_BEEF.asm](../sources.md#s27) |

## Band flag layout

<!-- csv: data/tables/z180-io-details.csv -->
| Port | Bit 0 | Bit 1 | Bit 2 | Bit 3 | Source |
|---|---|---|---|---|---|
| $A4 | $2000-$2FFF | $3000-$3FFF | $4000-$4FFF | $5000-$5FFF | [design source](../../data/lattice/Lattice_original-BE8C.ldf), HDn_DRIVE |
| $A5 | $6000-$6FFF | $7000-$7FFF | $8000-$8FFF | $9000-$9FFF | [design source](../../data/lattice/Lattice_original-BE8C.ldf), HDn_DRIVE |

## Tracked softswitches

| Bit | Set/clear by | Also loaded from |
|---|---|---|
| HIRES | $C057 / $C056, read or write | |
| PAGE2 | $C055 / $C054, read or write | AD6 on any access to $C068 (STATEREG bit 6) |
| RAMWRT | $C005 / $C004, write | AD4 on any access to $C068 (STATEREG bit 4) |
| STORE80 | $C001 / $C000, write | |

## Apple event addresses

| Addresses | Reads | Writes | Condition |
|---|---|---|---|
| $C050-$C053 (TEXT, MIXED) | yes | yes | |
| $C054-$C055 (PAGE1/2) | yes | yes | only while STORE80 is clear |
| $C056-$C057 (LORES/HIRES) | yes | yes | |
| $C05E-$C05F (AN3, double width) | yes | yes | |
| $C0B0-$C0B7 (card registers) | yes | yes | |
| $C00C-$C00F (80VID, ALTCHAR) | no | yes | |
| $C07E-$C07F | no | yes | the firmware has no handler; harmless |
| $C022 (text colors), $C029 (NEWVIDEO), $C02B (language) | no | yes | MODE_D3 set |
| $C034 (border color) | no | yes | Lattice v2.0 only, MODE_D3 set ([E15](errata.md#e15-the-iigs-border-color-does-not-show)) |

## Z180 interrupt inputs

| Input | Wired to | Use |
|---|---|---|
| INT0 | OTI-087 CINT (vertical retrace interrupt) | Does not work on a stock card: the line has no pull-up ([INT0 has no pull-up](board-connections.md#int0-has-no-pull-up)). With a pull-up added it serves frame-synchronous code, page flipping and palette changes; CRTC register $11 bits 5-4 enable it in the VGA chip. |
| INT1 | Lattice event signal | Apple events (the firmware's handler) |
| INT2 | Lone label at U18 pin 12, no connection | Not usable; the firmware never enables it ([connections the drawing leaves out](board-connections.md#connections-the-drawing-leaves-out)). |
| NMI | 10 kohm pull-up (R15), nothing else | Unused |

## Firmware DMA channels

| Channel | Use | Paced by |
|---|---|---|
| 0, memory to memory | Boot copy; mode-table copy into RAM; copies into VGA memory; fills | Burst mode (the DMA owns the bus until done) |
| 1, I/O port $A0 to or from memory | Command parameters in, status and register values out, bulk uploads, palette | DREQ1, edge-sensed, wired to the Lattice INT1 net |

## State observable by Z180 software

Events show TEXT, MIXED, HIRES, AN3, 80VID, ALTCHAR, NEWVIDEO, $C022 and $C02B, and $C034
with Lattice v2.0. PAGE2 events happen only with 80STORE off. $C07E/$C07F writes also raise
events but have no firmware handler.

There are no events for 80STORE ($C000/$C001), RAMWRT ($C004/$C005), $C068, RAMRD or
ALTZP, or PAGE2 with 80STORE on. U7 tracks HIRES, PAGE2, RAMWRT and 80STORE itself for
copy banking, with no port to read them back.

## U4 output controls

| Output | Must be active when | Evidence |
|---|---|---|
| BCLK | I/O write to $A0 (low pulse, rising edge at the end loads U3) | U3 clock; firmware writes $A0 for every byte the Apple reads |
| BEN (low) | I/O read of $A0, **or** BACK low (the copy) | U2 output enable; U2 must drive the SRAM data bus during a copy |
| AX | I/O access to $A0-$A7 | U7 port select; $A9 = 0 writes prove $A8-$AF are excluded ([the Z180's view of U7](../04-capture-logic.md#the-z180s-view-of-u7-ports-a0-a7)) |
| DIVOE | latch: set by any access to $A9, cleared by any access to $A8 | Firmware selects RGB with $A9, VGA with $A8; U8 gate D and U12 use it |
| AIRQ0 (low = IRQ) | Latch: $AC drives low (raise IRQ), $AD drives high (release IRQ) | $AD reset write and the even/odd port-pair pattern; the 1.4 firmware never raises IRQ |
| VGAIO_SEL | Linear-window flag, set by $AB and cleared by $AA. Goes to U15 only. | Firmware pair, product-term budget and available route to LA20 |

## ROM softswitch handlers

| Switch | Handler action or stored state |
|---|---|
| $C000/$C001 80STORE | store80 flag (written, never read; the Lattice tracks 80STORE itself) |
| $C00C/$C00D 80VID | 40/80 columns, mode change |
| $C00E/$C00F ALTCHAR | alternate character set (MouseText); font pointers |
| $C022 TBCOLOR | text foreground/background colors |
| $C029 NEWVIDEO | Super Hi-Res on/off (bit 7), mode change |
| $C02B language | international character set |
| $C050/$C051 TEXT | text/graphics, mode change |
| $C052/$C053 MIXED | mixed mode |
| $C054/$C055 PAGE2 | displayed page |
| $C056/$C057 HIRES | lores/hires, mode change |
| $C05E/$C05F AN3 | double width, mode change |

## Machine-readable copy

The tables as CSV: [`z180-io-ports.csv`](../../data/tables/z180-io-ports.csv) (the port
table), [`z180-io-decoders.csv`](../../data/tables/z180-io-decoders.csv) (decoders) and
[`z180-io-details.csv`](../../data/tables/z180-io-details.csv) (band flags).

---

[Reference tables](README.md) | [Z180 chapter](../05-z180.md)
