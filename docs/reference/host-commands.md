# Host command reference

[Reference tables](README.md) | [Glossary](../glossary.md)

Every host command in ROM 1.4: its bytes and its transfer phases. How one command runs,
step by step: [Host protocol](../09-host-protocol.md). Command $0F (SetTextFont) is
documented but missing from ROM 1.4; firmware 1.5 and 2.0 have it
([E10](errata.md#e10-settextfont-is-missing)).

Sources: the firmware's command table and handlers, Sequential's [`VGALOW.ASM`](../sources.md#s29)
and [`VGA.H`](../sources.md#s30), and the [firmware documentation](../sources.md#s15).

## Contents

- [Host registers](#host-registers)
- [Handshake values](#handshake-values)
- [Command table](#command-table)
- [Notes on individual commands](#notes-on-individual-commands)
- [Machine-readable copy](#machine-readable-copy)

## Host registers

The library uses bank $E0 for these addresses. Poll $C0B8: it is the only one of
$C0B0-$C0B8 whose read raises no event. A read of $C0B2 moves the transfer on to the next
byte. Source: [VGALOW.ASM](../sources.md#s29).

| Address | Library name | Apple write | Apple read |
|---|---|---|---|
| $C0B0 | WR_CMD | Command byte. Raises an event (Z180 INT1). | Same byte as $C0B2. Also raises an event. |
| $C0B1 | WR_DATA | Parameter or data byte. Raises an event. | Same byte as $C0B2. Raises an event. |
| $C0B2 | RD_DATA | Raises an event. | The byte the Z180 last wrote to its port $A0. Raises an event. |
| $C0B3-$C0B7 |  | Raises an event. | Same latch. Raises an event. |
| $C0B8 | HANDSHAKE | Nothing happens. | Same latch. **No event.** The library polls here for the handshake byte. |
| $C0B9-$C0BF |  | Nothing happens. | Same latch. No event. |

## Handshake values

<!-- csv: data/tables/host-command-details.csv -->
| Value | Meaning |
|---|---|
| $01 | Ready: the card's DMA is waiting for bytes (or has bytes ready to read) |
| $00 | Phase finished |
| $A5 | Command finished (SetMode, ClearScreen, ScrollScreen) |
| $A6 | SetMode failed: no such mode for this monitor |

## Command table

- Byte counts leave out the command byte.
- A multi-byte field is sent low byte first. Addresses and lengths are 3 bytes; VGA port
  numbers and RunCode's logical address are 2 bytes.
- A **parameter phase** is `$01` (ready), the parameter bytes, then `$00` (done). A command
  with no parameters skips it, but still has its own result or bulk phase if the table
  lists one.

Sources: [ROM_BEEF.asm:2694-2701](../sources.md#s27); [VGALOW.ASM](../sources.md#s29)
`_ClearScreen`, `_ScrollScreen`, `_UploadData`, `_RunCode`, `_SetVGAReg`, `_GetVGAReg`.

<!-- csv: data/tables/host-commands.csv -->
| Code | Command | Parameter bytes | Bulk or result phase | Completion |
|---|---|---|---|---|
| $00 | [GetStatus](#getstatus) | 0 | 13 host reads: one dummy, then 12 returned bytes | $01, then $00. The library does not wait for the $00. |
| $01 | [SetMode](#setmode) | 2: mode, emulation flag | None | $A5, or $A6 when the monitor has no such mode |
| $02 | [UploadData](#uploaddata) | 10: flag, destination (3), length (3), IIgs source (3, ignored) | Data in phases of up to 64 KB | Phase handshakes. Flag 0 writes the wrong place ([E4](errata.md#e4-uploaddata-cannot-load-z180-code-as-documented)). |
| $03 | [ScrollScreen](#scrollscreen-and-clearscreen) | 9: source (3), destination (3), length (3) | VRAM copy, low 512 KB only ([E8](errata.md#e8-scrollscreen-past-512-kb-overwrites-card-memory)); copies toward a higher address go wrong ([E9](errata.md#e9-scrollscreen-toward-a-higher-address-copies-the-wrong-bytes)) | $A5 |
| $04 | ScreenOff | 0 | None | Sets sequencer clocking bit 5. No completion handshake. |
| $05 | ScreenOn | 0 | None | Clears sequencer clocking bit 5. No completion handshake. |
| $06 | [SetPalette](#palette-commands) | 3: IIgs address (ignored) | 768 bytes in | Phase handshakes |
| $07 | [SetPaletteEntry](#palette-commands) | 4: index, red, green, blue | None | Parameter handshake |
| $08 | SetBorder | 1: palette index | None | Parameter handshake. Writes the overscan register, which the next mode change rewrites ([border color](../08-firmware.md#border-color)). |
| $09 | [RunCode](#runcode) | 5: CBR, CBAR, BBR, address (2) | Calls Z180 code | None. The library waits for $A5/$A6, but the ROM sends neither. |
| $0A | [ClearScreen](#scrollscreen-and-clearscreen) | 7: fill byte, start (3), length (3) | VRAM fill, whole 1 MB, in 64 KB blocks | $A5 |
| $0B | [SetShadow](#setshadow) | 1: value | None | Parameter handshake. Writes value OR $08 to port $A1. |
| $0C | [SetVGAReg](#setvgareg-and-getvgareg) | 6: index port (2), index, data port (2), value | None | Parameter handshake |
| $0D | [GetVGAReg](#setvgareg-and-getvgareg) | 5: index port (2), index, data port (2) | 2 host reads: one dummy, then the value | Result-phase handshake |
| $0E | [SetUserMode](#setusermode) | 0 | 84 bytes in | Bulk handshake. The first 81 bytes define mode $FF. |
| $0F | [SetTextFont](#settextfont) (documented, not in ROM 1.4) | Not accepted by ROM 1.4 | None in ROM 1.4 | ROM 1.4 ignores commands $0F and up. |

## Notes on individual commands

### GetStatus

GetStatus has no parameter phase. Its count byte says six bytes follow, but the firmware's
status record has only five fields. So the library's last read returns a byte of ROM code.
Sources: [ROM_BEEF.asm:1500-1574](../sources.md#s27); [VGALOW.ASM](../sources.md#s29) `_GetStatus`.

1. The host writes `$00` to `$C0B0`. The firmware sets DMA channel 1 to send 13 bytes
   from `GSVGA` onward (`stat_size + 7`, with `stat_size = 6`), then puts `$01` in U3.
2. The host waits for `$01` at `$C0B8`, then reads `$C0B2` once and throws the `$01` away.
   That read raises an event, so the DMA puts `G` in U3.
3. The host makes 12 more reads. Each returns the current byte and loads the next one.
4. The last read loads the 13th DMA byte, which the host never reads. The DMA finishes and
   the firmware writes `$00`. The library does not wait for it.

<!-- csv: data/tables/host-status-bytes.csv -->
| Host read after dummy | Returned value | Meaning |
|---|---|---|
| 1-5 | `G`, `S`, `V`, `G`, `A` | Signature |
| 6 | $06 | Count of following bytes the library reads |
| 7 | $14 in ROM 1.4; $15 in firmware 1.5, $20 in 2.0 | Firmware version: high nibble major, low nibble minor ([firmware documentation](../sources.md#s15) p1) |
| 8 | Emulation flag | 0 = Apple display emulation, 1 = native mode |
| 9 | Mode | Current firmware mode code |
| 10 | $01 | Reported video RAM size, always 1 MB in this ROM |
| 11 | Value read from $3C2 | Monitor/sense byte |
| 12 | $18 | First byte of the next ROM instruction, read past the five-field status record |

The manual defines video_ram 0 = 512 KB and 1 = 1 MB; this ROM always sends $01.
Source: [Firmware documentation](../sources.md#s15) pp9-10.

### SetMode

Flag 0 turns on Apple display emulation; flag 1 selects native VGA mode. The firmware
applies the mode at the next vertical blank, from the mode list the monitor-sense bit
picks. Sources: firmware `set_mode`, main loop; [VGALOW.ASM](../sources.md#s29) `_SetMode`.

The mode codes, and what each means on each monitor:
[Video modes](video-modes.md#built-in-mode-codes). Mode `$FF` uses the record that
SetUserMode loaded.

Flag 1 stops the firmware drawing the Apple screen, but not U7's copy of the Apple's
video writes ([SetShadow](#setshadow)). In ROM 1.4 an Apple display switch also runs
this set-up again while emulation is off
([E29](errata.md#e29-apple-display-switches-reset-a-native-vga-mode)).

### UploadData

The firmware ignores the IIgs source address; the library uses it to send the data. Data
goes in phases of up to 64 KB. Sources: [VGALOW.ASM](../sources.md#s29) `_UploadData`;
firmware `upload_data`.

Flag 0 is meant for Z180 memory, but every flag-0 upload goes to bank $08, the first 64 KB
of the VGA window, whatever bank was asked for. Only the low 16 bits of the destination
count. The cause: the firmware jumps to its add-8 step while the A register still holds
the flag, 0 ([E4](errata.md#e4-uploaddata-cannot-load-z180-code-as-documented)).
Source: [ROM_BEEF.asm:1807-1840](../sources.md#s27), ROM $1342.

Flag 1 with bank $10-$13 reaches SRAM instead, because the Z180's DMA address has only 20
bits ([Loading Z180 code](../09-host-protocol.md#loading-z180-code), which also lists the
renderer data in bank 1).

An upload must not cross video $80000: ROM 1.4 runs each phase as one DMA, which wraps
from Z180 $FFFFF to $00000 and writes the rest into card SRAM, over the firmware. Split
such an upload at $80000 into two commands. Source:
[Firmware documentation](../sources.md#s15) pp2-3. Firmware 1.5 and 2.0 split it
themselves ([UploadData across 512 KB](../firmware-fixes.md#uploaddata-across-512-kb)).

### ScrollScreen and ClearScreen

ScrollScreen copies between VRAM offsets in the low 512 KB. ClearScreen fills a VRAM range
with one byte anywhere in the 1 MB, one 64 KB block at a time. Both finish with `$A5`.
Outside those limits both overwrite card SRAM
([E8](errata.md#e8-scrollscreen-past-512-kb-overwrites-card-memory)).

ScrollScreen has an upward and a downward copy, so that an overlapping range can move
either way intact. ROM 1.4 sets up the downward copy one byte off, and picks the direction
with a byte-by-byte test. So some overlapping moves toward a higher address run upward and
repeat data ([E9](errata.md#e9-scrollscreen-toward-a-higher-address-copies-the-wrong-bytes)).

### Palette commands

SetPalette takes 256 RGB entries of three 8-bit components. The firmware buffers the 768
bytes at SRAM `$0F000`, then loads the DAC. It ignores the IIgs address parameter.
Sources: firmware `set_palette`; [VGALOW.ASM](../sources.md#s29) `_SetPalette`.

SetPaletteEntry writes one index and its red, green and blue values. The components are
full 8-bit values, not the 6-bit values of an ordinary VGA DAC
([Bt481 color chip](../06-video.md#bt481-color-chip)).

### RunCode

The firmware loads CBR, CBAR and BBR from the parameters, calls the logical address, and
restores its own MMU values afterward. The call runs inside the INT1 handler, with
interrupts off. The manual requires CBAR's low nibble = 2, so the handlers stay mapped at
$0000-$1FFF. Sources: firmware `run_code`; [Firmware documentation](../sources.md#s15) pp9-10.

With Sequential's `_RunCode` wrapper, the called code must write `$A5` to port `$A0` before
it returns: the wrapper waits for `$A5/$A6`, and the ROM never sends it.
Sources: `run_code`; [VGALOW.ASM](../sources.md#s29) `_RunCode`.

Ways to load code, and an MMU example:
[Loading Z180 code](../09-host-protocol.md#loading-z180-code). Memory the firmware uses,
and the rest of the hardware: [Beyond the firmware](../14-custom-code.md).

### SetShadow

Only bit 2 controls copying: 0 copies everything, 4 stops all copying. The firmware
forces bit 3 on by writing `value OR $08`; the Lattice ignores input bits 0 and 1.
Source: `set_shadow`.

The library names five flags: SH_SHR = 1, SH_HIRES = 2, SH_TEXT = 4, SH_DBL_HIRES = 8 and
SH_TEXT_80 = 16. The hardware has only the one enable, bit 2.
Source: [VGA.H](../sources.md#s30).

SetShadow stops only the copy. With Apple emulation on, the firmware keeps drawing the
Apple screen from the last copy until SetMode turns emulation off ([SetMode](#setmode)).
Which SRAM each switch frees: [SRAM ownership](z180-memory-map.md#sram-ownership).

### SetVGAReg and GetVGAReg

These commands name the index port and the data port. GetVGAReg needs a dummy read before
the value, because the first read moves the shared output latch on.
Source: [VGALOW.ASM](../sources.md#s29) `_GetVGAReg`.

Both are plain Z180 `OUT (C)` / `IN (C)` on the 16-bit ports given, with no range check.
So they reach every I/O port: the VGA chips, the card's own ports $A0-$AF and the Z180's
internal registers ([Reaching the card from the IIgs](../14-custom-code.md#reaching-the-card-from-the-iigs)).
Source: [ROM_BEEF.asm:1579-1645](../sources.md#s27).

### SetUserMode

The library sends 84 bytes in 42 16-bit stores. The firmware's DMA copies exactly `$54` =
84 bytes to `$179A`, and `set_video_mode` uses the first 81. Sources:
[VGALOW.ASM](../sources.md#s29) `_SetUserMode`; [ROM_BEEF.asm:1483-1493](../sources.md#s27).

The library structure is 111 bytes: 81 meaningful bytes plus 30 unused bytes. Transfer
bytes 81-83 are the first three of those unused bytes. Sources: [VGA.H](../sources.md#s30);
`tools/mode_files.py`:3-19.

Firmware 1.5 and 2.0 copy ext $06 bits 1-0 into the misc byte's clock bits 3-2 before they
program the record, so ext $06 picks the clock; ROM 1.4 lets the misc byte pick it
([E16](../firmware-fixes.md#e16-library-mode-files-run-at-the-wrong-clock)).

| Byte offsets | Contents |
|---|---|
| 0 | Misc output ($3C2) |
| 1 | Sequencer 1, clocking mode |
| 2 | Feature byte: bit 0 selects VGA/RGB path, bits 3-1 go to $3DA, high nibble to Bt481 Command Register A |
| 3-5 | Sequencer 2-4 |
| 6-30 | CRTC 0-$18 |
| 31-39 | Graphics controller 0-8 |
| 40-60 | Attribute controller 0-$14 |
| 61-80 | Oak extended registers 02, 03, 04, 05, 06, 13, 14, 15, 17, 19, 20, 21, 22, 25, 30, 31, 32, 33, 34, 35, in that order |
| 81-83 | Transferred but unused |
| 84-110 | Remaining unused library-structure bytes, not transferred |

Source of the layout: `tools/mode_files.py` and the firmware's `set_video_mode`. The real
records: [Video mode records](video-modes.md).

### SetTextFont

Sequential's August 10, 1995 [firmware documentation](../sources.md#s15) documents command
$0F with standard ROM, alternate ROM, PC ANSI and user-font selections (user data at SRAM
$00F000). ROM 1.4 ignores all commands >= $0F.
[Firmware 1.5 and 2.0](../firmware-fixes.md#e10-settextfont-is-missing) accept it. They
hold one built-in font, so the alternate ROM and PC ANSI selections show the standard font.

## Machine-readable copy

[`host-commands.csv`](../../data/tables/host-commands.csv) is the command table as CSV.

---

[Reference tables](README.md) | [Host protocol](../09-host-protocol.md)
