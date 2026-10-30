# Z180 physical memory map

[Reference tables](README.md) | [Glossary](../glossary.md)

What each Z180 memory address reaches, with the boot overlay and the video RAM half select
([Z180 computer](../05-z180.md)).

- The Z180 has a 20-bit physical address space. Its MMU maps 16-bit logical addresses into
  it. Every range on this page is physical ([address notation](../glossary.md#addresses-and-numbers)).
  Source: Zilog [UM0050](../sources.md#s39).
- At reset /RTS0 is high and the EPROM covers the first 128 KB. Clearing CNTLA0 bit 4
  lowers /RTS0 and puts SRAM there. The SRAM mirror at $20000 stays reachable throughout
  boot. Source: [ROM_BEEF.asm:54-204](../sources.md#s27).

Sources: the firmware's accesses and the [netlist](../../data/netlist/README.md), which fix
how the memory decoder U15 behaves ([Glue logic](../07-glue-logic.md)).

## Contents

- [Memory map](#memory-map)
- [Notes on individual regions](#notes-on-individual-regions)
- [SRAM ownership](#sram-ownership)
- [Region facts and evidence](#region-facts-and-evidence)
- [ROM 1.4 routine and data locations](#rom-14-routine-and-data-locations)
- [EPROM write contention](#eprom-write-contention)
- [Oak window selection](#oak-window-selection)
- [Interrupt vectors](#interrupt-vectors)
- [Machine-readable copy](#machine-readable-copy)

## Memory map

Each range links to its notes.

<!-- csv: data/tables/z180-memory-map.csv -->
| Physical range | After reset (/RTS0 high) | Normal (/RTS0 low) | Notes |
|---|---|---|---|
| [$00000-$1FFFF](#boot-overlay) | EPROM overlay | 128 KB SRAM | The firmware switches the overlay with /RTS0 |
| [$20000-$3FFFF](#sram-mirror) | SRAM mirror | SRAM mirror | Used during boot while the EPROM is at zero |
| [$40000-$4FFFF](#video-ram-half-switches) | Select video RAM half 0 | Select video RAM half 0 | Any access, read or write, selects the half; read data floats |
| [$50000-$5FFFF](#video-ram-half-switches) | Select video RAM half 1 | Select video RAM half 1 | Any access, read or write, selects the half; read data floats |
| [$60000-$7FFFF](#fixed-eprom-mapping) | 128 KB EPROM | 128 KB EPROM | Low half holds code and data; high half is zero |
| [$80000-$FFFFF](#video-window) | OTI-087X video window | OTI-087X video window | Oak register 5 and the board's controls set the mapping |

## Notes on individual regions

### Boot overlay

The firmware tests `$01FD` for RAM, then copies `$0000-$03FF`, `$0C00-$1FFF` and
`$6000-$FFFF` through the `$2xxxx` SRAM mirror. It clears CNTLA0 bit 4 to put SRAM at
zero. Source: [ROM_BEEF.asm:54-204](../sources.md#s27).

The firmware's own accesses prove the low 64 KB of the overlay. The
[netlist](../../data/netlist/README.md) connects EPROM A16 to HA16, so the overlay covers
the full 128 KB.

### SRAM mirror

The mirror reaches the same 128 KB SRAM in both overlay states. Boot keeps its stack at
physical `$300FF` (CBR = `$21`) and copies the ROM into SRAM through this mapping.
Source: [ROM_BEEF.asm:60-70](../sources.md#s27), 100-204.

An unreferenced routine at `$0208` would keep an `$A5` signature at physical `$3FFFF`
(CBR = `$30`). Nothing calls it. Sources: [ROM_BEEF.asm:250-266](../sources.md#s27); ROM
bytes searched for references to `$0208`.

### Video RAM half switches

These regions are switches, not memory. The firmware reads them and throws the value
away: `$4xxxx` selects half 0, and `$5xxxx` selects half 1.
Source: [ROM_BEEF.asm](../sources.md#s27) `access_softswitch0`:1667, `access_softswitch1`:1650, `upload_chunk`:1822-1827.

U15 has no read/write input, so writes select the same halves. The standard VGA window
needs half 1: Oak `$A0000` has bit 19 set.

Reads return a floating bus: U15's decode enables neither SRAM nor EPROM there, and the
OTI-087X answers only in its own windows. Source: [netlist](../../data/netlist/README.md).

### Fixed EPROM mapping

The 27C1000 holds 128 KB. Only its low 64 KB holds code and data; the upper half is all
zero. The uncalled `$0208` routine would read its palette and picture from that upper
half. Never write this range ([EPROM write contention](#eprom-write-contention)).
Sources: [ROM_BEEF.bin](../sources.md#s25); [ROM_BEEF.asm:276-285](../sources.md#s27).

### Video window

Oak extended register 5 selects standard VGA mapping (`$00`, Oak `$A0000-$BFFFF`) or a
linear 1 MB aperture (`$19`, starting at Oak `$100000`). Source:
[OTI-087 databook](../sources.md#s02) p34-35.

The board supplies Oak bit 20 from the `$AA/$AB` linear flag, bit 19 from the half
switch, and bits 18-0 from Z180 A18-A0. This differs from the prototype wiring
([the video RAM window](../06-video.md#the-video-ram-window)).
Source: [ROM_BEEF.asm:1807-1840](../sources.md#s27) and the `$AA/$AB` sites.

## SRAM ownership

Two separate switches decide which SRAM a program may use. Neither changes the other.

- **The copy** (Sequential's manual calls it shadowing): U7 copies the Apple's video
  writes into the screen-copy ranges below. SetShadow 4 turns it off.
- **Apple emulation:** the firmware's renderers draw the Apple screen from those copies
  and keep their own tables. SetMode with flag 1 turns it off, and no renderer runs.

Addresses are within each 64 KB bank.

<!-- csv: data/tables/z180-sram-ownership.csv -->
| Bank | Address | Used by | Free for a program |
|---|---|---|---|
| 0 | $0000-$03FF | Firmware: vectors, startup code, stack | Never |
| 0 | $0400-$0BFF | The copy: main text and lores pages | With the copy off |
| 0 | $0C00-$1FFF | Firmware: command and interrupt handlers | Never |
| 0 | $2000-$5FFF | The copy: main hires pages | With the copy off |
| 0 | $6000-$CFFF | Firmware: renderers, fonts, tables, mode records | Never |
| 0 | $D000-$FFFF | SetPalette's buffer at $F000-$F2FF; in firmware 1.5 and 2.0, SetTextFont's user font at $F000-$FFFF while font 3 is chosen, and SetPalette then uses firmware memory instead | With the copy off, apart from those buffers |
| 1 | $0000-$03FF | Nothing | Always |
| 1 | $0400-$0BFF | The copy: auxiliary text pages | With the copy off |
| 1 | $0C00-$0FFF | Nothing | Always |
| 1 | $1000-$1DFF | Double hires emulation: its repack tables, loaded from the EPROM each time it starts | While double hires emulation is not running |
| 1 | $1E00-$1FFF | Nothing | Always |
| 1 | $2000-$9FFF | The copy: auxiliary hires and Super Hi-Res pages | With the copy off |
| 1 | $A000-$BFFF | Super Hi-Res emulation: its code, tables and palette copy, copied in each time it starts | While Super Hi-Res emulation is not running |
| 1 | $C000-$FFFF | Nothing | Always |

- With the copy off but emulation on, the renderers still draw from the screen-copy
  ranges, so a program's data there shows on screen as garbage.
- A renderer that starts again rewrites its own range: keep nothing in $1000-$1DFF or
  $A000-$BFFF across a return to emulation.
- With the original Lattice chip, one 80STORE case also copies into bank 0 $6000-$9FFF, over the
  firmware's code ([E28](errata.md#e28-with-80store-on-u7-picks-the-copys-bank-without-looking-at-the-address));
  Lattice v2.0 never does.
- RunCode needs CBAR's low nibble = 2, so the handlers at $0000-$1FFF stay mapped.

Sources: Sequential's [firmware documentation](../sources.md#s15) pp9-10;
[ROM_BEEF.asm](../sources.md#s27) `copy_double_hires_a_b_lookup_tables`,
`set_videomode_superhires`, lines 9214-9272.

## Region facts and evidence

<!-- csv: data/tables/z180-memory-details.csv -->
| Physical range | Fact | Source |
| --- | --- | --- |
| $20000-$3FFFF | Boot stack at $300FF (CBR=$21) and the DMA copy target during boot. | [ROM_BEEF.asm:60-70](../sources.md#s27), 100-204 |
| $20000-$3FFFF | An unreferenced routine at $0208 would keep a signature byte $A5 at $3FFFF (CBR=$30); nothing calls it. | [ROM_BEEF.asm:250-266](../sources.md#s27); ROM bytes searched for references to $0208 |
| $40000-$4FFFF | The firmware only reads here (value thrown away). | [ROM_BEEF.asm](../sources.md#s27) access_softswitch0 (line 1667); U15 pin list |
| $50000-$5FFFF | Required before using the standard VGA window at $A0000. | [ROM_BEEF.asm](../sources.md#s27) access_softswitch1 (line 1650), upload_chunk (1822-1827) |
| $40000-$5FFFF | Read data floats; writes have the same half-selection effect as reads; the manual says do not modify $040000-$05FFFF | [netlist](../../data/netlist/README.md); [Firmware documentation](../sources.md#s15) pp9-10; U15 decode |

## ROM 1.4 routine and data locations

Sources: [ROM_BEEF.bin](../sources.md#s25); [ROM_BEEF.asm](../sources.md#s27)
cross-references.

| Z180 address | Contents |
|---|---|
| $0000 | `jp $0080` (reset) |
| $0038 | RST $38: writes `*` to the serial port, returns |
| $0066 | NMI: zero bytes, runs into the reset code |
| $0080 | Reset and boot copy ([`ROM_BEEF.asm:54-227`](../sources.md#s27)) |
| $0208 | Unreferenced boot-picture and default-mode routine (never called) |
| $0C00 | Interrupt vector table (INT1, INT2) and interrupt helpers |
| ~$0D00 | Mode lists and the mode-setting code (`set_video_mode`, 900-1210) |
| $0CE2-$1C7C | Command handlers; the table at $1C0F holds their addresses (SetMode $0CE2 ... SetShadow $1C7C) |
| $179A | 84-byte buffer for SetUserMode (mode $FF) |
| $1800-$19FF | Softswitch handler table: low-byte table starts at $1800, high-byte table at $1900; indexed by the low address byte |
| $1A00-$1A40 | Command parameters, video state flags |
| ~$1B30 | INT1 event handler and command dispatch (2637-2790) |
| $1C0F | Command table, 15 entries |
| $1E01 | Main loop |
| $0400-$0BFF | Not copied from EPROM; at runtime SRAM holds the Apple main text/lores pages |
| $2000-$5FFF | Not copied from EPROM; at runtime SRAM holds the Apple main hires pages |
| $6000-$FFFF | Renderers, fonts, color lookup tables, the 81-byte mode tables, palettes |

## EPROM write contention

The EPROM's chip enable (pin 22) is grounded. Its output enable (pin 2) comes from U15's
address decode, which cannot tell reads from writes. So a write there makes the CPU and
the EPROM drive the data bus at the same time. Never write there.
Source: [netlist](../../data/netlist/README.md).

ROM 1.4 writes $01 to $01FD once during cold boot while the overlay is on, to test whether
SRAM is already mapped ([Boot](../05-z180.md#boot)).

## Oak window selection

| Ext reg 5 | Oak sees | Firmware uses it for |
|---|---|---|
| $00 | Standard VGA windows at $A0000-$BFFFF (per graphics register 6), with Oak segment registers $23/$24/$25 adding address bits 20-16 | Renderers that draw through the VGA's planar, latch and color-expansion hardware |
| $19 | A linear 1 MB aperture at Oak address $100000 | Block copies, fills and uploads |

## Interrupt vectors

Source: [ROM_BEEF.asm:593-625](../sources.md#s27).

| Input | ROM table | Handler | Firmware use |
|---|---|---|---|
| INT1 | $0C00, selected by I | $0C7A | Event handler; enabled by ITC bit 1 |
| INT2 | $0C00, selected by I | $0CA8 | Hook that does nothing by default; disabled |

## Machine-readable copy

The tables as CSV: [`z180-memory-map.csv`](../../data/tables/z180-memory-map.csv) (the
memory map), [`z180-sram-ownership.csv`](../../data/tables/z180-sram-ownership.csv) and
[`z180-memory-details.csv`](../../data/tables/z180-memory-details.csv) (region facts).

---

[Reference tables](README.md) | [Z180 chapter](../05-z180.md)
