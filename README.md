# Sequential Systems Second Sight: hardware reference

> [!WARNING]
> **This is preliminary research.** It is provided as is, with no warranty, and may
> contain errors.
>
> Yes, generative AI was used extensively in this project. Don't worry, an emissary has
> been sent to inform John Connor.

The Second Sight (Sequential Systems, 1995) is an Apple IIgs and IIe slot card that drives
a VGA or AppleColor RGB monitor. A Zilog Z180 with 128 KB of RAM on the card keeps a copy
of the Apple's video memory and redraws it through an Oak VGA chip, and gives IIgs
programs new 256-color and 15-bit-color modes.

## Start here

| To | Read |
|---|---|
| Learn how the card works | [Overview](docs/01-overview.md) |
| Emulate the card | [Emulator guide](docs/10-emulator-guide.md#reading-route) |
| Build a replica, or put the card in an A2FPGA | [Replica guide](docs/11-replica-guide.md#reading-route), [On an A2FPGA card](docs/11-replica-guide.md#on-an-a2fpga-card) |
| Program the card from the IIgs | [Host protocol](docs/09-host-protocol.md), [Host commands](docs/reference/host-commands.md), [Errata](docs/reference/errata.md) |
| Put new firmware or a new Lattice chip on a card | [Firmware versions](docs/firmware-versions.md), [Lattice chip versions](docs/lattice-versions.md) |
| Change and build the firmware | [Firmware source](firmware/README.md) |
| Change and build the Lattice logic | [Lattice design source](docs/reference/lattice-source.md), [Building the Lattice fuse map](tools/lattice/README.md) |
| Write your own Z180 code or video effects | [Beyond the firmware](docs/14-custom-code.md) |
| Look up a pin, port, register or mode | [Reference tables](docs/reference/README.md), [Glossary](docs/glossary.md) |
| Check a claim | [Sources](docs/sources.md), [Method](docs/13-method.md), [Tools](tools/README.md) |

## Complete reference

| Document | What it covers |
|---|---|
| [01 Overview](docs/01-overview.md) | What the card does and how the parts work together |
| [02 Board](docs/02-board.md) | Parts list, the two board revisions, clocks, jumpers, connectors, rework |
| [03 Apple interface](docs/03-apple-interface.md) | Slot signals, the host registers, timing, IIgs vs IIe |
| [04 Capture logic](docs/04-capture-logic.md) | The Lattice ispLSI1016: how Apple video writes and softswitches reach the card |
| [05 Z180 computer](docs/05-z180.md) | Clock, memory map, boot, DMA, interrupts, the card's I/O ports |
| [06 Video](docs/06-video.md) | OTI-087 VGA chip, video RAM window, clock chip, Bt481 color chip, outputs, modes |
| [07 Glue logic](docs/07-glue-logic.md) | The four small PLDs and the latches: what each must do |
| [08 Firmware](docs/08-firmware.md) | ROM layout, boot, main loop, interrupt handler, renderers, known bugs |
| [09 Host protocol](docs/09-host-protocol.md) | The command interface IIgs programs use, and loading Z180 code |
| [10 Emulator guide](docs/10-emulator-guide.md) | How to build an accurate emulator of the complete card |
| [11 Replica guide](docs/11-replica-guide.md) | How to build the hardware again |
| [12 Correcting the capture logic](docs/12-lattice-fix.md) | Lattice v2.0, the corrected fuse map for errata E14, E15 and E28: what changes, getting and programming a chip, and going back |
| [13 Method](docs/13-method.md) | How each result was obtained, and how to reproduce it |
| [14 Beyond the firmware](docs/14-custom-code.md) | Resources available to custom Z180 and IIgs code, including what ROM 1.4 never uses |
| [Errata and workarounds](docs/reference/errata.md) | Every known fault: symptom, cause, workaround, and the firmware or Lattice fix |
| [Firmware fixes](docs/firmware-fixes.md) | How firmware 1.5 and 2.0 fix each firmware fault |
| [Reference tables](docs/reference/README.md) | Readable pin, memory, port, register, command, clock, and mode tables |
| [Firmware versions](docs/firmware-versions.md) | Firmware 1.4, 1.5 and 2.0: what each fixes, ready-built images, building from source |
| [Lattice chip versions](docs/lattice-versions.md) | The original Lattice chip and Lattice v2.0, for the ispLSI1016: ready-built fuse files, which chips to buy and which to avoid, programming a chip, going back, building from source |
| [Original images](original/README.md) | Sequential's EPROM and Lattice fuse file as read from a card, with the source that builds each byte for byte |
| [Glossary](docs/glossary.md) | Card-specific names, address domains and notation |
| [Sources](docs/sources.md) | Every source document, with its public URL |

## Repository layout

```
docs/            the reference, numbered in reading order
docs/reference/  readable pin, port, register, command, clock and mode tables
data/tables/     CSV tables: ports, memory map, registers, clocks, pins, commands, modes
data/lattice/    the Lattice chip's design source (ispLSI1016), and the original fuse map
data/netlist/    pin-level netlist, parts list and pinout checks
tools/           scripts that fetch, extract and decode the sources
tools/lattice/   build the Lattice fuse map with Lattice's tools and check it
tools/netlist/   the schematic transcription and its checks
references/      redistributable source documents (public-domain patents), cited in Sources
sources/         download list for the tools (the documents themselves are not committed)
```

## Credits

- Card, firmware and library: Sequential Systems ([manual](docs/sources.md#s16)).
- Preserved documents: the [Apple II Documentation Project](https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Interface%20Cards/Video/Sequential%20Systems%20Second%20Sight/),
  [Brutal Deluxe](https://www.brutaldeluxe.fr/documentation/secondsight.html),
  [bitsavers](http://bitsavers.informatik.uni-stuttgart.de/components/) and the
  [Internet Archive](https://archive.org/details/Second_Sight_VGA_Manual_v1).
- Annotated firmware disassembly: [jawaidbazyar2/secondsight](https://github.com/jawaidbazyar2/secondsight).
- ispLSI1016 designs with source and fuse maps, used to learn the fuse encoding:
  [eventcatcher/startrack](https://github.com/eventcatcher/startrack).

## License

No license has been chosen for this repository yet.
