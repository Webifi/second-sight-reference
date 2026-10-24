;; SecondSight_v2_0.asm: Second Sight firmware 2.0, for a card with Lattice v2.0,
;; the corrected fuse map (checksum BBB1, docs/lattice-versions.md). It is
;; firmware/v1.5/ (firmware 1.5) plus one more fix, E15, which only Lattice v2.0
;; makes possible; a change other than E15 goes into both. docs/firmware-versions.md
;; lists the versions. Each change is marked CHANGE (En)
;; at the affected code; En is the erratum in
;; docs/reference/errata.md. Everything not marked CHANGE is the same as in firmware/v1.4/src.
;; On a card with the original Lattice chip this firmware runs like firmware/v1.5/: no
;; $C034 event ever arrives, so the E15 code never acts.
;;
;; CHANGES
;;   Version: GetStatus reports $20, version 2.0, instead of ROM 1.4's $14 (src/commands.asm).
;;   E1  Mode $13 shows a broken picture: the record's ext $21 is $00, and picture uploads
;;       in mode $13 go through the standard $A0000 window (src/modes.asm,
;;       src/commands.asm, src/text.asm).
;;   E2  Double hires hangs: the set-up skips the early MMU switch, and the two
;;       line routines run from copies below $9000 (src/dhires.asm, src/mainloop.asm).
;;   E3  Super Hi-Res lines 102-127 use the wrong palette: one byte (src/superhires.asm).
;;   E4  UploadData flag 0 never reaches Z180 memory: one jump (src/commands.asm).
;;   E5  RunCode never reports completion: a wrapper at $1F00 sends $A5 after the call
;;       (src/events.asm, src/mainloop.asm).
;;   E6  Mixed-hires text ignores the $C022 colors: the text lines draw in DAC entries 14
;;       and 15, loaded with the $C022 colors (src/hires.asm, src/text.asm).
;;   E7  Double lores shows as single lores: a double lores renderer, chosen for lores
;;       with AN3 off and 80-column video (src/mainloop.asm, src/text.asm).
;;   E8  ScrollScreen and ClearScreen past 512 KB overwrite card memory, and E9
;;       ScrollScreen toward a higher address copies the wrong bytes: both commands are
;;       rewritten, with the half chosen per piece and the direction from whole addresses
;;       (src/commands.asm, src/text.asm).
;;   E10 SetTextFont is missing: command $0F is accepted and loads the built-in or the
;;       user font (src/events.asm, src/mainloop.asm, src/textsetup.asm, src/text.asm).
;;   E11 Super Hi-Res color fill mode is ignored: fill lines are converted from a filled
;;       copy (src/superhires.asm).
;;   E13 Fast animation is choppy: the Super Hi-Res converter walks each band forward with
;;       the stack pointer and finds each byte's table through a page table, about 68 ms
;;       a full screen instead of 92 (src/superhires.asm).
;;   E15 The IIgs border color does not show: a $C034 handler records the color, and the
;;       main loop shows it in DAC entry $FF, or in Super Hi-Res points the border at the
;;       closest palette entry (src/boot.asm, src/events.asm, src/mainloop.asm,
;;       src/superhires.asm).
;;   E26 Flashing text ignores $C022 and does not flash in 80 columns: the flashing pair
;;       follows the text colors, and 80 columns stop reloading them every pass
;;       (src/textsetup.asm, src/text.asm, src/mainloop.asm).
;;   E27 Four 8x16 language characters sit one row low: the extra row of $9A is left out
;;       (src/fonts.asm).
;;   E16 Library mode files run at the wrong clock, and E17 the true-color mode file
;;       shows palette colors: SetUserMode's record is corrected before it is programmed
;;       (src/modeset.asm, src/text.asm).
;;   E19 and E25 Uploads of whole 64 KB blocks hang older programs: UploadData acts out
;;       the remainder phase the old library waits for (src/commands.asm, src/text.asm,
;;       src/hardware.inc).
;; E12, palettes rewritten during each frame, has no firmware fix (docs/reference/errata.md).
;; Validation limits and warnings: docs/firmware-versions.md.
;;
;; Build, from the repository root:
;;   python tools/build_rom.py firmware/v2.0/SecondSight_v2_0.asm
;; The image goes to build/firmware/SecondSight_v2_0.bin, and the build lists
;; every byte range that differs from ROM 1.4. The same image, ready to program into an
;; EPROM, is prebuilt/firmware/SecondSight_firmware_v2.0-<byte sum>.bin.
;;
;; Source layout, memory map and CHANGE (En) conventions: firmware/v1.4/ROM_BEEF.asm.

                .hd64
                .area   CODE (ABS)

                .include "src/hardware.inc"
                .include "src/boot.asm"
                .include "src/interrupts.asm"
                .include "src/modeset.asm"
                .include "src/commands.asm"
                .include "src/variables.asm"
                .include "src/events.asm"
                .include "src/mainloop.asm"
                .include "src/hires.asm"
                .include "src/lores.asm"
                .include "src/chartables.asm"
                .include "src/textsetup.asm"
                .include "src/fonts.asm"
                .include "src/dhires.asm"
                .include "src/text.asm"
                .include "src/superhires.asm"
                .include "src/colourtables.asm"
                .include "src/modes.asm"
                .include "src/dhrtables.asm"
