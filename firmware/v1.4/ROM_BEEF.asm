;; ROM_BEEF.asm: the Second Sight's Z180 firmware, ROM 1.4 (rev 1.4-BEEF), as source.
;;
;; BUILDING (firmware/README.md)
;;   python tools/build_rom.py firmware/v1.4/ROM_BEEF.asm
;; needs the ASxxxx assembler 6.10 (asz80 and aslink). The image goes to
;; build/firmware/ROM_BEEF.bin and matches the ROM_BEEF.bin dump byte for byte: 131,072
;; bytes, byte sum $BEEF, SHA-256
;; bd29e30ebf004e205609112a3c21a26eb28504115e047862fbd27f641f784d61.
;; firmware/v1.5/ and firmware/v2.0/ are copies of this source with
;; the errata fixes written in, each marked CHANGE (En).
;;
;; SOURCES
;;   The program: ROM_BEEF.asm, the IDA disassembly of ROM_BEEF.bin at
;;     https://github.com/jawaidbazyar2/secondsight/blob/780abcb754ce4ed516980925230ddbb4581107f0/ROM_BEEF.asm
;;     (docs/sources.md, s27).
;;   Tables, fonts and notes: the disk image ss.source.082395.po
;;     (docs/sources.md, s06; copies in firmware/original): SECOND/MISC/MODES.S (the mode
;;     records, src/modes.asm), SECOND/FIRM/MKTAB.C and MKCTAB.C (the double hires tables,
;;     src/dhrtables.asm), SECOND/FIRM/FONT.TAB and FONT8.TAB (the language glyphs,
;;     src/fonts.asm) and SECOND/FIRM/RC.TXT (RunCode). The disk does not hold the program.
;;
;; SOURCE LAYOUT
;;   src/ contains one file per area, in address order. Labels name routines and data;
;;   disk-source names include vga_regs_01, T_A1 and hex81. I/O names are in
;;   src/hardware.inc.
;;   Tables use .db rows and retain the disk source's layout where available.
;;   Reserved space uses .ds. src/superhires.asm contains the conversion code.
;;   FREE SPACE blocks mark unused bytes for new code. ".assume label - 0xNNNN"
;;   stops the build if a fixed label moves.
;;
;;   SECOND/ZMAC contains the ZMAC assembler, which has no Z180 instructions.
;;   RC.TXT writes OUT0 as the macro "z180_out a,(CBAR)". This accounts for the
;;   ineffective "ld a, a" before each OUT0 of register A in ROM 1.4.
;;
;; CHANGING THE FIRMWARE
;;   Work in a copy of this tree, as firmware/v1.5/ is, and mark each change.
;;   1. Keep every existing routine and table at its address. The boot code copies fixed
;;      address ranges into SRAM, some code reaches tables by fixed addresses, and the
;;      Super Hi-Res renderer is copied to SRAM bank 1 and run there, so anything that
;;      moves breaks the card. To change a routine, overwrite instructions in place with
;;      code of the same length, usually a JP or CALL to new code plus NOPs.
;;   2. Put new code and data in a FREE SPACE block (search the src files for "FREE SPACE").
;;      Each block ends with .org, which puts what follows back at its fixed address. New
;;      code that runs past the end of its block overlaps the code that follows, and the
;;      build stops with "address $xxxx is written twice".
;;
;; MEMORY (docs/05-z180.md, docs/reference/z180-memory-map.md)
;;   EPROM (U10, 128 KB): this source is its low 64 KB; the upper 64 KB is zero.
;;   Boot: the Z180 starts at $0000 with the EPROM mapped there, copies EPROM
;;     $0000-$03FF, $0C00-$1FFF and $6000-$FFFF into SRAM bank 0 at the same addresses,
;;     unmaps the EPROM and runs from SRAM.
;;   $0400-$0BFF and $2000-$5FFF are not copied: at run time SRAM bank 0 holds the
;;     Apple's text and lores pages and hires pages there (the screen copy). Their zero
;;     EPROM bytes are not free space.
;;   $A000-$BFFF: Super Hi-Res set-up copies this range to SRAM $1A000 and runs that copy.
;;   Mode records: set_video_mode reads them by DMA straight from the EPROM (physical
;;     $6xxxx), so only a new EPROM changes them.
;;   In the low 64 KB, EPROM offset, SRAM bank 0 address and the firmware's usual logical
;;   address are the same number.
;;
;; CARD OPERATION (docs/01-overview.md)
;;   The capture logic (U7 with latches U2, U5/U6 and GAL U17) copies the Apple's video
;;   writes into SRAM without the firmware, and raises
;;   INT1 for each video softswitch access or host command byte ("an event"). The INT1
;;   handler updates state flags and runs host commands. The main loop picks a renderer for
;;   the Apple's current video mode, and the renderer redraws the VGA screen from the SRAM
;;   copy.

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
