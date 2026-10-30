# 09 Host protocol: commands from the IIgs, and loading Z180 code

[Reference index](../README.md) | [Glossary](glossary.md) | [Reference tables](reference/README.md)

The IIgs talks to the card through four addresses: WR_CMD ($C0B0), WR_DATA ($C0B1),
RD_DATA ($C0B2) and HANDSHAKE ($C0B8) ([host registers](reference/host-commands.md#host-registers)).
Sequential's library does the transfers ([VGALOW.ASM](sources.md#s29),
[VGALIB.C](sources.md#s31)).

## Contents

- [One command, step by step](#one-command-step-by-step)
- [Commands](#commands)
- [Loading Z180 code](#loading-z180-code)
- [Calling and returning](#calling-and-returning)

## One command, step by step

A command with parameters runs in this order
([handshake values](reference/host-commands.md#handshake-values)). GetStatus, ScreenOff,
ScreenOn and SetUserMode take no parameters, so they skip the parameter phase and its
$01/$00 handshake. GetStatus and SetUserMode still have a data phase.
Source: [ROM_BEEF.asm:2694-2701](sources.md#s27), command table.

```
IIgs                                   card
----                                   ----
write cmd to $C0B0  ------------------>  INT1: handler reads $A7/$A6 = $C0B0, reads port $A0 (cmd)
                                         looks up the parameter count (table after the dispatch code)
                                         sets DMA channel 1: port $A0 -> buffer at $1A08, n bytes
                                         writes $01 to port $A0
poll $C0B8 until $01 (WaitHSOn)
write n bytes to $C0B1  -------------->  each write raises INT1/DREQ1; DMA reads port $A0 (acknowledge)
                                         DMA count reaches 0; writes $00 to port $A0
poll $C0B8 until $00 (WaitHSOff)
                                         runs the command (still inside the interrupt)
(some commands) bulk phase: $01, bytes, $00 again
(some commands) poll $C0B8 until $A5 or $A6 (WaitHSDone)
```

Transfer details:

- During a DMA phase, a write to **any** of $C0B0-$C0B7 is a data byte. The Lattice raises
  the same event for all of them, and the DMA just reads port $A0. The library itself
  sends some parameters through $C0B0: SetPalette's address, SetBorder, SetVGAReg and
  GetVGAReg.
- The library's fast loops store 16 bits at a time (`sta <WR_DATA` with a 16-bit
  accumulator, then `iny iny`). Each store writes $C0B1 and then $C0B2. Both raise an
  event, so both are data bytes. The Lattice holds the 65816 with RDY until the card takes
  each byte.
- **Reading results.** Each IIgs read of $C0B0-$C0B7 makes the DMA write the next byte to
  port $A0. So the first read after the $01 handshake returns the old handshake value. The
  library reads $C0B2 once and throws that value away (GetStatus, GetVGAReg).
- ROM 1.4 ignores command $0F and up after the command byte. Firmware 1.5 and 2.0 also
  accept $0F, SetTextFont ([E10](reference/errata.md#e10-settextfont-is-missing)).
- Writes to $C0B1-$C0B7 outside a command are acknowledged and dropped.

## Commands

- Byte counts, parameters and replies of every command:
  [command table](reference/host-commands.md#command-table).
- Mode numbers for SetMode: [mode codes](reference/video-modes.md#built-in-mode-codes).
- Turning the screen copy on and off: [SetShadow](reference/host-commands.md#setshadow).

### UploadData destinations

The destination is a 24-bit offset. When its bank byte is below 8, the firmware adds 8 and
uses the half switch at 0, so offsets $000000-$07FFFF land in the VGA window at Z180
$80000-$FFFFF. Banks 8 and up use the half switch at 1. Flag 0 ("Z180 memory") always
writes bank $08 ([E4](reference/errata.md#e4-uploaddata-cannot-load-z180-code-as-documented)).
An upload must not cross video $80000
([UploadData](reference/host-commands.md#uploaddata)).

### Pixel addressing in the library

The library manual gives the address of a pixel at 8, 16 or 24 bits per pixel as
`address = (Y * width) + (X * (pixDepth / 8)) + ptrToPixImage`. Its record comment calls
`width` the width in pixels, but the formula works only when `width` is the length of a row
in bytes. The same page gives each palette color 8 bits per component, 16.7 million colors
in all. Source: [Programmer's Library Documentation](sources.md#s14) p1.

## Loading Z180 code

RunCode calls any Z180 address, with the MMU set as the IIgs asks. The code must first get
into Z180 memory. The firmware allows three ways:

1. **Screen copy.** With copying on, every byte the IIgs writes to its main hires page 2
   ($00/$4000-$5FFF or $E0/$4000-$5FFF, directly or through shadowing) is copied into SRAM
   bank 0 at $4000-$5FFF. The firmware never runs code there. RunCode with BBR = 0 and
   address $4000 runs it. If hires page 2 is on screen, the bytes show.
2. **SetPalette.** The 768 bytes land at SRAM $0F000 before they go to the DAC. RunCode at
   $F000 runs them. The palette shows garbage meanwhile. In firmware 1.5 and 2.0 this works
   while SetTextFont's user font is not chosen.
3. **UploadData with flag 1 and bank $10-$13.** The firmware uses banks 8 and up as given.
   The Z180's DMA memory address register keeps only address bits 19-16 (Zilog
   [UM0050](sources.md#s39)). So bank $10 lands in SRAM $0xxxx, $11 in $1xxxx, and $12/$13
   in the mirror $2xxxx/$3xxxx. Flag 0 does not work: it always writes bank $08.

**Free space.** The screen copy never writes bank 1 $A000-$FFFF (24 KB), but not all of it
is free while the firmware draws:

- The Super Hi-Res renderer keeps a palette copy at physical $1BB00
  ([`ROM_BEEF.asm:9214-9272`](sources.md#s27)).
- The manual reserves $A000-$BFFF for SHR shadowing code while SHR emulation runs.
- $C000-$FFFF is free. All of bank 1 is free once the copy (SetShadow 4) and Apple
  emulation (SetMode with flag 1) are both off.

Source: [Firmware documentation](sources.md#s15) pp9-10.

Code that runs alongside the firmware has more limits:
[Beyond the firmware: Memory](14-custom-code.md#memory).

### Calling and returning

The completion byte and the MMU limits are in [RunCode](reference/host-commands.md#runcode).

For example, code at SRAM $1A000 runs with CBAR = $F2, BBR = $10, CBR = 0 and address
$A000 (logical $A000 + BBR x 4096 = physical $1A000).

---

Previous: [08 Firmware](08-firmware.md) | [Reference index](../README.md) | Next: [10 Emulator guide](10-emulator-guide.md)
