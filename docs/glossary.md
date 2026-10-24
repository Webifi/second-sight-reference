# Terms, signals, and notation

[Reference index](../README.md) | [Reference tables](reference/README.md) | [Sources](sources.md)

The number notation, signal names and terms these pages use.

## Contents

- [Addresses and numbers](#addresses-and-numbers)
- [Signal names and polarity](#signal-names-and-polarity)
- [Transactions and Apple video](#transactions-and-apple-video)
- [Device and file vocabulary](#device-and-file-vocabulary)

## Addresses and numbers

`$` marks a hexadecimal number. A range includes both ends, and `KB` in the memory maps is
1,024 bytes. The same number means different things in different address spaces:

| Address space | Example | What the number means |
|---|---|---|
| Apple bank/offset | $E1/2000 | Bank $E1, offset $2000 on the Apple side. [Apple interface](03-apple-interface.md) |
| Z180 logical address | $A000 | A 16-bit CPU address, translated by MMU registers before reaching the bus. [Z180 MMU](05-z180.md#mmu) |
| Z180 physical address | $1A000 | Address on the 20-bit Z180 bus after translation. [Memory map](reference/z180-memory-map.md) |
| Z180 I/O port | $A0 or $3C2 | An I/O-cycle address, not a memory address. [Port table](reference/z180-io-ports.md) |
| Oak bus address | $100000 | Address presented to the VGA chip; board logic supplies high bits beyond the Z180 window. [Video window](06-video.md#the-video-ram-window) |
| VRAM offset | $080000 | Byte position within the video RAM, separate from the bus aperture used to reach it. [Video window](06-video.md#the-video-ram-window) |
| Firmware mode code | $FE | A mode-list key, not a memory address or a VGA register number. [Modes](06-video.md#built-in-modes) |

The same SRAM can appear at more than one Z180 address. A **mirror** is another mapping to
the same bytes; an **overlay** switches which device appears at an address
([Z180 memory map](reference/z180-memory-map.md)).

An **aperture** or **window** is a bus-address range through which the CPU reaches video
memory. The **half switch** supplies Oak address bit 19 for the Z180 $80000-$FFFFF window.
In linear mode it picks the 512 KB half; for the standard $A0000 window it must be 1
([Video window](06-video.md#the-video-ram-window)).

## Signal names and polarity

| Notation or name | Meaning |
|---|---|
| `/NAME`, `NAME_n`, or a schematic overbar | Active low: asserted means a low level. Plain [netlist](../data/netlist/README.md) text can leave the polarity out; the drawing shows it ([how to read the data](../data/netlist/README.md#how-to-read-the-data)). |
| AA / AD | Apple address / data bus. [Lattice pins](reference/lattice-pins.md) |
| HA / HD | Z180 address / data bus on this board. [Lattice pins](reference/lattice-pins.md) |
| CPU | U7's bus-phase input, PHASE 0; not the name of a second processor. |
| PHASE 0 / PHASE0 / PH0 | Apple slot clock; high is the data phase in the IIgs timing description ([TN #68](sources.md#s43)). |
| /M2SEL / M2SEL_n | IIgs slow-side address-valid signal; slot pin 39 carries SYNC on a IIe. [Apple interface](03-apple-interface.md) |
| M2B0 | IIgs low bank bit, driven briefly during the address phase. It does not include the RAMWRT/80STORE effects ([TN #68](sources.md#s43)). |
| B / BANK_HELD | U7's held copy of the timed bank input. |
| BACK / /BUSACK | Z180 bus grant; low enables the captured-address latches ([netlist](../data/netlist/README.md)). |
| BREQ / /BUSREQ | U17's request for the Z180 bus ([netlist](../data/netlist/README.md)). |
| ARES / RES / RESN / RESET | Four different reset nets; similar names do not mean they connect. [Reset](03-apple-interface.md#reset) |
| Y0 / Y1 / Y2 | Lattice clock inputs. Y1 can serve as reset instead; on this card it is neither ([Lattice clocks](04-capture-logic.md#clocks-and-phase), [reset](04-capture-logic.md#reset-and-power-on)). |
| HCLK / PHI | Z180 clock used by the registered glue logic. [Board clocks](02-board.md#clocks) |
| VCLK / MCLK | Video clock / video-memory clock. [Clock selections](reference/clocks.md) |
| CSEL / FS / MS | Oak clock select outputs / OTI-068 video-frequency select inputs / memory-clock select inputs. [Clock selections](reference/clocks.md) |
| DIVOE | U4 output-path control: low passes the VGA clock through U8, high lets U12 supply the divided RGB clock. |

In Boolean expressions, `&` = AND, `|` = OR, `!` or `~` = NOT, and `xor` or `^` = exclusive
OR. A name on both sides of an equation can be a feedback latch, not a clocked register
([how to read the source](reference/lattice-source.md#how-to-read-the-source)).

## Transactions and Apple video

| Term | Meaning |
|---|---|
| Capture / copy | Hardware latches an Apple memory write and moves it into SRAM through U17. The Z180 firmware does not do the copy. [Capture logic](04-capture-logic.md#copying-video-writes) |
| Event | A softswitch or host-register access that U7 saves for the Z180, with INT1/DREQ1 asserted. [Event table](04-capture-logic.md#events-telling-the-z180-about-softswitch-accesses) |
| Acknowledge | A Z180 access to port $A0 that clears the pending event. |
| RDY stall | The Apple holds its current cycle while an earlier event waits for its acknowledge. Copies alone do not stall. [Capture logic](04-capture-logic.md#rdy-no-lost-events) |
| Band flag / dirty flag | One bit that records a captured write in a 4 KB band of $2000-$9FFF. [Band flags](04-capture-logic.md#band-flags-ports-a4-a5) |
| Softswitch | An Apple I/O address whose access changes a display or memory-selection state. Depending on the switch, a read, a write or both count. [Tracked switches](04-capture-logic.md#tracked-softswitches) |
| Main / auxiliary (aux) | The two Apple memory spaces, copied into SRAM banks 0 and 1 by U7's bank rule. [Bank tracking](04-capture-logic.md#bank-tracking) |
| Shadowing | IIgs writes copied from fast-side memory into slow-side video memory, which makes them visible at the slot. [Apple interface](03-apple-interface.md#what-the-card-needs-from-the-iigs-every-slow-side-cycle) |
| Hires / SHR | Apple high-resolution graphics / IIgs Super Hi-Res graphics. [Firmware renderers](08-firmware.md#renderers) |
| SCB | Scan-line control byte in the Super Hi-Res table at $9D00; its palette number matters to the [band-pointer defect](08-firmware.md#super-hi-res-band-pointer). |
| TEXT / MIXED / HIRES / AN3 | Apple display switches: text/graphics, mixed text and graphics, hires/lores, and the double-width switch. Which ones raise events: [Capture logic](04-capture-logic.md#events-telling-the-z180-about-softswitch-accesses). |
| 80STORE / PAGE2 / RAMWRT | Apple memory-selection switches used by U7's bank rule. U7 tracks them itself; the Z180 cannot read them back ([tracked switches](04-capture-logic.md#tracked-softswitches)). |
| Native mode | A Second Sight display mode the host selects, instead of the firmware's copy of the Apple screen. [SetMode](reference/host-commands.md#setmode) |
| Open bus | No device drives some or all data bits. What reads return: [configuration and open reads](reference/z180-io-ports.md#configuration-and-open-reads). |

## Device and file vocabulary

| Term | Meaning |
|---|---|
| PLD / GAL / CPLD / FPGA | Programmable logic device; Generic Array Logic; complex PLD; field-programmable gate array. The card uses small PLDs and an ispLSI1016; a replica can use a CPLD or FPGA. [Board](02-board.md), [Replica guide](11-replica-guide.md) |
| GLB / GRP / PT | Generic logic block / global routing pool / product term in Lattice logic. Product-term sharing combines terms across outputs. [Lattice design source](reference/lattice-source.md#building-and-changing-the-design) |
| JEDEC / LDF | Fuse-map file format / Lattice pDS design file, the form of the U7 source. [Lattice design source](reference/lattice-source.md) |
| MMU / DMA | Memory management unit / direct memory access. The Z180 has address-translation registers and two DMA channels. [Z180](05-z180.md) |
| CBR / BBR / CBAR | Z180 common base register / bank base register / common-bank area register. They set the logical-to-physical translation ([MMU](05-z180.md#mmu), [RunCode](09-host-protocol.md#calling-and-returning); [Zilog UM0050](sources.md#s39), [firmware documentation](sources.md#s15)). |
| ASCI / CSI/O | Z180 asynchronous serial communication interfaces / clocked serial I/O ([Zilog UM0050](sources.md#s39)). |
| SRAM / DRAM / EPROM / EEPROM | Static RAM / dynamic RAM / erasable programmable ROM / electrically erasable programmable ROM: the card's processor RAM, video RAM, firmware store and serial settings store. [Board](02-board.md) |
| DAC / RAMDAC | Digital-to-analog converter / DAC with palette RAM. The Bt481 turns pixel data into analog red, green and blue. [Video](06-video.md#bt481-color-chip) |
| CRTC / FIFO | CRT timing controller / first-in, first-out buffer. [OTI-087 registers](reference/oti087-registers.md) |
| VT / VBS / VRS | Vertical total / vertical blank start / vertical retrace start, timing fields in the CRTC extensions ([OTI-087 databook](sources.md#s02) p39-40). |
| HSYNC / VSYNC / XSYNC | Horizontal sync / vertical sync / U12's composite-sync output. [Glue logic](07-glue-logic.md#u12-applecolor-rgb-timing) |
| PLCC / ZIP | Plastic leaded chip carrier / zigzag inline package. Pin positions depend on the part. [Netlist sources](../data/netlist/SOURCES.md) |
| BOM / refdes | Bill of materials / reference designator, such as U7 or R32. [Netlist](../data/netlist/README.md) |
| Strap | A board connection or resistor that sets a configuration input. An open jumper can still read high through a pull-up. [Board](02-board.md#jumpers) |

---

[Reference index](../README.md) | [Reference tables](reference/README.md) | [Sources](sources.md)
