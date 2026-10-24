;; for_original_u7/src/mainloop.asm: src/mainloop.asm with the changes for a card with the original
;; U7 (fuse map BE8C); SecondSight_for_original_u7.asm includes it. Every change from
;; src/ is marked CHANGE (En). En refers to docs/reference/errata.md.

;; ----------------------------------------------------------------------------------------
;; Main loop (docs/08-firmware.md, Main loop). If a mode change is pending: choose the
;; setup and render routines for the Apple's current mode (get_emulation_routine), clear
;; the flag and jump to the setup, which ends by jumping back here. Else, if SetMode owes
;; its completion byte, write $A5 to port $A0. Then jump to the render routine, which
;; draws and jumps back here.
;; ----------------------------------------------------------------------------------------
main_loop:
                .assume main_loop - 0x1E01 ;; must stay at $1E01
                ;; Mode change pending: ask get_emulation_routine for the set-up routine
                ;; (HL) and the renderer (DE) for the Apple's video state, keep both, clear
                ;; the flag and jump to the set-up routine. It ends with a jump back to
                ;; main_loop.
                ld      a, (mode_change_pending)
                cp      #0
                jr      Z, main_loop_no_change
                call    get_emulation_routine
                ld      (set_emulated_videomode), hl
                ld      (emulate_current_videomode), de
                ld      a, #0
                ld      (mode_change_pending), a
                ld      hl, (set_emulated_videomode)
                jp      (hl)

main_loop_no_change:
                ;; SetMode's $A5 is owed only when emulation was turned back on;
                ;; set_native_mode sends its own reply.
                ld      a, (setmode_reply_owed)
                cp      #0
                jr      Z, main_loop_render
                ld      a, #0xA5
                out0    (CARD_DATA), a
                ld      a, #0
                ld      (setmode_reply_owed), a

main_loop_render:
                ;; Run the renderer for one pass. It ends with a jump back to main_loop.
                ld      hl, (emulate_current_videomode)
                jp      (hl)

;; Never reached.
unreached_jp_hl:
                jp      (hl)

;; ----------------------------------------------------------------------------------------
;; The mode SetMode asked for, and setmode_reply_owed = 1 while SetMode's $A5 is owed.
;; ----------------------------------------------------------------------------------------
vga_mode:       .db     0
                                        ; 01 = 40x25, 03 = 80x25, 53 = 640x480x256, 13 = 320x200x256, 61 = 640x400x256, FA = 560x192x16, FB=280x192x16, FC=40x24, FD=80x24, FE=640x200
setmode_reply_owed:
                .db     0

;; ----------------------------------------------------------------------------------------
;; Setup routine while Apple emulation is off: sets the requested VGA mode, turns the
;; screen on and replies $A5, or $A6 when set_video_mode refused the mode.
;; ----------------------------------------------------------------------------------------
set_native_mode:
                ;; set_video_mode returns with carry set when it does not know the mode
                ;; (its first CP $FF sets carry, and that path changes no flag after it); a
                ;; programmed mode returns with carry clear.
                ld      a, (vga_mode)
                call    set_video_mode
                jr      C, native_mode_refused
                call    screen_on
                ld      a, #0xA5
                out0    (CARD_DATA), a
                ld      a, #0
                ld      (setmode_reply_owed), a
                jp      main_loop

native_mode_refused:
                ld      a, #0xA6
                out0    (CARD_DATA), a
                ld      a, #0
                ld      (setmode_reply_owed), a
                jp      main_loop

;; ----------------------------------------------------------------------------------------
;; Render routine while emulation is off: draws nothing.
;; ----------------------------------------------------------------------------------------
emulation_disabled:
                jp      main_loop

;; ----------------------------------------------------------------------------------------
;; Chooses the setup routine (HL) and render routine (DE) for the Apple's video state, in
;; this order: emulation off, Super Hi-Res, 80- or 40-column text, double hires (HIRES,
;; AN3 off and 80-column video), hires, double lores (AN3 off and 80-column video, added
;; for erratum E7), lores. docs/reference/video-modes.md, Firmware renderer selection.
;; ----------------------------------------------------------------------------------------
get_emulation_routine:
                .assume get_emulation_routine - 0x1E5B ;; must stay at $1E5B
                ;; Each test returns HL = set-up routine, DE = renderer.
                ld      a, (emul_flag)
                cp      #0
                jr      Z, emulate_superhires_check
;; CHANGE (E29): was ld hl, #set_native_mode. With emulation off, ROM 1.4 ran
;; set_native_mode for every pending mode change, so an Apple display switch programmed
;; the SetMode mode again. native_mode_check (src/text.asm, $9776 block; main_loop runs
;; with BBR = 0) runs it only for SetMode. The two lines after the JP are never run.
                jp      native_mode_check
                ld      de, #emulation_disabled
                ret

emulate_superhires_check:
                ld      a, (shr_enabled_flag)
                cp      #0
                jr      Z, emulate_text80_check
                ld      hl, #set_videomode_superhires
                ld      de, #emulate_superhires
                ret

emulate_text80_check:
                ld      a, (text_flag)
                cp      #0
                jr      Z, emulate_hires_dhr_check
                ld      a, (text80_enabled_flag)
                cp      #0
                jr      Z, emulate_text40_check
                ld      hl, #set_videomode_text80
                ld      de, #emulate_text80
                ret

emulate_text40_check:
                ld      hl, #set_videomode_text40
                ld      de, #emulate_text40
                ret

emulate_hires_dhr_check:
                ld      a, (hires_flag)
                cp      #0
                jr      Z, emulate_lores_dlr_check
                ld      a, (doublewidth_flag)
                cp      #0
                jr      Z, emulate_single_hires
                ld      a, (text80_enabled_flag)
                cp      #0
                jr      Z, emulate_single_hires
                ld      hl, #set_videomode_double_hires
                ld      de, #emulate_double_hires
                ret

emulate_single_hires:
                ld      hl, #set_videomode_hires
                ld      de, #emulate_hires
                ret

emulate_lores_dlr_check:
;; CHANGE (E7): was ld a, (doublewidth_flag) / cp #0 / jr Z, emulate_single_lores, a test
;; that sent double lores (AN3 off) to the single lores routines as well, because ROM 1.4
;; has no double lores renderer. The JP goes to double_lores_check (src/text.asm, $9D00),
;; which returns the new double lores routines for lores with AN3 off and 80-column video,
;; the same condition as double hires, and jumps back to emulate_single_lores for any
;; other lores. The four NOPs fill the rest of the old test and are never run.
                jp      double_lores_check
                nop
                nop
                nop
                nop

emulate_single_lores:
                ld      hl, #set_videomode_lores
                ld      de, #emulate_lores
                ret

;; ========================================================================================
;; FREE SPACE $1EC4-$1FFF (316 bytes).
;; Zero in ROM 1.4; nothing refers to it. It follows the last routine of the
;; command and mode-selection code, is copied into SRAM at boot and is always mapped
;; (common area 0). The largest free block in the copied code.
;; Put new code or data between the label and the .org; the .org keeps what follows
;; at $2000.
;; ========================================================================================
free_1EC4:
;; ----------------------------------------------------------------------------------------
;; CHANGE (E26): the end of set_textmode_palette. It writes DAC entry 4 black, as ROM 1.4
;; did, then copies the background and text colors just loaded (text_bg_red...
;; text_fg_blue) into the flashing pair (background_r... foreground_b), in the same
;; order. setup_textmode_palette then swaps the $C022 colors, so flashing characters
;; alternate between normal and inverse in the colors $C022 asks for.
;; ----------------------------------------------------------------------------------------
text_palette_tail:
                xor     a
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                out     (c), a
                out     (c), a
                ld      hl, #text_bg_red
                ld      de, #background_r
                ld      bc, #6
                ldir
                ret


                .org    0x1EE6
;; ----------------------------------------------------------------------------------------
;; CHANGE (shared): runs a routine in the FREE SPACE block $9776-$9FFF (src/text.asm) from
;; any memory layout. That block is mapped only while BBR = 0, and a host command runs
;; inside INT1 with whatever layout the current renderer set (Super Hi-Res and double
;; hires use other BBR values). In: HL = the routine's address. The routine runs with
;; BBR = 0, which in every layout the firmware uses maps logical $9776-$9FFF to the same
;; physical addresses in SRAM bank 0; BC, DE, IX and IY reach it unchanged, and it may
;; return results in them (A and the flags are lost). Call it with interrupts off, as a
;; command handler runs.
;; ----------------------------------------------------------------------------------------
call_in_bank0:
                in0     a, (BBR)
                push    af
                xor     a
                out0    (BBR), a
                call    call_hl
                pop     af
                out0    (BBR), a
                ret

call_hl:
                jp      (hl)

                .org    0x1F00
;; ----------------------------------------------------------------------------------------
;; CHANGE (E5): fixes RunCode never reporting completion. run_code calls the user's code
;; and returns without the completion byte $A5 that _RunCode in the IIgs library
;; (VGALOW.ASM) waits for, so the library waited forever. This wrapper sends it after
;; run_code returns. User code that already sends $A5 itself still works: the second $A5
;; changes nothing. A user routine that never returns still never reports. api_table's
;; RunCode entry points here.
;; ----------------------------------------------------------------------------------------
run_code_and_report:
                call    run_code
                ld      a, #0xA5
                out0    (CARD_DATA), a          ;; the completion byte for the IIgs
                ret

                .org    0x1F10
;; ----------------------------------------------------------------------------------------
;; CHANGE (E2): copies of mono_dhires_line and colour_dhires_line (src/dhires.asm, where
;; their comments are), byte for byte, 220 bytes at $1F10-$1FEB. In the double hires
;; memory layout (CBAR $C9, BBR $08, CBR $94) logical $9000-$9DFF shows the repack tables
;; and only $0000-$8FFF is the firmware's own bank 0, but the originals lie at
;; $8FCD-$90A8. These copies lie below $9000 in common area 0, which every layout maps.
;; They use only relative jumps, so they run unchanged here. dhires_row calls them.
;; ----------------------------------------------------------------------------------------
mono_dhires_line_low:
                ld      c, #0xA
                push    de
                push    de
                exx
                pop     de
                exx
mono_byte_loop_low:
                exx
                ld      b, #0x96        ; 96xx -> 01/16xx (T_A7)
                ld      h, #0x9D        ; 9Dxx -> 01/1Dxx (T_B7)
                ld      c, 0(iy)
                ld      l, 0(ix)
                ld      a, (bc)
                or      (hl)
                ld      (de), a
                inc     de
                dec     b
                dec     h
                ld      c, l
                ld      l, 1(iy)
                ld      a, (bc)
                or      (hl)
                ld      (de), a         ; output byte 1
                inc     de
                dec     b
                dec     h
                ld      c, l
                ld      l, 1(ix)
                ld      a, (bc)
                or      (hl)
                ld      (de), a         ; output byte 2
                inc     de
                dec     b
                dec     h
                ld      c, l
                ld      l, 2(iy)
                ld      a, (bc)
                or      (hl)
                ld      (de), a         ; output byte 3
                inc     de
                dec     b
                dec     h
                ld      c, l
                ld      l, 2(ix)
                ld      a, (bc)
                or      (hl)
                ld      (de), a         ; output byte 4
                inc     de
                dec     b
                dec     h
                ld      c, l
                ld      l, 3(iy)
                ld      a, (bc)
                or      (hl)
                ld      (de), a         ; output byte 5
                inc     de
                dec     b
                dec     h
                ld      c, l
                ld      l, 3(ix)
                ld      a, (bc)
                or      (hl)
                ld      (de), a         ; output byte 6
                inc     de
                exx
                ld      de, #4
                add     ix, de
                add     iy, de
                dec     c
                jr      NZ, mono_byte_loop_low
                pop     de
                ret

colour_dhires_line_low:
                ld      c, #0xA
                push    de
                push    de
                exx
                pop     de
                exx
colour_byte_loop_low:
                ld      d, #0xC0
                exx
                ld      b, #0x96        ; 96xx -> 01/16xx (T_A7)
                ld      h, #0x9D        ; 9Dxx -> 01/1Dxx (T_B7)
                ld      c, 0(iy)
                ld      l, 0(ix)
                ld      a, (bc)
                or      (hl)
                exx
                ld      e, a
                ld      a, (de)
                exx
                ld      (de), a
                inc     de
                dec     b
                dec     h
                ld      c, l
                ld      l, 1(iy)
                ld      a, (bc)
                or      (hl)
                exx
                ld      e, a
                ld      a, (de)
                exx
                ld      (de), a
                inc     de
                dec     b
                dec     h
                ld      c, l
                ld      l, 1(ix)
                ld      a, (bc)
                or      (hl)
                exx
                ld      e, a
                ld      a, (de)
                exx
                ld      (de), a
                inc     de
                dec     b
                dec     h
                ld      c, l
                ld      l, 2(iy)
                ld      a, (bc)
                or      (hl)
                exx
                ld      e, a
                ld      a, (de)
                exx
                ld      (de), a
                inc     de
                dec     b
                dec     h
                ld      c, l
                ld      l, 2(ix)
                ld      a, (bc)
                or      (hl)
                exx
                ld      e, a
                ld      a, (de)
                exx
                ld      (de), a
                inc     de
                dec     b
                dec     h
                ld      c, l
                ld      l, 3(iy)
                ld      a, (bc)
                or      (hl)
                exx
                ld      e, a
                ld      a, (de)
                exx
                ld      (de), a
                inc     de
                dec     b
                dec     h
                ld      c, l
                ld      l, 3(ix)
                ld      a, (bc)
                or      (hl)
                exx
                ld      e, a
                ld      a, (de)
                exx
                ld      (de), a
                inc     de
                exx
                ld      de, #4
                add     ix, de
                add     iy, de
                dec     c
                jr      NZ, colour_byte_loop_low
                pop     de
                ret

;; ----------------------------------------------------------------------------------------
;; CHANGE (E10): check_for_api_call jumps here for command numbers $0F and up, with the
;; flags of its CP $0F: Z for $0F. $10 and up are ignored as before. $0F, SetTextFont,
;; runs set_text_font (FREE SPACE $9776 block, src/text.asm) through call_in_bank0, since
;; a command runs inside INT1 under any memory layout and this block is always mapped.
;; Both ways end at command_return, which pops DE and BC as for any command.
;; ----------------------------------------------------------------------------------------
command_0f_check:
                jp      NZ, command_return
                ld      hl, #set_text_font
                call    call_in_bank0
                jp      command_return

                .org    0x2000
