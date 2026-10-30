# Clock selections and bus timing

[Reference tables](README.md) | [Glossary](../glossary.md)

Each OTI-068 clock selection's frequency, and where ROM 1.4 and the `ss.source.082395.po`
mode files use it.

- **VCLK** is the video clock. The Oak's CSEL3-CSEL0 outputs drive the OTI-068's FS3-FS0
  inputs to pick it.
- **MCLK** is the video-memory clock, picked separately by the MS1-MS0 jumpers.
- Both come from a 14.31818 MHz crystal. The Z180's clock is a separate 36 MHz oscillator,
  so no OTI-068 selection changes the CPU speed.

Sources: the [OTI-068 databook](../sources.md#s01) frequency table; firmware and mode-file
values decoded by `tools/mode_files.py`; the [production photo](../sources.md#s20) for the
memory-clock straps.

## Contents

- [Frequency table](#frequency-table)
- [Notes on individual selections](#notes-on-individual-selections)
- [Board clock connections](#board-clock-connections)
- [Z180 automatic waits](#z180-automatic-waits)
- [VGA bus timing](#vga-bus-timing)
- [Timing at 18 and 36 MHz](#timing-at-18-and-36-mhz)
- [Machine-readable copy](#machine-readable-copy)

## Frequency table

<!-- csv: data/tables/oti068-clocks.csv -->
| Output | Select pins | MHz | Used by |
|---|---|---|---|
| VCLK | FS3-FS0 = $0 | 25.175 | VGA 320x200x256, 640x480x256, 640x400x256, 640x200, double hires, hires; AppleColor 560x192 in the firmware tables |
| VCLK | FS3-FS0 = $1 | 28.322 | VGA 40/80-column text; several mode files |
| VCLK | FS3-FS0 = $2 | 65.000 | None |
| VCLK | FS3-FS0 = $3 | 44.900 | None |
| VCLK | FS3-FS0 = $4 | 28.322 | Several RGB mode files, after the misc-output override ([clock selection](#clock-selection-and-overrides)) |
| VCLK | FS3-FS0 = $5 | 36.000 | AppleColor 40-column text and 280x192 in the firmware tables |
| VCLK | FS3-FS0 = $6 | 40.000 | None |
| VCLK | FS3-FS0 = $7 | 36.000 | None |
| VCLK | FS3-FS0 = $8 | 25.175 | None |
| VCLK | FS3-FS0 = $9 | 28.322 | None |
| VCLK | FS3-FS0 = $A | 78.000 | `M640X48016M`, whose DAC setting leaves true color off ([24-bit mode width](../14-custom-code.md#24-bit-mode-width)) |
| VCLK | FS3-FS0 = $B | 65.000 | None |
| VCLK | FS3-FS0 = $C | 63.000 | AppleColor 80-column text, 640x200, 640x400: 63 MHz / 2 in the sequencer / 2 in U12 = 15.75 MHz dots ([clock dividers](#clock-dividers)) |
| VCLK | FS3-FS0 = $D | 72.000 | `M80X25.1575M` and `M80X24.1575M`, after the misc-output override |
| VCLK | FS3-FS0 = $E | 40.000 | None |
| VCLK | FS3-FS0 = $F | 50.000 | `M640X48032K.50M`, `M640X40032K.50M` and `M1280X480.50M` |
| MCLK | MS1-MS0 = 00 | 44.000 | None |
| MCLK | MS1-MS0 = 01 | 50.000 | None |
| MCLK | MS1-MS0 = 10 | 66.000 | None |
| MCLK | MS1-MS0 = 11 | 40.000 | This board ([memory-clock straps](#memory-clock-straps)) |

## Notes on individual selections

### Clock selection and overrides

Oak extended register 6 bits 1-0 share storage with misc output `$3C2` bits 3-2. The last
write wins, and the 1.4 firmware writes misc output last. Register 6 supplies the upper
selection bits. Sources: [OTI-087 databook](../sources.md#s02) p35; [ROM_BEEF.asm](../sources.md#s27) `set_video_mode`.

So the mode tables show the final selection, which is not always the frequency in the file
name. Changing the selection needs an Oak software reset; the firmware makes the change
inside a sequencer reset. Source: [OTI-087 databook](../sources.md#s02) p35.

### Clock dividers

The selected frequency is not always the final dot rate. The RGB modes at 63 MHz divide by
2 in the sequencer and again by 2 in U12, giving 15.75 MHz dots.

RGB mode `$FA` is the exception: it chooses the VGA path and skips U12's divider. The mode
record, not the name in the monitor list, sets that path.

### Memory-clock straps

Production TP1 and TP2 are open on [s20](../sources.md#s20), [s108](../sources.md#s108),
[s109](../sources.md#s109) and [s128](../sources.md#s128). Their R19/R6 pull-ups are marked `103` (10 kohm), so
MS1-MS0 is binary 11: 40 MHz. The drawing calls the straps JP1/JP2; the three-pad
production JP1 beside SRAM is a separate resistor position. Source: [OTI-068 databook](../sources.md#s01).

## Board clock connections

Sources: [production photo](../sources.md#s20), [Z8S180 specification](../sources.md#s62).

| Clock | Source | Goes to | Value |
|---|---|---|---|
| Z180 EXTAL | 36 MHz oscillator | Z8S180 | 36 MHz; the CPU divides by 2 after reset and the firmware never changes it, so PHI = **18 MHz** |
| HCLK | Z180 PHI through R1 | PLDs U15, U17 (registered) | 18 MHz; R1 is series damping, not a divider. Apparent `220` on s128 supports 22 ohm at medium confidence; older photographs are too blurred to certify the drawing's value. |
| Reference | X2 14.31818 MHz | OTI-068 | |
| VCLK | OTI-068, selected by Oak CSEL3-0 | OTI-087X, Bt481 (directly for VGA, through U12 for AppleColor RGB) | 16 choices ([frequency table](#frequency-table)) |
| MCLK | OTI-068, selected by MS1-MS0 jumpers | OTI-087X memory clock | jumpers open, pull-ups fitted: **40 MHz** |
| Lattice Y0 ("CLK") | 7M or Q3 | U7 softswitch flip-flops | either meets the timing |
| Lattice Y2 | 7M (slot pin 36), through a rework wire ([production changes](../02-board.md#production-changes)) | U7 bank-window flip-flops | 7M ([TN #68](../sources.md#s43)) |

## Z180 automatic waits

Source: [Zilog UM0050](../sources.md#s39), DCNTL tables 3 and 4.

| Access | After DCNTL = 0 | Before that write, at the reset setting |
|---|---|---|
| Memory: SRAM, EPROM, VGA window | 0 automatic waits, 3 clocks | 3 memory waits |
| External I/O: card ports and VGA registers | 1 automatic wait, 4 clocks | 4 I/O waits |
| Internal registers $00-$3F | No waits, except some serial and timer data registers | Each register's timing is in [UM0050](../sources.md#s39) |

## VGA bus timing

| VGA memory timing | Limit | Source |
|---|---|---|
| Memory command width | At least 165 ns | [OTI-087 p47](../sources.md#s02) |
| IOCHRDY assertion after command starts | At most 30 ns | [OTI-087 p47](../sources.md#s02) |
| Read data valid after command, zero wait | 65 ns | [OTI-087 p47](../sources.md#s02) |
| Read at 18 MHz | Two waits give +22 ns command-width margin; one gives -33 ns | [PS0140](../sources.md#s62) Table 8 and [OTI-087 p47](../sources.md#s02) |
| Write at 18 MHz | Three waits meet worst case; two are short by 6 ns | [PS0140](../sources.md#s62) Table 8 and [OTI-087 p47](../sources.md#s02) |

These are the waits the Oak's timing needs, not the count U15 forces: U15 cannot tell
reads from writes, and its count is not recovered
([U15](../07-glue-logic.md#u15-memory-decode-boot-overlay-half-switch-waits)).

## Timing at 18 and 36 MHz

The Z180 can be switched to 36 MHz ([Clock](../14-custom-code.md#clock)). The SRAM
rows below use the Toshiba -10 part and the existing decode-delay assumptions;
[PLD speed grades vary](../02-board.md#pld-markings). The [s128 card](../sources.md#s128)
has NEC D431000AGW-70L marked ES, ICT -15 PLDs and a 16 MHz CPU grade. Its 18 MHz
reset clock exceeds that CPU grade. These Toshiba calculations and CPU timing
guarantees must not be presented as validated limits for s128.

| Access or limit | At 18 MHz | At 36 MHz | Source |
|---|---|---|---|
| 100 ns SRAM read / opcode fetch | Zero waits miss worst-case margins by 16 / 44 ns; one wait gives +39 / +12 ns | Three waits needed; 167 ns cycle, equal to zero waits at 18 MHz | [PS0140](../sources.md#s62) Table 8; [Toshiba SRAM databook](../../data/netlist/SOURCES.md#package-pinouts-used) B-38; U15 decode delay |
| VGA memory command, 165 ns minimum | At least two waits; writes need three at worst case | Read needs five waits; write six; only three programmable memory waits | [OTI-087 p47](../sources.md#s02) |
| VGA address setup, 25 ns minimum | Typical half-clock is 27.8 ns; worst-case setup is not guaranteed | Half-clock is only 13.9 ns; waits occur too late to fix setup | [OTI-087 p47](../sources.md#s02); [PS0140](../sources.md#s62) |
| EPROM opcode fetch, even a 120 ns part | One wait suffices; reset uses three | Needs four or more waits | [PS0140](../sources.md#s62) |
| SRAM copy write pulse, 60 ns minimum (Toshiba -10) | Two whole clocks = 111 ns is the shortest registered pulse; U17's actual pulse is not recovered | Two clocks = 55.6 ns; three needed | [Toshiba SRAM databook](../../data/netlist/SOURCES.md#package-pinouts-used) B-38 |

## Machine-readable copy

[`oti068-clocks.csv`](../../data/tables/oti068-clocks.csv) is the frequency table as CSV.

---

[Reference tables](README.md) | [Video chapter](../06-video.md)
