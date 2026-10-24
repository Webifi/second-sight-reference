;; v2.0/src/variables.asm: v1.4/src/variables.asm with the changes for a card with the corrected
;; U7 (fuse map BBB1); SecondSight_v2_0.asm includes it. Every change from
;; v1.4/src/ is marked CHANGE (En). En refers to docs/reference/errata.md.

;; ----------------------------------------------------------------------------------------
;; SetUserMode's buffer: the 84 bytes the IIgs sends. The first 81 are the register
;; record of mode $FF (set_user_mode, set_video_mode).
;; ----------------------------------------------------------------------------------------
user_mode_record:
                .ds     84
                .ds     18              ; unused

;; ----------------------------------------------------------------------------------------
;; The event dispatch table, filled at boot by setup_softswitch_handlers. For the event
;; at $C0nn, the handler's address is at event_handlers_low+nn (low byte) and
;; event_handlers_high+nn (high byte). handle_event relies on the table starting at
;; $1800: it builds the address from the page number $18.
;; ----------------------------------------------------------------------------------------
event_handlers_low:
                .ds     256
                .assume event_handlers_low - 0x1800 ;; must stay at $1800
event_handlers_high:
                .ds     256

;; ----------------------------------------------------------------------------------------
;; Host command state (check_for_api_call). cmd_next_state, cmd_param_index and cmd_param_ptr are
;; written but never read.
;; ----------------------------------------------------------------------------------------
cmd_next_state:
                .dw     0               ; where the next $C0B0 byte goes (unused)
cmd_param_count:
                .db     0               ; parameter count of the current command
cmd_param_index:
                .db     0               ; parameter index (unused)
cmd_param_ptr:  .dw     0               ; parameter pointer (unused)
cmd_number:     .db     0               ; current command number
                .db     0               ; unused

;; ----------------------------------------------------------------------------------------
;; The current command's parameter bytes, in the order the IIgs sends them. DMA writes
;; them here; the handlers read them by these names (cmd_param1+1 is byte 2).
;; ----------------------------------------------------------------------------------------
cmd_param1:     .dw     0               ; bytes 1-2
cmd_param3:     .db     0               ; byte 3
cmd_param4:     .dw     0               ; bytes 4-5
cmd_param6:     .db     0               ; byte 6
cmd_param7:     .dw     0               ; bytes 7-8
cmd_param9:     .db     0               ; byte 9
                .ds     23              ; bytes 10-32: room for longer commands; unused

;; ----------------------------------------------------------------------------------------
;; The Apple video state, kept by the event handlers and read by get_emulation_routine
;; and the renderers.
;; ----------------------------------------------------------------------------------------
text_flag:      .db     1               ; $C050/$C051: 1 = text, 0 = graphics
store80_flag:   .db     0               ; $C000/$C001: 1 = 80STORE off, 0 = on
hires_flag:     .db     0               ; $C056/$C057: 1 = hires, 0 = lores
altcharset_flag:
                .db     0               ; $C00E/$C00F: 1 = alternate character set
text80_enabled_flag:
                .db     0               ; $C00C/$C00D: 1 = 80 columns
newvideo_flag:  .db     0               ; $C029 NEWVIDEO; bit 5 = monochrome double hires
mixed_mode_flag:
                .db     0               ; $C052/$C053: 1 = mixed (four text lines at the bottom)
current_page:   .db     0               ; $C054/$C055: 0 = page 1, 1 = page 2
                .db     0               ; unused
doublewidth_flag:
                .db     0               ; $C05E/$C05F: 1 = double-width graphics (AN3 off)
text_colour:    .db     0xF0            ; $C022 TBCOLOR: bits 7-4 text, bits 3-0 background
language:       .db     0               ; $C02B: bits 7-5 = language (0 = US English ... 7 = Swedish)
shr_enabled_flag:
                .db     0               ; 1 = Super Hi-Res on (NEWVIDEO bit 7)
unused_1A35:    .db     0               ; written by the unreached old INT1 handler only
emul_flag:      .db     0               ; SetMode flag: 0 = show the Apple's video, 1 = native mode
emulate_current_videomode:
                .dw     emulate_text40  ; renderer for the current Apple mode
set_emulated_videomode:
                .dw     set_videomode_text40 ; set-up routine for that mode

mode_change_pending:
                .db     1               ; 1 = mode change pending (the main loop acts on it)

;; ----------------------------------------------------------------------------------------
;; The character tables in use: screen code to VGA character, and screen code to VGA
;; attribute. normal_char_codes and the next page normally, the MouseText pair
;; with the alternate character set on.
;; ----------------------------------------------------------------------------------------
char_code_table:
                .dw     0
char_attr_table:
                .dw     0
