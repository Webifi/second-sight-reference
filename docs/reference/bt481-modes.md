# Bt481 color modes and Command Register A

[Reference tables](README.md) | [Glossary](../glossary.md)

How the Bt481 reads the P7-P0 pixel bus in each mode. The card's Bt481AKPJ is an
engineering sample marked "PROTO 2" ([production photo](../sources.md#s20)). In every mode
the firmware uses, it behaves as the Bt481A datasheet says.

The built-in modes use 8-bit palette indexes, and the library's 32K-color modes use 15-bit
color. Custom code can also select the 16- and 24-bit modes and Command Register B.

Sources: Brooktree [Bt481A datasheet](../sources.md#s36) L481A_C, the firmware's DAC
accesses, and the mode files.

## Command Register A mode table

Bits A7-A4 pick the mode. Source: [Bt481A datasheet](../sources.md#s36) p7.

<!-- csv: data/tables/bt481-command-register-a.csv -->
| A7 | A6 | A5 | A4 | Pixel mode | Pixel clocks per pixel on P7-P0 | Used by |
|---|---|---|---|---|---|---|
| 0 | any | any | any | 8-bit palette index, 256 entries | 1 | Every firmware mode table (feature byte high nibble 0) |
| 1 | 0 | 0 | 0 | 15-bit color (5 red, 5 green, 5 blue), both clock edges | 1: low byte on the rising edge, high byte on the falling edge | None |
| 1 | 1 | 0 | 0 | 16-bit color (5 red, 6 green, 5 blue), both clock edges | 1: low byte on the rising edge, high byte on the falling edge | None |
| 1 | 0 | 1 | 0 | 15-bit color, one clock edge | 2, low byte first | The library's 32K-color mode files (feature byte $A0/$A1): VGA 640x480 and 640x400 at 50 MHz; RGB 640x400 and 320x200 ([card mode files](#card-mode-files)) |
| 1 | 1 | 1 | 0 | 16-bit color, one clock edge | 2 | None |
| 1 | 0 | 0 | 1 | 24-bit color plus 8-bit overlay, both clock edges | 2 | None |
| 1 | 1 | 1 | 1 | 24-bit color, one clock edge (bypass) | 3 | None. A 16.7-million-color mode needs it, but `M640X48016M` leaves the DAC in palette mode. |

## Notes on individual modes and controls

### Card mode files

A mode record's feature byte: bit 0 picks the output (VGA or RGB), and the high nibble
goes to Command Register A. Source: [ROM_BEEF.asm:1018-1033](../sources.md#s27).

`M640X48016M` programs true-color timing but leaves the DAC in palette mode. The DAC and
CRTC values that make it a 24-bit mode:
[24-bit mode width](../14-custom-code.md#24-bit-mode-width).

### Remaining bits and power-on value

<!-- csv: data/tables/bt481-controls.csv -->
| Field | Value or behavior | Source |
| --- | --- | --- |
| A3 | Must be 0 | Bt481A |
| A2 | 1 forces internal RS2 high | Bt481A |
| A0 | 1 enables indirect Command Register B with address register = 2 | Bt481A |
| Command Register B signature | $1E | Bt481A |
| Command Register A power-on | 0 | Bt481A |
| Command Register B B1 and pin 2 | ANDed; both 1 gives 8-bit, B1 = 0 gives 6-bit regardless of pin | Bt481A p11 |
| Board power-on palette | Pin 2 tied high; B1 powers up 1; starts 8-bit, custom code can clear B1 for 6-bit | [netlist](../../data/netlist/README.md); Bt481A p11 |

### Access with RS2 grounded

<!-- csv: data/tables/bt481-access.csv -->
| Step or condition | Behavior | Source |
| --- | --- | --- |
| RS2 | Tied low on the production card. The Command A access and normal pixel-mask writes need RS2 low. | ROM; the prototype drawing connects HA2 instead |
| Command A access | Read pixel mask $3C6 four times in a row; the next $3C6 write reaches Command Register A | Bt481A |
| Access flag clear | A write to any other register clears the flag | Bt481A |
| Firmware sequence | Read $3C7 once, read $3C6 four times, write the command value | [ROM_BEEF.asm:1018-1033](../sources.md#s27) |

### Pixel word formats

Source: the Bt481A format descriptions.

<!-- csv: data/tables/bt481-word-formats.csv -->
| Format | Red | Green | Blue | Remaining bit |
|---|---|---|---|---|
| 15-bit, 5:5:5 (TARGA) | B14-B10 | B9-B5 | B4-B0 | B15 ignored |
| 16-bit, 5:6:5 (XGA) | B15-B11 | B10-B5 | B4-B0 | None |

## Machine-readable copy

The tables as CSV:
[`bt481-command-register-a.csv`](../../data/tables/bt481-command-register-a.csv),
[`bt481-controls.csv`](../../data/tables/bt481-controls.csv),
[`bt481-access.csv`](../../data/tables/bt481-access.csv) and
[`bt481-word-formats.csv`](../../data/tables/bt481-word-formats.csv).

---

[Reference tables](README.md) | [Video chapter](../06-video.md)
