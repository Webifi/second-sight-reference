;; v2.0/src/interrupts.asm: v1.4/src/interrupts.asm with the changes for a card with the corrected
;; U7 (fuse map BBB1); SecondSight_v2_0.asm includes it. Every change from
;; v1.4/src/ is marked CHANGE (En). En refers to docs/reference/errata.md.

;; ----------------------------------------------------------------------------------------
;; ==== $0C00-$1FFF: interrupts, the host command handlers, the event handlers and the
;; main loop. All of it is copied into SRAM at boot.
;;
;; The Z180 interrupt vector table. I = $0C (set_interrupt_vector) and IL = 0, so the
;; vector for each interrupt source is the word at $0C00 + 2 x its number. Only INT1 is
;; ever enabled. docs/reference/z180-memory-map.md, Interrupt vectors.
;; ----------------------------------------------------------------------------------------
interrupt_vector_table:
                .dw     int1_handler    ; INT1: Apple events (capture logic U7)
                .assume interrupt_vector_table - 0x0C00 ;; must stay at $0C00
                .dw     int2_handler    ; INT2: never enabled
                .dw     0               ; timer 0
                .dw     0               ; timer 1
                .dw     0               ; DMA channel 0
                .dw     0               ; DMA channel 1
                .dw     0               ; CSI/O
                .dw     0               ; ASCI channel 0
                .dw     0               ; ASCI channel 1

;; ----------------------------------------------------------------------------------------
;; Three hook slots, each a handler address or 0 when unused. set_interrupt_hook writes
;; slot 0 (int1_hook) or slot 1 (int2_hook); call_hl_if_set calls a slot's handler. None of
;; the three is read by code that runs: hook_slot0 by the unreached code after rst38_handler,
;; int1_hook by the unreached old INT1 handler, int2_hook by int2_handler (INT2 is off).
;; ----------------------------------------------------------------------------------------
hook_slot0:     .dw     0
int1_hook:      .dw     0
int2_hook:      .dw     0

;; ----------------------------------------------------------------------------------------
;; Sets the interrupt vector register I to $0C (the table at $0C00).
;; ----------------------------------------------------------------------------------------
set_interrupt_vector:
                ld      a, #>(interrupt_vector_table) ; INT1 vector
                ld      i, a
                ret

;; ----------------------------------------------------------------------------------------
;; Writes a handler address into a hook slot. Arguments on the stack: slot number (0 =
;; INT1 slot $0C14, 1 = INT2 slot $0C16) and the address. setup_softswitch_handlers puts
;; handle_event into the INT1 slot, which int1_handler does not read.
;; ----------------------------------------------------------------------------------------
set_interrupt_hook:
                ;; Take the two arguments from under the return address, leave the stack as
                ;; it was.
                pop     hl
                pop     bc
                pop     de
                push    de
                push    bc
                push    hl
                push    ix
                push    iy
                ;; Slot address = $0C12 + 2 x (slot + 1): slot 0 is $0C14, slot 1 is $0C16.
                ld      hl, #0xC12
                ld      b, #0
                sla     c
                add     hl, bc
                inc     hl
                inc     hl
                ld      (hl), e
                inc     hl
                ld      (hl), d
                pop     iy
                pop     ix
                ret

;; ----------------------------------------------------------------------------------------
;; Calls the handler at HL, unless HL is 0.
;; ----------------------------------------------------------------------------------------
call_hl_if_set:
                ld      a, h
                or      l
                ret     Z
                jp      (hl)

;; ----------------------------------------------------------------------------------------
;; Small helpers: interrupt mode 0, 1 or 2; EI; DI.
;; ----------------------------------------------------------------------------------------
set_interrupt_mode0:
                im      0
                ret

set_interrupt_mode1:
                im      1
                ret

set_interrupt_mode2:
                im      2
                ret

enable_interrupts:
                ei
                ret

disable_interrupts:
                di
                ret

;; ----------------------------------------------------------------------------------------
;; RST $38 target: writes '*' to the serial port's transmit register (ASCI channel 0,
;; port 6), a trace mark. The routine after it calls the hook in slot $0C12.
;; ----------------------------------------------------------------------------------------
rst38_handler:
                di
                push    af
                push    bc
                ld      a, #'*
                out0    (TDR0), a
                pop     bc
                pop     af
                ei
                ret
;; Unreachable: no vector or call leads here. Calls the hook in hook_slot0 and
;; returns with interrupts on.
call_hook_slot0:
                push    af
                push    hl
                push    bc
                push    de
                ld      hl, (hook_slot0)
                call    call_hl_if_set
                pop     de
                pop     bc
                pop     hl
                pop     af
                ei
                ret

;; ----------------------------------------------------------------------------------------
;; Turn INT0 on or off (ITC bit 0). INT0 is the Oak's vertical retrace interrupt,
;; which has no pull-up on this card; ROM 1.4 never turns it on.
;; ----------------------------------------------------------------------------------------
enable_int0:
                in0     a, (ITC)
                set     0, a
                ld      a, a
                out0    (ITC), a
                ret

disable_int0:
                in0     a, (ITC)
                res     0, a
                ld      a, a
                out0    (ITC), a
                ret

;; ----------------------------------------------------------------------------------------
;; INT1 entry, through the vector at $0C00: jumps straight to handle_event. The code after
;; the JP (reads port $A0, calls the hook in slot $0C14, RETI) is unreachable.
;; ----------------------------------------------------------------------------------------
int1_handler:
                .assume int1_handler - 0x0C7A ;; must stay at $0C7A
                jp      handle_event
;; Unreachable INT1 handler: saves the event's data byte, calls the hook in
;; int1_hook and returns from the interrupt.
old_int1_handler:
                push    af
                in0     a, (CARD_DATA)
                ld      (unused_1A35), a ; Data bus value at the INT1 interrupt; unused.
                push    hl
                push    bc
                push    de
                ld      hl, (int1_hook)
                call    call_hl_if_set
                pop     de
                pop     bc
                pop     hl
                pop     af
                ei
                reti

;; ----------------------------------------------------------------------------------------
;; Turn INT1 (Apple events) on or off: ITC bit 1.
;; ----------------------------------------------------------------------------------------
enable_int1:
                in0     a, (ITC)
                set     1, a
                ld      a, a
                out0    (ITC), a
                ret

disable_int1:
                in0     a, (ITC)
                res     1, a
                ld      a, a
                out0    (ITC), a
                ret

;; ----------------------------------------------------------------------------------------
;; INT2: calls the hook in slot $0C16 if one is set. ROM 1.4 never enables INT2.
;; ----------------------------------------------------------------------------------------
int2_handler:
                di
                push    af
                push    hl
                push    bc
                push    de
                ld      hl, (int2_hook)
                call    call_hl_if_set
                pop     de
                pop     bc
                pop     hl
                pop     af
                ei
                ret

;; ----------------------------------------------------------------------------------------
;; Turn INT2 on or off: ITC bit 2.
;; ----------------------------------------------------------------------------------------
enable_int2:
                in0     a, (ITC)
                set     2, a
                ld      a, a
                out0    (ITC), a
                ret

disable_int2:
                in0     a, (ITC)
                res     2, a
                ld      a, a
                out0    (ITC), a
                ret
                .db     0
                .db     0

;; ----------------------------------------------------------------------------------------
;; The palette address source bit last written to the attribute controller's index
;; register: $20 = the display uses the palette (normal), $00 = the CPU may change it.
;; ----------------------------------------------------------------------------------------
palette_access_flag:
                .db     0
                                        ; 00 = host has access to palette, 20 = display has access to palette
                .db     0
                .db     0
unused_CD2:     .db     0

;; ----------------------------------------------------------------------------------------
;; Parameters of the next DMA job, shared by upload, scroll, fill, palette and mode code:
;; dma_source + dma_source_bank = source address and bank (or the I/O port, $A0, for transfers
;; from the IIgs), dma_dest + dma_dest_bank = destination address and bank, dma_count = byte
;; count (0 = 64 KB).
;; ----------------------------------------------------------------------------------------
dma_source:     .dw     0
dma_source_bank:
                .db     0
dma_dest:       .dw     0
dma_dest_bank:  .db     0
dma_count:      .dw     0
                .db     0, 0, 0, 0, 0, 0, 0
