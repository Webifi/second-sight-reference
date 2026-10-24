# Firmware fixes

[Reference index](../README.md) | [Firmware versions](firmware-versions.md) | [Errata](reference/errata.md) | [08 Firmware](08-firmware.md)

How firmware 1.5 and 2.0 fix each erratum. Each change is marked `CHANGE (En)` in their
source, [`firmware/v1.5`](../firmware/v1.5/SecondSight_v1_5.asm) and
[`firmware/v2.0`](../firmware/v2.0/SecondSight_v2_0.asm); ROM 1.4's source,
[`firmware/v1.4`](../firmware/v1.4/ROM_BEEF.asm), marks the fault `BUG (En)`. Addresses are ROM 1.4's. One more
change is not an erratum fix:
[UploadData across 512 KB](#uploaddata-across-512-kb), marked `CHANGE (512 KB)`.

- [E1](#e1-mode-13-shows-a-broken-picture) Mode $13 shows a broken picture
- [E2](#e2-double-hires-hangs) Double hires hangs
- [E3](#e3-super-hi-res-lines-102-127-use-the-wrong-palette) Super Hi-Res lines 102-127 use the wrong palette
- [E4](#e4-uploaddata-cannot-load-z180-code-as-documented) UploadData cannot load Z180 code as documented
- [E5](#e5-runcode-never-reports-completion) RunCode never reports completion
- [E6](#e6-mixed-hires-text-ignores-the-c022-colors) Mixed-hires text ignores the $C022 colors
- [E7](#e7-double-lores-is-not-implemented) Double lores is not implemented
- [E8](#e8-scrollscreen-past-512-kb-overwrites-card-memory) ScrollScreen past 512 KB overwrites card memory
- [E9](#e9-scrollscreen-toward-a-higher-address-copies-the-wrong-bytes) ScrollScreen toward a higher address copies the wrong bytes
- [E10](#e10-settextfont-is-missing) SetTextFont is missing
- [E11](#e11-super-hi-res-color-fill-mode-is-ignored) Super Hi-Res color fill mode is ignored
- [E13](#e13-fast-animation-is-choppy) Fast animation is choppy
- [E15](#e15-the-iigs-border-color-does-not-show) The IIgs border color does not show (firmware 2.0, with [Lattice v2.0](lattice-versions.md))
- [E16](#e16-library-mode-files-run-at-the-wrong-clock) Library mode files run at the wrong clock
- [E17](#e17-the-true-color-mode-file-shows-palette-colors) The true-color mode file shows palette colors
- [E19](#e19-uploads-of-whole-64-kb-blocks-hang-older-programs) Uploads of whole 64 KB blocks hang older programs (partly)
- [E25](#e25-very-large-pictures-may-hang-the-card) Very large pictures may hang the card (partly)
- [E26](#e26-flashing-text-ignores-the-c022-colors) Flashing text ignores the $C022 colors
- [E27](#e27-four-language-characters-sit-one-row-low-in-the-8x16-font) Four language characters sit one row low in the 8x16 font
- [E29](#e29-apple-display-switches-reset-a-native-vga-mode) Apple display switches reset a native VGA mode

## E1. Mode $13 shows a broken picture

The fault: [E1](reference/errata.md#e1-mode-13-shows-a-broken-picture).

Two changes:

1. **The picture.** The mode $13 record (81 bytes at $C0A2) is IBM's standard mode 13h
   plus Oak ext $21 = $04, packed pixels. Its ext $21 byte at $C0EA is $00, which
   makes the record Oak's own mode 13h, 320 x 200 in 256 colors. `set_video_mode` copies
   the record by DMA from the EPROM itself, so the change is in the EPROM image.
2. **The uploads.** In standard mode 13h the two low address bits choose the memory
   plane, so a picture must be written through the standard $A0000 window. The first
   8 bytes of `upload_data` ($127A) call `upload_select_window` in free memory. It
   picks out picture uploads in mode $13: flag 1 with destination bank 0, Apple
   emulation off (`emul_flag` = 1), `vga_mode` = $13, and at most 64 KB. For those it
   writes port $AA instead of $AB, selects half 1, leaves Oak register 5 at $00 and sets
   the destination bank to 2, which `upload_chunk` turns into $0A: byte n goes to Z180
   $A0000 + n. Every other upload gets the linear window as before.

The AppleColor RGB list stays without mode $13; adding it needs a new 81-byte record
with 15.7 kHz timing and an entry in that list.

## E2. Double hires hangs

The fault: [E2](reference/errata.md#e2-double-hires-hangs).

**No change to those bytes alone fixes it.** Table A1 and the scan routines need the same
logical addresses, so the routines that run there have to move.

Two changes, both found from the memory layout the
double-hires code sets (CBAR = $C9, BBR = $08, CBR = $94: logical $9000-$9DFF shows the
tables, $C000-$FFFF shows video memory, and only $0000-$8FFF is the firmware's own bank 0):

1. **Setup.** `set_videomode_double_hires` ($8D7E) switches to that layout first and then
   calls the table copiers at $90A9 and $90E8, which therefore run table memory. None of
   its work needs the layout: the table copies and the video-memory fill are DMA transfers
   with physical addresses, and the rest is port writes. `emulate_double_hires` ($8E14)
   sets the layout itself at the start of every pass and restores the normal one at the
   end. The change skips the three register writes (15 bytes at $8D7F) with `18 0D`
   (`JR $8D8E`) at $8D7F.
2. **Rendering.** `mono_dhires_line` ($8FCD-$902B) runs past $9000, and
   `colour_dhires_line` ($902C-$90A8) lies wholly above it (the s27 disassembly calls
   them `dhires_scan_colour` and `dhires_scan_mono`). The change copies both, 220
   bytes, unchanged into the unused bank-0 bytes below $9000: $1F10-$1FEB, inside
   $1EC4-$1FFF. They use only relative jumps, so they run anywhere. Then the two calls in
   `dhires_row` move to the copies: `CD CD 8F` at $8F93 becomes `CD 10 1F`, and `CD 2C 90`
   at $8FB2 becomes `CD 6F 1F`.

Everything else the double-hires path runs (`emulate_double_hires`, `render_dhires_rows`,
`dhires_row`, the event handler and the command handlers) already lies below $9000.
E5's wrapper at $1F00-$1F08 fits beside the moved routines.
Source: [ROM_BEEF.asm:7090-7175 and 7306-7540](sources.md#s27); addresses from the
ROM 1.4 source ([`firmware/v1.4/src`](../firmware/v1.4/src)).

## E3. Super Hi-Res lines 102-127 use the wrong palette

The fault: [E3](reference/errata.md#e3-super-hi-res-lines-102-127-use-the-wrong-palette).

`render_superhires` starts the $6000-$6FFF band
with `LD IX,$9D7F` (at $AB11, bytes `DD 21 7F 9D`). Its line loop increments IX before
it reads each control byte, so this band begins with line 128's byte instead of line
127's. The other bands already start one lower to allow for that increment. The change
makes the pointer's low byte at $AB13 $7E instead of $7F.
The [E13](reference/errata.md#e13-fast-animation-is-choppy) renderer draws each band forwards, so
there the band starts at line 102's own control byte, `LD IX,$9D66`.

## E4. UploadData cannot load Z180 code as documented

The fault: [E4](reference/errata.md#e4-uploaddata-cannot-load-z180-code-as-documented).

In `upload_chunk`, `CP #0` / `JR Z` (at $1345,
bytes `FE 00 28 0C`) sends flag 0 to the instruction that adds 8 to the bank ($1355),
the step meant for video memory. Flag 0 must instead go straight to `dma_upload`
($135A), which uses the requested bank as it is. The change makes the jump distance
at $1348 $11 instead of $0C.

## E5. RunCode never reports completion

The fault: [E5](reference/errata.md#e5-runcode-never-reports-completion).

`run_code` ($1C2D) saves the MMU registers, calls the user
code, restores the registers and returns, without sending the completion code $A5.
The change puts a small routine around it instead of rewriting it: nine bytes at $1F00,
`CD 2D 1C 3E A5 ED 39 A0 C9` (`CALL $1C2D` / `LD A,$A5` / `OUT0 ($A0),A` / `RET`), and
the RunCode entry of the command table at $1C21 changes from `2D 1C` to `00 1F` so the
command reaches the new routine. User code that already writes $A5 itself still works:
the second $A5 changes nothing. A user routine that never returns still never reports.

## E6. Mixed-hires text ignores the $C022 colors

The fault: [E6](reference/errata.md#e6-mixed-hires-text-ignores-the-c022-colors).

The card already receives every $C022 write (an event while MODE_D3 is set,
[event addresses](reference/z180-io-ports.md#apple-event-addresses)), and the handler
`softswitch_C022_tbcolor` stores it at $1A32. In hires the text lines are drawn into the
same planes as the picture, so ROM 1.4 shows them in hires entries 15 (white) and 0
(black). The hires tables never set plane 3, so the picture uses palette entries 0-7
only, which leaves entries 14 and 15 free. The change:

1. The first three bytes of the text-line routine `render_text_line_in_8x8_font` at
   $6354 (`46 3E 05`, `LD B,(HL)` / `LD A,5`) become `JP $9C00` (`C3 00 9C`), to 117
   bytes of new code at $9C00-$9C74.
2. Before each text line the new code loads DAC entries 14 (background, the low nibble
   of $1A32) and 15 (text, the high nibble) from the color table at $7E04, the way
   `set_textmode_palette` loads entries 0 and 1.
3. It sets the VGA set/reset and enable set/reset registers (graphics controller 0 and
   1) to $0E, which forces the three upper planes to 1 during the text writes. The glyph
   bit in plane 0 then selects entry 15 or 14.
4. It loads A with 5, as the replaced `LD A,5` did, and calls the rest of the routine at
   $6357, which draws the line. Then it clears both registers again and returns.
   `LD B,(HL)` did nothing (the next instruction loads BC), so it is not run.

Reading $1A32 on every line follows later $C022 changes, and the picture's colors stay
untouched. Inverse and flashing characters in these lines still show as normal text, as
in ROM 1.4.

## E7. Double lores is not implemented

The fault: [E7](reference/errata.md#e7-double-lores-is-not-implemented).

All the input is already there: the capture logic copies both text pages, main in SRAM
bank 0 and auxiliary in bank 1, and AN3 and 80-column writes reach the firmware as events.
ROM 1.4 lacks only the renderer: its mode check (`emulate_lores_dlr_check`, $1EB6) sends
double lores to the single-lores routines. The change:

1. The mode check's first 7 bytes become `JP $9D00` and four NOPs. The new code at $9D00
   picks the double lores routines for lores with AN3 off and 80-column video, the same
   condition as double hires. Any other lores goes back to the single lores routines at
   $1EBD.
2. The set-up routine does what the single lores one does: mode $FE (640 x 200), half 0,
   the lores and text palettes, screen on.
3. The renderer draws 80 blocks per row, each 8 pixels wide, half a single lores block.
   For each text-page byte position it draws first the auxiliary byte's color, then the
   main byte's. Each byte gives a top block (low nibble) and a bottom block (high nibble).
   An auxiliary nibble holds its color rotated one bit to the right, the Apple IIe
   double-lores rule, so the renderer rotates it one bit to the left to get the color:
   `((n << 1) | (n >> 3)) & $0F`. Source: [Double Lo-Res Graphics](sources.md#s83).
4. Mixed mode draws the last four rows as 80-column text with the single lores renderer's
   text routine (`render_text80_row`), main characters in the odd cells and auxiliary ones
   in the even cells.

- The renderer maps the video window at logical $A000-$EFFF (CBAR $FA) instead of
  $9000-$EFFF, so its own code at $9D00 stays mapped while it draws. Auxiliary memory is at
  $F000 (CBR $21), as in single lores.
- It always shows text page 1, like the 80-column text and double hires renderers. With
  80STORE on, PAGE2 selects auxiliary memory for the Apple's writes, and the firmware is
  never told about 80STORE: U7 tracks it but raises no event for it.
- It redraws every block on every pass. A redraw cache for both pages would need 1,920
  bytes, and there is no room for it.

The new code takes $9D00-$9ECC (461 bytes).

## E8. ScrollScreen past 512 KB overwrites card memory

The fault: [E8](reference/errata.md#e8-scrollscreen-past-512-kb-overwrites-card-memory).

Both commands are rewritten in free memory; the first 8 bytes of `scroll_screen` ($13E8)
and `clear_screen` ($1653) jump to the new code through `call_in_bank0`.

1. **ScrollScreen** takes both addresses as 20-bit video addresses and moves the data in
   pieces of at most 4 KB that never cross $80000, choosing the video half for each
   piece. A piece whose source and destination are in one half is one DMA through the
   linear window, as before. A piece between halves, at most 1 KB, goes through a buffer
   in firmware memory (SRAM $0A600): source half selected and the piece copied into the
   buffer, then destination half selected and copied out. The halves are different memory, so such a
   piece cannot overlap itself, and the order of the pieces follows the copy direction
   ([E9](reference/errata.md#e9-scrollscreen-toward-a-higher-address-copies-the-wrong-bytes)).
2. **ClearScreen** fills in pieces that end at each 64 KB boundary of the video address,
   so no single DMA crosses $80000 or $100000.
3. **Both** cut a range that runs past $FFFFF, the end of video memory, at that point.

## E9. ScrollScreen toward a higher address copies the wrong bytes

The fault: [E9](reference/errata.md#e9-scrollscreen-toward-a-higher-address-copies-the-wrong-bytes).

In the new ScrollScreen (see [E8](#e8-scrollscreen-past-512-kb-overwrites-card-memory)):

1. The direction test compares the two 20-bit addresses as whole numbers and copies
   downward only when the destination is higher.
2. The downward copy starts each address at address + length - 1, with the borrow carried
   into the bank byte, so each DMA starts at the last byte of its range.

## E10. SetTextFont is missing

Fixed for the built-in and user fonts. The fault: [E10](reference/errata.md#e10-settextfont-is-missing).

1. The dispatcher's `JP NC` after `CP $0F` ($1B6A) goes to a 12-byte routine at
   $1FEC, which ignores commands $10 and up as before and runs SetTextFont for $0F.
   The parameter-count table and `api_table` stay as they are: $0F takes its own path.
2. The handler receives the three parameter bytes (size $04 in the documentation) the
   way SetUserMode receives its data, keeps the font number, and, when an Apple text
   mode is on screen, asks the main loop for a mode change, so the text set-up runs
   again and loads the font at once.
3. `copy_font` ($7B00) first checks the font number. For $03 it loads the user font from
   SRAM $00F000: 256 glyphs indexed by VGA character code, 16 bytes each on a VGA monitor
   and 8 on AppleColor RGB, into plane 2 the way it loads the built-in font. Any other
   number loads the built-in font.

ROM 1.4 holds one built-in font, so $01 (alternate ROM font) and $02 (PC ANSI font) show
the standard font: neither font exists in the ROM, and there is no room for 4 KB fonts.
The mixed-mode text lines of lores and hires keep the built-in 8 x 8 font.

## E11. Super Hi-Res color fill mode is ignored

The fault: [E11](reference/errata.md#e11-super-hi-res-color-fill-mode-is-ignored).

The control bytes and pixels already reach SRAM; only the renderer ignored bit 5. The
converter reads each line left to right but cannot carry a color from pixel to pixel.
`select_line` first calls `fill_line_check` in the renderer's free space. For a
320-pixel line with bit 5 set, it copies the line's 160 bytes into a buffer in the
renderer's own block ($1A507), left to right, replacing every 0 pixel with the last nonzero pixel before it
on the same line, and points the converter's source at the buffer for that line. A line
that a 4 KB band starts part way through is copied from its real start, so the fill
color carries across the band boundary. Lines without bit 5 keep the existing path. The
copy costs about 0.9 ms per fill line and runs with interrupts on. The renderer runs from
its copy at $1A000-$1BFFF, refreshed from $0A000-$0BFFF at each Super Hi-Res entry, so the
change is in the $0A000 copy.

## E13. Fast animation is choppy

The fault: [E13](reference/errata.md#e13-fast-animation-is-choppy).

The new renderer draws a full screen in about 68 ms, against at least 92 ms for ROM 1.4;
60 new full screens a second stays out of reach. It cannot redraw less: the band flags say only which 4 KB band was written, and finding
the changed bytes by comparing each one with a kept copy (`LD A,(BC)` / `CP (HL)` /
`JR NZ` / `INC BC` / `INC HL`, 26 clocks) costs most of what converting it does.
Nor can it beat the IIgs side: the IIgs needs about 31 ms just to write 32,000 bytes
through its slow bus, and copying them costs the card 12-18 ms of its own bus time, so a
full new screen every 16.7 ms is impossible.
- **What the chip allows** ([Pixel formats the chip displays](06-video.md#pixel-formats-the-chip-displays)):
the OTI-087X has no 4-bit packed format, so every 320-mode pixel must be converted
before it reaches video memory.
- **The new renderer:** ROM 1.4 spends 24 of its 42 clocks per byte
building the table address (`LD H,n` / `LD L,A` / `ADD HL,HL` / `ADD HL,HL`), and calls
one of eight 32-byte routines per half line after testing the palette number. The new
renderer changes three things:
1. A read of video memory loads the latch with the whole 4-byte word that holds its
   address, so the low two address bits only pick the byte the read returns
   ([lane rule](06-video.md#the-64-bit-latch-lane-rule); Oak's
   [databook](sources.md#s02) p1: the chip implements all the IBM VGA's registers and
   data paths). A 256-byte page table in SRAM can therefore give the table page
   directly: `LD H,(HL)` with L = the source byte.
2. The stack pointer walks the band forwards, so `POP HL` reads two source bytes in 9
   clocks.
3. Register B holds the line's page table, so one copy of the code serves all 16
   palettes and the palette test goes.
```
pop  hl        ;  9  L = byte b0, H = byte b1
ld   a,h       ;  4  keep b1
ld   h,b       ;  4  B = the page table for the line's palette (SRAM)
ld   h,(hl)    ;  6  H = $F0 + 4n + (b0 AND 3)
ldi            ; 12  table word at H:b0 -> latch -> four screen bytes
ld   l,a       ;  4  the same for b1
ld   h,b       ;  4
ld   h,(hl)    ;  6
ldi            ; 12
```
That is 61 clocks for two bytes, 30.5 a byte. Each byte's entry sits at word
`(b AND $FC)` of page `$F0 + 4n + (b AND 3)` in each 4 KB piece of video memory, the same
4 KB per palette group as before; the four page tables take 1 KB in the renderer's own
block ($1A600), built again at each Super Hi-Res entry. A full screen takes 68.1 ms when every line has the same control byte and
69.5 ms when every line has its own, against at least 92 ms for ROM 1.4: about 14.7 full
screens a second instead of 10.8. Source: every instruction counted with
[UM0050](sources.md#s39) states and two waits per video access.
- **Where those 38.3 clocks a byte go:** 16 are the two video accesses of `LDI` with
their waits, 14.5 fetch the source and find the table page, 4 keep the second source byte
(`ld a,h` and `ld l,a`), 1.5 move the screen address
every four bytes (each store fills four pixels picked by address bit 0 and bits 3 and
up, so four bytes go to window offsets 6, 7, 8 and 9 of each 16), and 2.3 are line,
page and band bookkeeping. Every source byte needs one read to load the latch and one
write to store it, so those 16 clocks stay in any table conversion.
- **Interrupts:** an interrupt would push its return address into the Apple screen copy
while the stack pointer walks it, so each line runs with interrupts off. At each line
end the renderer restores its stack and lets a waiting interrupt in, so an event waits
at most one line, about 0.35 ms; meanwhile the Lattice holds the Apple's next copy or
event ([RDY](04-capture-logic.md#rdy-no-lost-events)).

**Cost of comparing the $9000 band.** The $9000 band flag also sets on
palette and control-byte writes ($9D00-$9FFF), so a program that only cycles colors has
lines 179-199 redrawn every pass ([E13](reference/errata.md#e13-fast-animation-is-choppy)).
Firmware could keep a copy of $9000-$9CFF and compare before redrawing, but a pass that
changes pixels there would then take up to 5.6 ms longer, to save 2.6 ms on a pass that
changes only palettes. [Lattice v2.0](lattice-versions.md#what-v20-changes) leaves the flag as the
factory chip has it, for the same reason.

## E15. The IIgs border color does not show

Firmware 2.0 only, with [Lattice v2.0](lattice-versions.md). The fault: [E15](reference/errata.md#e15-the-iigs-border-color-does-not-show).

With Lattice v2.0, a $C034 write while MODE_D3
is set is an event: U7 latches the byte the IIgs writes into U2, keeps the address's low
byte ($34), and interrupts the Z180, as for a $C022 write
([Events](04-capture-logic.md#events-telling-the-z180-about-softswitch-accesses)). With the
original Lattice chip nothing about the write reaches the card. Firmware 2.0 adds four things:

1. **A handler.** `set_softswitch_handler` ($1C86), called with A = $34 at the end of
   `setup_softswitch_handlers` ($1A40), puts the handler's address into the event
   dispatch table ($1834 low byte, $1934 high byte). `handle_event` reads the address
   from ports $A7/$A6 and the byte from port $A0, and calls the handler with the byte in
   A, as it does for $C022. The handler keeps bits 3-0. Bits 7-5 drive the IIgs clock
   chip, and the IIgs writes $C034 at every clock access with the border bits unchanged,
   so the handler returns at once when the color is the same as before.
2. **Showing the color.** The handler only records the color. Outside the interrupt,
   while Apple emulation is on, the main loop then loads DAC entry $FF with the color
   from the 16-color table at $7E04 (red, green and blue bytes per color,
   the table `set_textmode_palette` uses for $C022) and sets attribute register $11 to
   $FF. The text, lores, hires and double-hires palette loaders use only entries
   $00-$1F, so $FF is free in those modes.
3. **After every mode set** it does the same again, because `set_video_mode` rewrites
   register $11 from the mode record.
4. **Super Hi-Res.** There all 256 DAC entries hold the 16 IIgs palettes, and the Bt481's
   overlay inputs are grounded, so no entry is spare. The firmware points register $11 at
   the entry whose color is closest to the border color (`shr_border`, in
   `src/superhires.asm`), and looks again when that entry's color changes. The border is
   exact only when the picture uses that color.

## E16. Library mode files run at the wrong clock

The fault: [E16](reference/errata.md#e16-library-mode-files-run-at-the-wrong-clock).

`set_video_mode` writes ext $06 and then the misc output byte, and both set the low two
clock-select bits, so the misc byte wins. For user records (mode $FF, the record
SetUserMode stores at $179A), `set_user_video_mode` ($0DFD) jumps to
`user_mode_fixup` in free memory. It copies ext $06 bits 1-0 into misc bits 3-2 of the
stored record, then programs the record as before. Each library file then runs at the
clock its name says. The built-in records keep the current order, because the RGB record
for $FA relies on its misc byte deciding.

## E17. The true-color mode file shows palette colors

The fault: [E17](reference/errata.md#e17-the-true-color-mode-file-shows-palette-colors).

Ext $21 = $06, the x3 timing of 24-bit color, does not by itself identify this record:
any user record for 24-bit color sets it, with its own DAC setting and display width.
`user_mode_fixup` (see [E16](#e16-library-mode-files-run-at-the-wrong-clock)) compares
the stored record with a copy of the 81 bytes of `M640X48016M` in free memory. Only on a
match does it set the feature byte to $F0, so the Bt481 Command Register A gets $F0,
and CRTC $01 to $4F, before the record is programmed.

## E19. Uploads of whole 64 KB blocks hang older programs

Partly fixed. The fault: [E19](reference/errata.md#e19-uploads-of-whole-64-kb-blocks-hang-older-programs).

The old library ends each 64 KB block by waiting for $00 at $C0B8, then waits for a
ready handshake ($01) and for $00 again for a remainder phase that does not exist.
`upload_data`'s remainder test ($12E8) calls `upload_check_remainder` in free
memory. When the length is whole 64 KB blocks with no remainder, it supplies that phase:
after the $00 that ends the last block, it waits about 1 ms so the program sees it,
writes $01 to port $A0, waits about 1 ms, then writes $00. Both waits are counting
loops. The first wait matters: a $01 that follows the block's $00 at
once can reach the program before it has read the $00, and it then takes the $01 for
part of the last block and waits forever for another. The card cannot see the IIgs
reading $C0B8 (those reads are not events), so a program held up for longer than a wait
can still miss a step and hang; the August 1996 library or the two-byte padding is the
reliable fix. Source: [VGALOW.ASM](sources.md#s29) (1995) `_UploadData`.

## E25. Very large pictures may hang the card

Partly fixed. The fault: [E25](reference/errata.md#e25-very-large-pictures-may-hang-the-card).

As [E19](reference/errata.md#e19-uploads-of-whole-64-kb-blocks-hang-older-programs);
a 1024 x 1024 picture is an exact multiple of 64 KB.

## E26. Flashing text ignores the $C022 colors

The fault: [E26](reference/errata.md#e26-flashing-text-ignores-the-c022-colors).

Two changes:

1. `set_textmode_palette` also copies the colors it loads (`text_bg_red` to
   `text_fg_blue`, $7DAD-$7DB2) into the flashing pair. Its last instructions at $7D97
   become `JP` to 22 bytes of new code in free memory, which writes entry 4 black as
   before, copies the 6 bytes with `LDIR` and returns.
2. The 5 bytes at $91FF (`3E 00 32 07 92`, clearing `text80_palette_colour`) become
   `NOP`s, so 80 columns reload the colors only when $C022 changes, as 40 columns do.

## E27. Four language characters sit one row low in the 8x16 font

The fault: [E27](reference/errata.md#e27-four-language-characters-sit-one-row-low-in-the-8x16-font).

The change leaves out the 17th row of $9A ($8834, a blank row), so the bytes $8835-$8874
move down by one and every glyph is 16 rows; the freed byte $8874 is zero.

## E29. Apple display switches reset a native VGA mode

The fault: [E29](reference/errata.md#e29-apple-display-switches-reset-a-native-vga-mode).

`get_emulation_routine` ($1E62) jumps to `native_mode_check` in free memory. With
emulation off, it returns `set_native_mode` only when SetMode asked for the change
(`setmode_reply_owed` = 1). A change an Apple switch asked for goes straight back to the
main loop, which draws nothing.

## UploadData across 512 KB

Sequential's documentation tells programs never to upload across video $80000: ROM 1.4
cannot switch the video half in the middle of a transfer, and the Z180's DMA wraps to
address zero, over the firmware. It also says a later UploadData may split such a
transfer itself. Source: [Firmware documentation](sources.md#s15) pp2-3, UploadData.

What ROM 1.4 does with such a phase, from its source: one DMA runs from Z180 $FFFFF on to
$00000, so the bytes past video $7FFFF land in card SRAM from $00000 and are missing from
the picture. Up to 811 of them overwrite only the reset and boot code, which a reset copies
back from the EPROM. More reach the debug hooks and the stack at $032B-$03FF, and the card
crashes.

Firmware 1.5 and 2.0 split the phase: up to video $7FFFF, then the rest from Z180 $80000
with half 1, which is video $80000 and up. Past the end of the 1 MB, the rest wraps to
video $00000 instead of into SRAM.

- The host still sees one phase: $01, all its bytes, $00.
- Nothing is written to port $A0 between the pieces: a port $A0 access acknowledges the
  pending event, so it would drop a byte the host has already sent. U7 holds the IIgs
  with RDY until the second piece starts.
- The second piece uses level-sensed DMA requests. The host's next byte is usually
  waiting when it starts, with DREQ1 already low, so an edge-sensed request never comes.
  Level sense cannot take a byte twice: the DMA samples DREQ1 during its memory write,
  after its read of port $A0 has released U7's request (Zilog
  [UM0050](sources.md#s39) pp107-108).
- `dma_upload` ($135A) calls `upload_dma` ($9C75) through `call_in_bank0`;
  `upload_dma_start` ($9B6E) starts each piece.

---

[Reference index](../README.md) | [Firmware versions](firmware-versions.md) | [Errata](reference/errata.md)
