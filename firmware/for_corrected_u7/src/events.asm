;; for_corrected_u7/src/events.asm: src/events.asm with the changes for a card with the corrected
;; U7 (fuse map BBB1); SecondSight_for_corrected_u7.asm includes it. Every change from
;; src/ is marked CHANGE (En). En refers to docs/reference/errata.md.

;; ----------------------------------------------------------------------------------------
;; Builds the event dispatch table at $1800/$1900: every entry first points at the default
;; handler $1B28 (only returns; handle_event has already read port $A0, which is the
;; acknowledge), then each tracked address gets its handler through
;; set_softswitch_handler. Also sets the start-up state: text on, 80STORE off, Super
;; Hi-Res off, emulation on, 40-column text routines, mode change pending.
;; docs/08-firmware.md, The event handler.
;; ----------------------------------------------------------------------------------------
setup_softswitch_handlers:
                ;; The start-up state: normal character set, text mode, 80STORE off, Super
                ;; Hi-Res off, emulation on, 40-column text, mode change pending.
                ld      hl, #normal_char_codes
                ld      (char_code_table), hl
                ld      hl, #normal_char_attrs
                ld      (char_attr_table), hl
                ld      a, #1
                ld      (text_flag), a
                ld      a, #0
                ld      (store80_flag), a
                ld      a, #0
                ld      (shr_enabled_flag), a
                ld      hl, #emulate_text40
                ld      (emulate_current_videomode), hl
                ld      hl, #set_videomode_text40
                ld      (set_emulated_videomode), hl
                ld      a, #1
                ld      (mode_change_pending), a
                ld      a, #0
                ld      (emul_flag), a
                ;; Point all 256 entries at default_event_handler: low byte in
                ;; event_handlers_low, high byte in the page above.
                ld      hl, #event_handlers_low

set_default_handler_loop:
                ld      (hl), #<default_event_handler
                inc     h
                ld      (hl), #>default_event_handler
                dec     h
                inc     l
                jr      NZ, set_default_handler_loop
                ;; Then a handler for each softswitch the firmware follows. A = the low
                ;; byte of the $C0xx address, BC = the handler.
                ld      a, #0           ; CLR80COL softswitch
                ld      bc, #softswitch_C000_clr80col
                call    set_softswitch_handler
                ld      a, #1           ; SET80COL softswitch
                ld      bc, #softswitch_C001_set80col
                call    set_softswitch_handler
                ld      a, #0xC         ; CLR80VID softswitch
                ld      bc, #softswitch_C00C_clr80vid
                call    set_softswitch_handler
                ld      a, #0xD         ; SET80VID softswitch
                ld      bc, #softswitch_C00D_set80vid
                call    set_softswitch_handler
                ld      a, #0xE         ; CLRALTCHAR softswitch
                ld      bc, #softswitch_C00E_clraltchar
                call    set_softswitch_handler
                ld      a, #0xF         ; SETALTCHAR softswitch
                ld      bc, #softswitch_C00F_setaltchar
                call    set_softswitch_handler
                ld      a, #0x22        ; TBCOLOR softswitch (text/background colour)
                ld      bc, #softswitch_C022_tbcolor
                call    set_softswitch_handler
                ld      a, #0x29        ; NEWVIDEO softswitch
                ld      bc, #softswitch_C029_newvideo
                call    set_softswitch_handler
                ld      a, #0x2B        ; LANGSEL softswitch
                ld      bc, #softswitch_C02B_langsel
                call    set_softswitch_handler
                ld      a, #0x50        ; TXTCLR softswitch (graphics mode)
                ld      bc, #softswitch_C050_txtclr
                call    set_softswitch_handler
                ld      a, #0x51        ; TXTSET softswitch (text mode)
                ld      bc, #softswitch_C051_txtset
                call    set_softswitch_handler
                ld      a, #0x52        ; MIXCLR softswitch (disable mixed mode)
                ld      bc, #softswitch_C052_mixclr
                call    set_softswitch_handler
                ld      a, #0x53        ; MIXSET softswitch (set mixed mode)
                ld      bc, #softswitch_C053_mixset
                call    set_softswitch_handler
                ld      a, #0x54        ; TXTPAGE1 softswitch
                ld      bc, #softswitch_C054_page1
                call    set_softswitch_handler
                ld      a, #0x55        ; TXTPAGE2 softswitch
                ld      bc, #softswitch_C055_page2
                call    set_softswitch_handler
                ld      a, #0x56        ; LORES softswitch
                ld      bc, #softswitch_C056_lores
                call    set_softswitch_handler
                ld      a, #0x57        ; HIRES softswitch
                ld      bc, #softswitch_C057_hires
                call    set_softswitch_handler
                ld      a, #0x5E        ; SETAN3 softswitch (enable double-width graphics)
                ld      bc, #softswitch_C05E_setan3
                call    set_softswitch_handler
                ld      a, #0x5F        ; CLRAN3 softswitch (disable double-width graphics)
                ld      bc, #softswitch_C05F_clran3
                ;; CHANGE (E15): was call set_softswitch_handler. register_clran3_and_border
                ;; (src/boot.asm) makes that call and then installs the $C034 handler.
                call    register_clran3_and_border
                ;; set_interrupt_hook(slot 0, handle_event): arguments pushed, then removed
                ;; from the stack. Nothing reads that slot (int1_handler jumps to
                ;; handle_event directly).
                ld      hl, #0
                ld      bc, #handle_event
                push    bc
                push    hl
                call    set_interrupt_hook
                ld      b, h
                ld      c, l
                ld      hl, #4
                add     hl, sp
                ld      sp, hl
                ret

;; The handler for every softswitch the firmware does not follow: return at once.
;; handle_event has already read CARD_DATA, which acknowledged the event.
default_event_handler:
                jp      event_return

;; ----------------------------------------------------------------------------------------
;; INT1 event handler (docs/08-firmware.md, The event handler). The capture logic has
;; latched the event's Apple address: port $A7 gives bits 7-4, port $A6 bits 3-0.
;;   $C0Bx: check_for_api_call ($C0B0 is a command byte; $C0B1-$C0B7 outside a command
;;          are acknowledged and dropped).
;;   other $C0xx: handle_softswitch looks up the handler in the table at $1800/$1900,
;;          reads port $A0 (the data byte, and the acknowledge) into A and jumps to it.
;; Handlers end with jp event_return, which restores HL and AF, enables interrupts and returns.
;; ----------------------------------------------------------------------------------------
handle_event:
                .assume handle_event - 0x1B2B ;; must stay at $1B2B
                ;; Bits 7-4 of the event's address (EVENT_ADDR_HI), moved to the high
                ;; nibble. $B0 means $C0Bx: a card register, used by the host commands.
                push    af
                push    hl
                in0     a, (EVENT_ADDR_HI)
                and     #0xF
                sla     a
                sla     a
                sla     a
                sla     a
                cp      #0xB0           ; $C0Bx softswitches used for VGALIB
                jp      Z, check_for_api_call

handle_softswitch:
                ;; Add bits 3-0 (EVENT_ADDR_LO) to get the address's low byte nn. HL = the
                ;; handler from event_handlers_low+nn and event_handlers_high+nn.
                ld      l, a
                in0     a, (EVENT_ADDR_LO)
                and     #0xF
                or      l
                ld      h, #>event_handlers_low
                ld      l, a
                ld      a, (hl)
                inc     h
                ld      h, (hl)
                ld      l, a
                ;; Read the data byte the Apple wrote (this read also acknowledges the
                ;; event) and jump to the handler with it in A.
                in0     a, (CARD_DATA)
                jp      (hl)

command_return:
                ;; The way out for a command handler: restore DE and BC as well.
                pop     de
                pop     bc

event_return:
                ;; The way out for every event handler: restore HL and AF, interrupts on,
                ;; return to the code the event interrupted.
                pop     hl
                pop     af
                ei
                ret

not_api_call:
                ;; $C0B1-$C0B7 outside a command: acknowledge and drop.
                in0     a, (CARD_DATA)
                jr      event_return

;; ----------------------------------------------------------------------------------------
;; Host command dispatch. Commands $0F and up are ignored (erratum E10: SetTextFont is
;; missing). For a command with parameters it points DMA channel 1 at port $A0 and the
;; buffer at $1A08, writes $01 to port $A0 (the IIgs then sends the bytes, each one an
;; event that requests one DMA read), waits for the count to run out and writes $00.
;; Then it calls the handler from api_table, still inside the interrupt.
;; docs/09-host-protocol.md, One command, step by step.
;; ----------------------------------------------------------------------------------------
check_for_api_call:
                ;; Only $C0B0 starts a command.
                in0     a, (EVENT_ADDR_LO)
                and     #0xF            ; check for $C0B0 (CMD)
                jr      NZ, not_api_call
                push    bc
                push    de
                ;; The byte written to $C0B0 is the command number. $0F and up: ignore it.
                in0     a, (CARD_DATA)  ; read data bus for byte written to $C0B0
                cp      #0xF
;; CHANGE (E10): was jp NC, command_return, which refused command $0F, SetTextFont in the
;; firmware documentation. Commands $0F and up go to command_0f_check ($1FEC,
;; src/mainloop.asm), which runs SetTextFont for $0F and ignores the rest as before. The
;; parameter-count table and api_table stay as they are: $0F takes its own path, so it
;; needs no entry in either.
                jp      NC, command_0f_check
                ld      (cmd_number), a ; Store api command
                ;; Look up the command's parameter count. The table holds count + 1; 1
                ;; means no parameters, so go straight to the handler.
                ld      hl, #cmd_param_counts
                ld      b, #0
                ld      c, a
                add     hl, bc
                ld      a, (hl)
                dec     a
                cp      #0
                jp      Z, run_command
                ld      (cmd_param_count), a
                ld      a, #0
                ld      (cmd_param_index), a
                ld      hl, #cmd_param1
                ld      (cmd_param_ptr), hl
                ld      hl, #receive_cmd_params
                ld      (cmd_next_state), hl
                jr      receive_cmd_params

;; ----------------------------------------------------------------------------------------
;; The 15-byte parameter-count table: one byte per
;; command $00-$0E, the number of parameter bytes plus one. Erratum E10 needs a 16th entry.
;; ----------------------------------------------------------------------------------------
cmd_param_counts:
                .db     0x01, 0x03, 0x0B, 0x0A, 0x01, 0x01, 0x04, 0x05 ; $00-$07
                .db     0x02, 0x06, 0x08, 0x02, 0x07, 0x06, 0x01 ; $08-$0E

receive_cmd_params:
                ;; DMA channel 1: from port $A0 to cmd_param1 (physical $21A08, the SRAM
                ;; seen through bank 2), one byte for each write the IIgs makes. I/O to
                ;; memory, level-triggered requests.
                ld      a, #2
                out0    (MAR1B), a
                ld      bc, #cmd_param1
                ld      a, b
                out0    (MAR1H), a
                ld      a, c
                out0    (MAR1L), a
                ld      a, #0
                out0    (IAR1H), a
                ld      a, #0xA0
                out0    (IAR1L), a
                ld      a, (cmd_param_count)
                ld      a, a
                out0    (BCR1L), a
                ld      a, #0
                out0    (BCR1H), a
                in0     a, (DCNTL)
                or      #0xA
                and     #0xFA
                ld      a, a
                out0    (DCNTL), a
                in0     a, (DSTAT)
                or      #0x81
                and     #0xDF
                ld      a, a
                out0    (DSTAT), a
                ;; Tell the IIgs to send the parameters ($01 in the output latch), wait for
                ;; the last byte, then put $00 back.
                ld      a, #1
                out0    (CARD_DATA), a

wait_for_channel1_dma_transfer_loop:
                in0     a, (DSTAT)
                bit     7, a            ; Bit 7: DE1 (DMA enable channel 1)
                jp      NZ, wait_for_channel1_dma_transfer_loop
                ld      a, #0
                out0    (CARD_DATA), a

run_command:
                ;; Call the handler from api_table: HL = api_table + 2 x command number.
                ;; The handler runs inside the interrupt; commands that move data do their
                ;; own DMA and handshake.
                ld      hl, #check_for_api_call
                ld      (cmd_next_state), hl
                ld      hl, #api_table
                ld      b, #0           ; clear high byte
                ld      a, (cmd_number)
                sla     a               ; multiply by 2
                ld      c, a            ; c = function number * 2
                add     hl, bc          ; HL = api_table + (function number * 2)
                ld      c, (hl)         ; c = low byte of function address + 1
                inc     hl
                ld      b, (hl)         ; b = high byte of function address
                push    bc
                pop     hl
                call    call_api_function
                jp      command_return

;; ----------------------------------------------------------------------------------------
;; Jumps to the handler address in HL.
;; ----------------------------------------------------------------------------------------
call_api_function:
                jp      (hl)

;; ----------------------------------------------------------------------------------------
;; The 15 command handlers, in command order $00-$0E.
;; ----------------------------------------------------------------------------------------
api_table:      .dw     get_status
                .assume api_table - 0x1C0F ;; must stay at $1C0F
                .dw     set_mode
                .dw     upload_data
                .dw     scroll_screen
                .dw     screen_off
                .dw     screen_on
                .dw     set_palette
                .dw     set_palette_entry
                .dw     set_border
;; CHANGE (E5): fixes RunCode never reporting completion. The entry pointed at run_code;
;; it points at run_code_and_report (FREE SPACE $1EC4 block, src/mainloop.asm), which
;; calls run_code and then sends the completion byte $A5 that _RunCode in the IIgs library
;; (VGALOW.ASM) waits for.
                .dw     run_code_and_report
                .dw     clear_screen
                .dw     set_shadow
                .dw     set_vga_reg
                .dw     get_vga_reg
                .dw     set_user_mode

;; ----------------------------------------------------------------------------------------
;; Command $09, RunCode (CBR, CBAR, BBR, address): saves the MMU registers, writes the
;; address into the CALL at call_user_code, sets the requested MMU registers, calls the
;; code, then restores the MMU. Erratum E5: it never writes the completion byte $A5.
;; docs/reference/host-commands.md, RunCode.
;; ----------------------------------------------------------------------------------------
run_code:
                .assume run_code - 0x1C2D ;; must stay at $1C2D
                ;; Save the firmware's MMU settings.
                in0     a, (CBAR)       ; 3A = CBAR (MMU Common/Bank Area Register)
                ld      (firmware_cbar), a
                in0     a, (BBR)        ; 39 = BBR (MMU Bank Base Register)
                ld      (firmware_bbr), a
                in0     a, (CBR)        ; 38 = CBR (MMU Common Base Register)
                ld      (firmware_cbr), a
                ;; Write cmd_param4 (the code's address) into the CALL below, then
                ;; load the caller's MMU settings: cmd_param1+1 = CBAR,
                ;; cmd_param3 = BBR, cmd_param1 = CBR.
                ld      a, (cmd_param4)
                ld      (call_user_code+1), a
                ld      a, (cmd_param4+1)
                ld      (call_user_code+2), a
                ld      a, (cmd_param1+1)
                ld      a, a
                out0    (CBAR), a       ; Set CBAR
                ld      a, (cmd_param3)
                ld      a, a
                out0    (BBR), a        ; Set BBR
                ld      a, (cmd_param1)
                ld      a, a
                out0    (CBR), a        ; Set CBR

call_user_code:
                ;; The CALL's address is rewritten each time; the $0000 assembled here is
                ;; only its starting value. The code runs inside the INT1 handler, with
                ;; interrupts off.
                call    reset_vector
                ;; Put the firmware's MMU settings back and return to the dispatcher.
                ld      a, (firmware_bbr)
                ld      a, a
                out0    (BBR), a
                ld      a, (firmware_cbr)
                ld      a, a
                out0    (CBR), a
                ld      a, (firmware_cbar)
                ld      a, a
                out0    (CBAR), a
                ret
firmware_cbar:
                .db     0
firmware_bbr:
                .db     0
firmware_cbr:
                .db     0

;; ----------------------------------------------------------------------------------------
;; Command $0B, SetShadow (value): writes value OR $08 to port $A1. Bit 2 stops all
;; copying (COPY_INHIBIT); bit 3 is IIgs mode (MODE_D3), always kept on.
;; ----------------------------------------------------------------------------------------
set_shadow:
                ;; Bit 3 (IIgs mode) always stays on.
                ld      a, (cmd_param1)
                or      #8
                ld      a, a
                out0    (CARD_CONFIG), a
                ret

;; ----------------------------------------------------------------------------------------
;; Puts the handler address in BC into the dispatch table entry for the event address
;; byte in A: $1800+A gets the low byte, $1900+A the high byte.
;; ----------------------------------------------------------------------------------------
set_softswitch_handler:
                .assume set_softswitch_handler - 0x1C86 ;; must stay at $1C86
                ;; H = the table's page, L = the event address byte.
                ld      h, #>event_handlers_low
                ld      l, a
                ld      (hl), c
                inc     h
                ld      (hl), b
                ret

;; ----------------------------------------------------------------------------------------
;; The event handlers, one per tracked $C0xx address. Each gets the data byte in A,
;; updates its flag, sets mode_change_pending when the display mode changes,
;; and ends with jp event_return. Several write a trace letter to the serial port (port 6).
;; The Lattice never raises $C000/$C001 events, so the 80STORE handlers never run.
;; docs/reference/z180-io-ports.md, ROM softswitch handlers.
;; ----------------------------------------------------------------------------------------
softswitch_C000_clr80col:
                ;; 80STORE off. The capture logic never raises $C000/$C001 events, so this
                ;; and the next handler never run.
                ld      a, #'F
                out0    (TDR0), a
                ld      a, #1
                ld      (store80_flag), a
                jp      event_return

softswitch_C001_set80col:
                ld      a, #'N
                out0    (TDR0), a
                ld      a, #0
                ld      (store80_flag), a
                jp      event_return

softswitch_C00C_clr80vid:
                ;; Each handler that changes the display mode asks for a mode change only
                ;; when the flag really changes.
                ld      a, #'N
                out0    (TDR0), a
                ld      a, (text80_enabled_flag)
                cp      #0
                jp      Z, event_return
                ld      a, #0
                ld      (text80_enabled_flag), a
                ld      a, #1
                ld      (mode_change_pending), a
                jp      event_return

softswitch_C00D_set80vid:
                ld      a, #'F
                out0    (TDR0), a
                ld      a, (text80_enabled_flag)
                cp      #1
                jp      Z, event_return
                ld      a, #1
                ld      (text80_enabled_flag), a
                ld      a, #1
                ld      (mode_change_pending), a
                jp      event_return

softswitch_C00E_clraltchar:
                ;; Normal character set: the first pair of character tables.
                ld      a, #0
                ld      (altcharset_flag), a
                ld      a, #'M
                out0    (TDR0), a
                ld      hl, #normal_char_codes
                ld      (char_code_table), hl
                ld      hl, #normal_char_attrs
                ld      (char_attr_table), hl
                jp      event_return

softswitch_C00F_setaltchar:
                ;; Alternate character set (MouseText): the second pair.
                ld      a, #1
                ld      (altcharset_flag), a
                ld      hl, #alt_char_codes
                ld      (char_code_table), hl
                ld      hl, #alt_char_attrs
                ld      (char_attr_table), hl
                jp      event_return

;; ----------------------------------------------------------------------------------------
;; $C022, the IIgs text and background colors: stored for the text palettes
;; (set_textmode_palette). The renderers notice the change and reload the palette.
;; ----------------------------------------------------------------------------------------
softswitch_C022_tbcolor:
                ld      (text_colour), a
                jp      event_return

;; ----------------------------------------------------------------------------------------
;; $C029, NEWVIDEO: bit 7 = Super Hi-Res, bit 5 = monochrome double hires. Turning Super
;; Hi-Res on asks for a mode change, unless the Super Hi-Res renderer (emulate_superhires,
;; $A12F) is already running.
;; ----------------------------------------------------------------------------------------
softswitch_C029_newvideo:
                ;; Super Hi-Res on: ask for a mode change, unless the renderer in use is
                ;; already emulate_superhires (then cancel any pending change).
                ld      (newvideo_flag), a
                bit     7, a
                jr      Z, newvideo_shr_off
                ld      a, #1
                ld      (shr_enabled_flag), a
                ld      a, (emulate_current_videomode)
                cp      #<emulate_superhires
                jr      NZ, newvideo_mode_change
                ld      a, (emulate_current_videomode+1)
                cp      #>emulate_superhires
                jr      NZ, newvideo_mode_change
                ld      a, #0
                ld      (mode_change_pending), a
                jp      event_return

newvideo_mode_change:
                ld      a, #1
                ld      (mode_change_pending), a
                jp      event_return

newvideo_shr_off:
                ;; Super Hi-Res off: ask for a mode change if it was on.
                ld      a, (shr_enabled_flag)
                cp      #0
                jp      Z, event_return
                ld      a, #0
                ld      (shr_enabled_flag), a
                ld      a, #1
                ld      (mode_change_pending), a
                jp      event_return

softswitch_C02B_langsel:
                ld      (language), a
                jp      event_return

softswitch_C050_txtclr:
                ;; Graphics. The serial port gets a trace character.
                ld      a, #'$
                out0    (TDR0), a
                ld      a, (text_flag)
                cp      #0
                jp      Z, event_return
                ld      a, #0
                ld      (text_flag), a
                ld      a, #1
                ld      (mode_change_pending), a
                jp      event_return

softswitch_C051_txtset:
                ld      a, #'#
                out0    (TDR0), a
                ld      a, (text_flag)
                cp      #1
                jp      Z, event_return
                ld      a, #1
                ld      (text_flag), a
                ld      a, #1
                ld      (mode_change_pending), a
                jp      event_return

softswitch_C052_mixclr:
                ;; Mixed mode, page 1 and page 2 only update their flag: the renderers read
                ;; them on every pass, so no mode change is needed.
                ld      a, #0
                ld      (mixed_mode_flag), a
                jp      event_return

softswitch_C053_mixset:
                ld      a, #1
                ld      (mixed_mode_flag), a
                jp      event_return

softswitch_C054_page1:
                ld      a, #0
                ld      (current_page), a
                jp      event_return

softswitch_C055_page2:
                ld      a, #1
                ld      (current_page), a
                jp      event_return

softswitch_C056_lores:
                ld      a, #'L
                out0    (TDR0), a
                ld      a, (hires_flag)
                cp      #0
                jp      Z, event_return
                ld      a, #0
                ld      (hires_flag), a
                ld      a, #1
                ld      (mode_change_pending), a
                jp      event_return

softswitch_C057_hires:
                ld      a, #'L
                out0    (TDR0), a
                ld      a, (hires_flag)
                cp      #1
                jp      Z, event_return
                ld      a, #1
                ld      (hires_flag), a
                ld      (mode_change_pending), a
                jp      event_return

softswitch_C05E_setan3:
                ;; $C05E (AN3 off): double-width graphics, the double hires and double
                ;; lores condition.
                ld      a, (doublewidth_flag)
                cp      #1
                jp      Z, event_return
                ld      a, #1
                ld      (doublewidth_flag), a
                ld      (mode_change_pending), a
                jp      event_return

softswitch_C05F_clran3:
                ld      a, (doublewidth_flag)
                cp      #0
                jp      Z, event_return
                ld      a, #0
                ld      (doublewidth_flag), a
                ld      a, #1
                ld      (mode_change_pending), a
                jp      event_return
