;; src/mainloop.asm, $1E01-$1FFF: the main loop, renderer selection, FREE SPACE $1EC4.
;; Part of the ROM 1.4 firmware source; ROM_BEEF.asm includes it.

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
;; AN3 off and 80-column video), hires, lores. Double lores falls through to single lores
;; (erratum E7). docs/reference/video-modes.md, Firmware renderer selection.
;; ----------------------------------------------------------------------------------------
get_emulation_routine:
                .assume get_emulation_routine - 0x1E5B ;; must stay at $1E5B
                ;; Each test returns HL = set-up routine, DE = renderer.
                ld      a, (emul_flag)
                cp      #0
                jr      Z, emulate_superhires_check
                ;; BUG (E29): every pending mode change runs set_native_mode while
                ;; emulation is off, also one an Apple display switch requested. The SetMode
                ;; mode is then programmed again: SetVGAReg changes are lost, ScreenOff is
                ;; undone, and $A5 goes to the handshake latch unasked.
                ld      hl, #set_native_mode
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
                ;; BUG (E7): double lores (AN3 off) takes the same path as single lores;
                ;; there is no double lores renderer.
                ld      a, (doublewidth_flag)
                cp      #0
                jr      Z, emulate_single_lores

; Double Lores support is missing

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
                .org    0x2000
