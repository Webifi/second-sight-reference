# Errata and workarounds

[Reference tables](README.md) | [Glossary](../glossary.md) | [Firmware](../08-firmware.md)

Every known fault of ROM 1.4, the card logic (U7), the IIgs library, the mode files and
the programs written for the card. Each entry gives the symptom, the cause, a workaround
for a card as shipped, and the fix: [firmware 1.5 and 2.0](../firmware-versions.md)
([how](../firmware-fixes.md)) or [U7 v2.0](../lattice-versions.md). Workarounds use only
the card's own host commands ([Reaching the card from the IIgs](../14-custom-code.md#reaching-the-card-from-the-iigs)).

## Contents

- [Index](#index)
- [ROM 1.4 faults](#rom-14-faults)
- [Card logic faults](#card-logic-faults)
- [Library and mode-file faults](#library-and-mode-file-faults)
- [Faults of earlier firmware](#faults-of-earlier-firmware)
- [Faults in programs](#faults-in-programs)
- [Reported faults](#reported-faults)

## Index

| ID | Problem | Affects | Evidence | Workaround | Fix |
|---|---|---|---|---|---|
| [E1](#e1-mode-13-shows-a-broken-picture) | Mode $13 (320 x 200 x 256) shows a broken picture; refused on the RGB monitor | ROM 1.4 | Reported 1996 ([GView README](../sources.md#s04)); cause found in the ROM | Period fix: use a 640-wide mode. Register fix needs custom code | [Firmware 1.5 and 2.0](../firmware-fixes.md#e1-mode-13-shows-a-broken-picture) |
| [E2](#e2-double-hires-hangs) | Double hires hangs the card | ROM 1.4 | Reported 1995 ([GenieLamp](../sources.md#s70)); cause found in the ROM | None | [Firmware 1.5 and 2.0](../firmware-fixes.md#e2-double-hires-hangs) |
| [E3](#e3-super-hi-res-lines-102-127-use-the-wrong-palette) | Super Hi-Res lines 102-127 use the next line's palette | ROM 1.4 | Found in the ROM | Change one SRAM byte | [Firmware 1.5 and 2.0](../firmware-fixes.md#e3-super-hi-res-lines-102-127-use-the-wrong-palette) |
| [E4](#e4-uploaddata-cannot-load-z180-code-as-documented) | UploadData with flag 0 never reaches Z180 memory | ROM 1.4 | Found in the ROM; Sequential's own UP tool expects the opposite | Use flag 1 and bank $10 | [Firmware 1.5 and 2.0](../firmware-fixes.md#e4-uploaddata-cannot-load-z180-code-as-documented) |
| [E5](#e5-runcode-never-reports-completion) | RunCode never reports completion | ROM 1.4 with Sequential's library | Found in the ROM and library code | Send $A5 from the Z180 code | [Firmware 1.5 and 2.0](../firmware-fixes.md#e5-runcode-never-reports-completion) |
| [E6](#e6-mixed-hires-text-ignores-the-c022-colors) | Mixed-hires text ignores the $C022 colors | ROM 1.4 | Found in the ROM | None | [Firmware 1.5 and 2.0](../firmware-fixes.md#e6-mixed-hires-text-ignores-the-c022-colors) |
| [E7](#e7-double-lores-is-not-implemented) | Double lores shows as single lores | ROM 1.4 | Reported 1995 ([manual](../sources.md#s16)); confirmed in the ROM | Custom renderer only | [Firmware 1.5 and 2.0](../firmware-fixes.md#e7-double-lores-is-not-implemented) |
| [E8](#e8-scrollscreen-past-512-kb-overwrites-card-memory) | ScrollScreen past 512 KB overwrites the card's memory; so does a ClearScreen block that crosses $80000 | ROM 1.4 | Found in the ROM | Keep scrolls below $80000; start fills on 64 KB boundaries | [Firmware 1.5 and 2.0](../firmware-fixes.md#e8-scrollscreen-past-512-kb-overwrites-card-memory) |
| [E9](#e9-scrollscreen-toward-a-higher-address-copies-the-wrong-bytes) | ScrollScreen toward a higher address copies one byte off, or repeats data when the ranges overlap | ROM 1.4 | Found in the ROM | Force the upward copy | [Firmware 1.5 and 2.0](../firmware-fixes.md#e9-scrollscreen-toward-a-higher-address-copies-the-wrong-bytes) |
| [E10](#e10-settextfont-is-missing) | SetTextFont ($0F) is documented but missing | ROM 1.4 | Found in the ROM | None in ROM | [Firmware 1.5 and 2.0](../firmware-fixes.md#e10-settextfont-is-missing) |
| [E11](#e11-super-hi-res-color-fill-mode-is-ignored) | Super Hi-Res color fill mode is ignored | ROM 1.4 | Reported 1996 (owner); cause found in the ROM | Program expands the fill | [Firmware 1.5 and 2.0](../firmware-fixes.md#e11-super-hi-res-color-fill-mode-is-ignored) |
| [E12](#e12-palettes-rewritten-during-each-frame-show-wrong-colors) | Palettes rewritten during each frame (3200-color pictures) show wrong colors | ROM 1.4 | Reported 1995 ([manual](../sources.md#s16)) and 1996 (owners); cause found in the ROM | Show the picture in a 15-bit mode | None in firmware |
| [E13](#e13-fast-animation-is-choppy) | Fast animation is choppy | ROM 1.4 | Reported 1996-1998 (owners); speed calculated from the ROM | None; changing less screen per frame helps | Partly: faster in [firmware 1.5 and 2.0](../firmware-fixes.md#e13-fast-animation-is-choppy), never 60 frames/s |
| [E14](#e14-direct-e1-writes-with-ramwrt-on-are-not-copied-above-6000) | Direct $E1 writes with RAMWRT on are not copied above $6000 (the game Rastan) | Card logic | Found in the U7 logic; matches an owner's report on the game Rastan | Change the game's code | [U7 v2.0](../lattice-versions.md) |
| [E15](#e15-the-iigs-border-color-does-not-show) | The IIgs border color ($C034) never shows on the card | Card logic | Found in the U7 logic | SetBorder after each mode change | [U7 v2.0](../lattice-versions.md) with [firmware 2.0](../firmware-fixes.md#e15-the-iigs-border-color-does-not-show) (Super Hi-Res: nearest color) |
| [E16](#e16-library-mode-files-run-at-the-wrong-clock) | Several library mode files run at a different clock than their names | Library mode files with ROM 1.4 | Found in the mode files and the ROM; rests on [databook p35](../sources.md#s02) | Fix the record | [Firmware 1.5 and 2.0](../firmware-fixes.md#e16-library-mode-files-run-at-the-wrong-clock) |
| [E17](#e17-the-true-color-mode-file-shows-palette-colors) | The true-color mode file leaves the color chip in palette mode | Library file `M640X48016M` | Found in the mode file | Register fix | [Firmware 1.5 and 2.0](../firmware-fixes.md#e17-the-true-color-mode-file-shows-palette-colors) |
| [E18](#e18-old-library-upload-and-status-bugs) | Old library: one-byte upload remainder, status copy | Library before 8/1995 | Reported 1995 (Sequential's library notes) | Use the 8/1996 library | No |
| [E19](#e19-uploads-of-whole-64-kb-blocks-hang-older-programs) | An upload that is a whole number of 64 KB blocks hangs the program | Library before 8/1996 (SecondView 1.0a6, GView 0.25c, GS FlicSS 0.7) | Fixed in Sequential's 1996 library; found in the programs' code | Use the 8/1996 library | Partly: [firmware 1.5 and 2.0](../firmware-fixes.md#e19-uploads-of-whole-64-kb-blocks-hang-older-programs) |
| [E20](#e20-uploads-above-512-kb-crashed-the-card) | Uploads above 512 KB crashed the card | Firmware of June 1995 | Reported 1995 ([SecondView release notes](../sources.md#s06)) | Fixed in ROM 1.4 | Not needed |
| [E21](#e21-faults-fixed-in-v11) | Several mode and palette faults | Firmware before v1.1 | Reported 1995 (Sequential's [v1.1 notes](../sources.md#s06)) | Fixed in v1.1 | Not needed |
| [E22](#e22-gview-025c-leaves-out-the-rightmost-pixel-column) | GView 0.25c leaves out the rightmost pixel column | GView 0.25c | Found in the program's code | None | No |
| [E23](#e23-secondview-10a6-zeroes-the-first-pixel-of-rows-2-4-6-in-interlaced-gifs) | SecondView 1.0a6 zeroes the first pixel of rows 2, 4, 6 in interlaced GIFs | SecondView 1.0a6 | Found in the program's code and its source | Use non-interlaced GIFs | No |
| [E24](#e24-the-card-can-hang-at-power-up-or-after-a-reset) | The card can hang at power-up or after a reset (VGA monitors) | Early boards, 1995 | Reported 1995 ([manual](../sources.md#s16)); cause from the RDY wiring; the cause is not certain | Press reset again | No |
| [E25](#e25-very-large-pictures-may-hang-the-card) | Pictures of 1024 x 1024 and larger may hang the card | GView 0.25c, 1996 | Reported 1996 ([GView README](../sources.md#s04)); cause found in GView's code (E19); the cause is not certain | Same as E19 | Partly: [firmware 1.5 and 2.0](../firmware-fixes.md#e25-very-large-pictures-may-hang-the-card) |
| [E26](#e26-flashing-text-ignores-the-c022-colors) | Flashing text: white and blue in 40 columns whatever $C022 says; no flashing in 80 columns | ROM 1.4 | Found in the ROM | Avoid flashing text | [Firmware 1.5 and 2.0](../firmware-fixes.md#e26-flashing-text-ignores-the-c022-colors) |
| [E27](#e27-four-language-characters-sit-one-row-low-in-the-8x16-font) | Characters $9B-$9E of the 8x16 font sit one dot row low; the sharp s loses a row, the Swedish A ring gets a stray dot | ROM 1.4, VGA monitor | Found in the ROM and its font file | None | [Firmware 1.5 and 2.0](../firmware-fixes.md#e27-four-language-characters-sit-one-row-low-in-the-8x16-font) |
| [E28](#e28-with-80store-on-u7-picks-the-copys-bank-without-looking-at-the-address) | With 80STORE on, writes outside the 80STORE pages are copied to the wrong bank; one case overwrites the firmware | Card logic | Found in the U7 logic | Turn 80STORE off while writing outside text page 1 and hires page 1 | [U7 v2.0](../lattice-versions.md) |
| [E29](#e29-apple-display-switches-reset-a-native-vga-mode) | With Apple emulation off, an Apple display switch makes the card program the SetMode mode again: SetVGAReg changes are lost, ScreenOff is undone, $A5 appears at $C0B8 unasked | ROM 1.4 | Found in the ROM | Send SetVGAReg changes and ScreenOff again after the IIgs changes its display mode | [Firmware 1.5 and 2.0](../firmware-fixes.md#e29-apple-display-switches-reset-a-native-vga-mode) |

## ROM 1.4 faults

### E1. Mode $13 shows a broken picture

- **Symptom:** a 320 x 200 x 256 picture does not display correctly. [GView 0.25c's README](../sources.md#s04)
  (February 1996) lists "320x200x256 does not work" under Known Errors.
- **Cause:** the ROM's mode $13 table combines Oak packed-pixel mode with IBM's standard
  mode 13h addressing; [Oak's own BIOS](../sources.md#s58) never does. Packed mode addresses
  video memory a byte at a time and ignores the doubleword and word shifts, so the line
  pitch becomes 640 bytes: the card shows every other picture line in the top half of the
  screen and leaves the bottom half blank.
  Details: [Mode $13 addressing and display](../08-firmware.md#mode-13-packed-pixel-note).
- **Also:** on the AppleColor RGB monitor the ROM refuses mode $13 and keeps the previous
  mode.
- **Workaround used at the time:** show 8-bit pictures in mode $53 (640 x 480) or $61
  (640 x 400, the only 256-color mode on the RGB monitor), doubling each pixel in software.
  GView did this. Source: [GView README](../sources.md#s04).
- **Register fix:** after SetMode $13, send SetVGAReg with index port $03DE,
  index $21, data port $03DF, value $00. That gives exactly Oak's own mode 13h, which
  displays correctly on any OTI-087. Source: [Oak BIOS](../sources.md#s58).
- The picture must then be written the standard VGA way, through Oak's $A0000 window:
  linear window off ($AA), half switch 1 (any access to $5xxxx), Z180 physical
  $A0000-$AFFFF ([Video window](../06-video.md#the-video-ram-window)). Do it with Z180
  code loaded with UploadData and started with
  RunCode ([Loading Z180 code](../09-host-protocol.md#loading-z180-code)); UploadData
  cannot do it, because it always writes through the linear window. In standard mode
  13h the two low address bits pick the plane, and the display reads each plane at every
  fourth location. Source: [IBM VGA Technical Reference](../sources.md#s68) p2-54 and p2-75.
- **Fix:** [firmware 1.5 and 2.0](../firmware-fixes.md#e1-mode-13-shows-a-broken-picture).

### E2. Double hires hangs

- **Symptom:** entering double hires (80-column, hires and $C05E on) hangs the card's
  processor; the VGA picture shows garbage and stops updating. Owners reported the freeze
  in December 1995. Source: [GenieLamp, December 1995](../sources.md#s70).
- **Cause:** the renderer's scan routines sit at the same logical addresses ($9000 up)
  that its memory layout gives to the lookup tables, so the Z180 executes table data.
  [Double hires setup defect](../08-firmware.md#double-hires-setup-defect).
- **Workaround:** none.
- **Fix:** [firmware 1.5 and 2.0](../firmware-fixes.md#e2-double-hires-hangs).

### E3. Super Hi-Res lines 102-127 use the wrong palette

- **Symptom:** in Super Hi-Res, lines 102-127 take their scan-line control byte (and so
  their palette and 320/640 setting) from the line below. Visible only when neighboring
  lines differ, as in Doom.
- **Cause:** one wrong pointer byte. [Super Hi-Res band pointer](../08-firmware.md#super-hi-res-band-pointer).
- **Workaround:** write $7E to SRAM $0AB13 (it holds $7F). Every Super
  Hi-Res entry copies SRAM $0A000-$0BFFF to $1A000 and runs from there, so the fix
  persists until reset. If Super Hi-Res is already on, also write $7E to $1AB13.
- Or, on a card with ROM 1.4, a program writes the correct byte into card SRAM before it
  starts: UploadData with flag 1, destination $10AB13 and the two bytes $7E $9D (the second
  byte rewrites the $9D already at $AB14); it lasts until the next reset. Other
  [SRAM write methods](../14-custom-code.md#writing-card-sram-from-the-iigs).
- [SecondSight.Card.INFO.txt](../sources.md#s41) (1998) names "SSRomFix", a GS/OS startup file that "fixes a bug in SS ROM".
  A startup file can only change card SRAM until the next reset, and this band pointer is
  the known ROM fault such a change fixes completely ([Other ROM revisions](../08-firmware.md#other-rom-revisions)).
- **Fix:** [firmware 1.5 and 2.0](../firmware-fixes.md#e3-super-hi-res-lines-102-127-use-the-wrong-palette).

### E4. UploadData cannot load Z180 code as documented

- **Symptom:** an upload with flag 0 ("Z180 memory") always lands in the first 64 KB of
  video memory (bank $08), whatever destination bank is given.
- **Cause:** the flag-0 path adds 8 to the flag byte instead of the bank.
  [Known defects](../08-firmware.md#known-defects-and-oddities).
- **Workaround:** use flag 1 with destination bank $10-$13. Banks of 8 and up
  are used as they are, and the DMA address register keeps only 20 bits, so bank $10
  lands in SRAM $0xxxx and $11 in $1xxxx.
  Details: [Loading Z180 code](../09-host-protocol.md#loading-z180-code).
- **Sequential's own example fails on ROM 1.4:** [`SECOND/MISC/UP.C`](../sources.md#s06) on `ss.source.082395.po`
  loads `SAMPLE1.BIN` with `_UploadData(FL_CODE, 0x002000, ...)` (`FL_CODE` = 0 in [VGA.H](../sources.md#s30))
  and starts it with RunCode at $2000. With ROM 1.4 the code lands in video memory, and
  RunCode runs whatever SRAM $2000 holds. The disk dates from August 1995, before ROM 1.4
  shipped. Source: UP.C, VGA.H, SAMPLE1.LST.
- **Fix:** [firmware 1.5 and 2.0](../firmware-fixes.md#e4-uploaddata-cannot-load-z180-code-as-documented).

### E5. RunCode never reports completion

- **Symptom:** Sequential's `_RunCode` waits forever.
- **Cause:** the ROM's `run_code` never writes $A5 to port $A0 after the called code
  returns, but the library waits for $A5 or $A6. Source: [VGALOW.ASM](../sources.md#s29).
- **Workaround:** end your Z180 code with `ld a,$A5` / `out0 ($A0),a` before `ret`. When calling
  a ROM routine that does not do this, do not wait for $A5.
- **Fix:** [firmware 1.5 and 2.0](../firmware-fixes.md#e5-runcode-never-reports-completion).

### E6. Mixed-hires text ignores the $C022 colors

- **Symptom:** the four text lines under a hires picture are white on black on the card,
  whatever $C022 says, while the card's text and lores modes use the $C022 colors.
  The IIgs shows them in the $C022 colors. Source: [Apple IIgs Hardware Reference](../sources.md#s78), Screen Color register.
- **Cause:** [Mixed-mode text colors](../08-firmware.md#mixed-mode-text-colors).
- **Workaround:** none through the host commands.
- **Fix:** [firmware 1.5 and 2.0](../firmware-fixes.md#e6-mixed-hires-text-ignores-the-c022-colors).

### E7. Double lores is not implemented

- **Symptom:** double lores shows as single lores.
- **Workaround:** only a custom renderer uploaded to the card
  ([Beyond the firmware](../14-custom-code.md)).
- **Fix:** [firmware 1.5 and 2.0](../firmware-fixes.md#e7-double-lores-is-not-implemented).

### E8. ScrollScreen past 512 KB overwrites card memory

- **Symptom:** the part of a ScrollScreen range at video address $80000 (512 KB) or
  above lands in the card's own address space instead of video memory: video
  $80000-$BFFFF on card SRAM (both copies of it), $C0000-$DFFFF on the half-switch
  addresses, $E0000-$FFFFF on the EPROM.
  - A **destination** there overwrites the running firmware in SRAM, and the card
    crashes: the host waits for $A5 forever. Over the half-switch addresses each write
    selects a video half, which moves where the rest of the copy lands; over the EPROM
    the writes change nothing.
  - A **source** there copies SRAM or EPROM bytes into the picture instead of video data.
  ClearScreen fills anywhere in the 1 MB, but in a fill that does not start on a 64 KB
  boundary, the 64 KB block that crosses $80000 or $100000 runs on into SRAM from
  $00000 and crashes the card the same way.
- **Cause:** both commands move data with Z180 DMA through the linear video window,
  where Z180 physical address = $80000 + video address. The DMA bank registers hold
  only four bits, so a bank of 16 or more wraps to Z180 physical $00000-$7FFFF: card
  SRAM ($00000-$1FFFF, where the running firmware lives, and its alias up to $3FFFF),
  the half-switch addresses ($40000-$5FFFF) or the EPROM ($60000-$7FFFF).
  - `scroll_screen` selects the low half once and adds 8 to both bank bytes in both copy
    directions. Any byte at video $80000 or above therefore wraps.
  - ClearScreen's `fill_video_mem_block` decides per 64 KB block: a block that starts at
    bank 8 or above selects the upper half and keeps its bank, so it lands correctly. One
    DMA still runs straight across $FFFFF, so a block that starts in bank 7 or bank 15 at
    a nonzero offset wraps.
  Source: [ROM_BEEF.asm:1918-2211](../sources.md#s27) (`scroll_screen`), 2214 onward (`clear_screen`,
  `fill_video_mem_block`).
- **Workaround:** keep ScrollScreen source and destination ranges below $80000, and start
  each ClearScreen on a 64 KB boundary or keep it inside one 64 KB block. For copies in
  the upper half, use custom Z180 code with the $4xxxx/$5xxxx half switch
  ([Video RAM window](../06-video.md#the-video-ram-window)).
- GS FlicSS 0.7 hits this: it scrolls 256,000 bytes from 0 to $04B000, which ends at
  $089800.
- **Fix:** [firmware 1.5 and 2.0](../firmware-fixes.md#e8-scrollscreen-past-512-kb-overwrites-card-memory).

### E9. ScrollScreen toward a higher address copies the wrong bytes

- **Symptom:** a ScrollScreen whose destination lies above its source often does not copy
  the requested range. Depending on the address bytes (see the cause), the copy is right,
  or lands one byte off, or repeats data:
  - **One byte off:** the first destination byte keeps its old value, and the byte just
    past the end of the destination receives the byte just past the end of the source.
  - **Repeated data:** when the two ranges overlap, the start of the source repeats
    through the rest of the destination.
  Copies toward a lower address are always right.
- **Cause:** `scroll_screen` first picks a copy direction, then sets up one Z180 DMA
  transfer per 64 KB. Two steps are wrong:
  1. **The direction test** compares the destination with the source one byte at a time,
     bank byte first ($1403). If any destination byte is smaller than the source's byte in
     the same place, the ROM copies upward (increment); only when no destination byte is
     smaller does it copy downward (decrement). Example: source $0010F0, destination
     $001110, 32 bytes higher. The low byte $10 is smaller than $F0, so the ROM copies
     upward. With a length over 32 bytes the upward copy reads source bytes it has already
     overwritten, so the first 32 bytes repeat through the destination.
  2. **The downward copy** must start at the last byte of each range, start + length - 1.
     The ROM adds the length to both addresses ($1424 and $143C) without subtracting one,
     so the DMA copies source + length down to source + 1 into destination + length down
     to destination + 1.
  Source: [ROM_BEEF.asm:1918-2084](../sources.md#s27) (`scroll_screen`,
  `copy_memory_block_decrement`).
- **Workaround:** make the ROM copy upward, which copies exactly the requested
  range. Send the source bank byte with its top four bits set ($F0 plus the bank). The
  DMA uses only the low four bits of a bank, so the copy still reads the right place, but
  the direction test always finds the destination bank smaller. An upward copy is
  correct whenever the ranges do not overlap. Move an overlapping range toward a higher
  address in pieces no longer than the distance between source and destination, the last
  piece first.
- **Fix:** [firmware 1.5 and 2.0](../firmware-fixes.md#e9-scrollscreen-toward-a-higher-address-copies-the-wrong-bytes).

### E10. SetTextFont is missing

- Sequential's [firmware documentation](../sources.md#s15) documents command $0F, SetTextFont; ROM 1.4 ignores
  commands $0F and above.
- **Workaround:** none in ROM 1.4.
- **Fix:** [firmware 1.5 and 2.0](../firmware-fixes.md#e10-settextfont-is-missing).

### E11. Super Hi-Res color fill mode is ignored

- **Symptom:** on a 320-pixel line whose scan-line control byte has bit 5 set, the IIgs
  shows each pixel of value 0 in the color of the pixel before it. The card shows those
  pixels in color 0 of the line's palette. Source: [Apple IIgs Hardware Reference](../sources.md#s78), "Color Fill mode". A 1996 owner report agrees: the card "doesn't support fill mode".
  Source: [comp.sys.apple2, June 1996](../sources.md#s72).
- **Cause:** the renderer reads only bits 7 and 3-0 of each control byte:
  [Super Hi-Res](../08-firmware.md#super-hi-res).
- **Workaround:** the program draws the filled pixels itself and leaves bit 5 clear.
  Through the host commands, a program can upload the expanded line to an 8-bit mode.
- **Fix:** [firmware 1.5 and 2.0](../firmware-fixes.md#e11-super-hi-res-color-fill-mode-is-ignored).

### E12. Palettes rewritten during each frame show wrong colors

- **Symptom:** a "3200-color" picture has its own 16-color palette for each of its 200
  lines. The program that shows it watches the IIgs video counters and rewrites the
  palettes for lines still to come while the IIgs draws an earlier line, on every line
  of every frame. Source: [Apple File Type Note $C1/$0002](../sources.md#s82). The card
  shows each palette with whatever value it holds when the renderer samples it, so most
  lines get another line's colors.
  Sequential's June 1995 manual already lists "3200-mode" as
  incompatible, because the card cannot keep pace with its palette updates. Source: [manual](../sources.md#s16) p25. Owners reported it in 1996: the card "doesn't support 3200
  mode because it doesn't support scan-line interrupts". Source: [comp.sys.apple2, June 1996](../sources.md#s72).
- **Cause:** the card's VGA display runs on its own timing, not the IIgs beam, and the
  renderer compares palette memory only between its own passes:
  [Super Hi-Res](../08-firmware.md#super-hi-res).
- **Workaround:** show the picture in one of the card's own 15-bit modes instead of
  Super Hi-Res: convert it to 15-bit color and upload it. SecondView 1.0a5 (July 1995)
  showed 3200-color pictures this way, in the 15/16-bit modes.
  Source: [SecondView release notes](../sources.md#s06).
- **Fix:** none in firmware. Nothing on the card follows the IIgs beam: palette writes
  reach the Z180 only as copies into SRAM, with no event and no line number, so firmware
  could only guess which line each version of a palette was for. A viewer rewrites a
  32-byte palette for each of the 200 lines, 60 times a second: 384,000 copies a second,
  which at about 8 clocks each already take about a sixth of the Z180's time
  ([copy speed](../05-z180.md#a-functional-timing-estimate)); reading all 512
  palette bytes every millisecond on top of that leaves no time to draw. U7 cannot help:
  an event for each palette write would hold the IIgs on RDY and break the viewer's timing.

### E13. Fast animation is choppy

- **Symptom:** owners reported that animation in games and demos is "extremely choppy
  and appears to skip frames" (the Ninjaforce MegaDemo especially); another wrote that
  games running at 20 frames per second or slower look right. Sources: [secondsight.rgb](../sources.md#s73); [comp.sys.apple2, June 1996](../sources.md#s72).
- **Cause:** ROM 1.4's Super Hi-Res redraw of the whole screen takes at least 92 ms, more
  than five IIgs frames, and at most one changed 4 KB band (about 25 lines) fits in one
  frame: [redraw speed](../08-firmware.md#super-hi-res). Source: [Zilog UM0050](../sources.md#s39).
- **Workaround:** none for existing programs. A program that changes less screen memory
  per frame gives the card less to redraw.
- **Fix:** faster in [firmware 1.5 and 2.0](../firmware-fixes.md#e13-fast-animation-is-choppy), but never 60 new full screens a second.
- **Palette writes also redraw lines 179-199.** The $9000 band flag sets on any copied
  write to $9000-$9FFF, which includes the control bytes and palettes at $9D00-$9FFF
  (`DIRTY_9000 = AA12 & WRITE_8000_9FFF`, [Lattice design source](lattice-source.md)). The
  renderer already compares control bytes and palettes on its own every pass, so a
  program that only changes palettes, such as one cycling colors, costs a needless
  redraw of the 3,328-byte band on every pass: about 9.6 ms with ROM 1.4, 7.1 ms with the
  new renderer.
  - [U7 v2.0](../lattice-versions.md) leaves this flag as the factory chip has it: the
    saving is a few milliseconds a pass, and only for programs that change palettes
    without drawing.
- The same owner's report of a blank background in the game Rastan is [E14](#e14-direct-e1-writes-with-ramwrt-on-are-not-copied-above-6000).

### E26. Flashing text ignores the $C022 colors

- **Symptom:** on the IIgs a flashing character alternates between normal and inverse
  in the text and background colors of $C022. On the card:
  - **40 columns:** flashing characters alternate between white on blue and blue on
    white, whatever $C022 says. Before the first swap after a mode change, and after each
    $C022 change, they show briefly as inverse characters in the $C022 colors.
  - **80 columns:** flashing characters do not flash. They show as inverse characters in
    the $C022 colors (when $C022 is $00 they alternate white on blue and blue on white).
  - Lores mixed mode's text lines flash white and blue as in 40 columns.
- **Cause:** flashing characters (screen codes $40-$7F of the normal set) draw their
  glyph in DAC entry 3 on entry 2. `set_textmode_palette` loads entries 2 and 3 with the
  $C022 text and background colors. Every sixth pass (fourth in lores)
  `setup_textmode_palette` swaps a stored pair and writes it to entries 2 and 3, but that
  pair (`background_r` to `foreground_b`, $9484-$9489) is never loaded from $C022: it
  starts as blue ($00 $00 $D0) and white and only ever swaps. In 80 columns
  `emulate_text80` also clears `text80_palette_colour` after every pass ($91FF), so the
  next pass reloads entries 2 and 3 from $C022 straight after the swap.
  Source: [firmware/src/text.asm](../../firmware/src/text.asm) (`emulate_text80`,
  `setup_textmode_palette`, the flashing pair), [firmware/src/textsetup.asm](../../firmware/src/textsetup.asm)
  (`set_textmode_palette`), [firmware/src/lores.asm](../../firmware/src/lores.asm) (`get_text_colour`, attribute $23).
- **Workaround:** show inverse text instead of flashing text.
- **Workaround, 40 columns:** load the pair with the $C022 colors. UploadData
  flag 1, destination $109484, 6 bytes: the background color's red, green and blue, then
  the text color's, as 8-bit DAC values (the 16 IIgs colors are `apple_colour_table` in
  [firmware/src/textsetup.asm](../../firmware/src/textsetup.asm)). Send it again after
  each $C022 change. The card then alternates normal and inverse in those colors.
- **Workaround, 80 columns:** none.
- **Fix:** [firmware 1.5 and 2.0](../firmware-fixes.md#e26-flashing-text-ignores-the-c022-colors).

### E27. Four language characters sit one row low in the 8x16 font

- **Symptom:** on a VGA monitor (the 8x16 font) the characters at VGA codes $9B-$9E,
  which the IIgs language setting shows for German } (u diaeresis) and ~ (sharp s) and
  Swedish ] (A ring) and } (a ring), sit one dot row lower than the rest. The sharp s
  loses the bottom row of its tail, and the A ring gets that row as a dot at its top
  left. The 8x8 font (AppleColor RGB) is right.
- **Cause:** the 8x16 language glyphs at $8694 are `FONT.TAB` from
  `ss.source.082395.po` (`SECOND/FIRM`, [firmware/original/FONT.TAB](../../firmware/original/FONT.TAB)),
  compiled as it is, and that file draws character $9A with 17 rows. The table is
  therefore 481 bytes, but `copy_font` copies 30 glyphs of 16 bytes from its start, so
  each of $9B-$9E starts one byte early: its first row is the previous glyph's last row
  and its own last row is not copied. Source: [firmware/src/fonts.asm](../../firmware/src/fonts.asm)
  (`hex81`), [firmware/src/textsetup.asm](../../firmware/src/textsetup.asm) (`copy_font`).
- **Workaround:** none.
- **Fix:** [firmware 1.5 and 2.0](../firmware-fixes.md#e27-four-language-characters-sit-one-row-low-in-the-8x16-font).

### E29. Apple display switches reset a native VGA mode

- **Symptom:** with Apple emulation off (SetMode flag 1), each time the IIgs changes TEXT,
  HIRES, 80VID, AN3 or the Super Hi-Res bit of NEWVIDEO, the card programs the SetMode mode
  again from its record:
  - registers changed since with SetVGAReg, such as a CRTC start address used to flip
    pages, go back to the record's values;
  - a ScreenOff is undone;
  - $A5, SetMode's completion byte, goes to the handshake latch at $C0B8 unasked.
- **Cause:** the event handlers for those switches request a mode change without looking
  at the emulation flag. With emulation off, the main loop answers every mode change with
  `set_native_mode`, SetMode's own set-up. Source: [ROM_BEEF.asm](../sources.md#s27)
  `get_emulation_routine`, `set_native_mode`, the softswitch handlers.
- **Workaround:** after the IIgs changes its display mode, send the SetVGAReg changes and
  ScreenOff again.
- **Fix:** [firmware 1.5 and 2.0](../firmware-fixes.md#e29-apple-display-switches-reset-a-native-vga-mode).

## Card logic faults

### E14. Direct $E1 writes with RAMWRT on are not copied above $6000

- **Two ways to write the screen:** RAMWRT is the Apple II switch at $C005 (off at $C004)
  that sends writes aimed at bank $00 to auxiliary memory (bank $01, shadowed to $E1). A
  program can write the Super Hi-Res screen that way, or *directly*, with an address that
  names bank $E1 (or $01 with shadowing) itself, such as `STA $E19E20`.
- **Symptom:** direct writes made while RAMWRT happens to be on are lost above $6000 on the
  card: the upper Super Hi-Res screen, its scan-line control bytes ($9D00) and its palettes
  ($9E00). Direct writes below $6000 land in the wrong SRAM bank.
- **Cause:** the slot's bank signal M2B0 shows the bank in the address but not RAMWRT
  ([Apple TN #68](../sources.md#s43)). The card copies $6000-$9FFF only when B xor RAMWRT is 1. A redirected
  write has B = 0 and RAMWRT = 1, so it is copied, to auxiliary memory. A direct write
  with RAMWRT on has B = 1 and RAMWRT = 1, so B xor RAMWRT is 0, the same value as for a
  main-memory write, and the card drops it; below $6000 its bank equation also files it
  in bank 0 ([Bank tracking](../04-capture-logic.md#bank-tracking)).
- **The logic is exact:** Lattice's pDS 2.61 builds the recovered source, copy rule
  (CAPTURE) and bank equation (CATCH_BANK) included, into BE8C with every fuse equal
  ([how this was checked](../04-capture-logic.md#how-this-was-checked)).
- **Rastan hits it:** Rastan is the IIgs version of Taito's 1987 arcade game, a
  side-scrolling sword fighter. It runs with $C068 = $3C (RAMRD and RAMWRT on). Its screen
  pixels go through bank $00 and are copied, but it stores its scan-line control bytes and
  palettes straight to $E1/$01 (`STA $019D18,X` at $02:153C, `STA $019D00,X` at $02:2939,
  an `MVN` into $E1:9E20-$9E3F at $02:20FF). On the card those stay stale, so the
  background shows black or in the title screen's colors, matching the owner's report of
  a blank background. Found in the game's code.
  Source: [secondsight.rgb](../sources.md#s73).
- **Rastan's code is correct IIgs code, not a game bug.** RAMWRT redirects only writes
  aimed at bank $00, so on a IIgs a long store to $01 or $E1 always lands there. The game
  turns RAMRD and RAMWRT on so that its bank $00 direct-page and stack writes land in
  bank $01, the Super Hi-Res buffer: `PEI` copies into a relocated stack ($03:69F1),
  `PHA` tile copies ($03:E79D) and direct-page shifts. That is the fastest way to draw a
  IIgs screen. Only the card's B xor RAMWRT rule treats the long stores differently.
- **Changing the game, any site:** turn RAMWRT off around each direct write: `STA $C004` before,
  `STA $C005` after, through a `JSL` to a small routine where there is no room in place.
  With RAMWRT off, B xor RAMWRT is 1 and the card copies the write to auxiliary memory;
  the IIgs result is unchanged.
- **Changing the game, where Super Hi-Res shadowing is on:** change the bank byte of the long
  store from $01 to $00, for example `STA $019D18,X` (`9F 18 9D 01`) to `STA $009D18,X`
  (`9F 18 9D 00`). With RAMWRT on, the IIgs still puts the byte in $01:9D18 and shadows
  it to $E1, and the card sees a redirected write and copies it. This does not apply
  to a site that writes $E1 while shadowing is off, such as Rastan's `MVN` into $E1:
  check $C035 bit 3 at each site, or turn RAMWRT off as above.
- **The right rule:** B = 1 always means the auxiliary bank, so the rule should be B or
  RAMWRT, and CATCH_BANK's first term needs no !RAMWRT. An emulator or a replica can offer
  that as an option, with the original behavior as the default.
- A new program avoids the fault by clearing RAMWRT before writing $E1 directly.
- **Fix:** [U7 v2.0](../lattice-versions.md#what-v20-changes) decides "B or RAMWRT", so those
  writes are copied into SRAM bank 1 like any other screen write. Firmware cannot fix it:
  it can work out the mode, but the bytes it would need never reach the card:
  - It knows Super Hi-Res is on, because the $C029 write raises an event.
  - It can guess that RAMWRT is on. In Super Hi-Res, copies that land in SRAM bank 0 at
    $2000-$5FFF are usually direct $E1 writes made with RAMWRT on, and firmware could move
    them to bank 1. It stays a guess: RAMWRT raises no event and has no readback port
    ([State observable by Z180 software](z180-io-ports.md#state-observable-by-z180-software)),
    and a program that writes main memory $2000-$5FFF with hires shadowing on makes the
    same copies.
  - Writes to $6000-$9FFF are dropped before any copy: no band flag, no event, and U2
    does not latch the data byte ([Copying video writes](../04-capture-logic.md#copying-video-writes)).
    That range holds the upper screen, the scan-line control bytes and the palettes,
    which is everything Rastan loses. Knowing the mode gives the firmware no colors to show.
  - The Z180 cannot read Apple memory, so it cannot fetch the missing bytes either.

### E15. The IIgs border color does not show

- **Symptom:** the card's border never follows the IIgs border color, which the IIgs sets
  with bits 3-0 of $C034 (the Control Panel's border setting, or a program). The card's
  border is the color each mode record picks: palette entry $10 in most text modes,
  entry 0 in the graphics modes ([Border color](../08-firmware.md#border-color)).
- **Cause:** a $C034 write reaches the slot like every access to the IIgs's internal I/O
  (/M2SEL is low; [TN #68](../sources.md#s43)), with the new value on the slot's data bus.
  The card learns such a value only when U7 treats the access as an event: U7 then
  latches the byte into U2 and interrupts the Z180, which reads it from port $A0. U7's
  event decode does not include $C034, so the byte is never latched and the Z180 never
  learns the value. Lattice's pDS 2.61 builds the recovered source, every `EVENT_DECODE`
  term included, into BE8C with every fuse equal. Sources:
  `EVENT_DECODE` in the [design source](../../data/lattice/SecondSight_U7.ldf) (block B7);
  [event addresses](z180-io-ports.md#apple-event-addresses).
- **Workaround:** SetBorder ($08) after every change of display mode, with a palette index
  whose color matches the IIgs border. A CDA of the time did this ([GEnie message](../sources.md#s74)).
- **Fix:** [U7 v2.0](../lattice-versions.md) together with [firmware 2.0](../firmware-versions.md).
  U7 v2.0 makes a $C034 write an event: it latches the byte the IIgs writes into U2 and
  interrupts the Z180, as for $C022. Firmware 2.0 reads that byte from port $A0 and shows
  bits 3-0 as the border: [the change](../firmware-fixes.md#e15-the-iigs-border-color-does-not-show).

### E28. With 80STORE on, U7 picks the copy's bank without looking at the address

- **The Apple's rule:** RAMWRT picks main or auxiliary memory for writes to $0200-$BFFF.
  With 80STORE on, PAGE2 picks it instead for text page 1 ($0400-$07FF), and also for
  hires page 1 ($2000-$3FFF) when HIRES is on. Source: [Apple IIgs Hardware Reference](../sources.md#s78)
  p44, Table 3-3. The IIe follows the same rule.
- **Cause:** U7's bank equation (`BANK_Q`, [Bank tracking](../04-capture-logic.md#bank-tracking))
  has no address terms. While 80STORE is on it applies PAGE2 to every copied address, and
  in IIgs mode it applies RAMWRT whenever HIRES is off, text page 1 included.
- **Symptom:** in these cases the card copies the write into the other SRAM bank, so its
  copy of that page holds wrong bytes until the program writes them again. These follow
  from `BANK_Q` in the [design source](../../data/lattice/SecondSight_U7.ldf), which
  pDS 2.61 builds into BE8C with every fuse equal:
  - 80STORE and PAGE2 on, a main-memory write to text page 2, hires page 2, or hires
    page 1 with HIRES off: copied to auxiliary.
  - 80STORE on, PAGE2 off, RAMWRT on, an auxiliary write outside the 80STORE pages (hires
    page 2 with HIRES on, or $2000-$3FFF with HIRES off on a IIe): copied to main.
  - IIgs mode, 80STORE on, HIRES and PAGE2 off, RAMWRT on: a main-memory write to text
    page 1 is copied to auxiliary.
- **One case stops the card.** In IIgs mode with 80STORE and HIRES on, PAGE2 off and
  RAMWRT on, a bank $00 write to $6000-$9FFF goes to auxiliary memory on the IIgs (and to
  the Super Hi-Res screen when shadowing is on). The card copies it into SRAM bank 0 over
  its own code at $6000-$9FFF.
- **Workaround:** a program can turn 80STORE off while it writes outside text page 1 and
  hires page 1.
- **Fix:** [U7 v2.0](../lattice-versions.md). Its bank equation follows the Apple's rule:
  with 80STORE on, PAGE2 picks the bank for text page 1, and for hires page 1 while HIRES
  is on; RAMWRT picks it for every other address
  ([the change](../12-lattice-fix.md#what-the-corrected-map-changes)).

## Library and mode-file faults

### E16. Library mode files run at the wrong clock

- Several mode files set Oak ext $06 and the misc output byte to different clocks. ROM
  1.4 writes the misc byte last, so the misc byte decides, and the mode runs at a clock
  other than its name. List: [Library mode files](../06-video.md#library-mode-files).
- **Workaround:** edit the record so both name the intended clock before sending SetUserMode.
- **Fix:** [firmware 1.5 and 2.0](../firmware-fixes.md#e16-library-mode-files-run-at-the-wrong-clock).

### E17. The true-color mode file shows palette colors

- `M640X48016M` sets true-color timing but leaves the Bt481 in 8-bit palette mode.
- **Workaround:** set Bt481 Command Register A to $F0 and CRTC $01 to $4F
  ([24-bit mode width](../14-custom-code.md#24-bit-mode-width)).
- From the IIgs, with GetVGAReg and SetVGAReg (use $03CE, the graphics-controller index,
  as the harmless index port): read $03C7 once, read $03C6 four times, then write $F0 to
  $03C6, which reaches Command Register A. For CRTC $01, clear CRTC $11 bit 7 first
  (on any VGA it write-protects CRTC $00-$07), write $01 = $4F, then restore $11.
  Sources: [Bt481A datasheet](../sources.md#s36); [ROM_BEEF.asm:1018-1033](../sources.md#s27).
- **Fix:** [firmware 1.5 and 2.0](../firmware-fixes.md#e17-the-true-color-mode-file-shows-palette-colors).

### E18. Old library upload and status bugs

- Library notes record: `_UploadData` sent a whole 64 KB chunk when one byte was left
  (fixed 8/16/95); a bad memcpy trashed the library's status copy (fixed 7/10/95);
  later fixes to `_GetVGAReg` and `_UploadData`.
- **Workaround:** link with the library from `sslib082696.po` (August 1996).
- **Fix:** none in firmware. Both faults are in the IIgs library, which writes to Apple
  memory that the card cannot reach. The August 1996 library is the fix.

### E19. Uploads of whole 64 KB blocks hang older programs

- **Symptom:** the IIgs program hangs after an upload whose length is an exact multiple of
  64 KB (for example 512 KB). The card itself finishes the upload correctly.
- **Cause:** the older `_UploadData` waits for the card's "ready" handshake for a
  remainder phase before checking whether any remainder is left. ROM 1.4 sends no
  remainder phase when the remainder is zero, so the program waits forever. The August
  1996 library checks first ([`VGALOW.ASM`](../sources.md#s29) line 576, "catch lengths of 0"; NOTES 8/26/96).
- **Programs with the old routine:** SecondView 1.0a6, GView 0.25c and GS FlicSS 0.7. In each, the bank
  loop's closing branch (`C6 01 D0 E7`, decrement the bank count and loop) is followed
  directly by `JSR WaitHSOn`, with no length test: SSVIEW (`ss.source.082395.po`,
  [`SECOND/SVIEW/SSVIEW`](../sources.md#s06)) at file offset $CB39, GVIEW (`gview.025c.po`) at $915F,
  and the [GS FlicSS](../sources.md#s81) data fork at $2502.
- **Workaround:** link with the August 1996 library. Programs that cannot be relinked can pad an
  upload by two bytes so that its length is not a multiple of 64 KB.
- **Fix:** partly, in [firmware 1.5 and 2.0](../firmware-fixes.md#e19-uploads-of-whole-64-kb-blocks-hang-older-programs).

## Faults of earlier firmware

### E20. Uploads above 512 KB crashed the card

- SecondView 1.0a2 (June 1995): pictures over 512 KB "were overwriting the VGA firmware
  and causing the board to crash", until the firmware could upload to the upper 512 KB.
  ROM 1.4 can. Source: [SecondView RELEASE.NOTES](../sources.md#s06).
- **Fix:** not needed; ROM 1.4 already uploads to the upper 512 KB.

### E21. Faults fixed in v1.1

Sequential's "Second Sight Firmware Update v1.1" notes ([`SECOND/SVIEW/SS.NOTES`](../sources.md#s06) on
`ss.source.082395.po`) list these additions and fixes.

| Area | Addition or fix |
|---|---|
| Double hires | Color and monochrome, monochrome chosen in the Display control panel (announced; the shipped EPROM still hangs: [E2](#e2-double-hires-hangs)) |
| Super Hi-Res | Programs that use several palettes: DuelTris, Easy Eyes, HyperStudio |
| Fonts | IIgs foreign-language characters; PC-font glyphs redrawn to match the IIgs |
| Softswitch data | IIgs video writes overwriting softswitch data could leave the card in the wrong mode, such as Super Hi-Res after returning from BASIC.SYSTEM |
| MouseText | Solid-apple character in the AppleColor RGB font |
| Upload storage | A way to turn off Apple II shadowing completely, freeing more Z180 memory |

- **Fix:** not needed; ROM 1.4 contains these changes. Double hires is the
  exception: [E2](#e2-double-hires-hangs).

## Faults in programs

### E22. GView 0.25c leaves out the rightmost pixel column

- **Symptom:** GView 0.25c uploads each row of a 640-pixel picture as 639 bytes, so
  column 639 on the card keeps whatever video memory held before. Found in the program's
  code.
- **Cause:** the display routine decrements the picture width before it builds the
  source rectangle: `LDA $1869` / `DEC A` / `STA $1869`, bytes `AD 69 18 3A 8D 69 18` at
  GVIEW data-fork offset $D990. The height is used as it is. The library's pixel-map
  copier takes right minus left as the row length (offset $FC9D), so a 640 x 480
  picture becomes 480 uploads of 639 bytes.
- **Workaround:** none; the lost column is one pixel wide.
- **Fix:** none in firmware. GView never sends the last pixel of each row.

### E23. SecondView 1.0a6 zeroes the first pixel of rows 2, 4, 6 in interlaced GIFs

- **Symptom:** in an interlaced GIF, counting rows from 0, the first pixel of rows 2, 4, 6
  and so on shows color 0. Found in the program's code.
- **Cause:** the GIF decoder stores each pixel with a 16-bit accumulator (`sta [<row],Y`)
  but advances one byte (`iny`): [`SECOND/SVIEW/IQGIF.ASM`](../sources.md#s06) loops xloop2 and xloop3, bytes
  `97 0B C8` at SSVIEW data-fork offset $2017. The high byte of each row's last pixel,
  always 0, lands on the next row's first pixel. The last interlace pass writes rows 1,
  3, 5 and so on after the even rows, so each one's spill overwrites the first pixel of
  the even row below it, and those zeros stay.
- **Workaround:** use a non-interlaced GIF.
- **Fix:** none in firmware. The pixel is overwritten in Apple memory before the upload.

## Reported faults

### E24. The card can hang at power-up or after a reset

- **Symptom:** some boards show changing patterns and lock up the computer at power-up or
  after an Apple reset, only with VGA monitors; a second reset usually clears it.
  Source: [manual](../sources.md#s16), June 1995, pp25 and 29.
- **Cause:** the card can stop the IIgs only by holding RDY low, which it does while an
  event waits for the Z180 to acknowledge it ([RDY](../04-capture-logic.md#rdy-no-lost-events)).
  A Z180 that has not started or has stopped never acknowledges; the Apple reset restarts
  it.
- **Workaround:** press reset again.
- **Fix:** none in firmware. The boot code acknowledges events before it sets any video
  mode: it writes port $A0 right after the EPROM copy and the handler-table setup, and the
  first mode set runs afterwards, from the main loop ([Boot](../05-z180.md#boot);
  [ROM_BEEF.asm:54-227](../sources.md#s27)). From then on the INT1 handler serves events
  whenever interrupts are on. So a running Z180 holds the IIgs on RDY only for those
  first steps, and a hang that lasts until the next reset means the Z180 is not running,
  which no change to its firmware can fix.

### E25. Very large pictures may hang the card

- [GView's README](../sources.md#s04) (February 1996): pictures of "1024+ x 1024+ may crash or hang the
  system"; GView truncates them, "but the SecondSight still seems to hang sometimes".
- **Cause:** [E19](#e19-uploads-of-whole-64-kb-blocks-hang-older-programs): GView
  0.25c contains the old upload routine (GVIEW file offset $915F), and a 1024 x 1024
  picture at one byte per pixel is exactly 16 blocks of 64 KB.
- **Workaround:** the same as E19.
- **Fix:** partly, in [firmware 1.5 and 2.0](../firmware-fixes.md#e25-very-large-pictures-may-hang-the-card).

---

[Reference index](../../README.md)
