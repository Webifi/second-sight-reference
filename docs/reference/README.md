# Register, pin, and mode reference

Pin connections, port addresses, register fields, command formats, clock selections and video modes.

| Reference | Question it answers |
|---|---|
| [Board connections](board-connections.md) | Which parts are on the production card, how are the cables wired, and what does the drawing leave out? |
| [Apple slot pins](slot-pins.md) | What does each slot pin do, and where does it connect? |
| [Z180 memory map](z180-memory-map.md) | What appears at each physical address, before and after boot? |
| [Z180 I/O ports](z180-io-ports.md) | What does a port access read, change, or acknowledge? |
| [Lattice pins](lattice-pins.md) | Which ispLSI1016 pin carries each signal? |
| [Lattice design source](lattice-source.md) | What is U7's design, every equation commented, and how is it built? |
| [OTI-087 registers](oti087-registers.md) | What do the extended VGA registers control? |
| [Clock selections](clocks.md) | Which frequency does each OTI-068 selection produce? |
| [Bt481 modes](bt481-modes.md) | How do Command Register A and pixel packing select a color mode? |
| [Host commands](host-commands.md) | Which bytes, phases, and completion values does each command use? |
| [Errata and workarounds](errata.md) | What goes wrong in ROM 1.4, U7 and the library, and how can a IIgs program work around it? |
| [Video mode records](video-modes.md) | What timing and register values are in ROM 1.4 and the `ss.source.082395.po` mode files? |

## Other data

- [Pin-level netlist](../../data/netlist/README.md): prototype connectivity, parts, pinout
  comparisons, and unresolved connections.
- [Method](../13-method.md): how to reproduce the tables and checks.

[Reference index](../../README.md) | [Glossary](../glossary.md) | [Sources](../sources.md)
