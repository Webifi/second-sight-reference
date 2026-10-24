;; v1.5/src/boot.asm: v1.4/src/boot.asm with the changes for a card with the original
;; U7 (fuse map BE8C); SecondSight_v1_5.asm includes it. Every change from
;; v1.4/src/ is marked CHANGE (En). En refers to docs/reference/errata.md.

;; ----------------------------------------------------------------------------------------
;; Reset entry. After a reset the Z180 starts here with the EPROM mapped at address 0
;; (GAL U15 maps it while the Z180's /RTS0 pin is high). RunCode with address 0 also
;; lands here (run_code rewrites the CALL at call_user_code), which restarts the firmware
;; without the EPROM copy.
;; ----------------------------------------------------------------------------------------
reset_vector:
                jp      Reset

;; ========================================================================================
;; FREE SPACE $0003-$0037 (53 bytes).
;; Zero in ROM 1.4 and never run: the only RST it executes is RST $38. Copied into
;; SRAM at boot and always mapped (common area 0), so code here can be called from
;; anywhere.
;; Put new code or data between the label and the .org; the .org keeps what follows
;; at $0038.
;; ========================================================================================
free_0003:
                .org    0x0038

;; ----------------------------------------------------------------------------------------
;; RST $38 entry: jumps to rst38_handler, which writes '*' to the Z180 serial port. ROM 1.4 runs
;; no other RST; the bytes around this are free space.
;; ----------------------------------------------------------------------------------------
rst38_vector:
                jp      rst38_handler

;; ========================================================================================
;; FREE SPACE $003B-$007F (69 bytes).
;; Zero in ROM 1.4 and never run. $0066 is the NMI entry; NMI is held inactive by its
;; pull-up, so code may cover it. Copied into SRAM at boot and always mapped.
;; Put new code or data between the label and the .org; the .org keeps what follows
;; at $0080.
;; ========================================================================================
free_003B:
                ;; Interrupts off. Release the Apple IRQ line, turn on IIgs mode with
                ;; copying on (CARD_CONFIG = $08), and clear the linear-window flag.
                .org    0x0080

;; ----------------------------------------------------------------------------------------
;; Boot (docs/05-z180.md, Boot):
;;   1. Interrupts off; port $AD releases the Apple IRQ; port $A1 = $08 turns on IIgs
;;      mode (MODE_D3) with copying on; any access to port $AA clears the linear video
;;      window flag.
;;   2. MMU: CBAR $F0, CBR $21, so logical $F000-$FFFF is physical $30000-$30FFF (the SRAM
;;      mirror), and SP = $F0FF there. Memory refresh, INT0-2, the timers, DMA, CSI/O and
;;      ASCI interrupts off. ("ld a, a" does nothing; the ROM has many of these.)
;;   3. Writes $01 to $01FD and reads it back. A 0 means the EPROM is still mapped at 0
;;      (a cold start): DMA copies EPROM $0000-$03FF, $0C00-$1FFF and $6000-$FFFF to
;;      physical $2xxxx (the SRAM mirror, so SRAM bank 0 at the same addresses), then
;;      clears CNTLA0 bit 4: /RTS0 goes low and SRAM appears at address 0. A 1 means SRAM
;;      is already mapped (RunCode jumped to $0000), and the copy is skipped (start_firmware).
;;   4. start_firmware: DCNTL = 0, SP = $03FF, Oak add-on mode, interrupt vector table, event
;;      handler table (setup_softswitch_handlers), INT1 on, port $A0 = 0 (event handshake
;;      idle: this access also acknowledges any event pending since power-up), the normal
;;      MMU layout (CBAR $F2, BBR 0, CBR 0), interrupts on, then the main loop at $1E01.
;; The start-up state asks for a mode change to Apple 40-column text.
;; ----------------------------------------------------------------------------------------
Reset:
                .assume Reset - 0x0080  ;; must stay at $0080
                di                      ; Disable interrupts
                ld      a, #0
                out0    (APPLE_IRQ_OFF), a
                ld      a, #8
                out0    (CARD_CONFIG), a
                in0     a, (LINEAR_OFF)
                ;; MMU: logical $F000-$FFFF is common area 1. CBR $21 puts it at physical
                ;; $30000-$30FFF ($F000 + $21000), the SRAM, so the stack at $F0FF works
                ;; before SRAM is mapped at 0.
                ld      a, #0xF0        ; 0000-EFFF = Bank Area
                                        ; F000-FFFF = Common Area 1
                out0    (CBAR), a
                ld      a, #0x21        ; Common Area 1 = 2/1000
                out0    (CBR), a
                ld      a, #0
                out0    (BBR), a
                ld      hl, #0xF0FF
                ld      sp, hl          ; Stack = F0FF
                ;; Turn off what the firmware does not use: memory refresh (static RAM
                ;; needs none), INT0-INT2, the timer interrupts, the DMA interrupts, the
                ;; CSI/O interrupt and the two serial port receive interrupts. Each step
                ;; reads the register, clears bits, writes it.
                ld      a, #0           ; Disable memory refresh (SRAM doesn't require refresh)
                out0    (RCR), a
                in0     a, (ITC)
                res     0, a
                res     1, a
                res     2, a
                ld      a, a
                out0    (ITC), a
                in0     a, (TCR)
                res     4, a
                res     5, a
                ld      a, a
                out0    (TCR), a
                in0     a, (DSTAT)
                res     2, a
                res     3, a
                ld      a, a
                out0    (DSTAT), a
                in0     a, (CNTR)
                res     6, a
                ld      a, a
                out0    (CNTR), a
                in0     a, (STAT0)
                res     0, a
                ld      a, a
                out0    (STAT0), a
                in0     a, (STAT1)
                res     0, a
                ld      a, a
                out0    (STAT1), a
                ;; Write $01 to sram_test_byte and read it back. With the EPROM still at
                ;; address 0 the read returns the EPROM's $00 (a cold start); with SRAM
                ;; there it returns $01 (RunCode jumped to $0000), and the copy below is
                ;; skipped.
                ld      a, #1
                ld      (sram_test_byte), a
                ld      a, (sram_test_byte)
                cp      #1
                jp      Z, start_firmware

; Source address = 00/0000
                ;; Cold start: copy the three parts of the EPROM the card runs from into
                ;; SRAM bank 0, each with one burst DMA transfer on channel 0 from physical
                ;; $0xxxx (EPROM) to $2xxxx (the same SRAM, seen at its own address before
                ;; the swap). DMODE: memory to memory, both addresses counting up, burst
                ;; mode. DSTAT bit 6 and bit 0 start channel 0; the CPU waits until the
                ;; transfer is done.
                ld      a, #0
                out0    (SAR0L), a
                ld      a, #0
                out0    (SAR0H), a
                ld      a, #0
                out0    (SAR0B), a

; Destination address = 02/0000
                ld      a, #0
                out0    (DAR0L), a
                ld      a, #0
                out0    (DAR0H), a
                ld      a, #2
                out0    (DAR0B), a

; Size = 0400
                ld      a, #0
                out0    (BCR0L), a
                ld      a, #4
                out0    (BCR0H), a
                in0     a, (DMODE)
                or      #2
                and     #0xC3
                ld      a, a
                out0    (DMODE), a
                in0     a, (DSTAT)
                or      #0x41
                and     #0xEF
                ld      a, a
                out0    (DSTAT), a

; Source address = 00/0C00
                ;; Second copy: $0C00-$1FFF ($1400 bytes).
                ld      a, #0
                out0    (SAR0L), a
                ld      a, #0xC
                out0    (SAR0H), a
                ld      a, #0
                out0    (SAR0B), a

; Destination address = 02/0C00
                ld      a, #0
                out0    (DAR0L), a
                ld      a, #0xC
                out0    (DAR0H), a
                ld      a, #2
                out0    (DAR0B), a

; Size = 1400
                ld      a, #0
                out0    (BCR0L), a
                ld      a, #0x14
                out0    (BCR0H), a
                in0     a, (DMODE)
                or      #2
                and     #0xC3
                ld      a, a
                out0    (DMODE), a
                in0     a, (DSTAT)
                or      #0x41
                and     #0xEF
                ld      a, a
                out0    (DSTAT), a

; Source address = 00/6000
                ;; Third copy: $6000-$FFFF ($A000 bytes).
                ld      a, #0
                out0    (SAR0L), a
                ld      a, #0x60
                out0    (SAR0H), a
                ld      a, #0
                out0    (SAR0B), a

; Destination address = 02/6000
                ld      a, #0
                out0    (DAR0L), a
                ld      a, #0x60
                out0    (DAR0H), a
                ld      a, #2
                out0    (DAR0B), a

; Size = A000
                ld      a, #0
                out0    (BCR0L), a
                ld      a, #0xA0
                out0    (BCR0H), a
                in0     a, (DMODE)
                or      #2
                and     #0xC3
                ld      a, a
                out0    (DMODE), a
                in0     a, (DSTAT)
                or      #0x41
                and     #0xEF
                ld      a, a
                out0    (DSTAT), a
                ;; Clear CNTLA0 bit 4. The serial port's /RTS0 pin goes low, and GAL U15
                ;; then maps SRAM at address 0 in place of the EPROM. The next instruction
                ;; already runs from the SRAM copy.
                in0     a, (CNTLA0)     ; Read ASCI Channel Control Register A
                res     4, a            ; Clear /RTS0
                ld      a, a
                out0    (CNTLA0), a     ; Update ASCI Channel Control Register A

;; ----------------------------------------------------------------------------------------
;; Both starts meet here: after the EPROM copy on a cold start, or straight from the $01FD
;; test when SRAM was already mapped. The code after "jp main_loop" below (another MMU
;; setup and jump, and a routine that clears /RTS0) is never reached.
;; ----------------------------------------------------------------------------------------
start_firmware:
                ;; DMA waits off, and the stack moves to the top of the stack area
                ;; ($032E-$03FF).
                ld      a, #0
                out0    (DCNTL), a
                ld      hl, #0x3FF
                ld      sp, hl          ; Stack = 03FF
                ;; Turn on the VGA chip, point I at the interrupt vector table, fill the
                ;; event dispatch table, and turn on INT1 (the Apple events).
                call    enable_oak_add_on_mode
                call    set_interrupt_vector
                call    setup_softswitch_handlers
                call    enable_int1
                ;; Any access to CARD_DATA acknowledges an event. This one clears an event
                ;; that arrived before INT1 was on.
                ld      a, #0
                out0    (CARD_DATA), a
                ;; The normal MMU layout: CBAR $F2 (bank area from $2000, common area 1
                ;; from $F000), BBR 0 and CBR 0, so logical address = physical address in
                ;; SRAM bank 0. The BBR and CBR writes are made twice.
                ld      a, #0xF2
                out0    (CBAR), a
                ld      a, #0
                out0    (BBR), a
                ld      a, #0
                out0    (CBR), a
                ld      a, #0
                out0    (BBR), a
                ld      a, #0
                out0    (CBR), a
                ;; Interrupts on and into the main loop.
                ei
                jp      main_loop

                ;; Never reached: the same MMU setup again and a jump to the main loop.
                ld      a, #0xF2
                out0    (CBAR), a
                ld      a, #0
                out0    (BBR), a
                ld      a, #0
                out0    (CBR), a
                jp      main_loop

;; ----------------------------------------------------------------------------------------
;; The boot's SRAM test byte (see Reset, step 3). On a cold start the write goes to the
;; EPROM, which drives the bus against the CPU for one cycle (docs/reference/
;; z180-memory-map.md, EPROM write contention); the read returns the EPROM's $00.
;; ----------------------------------------------------------------------------------------
sram_test_byte:
                .db     0
                ;; Never reached: clears /RTS0 like the boot code above, then returns.
                in0     a, (CNTLA0)     ; Read ASCI Channel Control Register A
                res     4, a            ; Clear /RTS0
                ld      a, a
                out0    (CNTLA0), a     ; Update ASCI Channel Control Register A
                ret

;; ----------------------------------------------------------------------------------------
;; Never called: no call, jump or pointer in ROM 1.4 leads here. It would set a 256-color
;; mode (640 x 480 on a VGA monitor, 640 x 400 on AppleColor RGB), load a palette and
;; unpack a boot picture from the EPROM's upper 64 KB (all zero in ROM 1.4), keeping an
;; $A5 signature at $FFFF in the bank it maps. Treat it as unfinished code.
;; ----------------------------------------------------------------------------------------
show_startup_picture:
                ;; The byte at $0208 doubles as the one-byte DMA source: the unpacker
                ;; stores each color there, and channel 0 copies it (source address fixed)
                ;; to the screen.
                nop
                ;; Map the upper EPROM page at logical $F000 (CBR $30) and look for the $A5
                ;; mark at $FFFF. The mark means the picture has been shown since power-up;
                ;; otherwise set it.
                ld      a, #0xF2
                out0    (CBAR), a
                ld      a, #0xE
                out0    (BBR), a
                ld      a, #0x30
                out0    (CBR), a
                ld      a, (picture_signature)
                cp      #0xA5
                ret     Z
                ld      a, #0xA5
                ld      (picture_signature), a
                ;; Pick the 256-color mode for the monitor: $61 (640 x 400) on AppleColor
                ;; RGB, $53 (640 x 480) on a VGA monitor (input status 0, bit 4 = monitor
                ;; sense).
                ld      bc, #VGA_STATUS0
                in      a, (c)
                bit     4, a
                jr      NZ, startup_picture_vga
                ld      a, #0x61
                call    set_video_mode
                jr      startup_picture_mode_set

startup_picture_vga:
                ld      a, #0x53
                call    set_video_mode

startup_picture_mode_set:
                ;; Screen off while the picture is drawn. Map the EPROM's upper 64 KB at
                ;; logical $2000 (BBR $6E: physical $70000) and load the palette, 768 bytes
                ;; at its start.
                call    screen_off
                ld      a, #0xF2
                out0    (CBAR), a
                ld      a, #0x6E
                out0    (BBR), a
                ld      a, #0x30
                out0    (CBR), a
                call    set_vga_palette
                ;; Point the VGA chip's 1 MB linear window at the Z180's physical
                ;; $80000-$FFFFF (LINEAR_ON plus Oak register 5 = $19), so DMA can write
                ;; the screen directly.
                ld      a, #0
                out0    (LINEAR_ON), a
                call    access_softswitch0
                ld      a, #5
                ld      bc, #OAK_INDEX
                out     (c), a          ; Select Oak video memory mapping register
                ld      a, #0x19        ; bit 0 = Use Oak memory mapping (not VGA)
                                        ; bit 1 = DMA
                                        ; bit 2/3 = 1M aperture
                                        ; bit 4-7 = start address 0x100000 (start of linear address range)
                ld      bc, #OAK_DATA
                out     (c), a
                ;; DMA channel 0: source $00208 (the one-byte buffer, held fixed),
                ;; destination $80000 (the first screen byte). BC = $A01B bytes of packed
                ;; picture data, read from $2300.
                ld      a, #8
                out0    (SAR0L), a
                ld      a, #2
                out0    (SAR0H), a
                ld      a, #0
                out0    (SAR0B), a
                ld      a, #0
                out0    (DAR0L), a
                ld      a, #0
                out0    (DAR0H), a
                ld      a, #8
                out0    (DAR0B), a
                ld      bc, #0xA01B
                ld      hl, #0x2300

unpack_loop:
                ;; Packed data: a byte other than $FE is one pixel of that color. $FE
                ;; starts a run: color byte, then a 16-bit count (low byte first).
                ld      a, (hl)
                cp      #0xFE
                jr      Z, unpack_run
                ld      (show_startup_picture), a
                inc     hl
                dec     bc
                ld      a, #1
                out0    (BCR0L), a
                jr      unpack_next

unpack_run:
                inc     hl
                dec     bc
                ld      a, (hl)
                ld      (show_startup_picture), a
                inc     hl
                dec     bc
                ld      a, (hl)
                out0    (BCR0L), a
                inc     hl
                dec     bc
                ld      a, (hl)
                out0    (BCR0H), a
                inc     hl
                dec     bc

unpack_next:
                ;; Send the pixel or run, and loop until the packed data is used up.
                call    start_dma0_fixed_source
                ld      a, b
                or      c
                jr      NZ, unpack_loop
                ;; Fill the rest of the screen with color $FF: a count of 0 (64 KB), then
                ;; $6080 bytes.
                ld      a, #0xFF
                ld      (show_startup_picture), a
                call    start_dma0_fixed_source
                ld      a, #0x80
                out0    (BCR0L), a
                ld      a, #0x60
                out0    (BCR0H), a
                call    start_dma0_fixed_source
                ;; Back to the normal VGA memory map, linear window off, screen on.
                ld      a, #5
                ld      bc, #OAK_INDEX
                out     (c), a          ; Select Oak video memory mapping register
                ld      a, #0           ; Standard VGA memory map
                ld      bc, #OAK_DATA
                out     (c), a
                call    access_softswitch1
                ld      a, #0
                out0    (LINEAR_OFF), a
                call    screen_on
                ;; Leave the picture up for a while: 30 x 65,535 turns of a delay loop.
                ld      c, #0x1E
                ld      de, #0xFFFF

startup_picture_delay:
                dec     de
                ld      a, e
                or      d
                cp      #0
                jr      NZ, startup_picture_delay
                dec     c
                jr      NZ, startup_picture_delay
                ret

;; ----------------------------------------------------------------------------------------
;; Starts DMA channel 0 for show_startup_picture's picture unpacking. Only show_startup_picture calls it.
;; ----------------------------------------------------------------------------------------
start_dma0_fixed_source:
                ;; DMODE: source address fixed, destination counting up, burst mode.
                in0     a, (DMODE)
                or      #0xA
                and     #0xCB
                ld      a, a
                out0    (DMODE), a
                in0     a, (DSTAT)
                or      #0x41
                and     #0xEF
                ld      a, a
                out0    (DSTAT), a
                ret

;; ----------------------------------------------------------------------------------------
;; Loads all 256 DAC entries from 768 bytes (red, green, blue per color) at logical $2000,
;; as show_startup_picture maps it. Only show_startup_picture calls it.
;; ----------------------------------------------------------------------------------------
set_vga_palette:
                ld      a, #0xFF
                ld      bc, #VGA_PEL_MASK
                out     (c), a
                ld      a, #0
                ld      bc, #VGA_DAC_WRITE_INDEX ; DAC write address
                out     (c), a
                ld      de, #0x300      ; Copy 256*3 bytes
                ld      hl, #0x2000

set_vga_palette_loop:
                ld      a, (hl)
                ld      a, a
                ld      bc, #VGA_DAC_DATA ; DAC data
                out     (c), a
                inc     hl
                dec     de
                ld      a, e
                or      d
                jr      NZ, set_vga_palette_loop
                ret

                ;; A lone RET that nothing calls.
                ret

;; ----------------------------------------------------------------------------------------
;; Empty debug hooks. Callers pass a byte in A (log_debug_byte), a character in A (log_debug_char)
;; or a string in HL (log_debug_string); each returns at once. Some event handlers write
;; trace characters to the serial port (port 6) directly instead.
;; ----------------------------------------------------------------------------------------
log_debug_byte:
                ret

;; log_debug_string: takes a string address in HL and returns at once.
log_debug_string:
                ret

log_debug_char:
                ret                     ; Restore the one-byte collapsed routine from the dump.
stack:                                  ; 210 bytes reserved for stack
;; $032E-$03FF (210 bytes).
;; The stack: the boot code sets SP = $03FF, and the stack grows down from there.
                .ds     210
;; $0400-$0BFF (2,048 bytes).
;; Not copied into SRAM at boot. At run time SRAM bank 0 $0400-$0BFF holds the Apple's
;; text and lores pages 1 and 2 (the screen copy), so these zero EPROM bytes are not free.
                .ds     2048
