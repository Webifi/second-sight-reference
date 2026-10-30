;; v1.5/src/commands.asm: v1.4/src/commands.asm with the changes for a card with the original
;; U7 (fuse map BE8C); SecondSight_v1_5.asm includes it. Every change from
;; v1.4/src/ is marked CHANGE (En). En refers to docs/reference/errata.md.

;; ----------------------------------------------------------------------------------------
;; Command $05, ScreenOn, and used after mode sets: clears bit 5 of the sequencer's
;; clocking mode register (screen on). screen_off (command $04) sets it.
;; ----------------------------------------------------------------------------------------
screen_on:
                ;; log_debug_string does nothing; the string and the jump around it are
                ;; left from a debug build.
                push    hl
                ld      hl, #screen_on_debug_msg ; "\r\nscreen on\r\n"
                call    log_debug_string
                jp      screen_on2
screen_on_debug_msg:
                .db     0xD, 0xA
                .ascii  'screen on'
                .db     0xD, 0xA, 0
                .db     0xFF            ;; one byte after the string, never run (IDA showed RST $38)

screen_on2:
                ;; Sequencer register 1, bit 5: 0 = screen on.
                pop     hl
                ld      a, #1
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a          ; select Sequencer Clocking Mode Register (1)
                ld      bc, #VGA_SEQ_DATA
                in      a, (c)          ; read existing settings
                res     5, a            ; but turn off bit 5 ("0=screen is turned on")
                ld      d, a
                ld      a, #1
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a          ; select Sequencer Clocking Mode Register (1)
                ld      a, d
                ld      bc, #VGA_SEQ_DATA
                out     (c), a          ; write the updated clocking mode
                ret

;; screen_off: command $04, ScreenOff.
screen_off:
                ;; Sequencer register 1, bit 5: 1 = screen off. The display stops reading
                ;; video memory, which also gives the CPU faster access.
                ld      a, #1
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a          ; select Sequencer Clocking Mode Register (1)
                ld      bc, #VGA_SEQ_DATA
                in      a, (c)          ; read existing settings
                set     5, a            ; but turn on bit 5 ("1=screen is turned off")
                ld      d, a
                ld      a, #1
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a          ; select Sequencer Clocking Mode Register (1)
                ld      a, d
                ld      bc, #VGA_SEQ_DATA
                out     (c), a          ; write the updated clocking mode
                ret

;; ----------------------------------------------------------------------------------------
;; Command $06, SetPalette (3 ignored bytes, then 768 bytes: red, green, blue for each
;; of 256 colors). The bulk bytes arrive by DMA from port $A0 into an SRAM buffer, then
;; go to the DAC. The MMU is restored afterwards. docs/reference/host-commands.md, Palette
;; commands.
;; CHANGE (E10): the buffer comes from palette_bbr, palette_dest and palette_src
;; (src/mainloop.asm). Their reset values are ROM 1.4's: SRAM $0F000, seen at logical
;; $2000 with BBR $0D. While SetTextFont's user font is chosen, set_text_font
;; (src/text.asm) points them at command_buffer instead, because the user font lives at
;; $0F000 and the text set-ups reload it from there.
;; ----------------------------------------------------------------------------------------
set_palette:
                ;; PEL mask $FF, and start writing at DAC entry 0.
                ld      a, #0xFF
                ld      bc, #VGA_PEL_MASK
                out     (c), a          ; PEL Mask Register = 0xFF
                ld      a, #0
                ld      bc, #VGA_DAC_WRITE_INDEX
                out     (c), a          ; Palette Address (Write Mode) Register = 0
                ;; Save the MMU and map the buffer at logical palette_src (CBAR $F2, BBR
                ;; palette_bbr).
                in0     a, (CBR)
                ld      (backup_cbr), a
                in0     a, (BBR)
                ld      (backup_bbr), a
                in0     a, (CBAR)
                ld      (backup_cbar), a
                ld      a, #0xF2
                out0    (CBAR), a       ; CBAR = 0xF2
                ld      a, (palette_bbr)
                out0    (BBR), a
                ;; DMA job for copy_api_data_chunk: $300 bytes from port $A0 (the IIgs) to
                ;; the buffer, physical palette_dest.
                ld      hl, #0x300
                ld      (dma_count), hl
                ld      hl, #0xA0
                ld      (dma_source), hl
                ld      hl, (palette_dest)
                ld      (dma_dest), hl
                xor     a               ; SRAM bank 0 (one byte, where ld a,#0 took two)
                ld      (dma_dest_bank), a
                call    copy_api_data_chunk
                ;; Write the 768 bytes to the DAC data port: red, green, blue for each
                ;; entry in turn.
                ld      de, #0x300
                ld      bc, #0x3C9
                ld      hl, (palette_src)

set_host_palette_loop:
                ld      a, (hl)
                ld      a, a
                ld      bc, #VGA_DAC_DATA ; PEL data register
                out     (c), a          ; Set palette entry
                inc     hl
                dec     de
                ld      a, e
                or      d
                jr      NZ, set_host_palette_loop
                ;; Restore the MMU.
                ld      a, (backup_cbr)
                out0    (CBR), a
                ld      a, (backup_bbr)
                out0    (BBR), a
                ld      a, (backup_cbar)
                out0    (CBAR), a
                ret
backup_cbr:     .db     0
backup_bbr:     .db     0
backup_cbar:    .db     0

;; ----------------------------------------------------------------------------------------
;; Command $07, SetPaletteEntry (index, red, green, blue): one DAC entry.
;; ----------------------------------------------------------------------------------------
set_palette_entry:
                ;; PEL mask $FF. cmd_param1 = entry, cmd_param1+1 = red, cmd_param3 =
                ;; green, cmd_param4 = blue (6-bit DAC values).
                ld      a, #0xFF
                ld      bc, #VGA_PEL_MASK ; DAC PEL mask
                out     (c), a
                ld      a, (cmd_param1) ; Get palette number to change
                ld      bc, #VGA_DAC_WRITE_INDEX ; DAC Address Write Mode Register
                out     (c), a          ; Set palette number to change
                ld      a, (cmd_param1+1) ; Load Red value into Accumulator
                ld      bc, #VGA_DAC_DATA ; DAC Data Register
                out     (c), a          ; Set Red value
                ld      a, (cmd_param3) ; Load Green value into Accumulator
                ld      bc, #VGA_DAC_DATA ; DAC Data Register
                out     (c), a          ; Set Green value
                ld      a, (cmd_param4) ; Load Blue value into Accumulator
                ld      bc, #VGA_DAC_DATA ; DAC Data Register
                out     (c), a          ; Set Blue value
                ret

;; ----------------------------------------------------------------------------------------
;; Command $0E, SetUserMode: receives 84 bytes into $179A. The first 81 are the register
;; record for mode $FF, which SetMode $FF then uses.
;; ----------------------------------------------------------------------------------------
set_user_mode:
                ;; DMA job: $54 bytes from port $A0 to $0179A.
                ld      hl, #0x54
                ld      (dma_count), hl
                ld      hl, #0xA0
                ld      (dma_source), hl
                ld      hl, #0x179A
                ld      (dma_dest), hl
                ld      a, #0
                ld      (dma_dest_bank), a
                call    copy_api_data_chunk
                ret

;; ----------------------------------------------------------------------------------------
;; Command $00, GetStatus: sends, by DMA through port $A0, the signature 'GSVGA' at $11A3,
;; the size byte, version $15 ($11A9), the emulation flag, the current mode, the video
;; RAM size (always 1 = 1 MB) and the monitor sense byte (Input Status 0).
;; docs/reference/host-commands.md, GetStatus.
;; ----------------------------------------------------------------------------------------
get_status:
                ;; Fill in the status record that follows 'GSVGA'.
                ld      a, #1           ; Always return 1 = 1MB video RAM
                ld      (stat_video_ram), a
                ld      a, (emul_flag)
                ld      (stat_emul_status), a
                ld      a, (vga_mode)
                ld      (stat_vga_mode), a
                ld      bc, #VGA_STATUS0 ; Bit 4 = Sense Switch (1 = On / VGA monitor). Sense Switches are used to detect CGA monitors (i.e. 15kHz) on an EGA video card.
                in      a, (c)
                ld      (stat_monitor_type), a

; Use I/O port A0 for DMA
                ;; DMA channel 1 sends the record to port $A0, one byte for each read the
                ;; IIgs makes. Memory to I/O, edge-triggered requests.
                ld      a, #0xA0
                out0    (IAR1L), a      ; DMA I/O Address Register Ch 1L
                ld      a, #0
                out0    (IAR1H), a      ; DMA I/O Address Register Ch 1H

; Set DMA source address
                ld      a, #<(aGsvga)
                out0    (MAR1L), a      ; DMA Memory Address Register Ch 1L
                ld      a, #>(aGsvga)
                out0    (MAR1H), a      ; DMA Memory Address Register Ch 1H
                ld      a, #0
                out0    (MAR1B), a      ; DMA Memory Address Register Ch 1B

; Set DMA length
                ld      a, (stat_size)
                add     a, #7
                ld      b, a
                ld      a, b
                out0    (BCR1L), a      ; DMA Byte Count Register Ch 1L
                ld      a, #0
                out0    (BCR1H), a      ; DMA Byte Count Register Ch 1H

; Enable DMA Channel 1
                in0     a, (DCNTL)
                or      #8              ; set bit 3 (DMA Channel 1 = Edge-sense)
                and     #0xFC           ; reset bits 0 and 1 (DMA Channel 1 = Memory to I/O)
                ld      a, a
                out0    (DCNTL), a
                in0     a, (DSTAT)
                or      #0x81           ; set bits 0 and 7 (Enable DMA Channel 1)
                and     #0xDF           ; reset bit 5 (Enable changing of DMA channel enablement)
                ld      a, a
                out0    (DSTAT), a

; Handshake with main CPU
                ;; Tell the IIgs the reply is ready ($01 in the output latch), wait for the
                ;; last byte to go, then put $00 back.
                ld      a, #1
                out0    (CARD_DATA), a

; Wait for DMA to complete

wait_for_status_transfer_loop:
                in0     a, (DSTAT)
                bit     7, a            ; Bit 7: DE1 (DMA enable channel 1)
                jp      NZ, wait_for_status_transfer_loop

; Handshake with main CPU
                ld      a, #0
                out0    (CARD_DATA), a
                ret
aGsvga:         .ascii  'GSVGA'
stat_size:
                .db     6
;; CHANGE (version): was $14. GetStatus reports this firmware's version, 1.5: the high
;; nibble is the major version and the low nibble the minor one, as Sequential's firmware
;; documentation (p1) and the library's VGA.H define the byte.
                .db     0x15            ; v1.5
stat_emul_status:
                .db     0
stat_vga_mode:  .db     0
stat_video_ram:
                .db     0
stat_monitor_type:
                .db     0

;; Never reached: a JR to the next instruction. GetStatus sends 13 bytes from 'GSVGA', two
;; more than the status record holds, so its last two bytes are this instruction ($18 $00).
;; The host reads the $18 and ignores it (docs/reference/host-commands.md, GetStatus).
status_overrun:
                jr      get_vga_reg

;; ----------------------------------------------------------------------------------------
;; Command $0D, GetVGAReg (index port, index, data port): writes the index, reads the
;; data port and sends the value by DMA (a dummy byte first).
;; ----------------------------------------------------------------------------------------
get_vga_reg:
                ;; cmd_param1 = index port, cmd_param3 = index, cmd_param4 = data port.
                ld      a, (cmd_param1) ; low byte of index register
                ld      c, a
                ld      a, (cmd_param1+1) ; high byte of index register
                ld      b, a
                ld      a, (cmd_param3) ; index register value
                out     (c), a
                ld      a, (cmd_param4) ; low byte of register address
                ld      c, a
                ld      a, (cmd_param4+1) ; high byte of register address
                ld      b, a
                in      a, (c)          ; a = register value
                ;; Send the two bytes at register_value by DMA channel 1, with the same
                ;; handshake as GetStatus.
                ld      (register_value), a ; store return value
                ld      a, #0xC
                out0    (MAR1L), a      ; DMA Memory Address Register Ch 1L
                ld      a, #0x12
                out0    (MAR1H), a      ; DMA Memory Address Register Ch 1H
                ld      a, #0
                out0    (MAR1B), a      ; DMA Memory Address Register Ch 1B
                ld      a, #2           ; Return 2 bytes
                out0    (BCR1L), a      ; DMA Byte Count Register Ch 1L
                ld      a, #0
                out0    (BCR1H), a      ; DMA Byte Count Register Ch 1H
                in0     a, (DCNTL)
                or      #8
                and     #0xFC
                ld      a, a
                out0    (DCNTL), a
                in0     a, (DSTAT)
                or      #0x81
                and     #0xDF
                ld      a, a
                out0    (DSTAT), a
                ld      a, #1
                out0    (CARD_DATA), a

wait_for_vga_reg_transfer_loop:
                in0     a, (DSTAT)
                bit     7, a
                jp      NZ, wait_for_vga_reg_transfer_loop
                ld      a, #0
                out0    (CARD_DATA), a
                ret
register_value:
                .dw     0

;; ----------------------------------------------------------------------------------------
;; Command $0C, SetVGAReg (index port, index, data port, value): writes the index, then
;; the value. Any I/O port works, which is how the errata's register fixes are sent.
;; ----------------------------------------------------------------------------------------
set_vga_reg:
                ;; cmd_param1 = index port, cmd_param3 = index, cmd_param4 = data port,
                ;; cmd_param6 = value.
                ld      a, (cmd_param1)
                ld      c, a
                ld      a, (cmd_param1+1)
                ld      b, a
                ld      a, (cmd_param3)
                out     (c), a
                ld      a, (cmd_param4)
                ld      c, a
                ld      a, (cmd_param4+1)
                ld      b, a
                ld      a, (cmd_param6)
                out     (c), a
                ret

; Access the softswitch at 5/0000

;; ----------------------------------------------------------------------------------------
;; The Oak's video half switch: a read anywhere in physical $40000-$4FFFF selects half 0
;; of the 1 MB video memory, $50000-$5FFFF half 1. These two routines map logical $2000 to
;; $5xxxx (BBR $4E) or $4xxxx (BBR $3E), read one byte and restore the MMU.
;; docs/06-video.md, The video RAM window.
;; ----------------------------------------------------------------------------------------
access_softswitch1:
                ;; Map logical $2000-$EFFF at physical $50000 (BBR $4E: $2000 + $4E000),
                ;; read one byte, put the MMU back.
                call    save_mmu_registers
                ld      a, #0xF2
                out0    (CBAR), a
                ld      a, #0x4E        ; 04/E000
                out0    (BBR), a
                ld      a, (hires_page1)
                call    restore_mmu_registers
                ret

; Access the softswitch at 4/0000

;; access_softswitch0: selects video memory half 0.
access_softswitch0:
                ;; The same with BBR $3E: physical $40000.
                call    save_mmu_registers
                ld      a, #0xF2
                out0    (CBAR), a
                ld      a, #0x3E
                out0    (BBR), a
                ld      a, (hires_page1)
                call    restore_mmu_registers
                ret

save_cbr:       .db     0
save_bbr:       .db     0
save_cbar:      .db     0

;; ----------------------------------------------------------------------------------------
;; Save / restore CBR, BBR and CBAR (used by the half-switch routines).
;; ----------------------------------------------------------------------------------------
save_mmu_registers:
                in0     a, (CBR)
                ld      (save_cbr), a
                in0     a, (BBR)
                ld      (save_bbr), a
                in0     a, (CBAR)
                ld      (save_cbar), a
                ret

;; restore_mmu_registers: puts back what save_mmu_registers saved.
restore_mmu_registers:
                ld      a, (save_cbr)
                out0    (CBR), a
                ld      a, (save_bbr)
                out0    (BBR), a
                ld      a, (save_cbar)
                out0    (CBAR), a
                ret

;; ----------------------------------------------------------------------------------------
;; Command $02, UploadData (flag, destination, length, 3 ignored bytes). Selects the
;; linear video window (port $AB, Oak extended register 5 = $19) and the write cache, then
;; receives the data by DMA from port $A0 in 64 KB phases (upload_chunk), and finally
;; turns the window off again and selects half 1. A picture upload in mode $13 uses the
;; standard $A0000 window instead (erratum E1), and an upload of whole 64 KB blocks ends
;; with the remainder phase the old library waits for (errata E19 and E25).
;; docs/reference/host-commands.md, UploadData.
;; ----------------------------------------------------------------------------------------
upload_data:
;; CHANGE (E1, E19): was ld a, #0 / out0 (LINEAR_ON), a / call access_softswitch0, the
;; start of the linear window set-up. In mode $13 a picture must be written through the
;; standard $A0000 window, because there the two low address bits choose the memory plane.
;; upload_select_window (FREE SPACE $9776 block, src/text.asm, reached through
;; call_in_bank0 because this command runs inside INT1 under any memory layout) picks the
;; window: the standard window for a picture upload in mode $13, otherwise the linear
;; window as before. It writes Oak register 5 itself, so the JR skips ROM 1.4's write of
;; $19 below, which stays in place and is never run. It also notes whether the upload has
;; whole 64 KB blocks, for the remainder phase of E19.
                ld      hl, #upload_select_window
                call    call_in_bank0
                jr      upload_window_selected
                ;; Never run since the E1 change: ROM 1.4's Oak register 5 = $19 (Oak
                ;; memory mapping, 1 MB window at the Z180's physical $80000), which
                ;; upload_select_window writes for the linear window.
                ld      a, #5           ; OAK Video Memory Mapping register
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0x19        ; bit 0 = Use Oak memory mapping (not VGA)
                                        ; bit 1 = DMA
                                        ; bit 2/3 = 1M aperture
                                        ; bit 4-7 = start address 0x100000 (start of linear address range)
                ld      bc, #OAK_DATA
                out     (c), a

upload_window_selected:
                ;; Oak register $22 = $08 turns on the write cache.
                ld      a, #0x22        ; OAK Feature Select register
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #8           ; bit 3 = Enable write cache
                ld      bc, #OAK_DATA
                out     (c), a
                ;; The source of every phase is port $A0. Parameters: cmd_param1 = flag (0
                ;; = Z180 memory, 1 = video memory), cmd_param1+1 / cmd_param3 / cmd_param4
                ;; = destination address, low to high, cmd_param4+1 / cmd_param6 /
                ;; cmd_param7 = length, low to high.
                ld      a, #0
                ld      (unused_CD2), a
                ld      a, #0xA0
                ld      (dma_source), a
                ld      a, #0
                ld      (dma_source+1), a
                ld      (dma_source_bank), a
                ;; The length's high byte counts whole 64 KB phases. Each phase is a DMA
                ;; count of 0 (64 KB); the destination bank then goes up by one.
                ld      a, (cmd_param7)
                cp      #0
                jp      Z, upload_small_chunk

upload_64k_chunk_loop:
                ld      a, (cmd_param1+1)
                ld      (dma_dest), a
                ld      a, (cmd_param3)
                ld      (dma_dest+1), a
                ld      a, (cmd_param4)
                ld      (dma_dest_bank), a
                ld      a, #0
                ld      (dma_count), a
                ld      (dma_count+1), a
                call    upload_chunk
                ld      a, (cmd_param4)
                inc     a
                ld      (cmd_param4), a
                ld      a, (cmd_param7)
                dec     a               ; reduce length remaining by 64K
                ld      (cmd_param7), a
                cp      #0
                jp      NZ, upload_64k_chunk_loop

upload_small_chunk:
                ;; Then one phase for the length's low 16 bits, if they are not zero.
;; CHANGE (E19, E25): was ld a, (cmd_param4+1) / ld b, a / ld a, (cmd_param6) / or b. The
;; IIgs library before August 1996 waits for a remainder phase ($01, then $00) even when
;; the length's low 16 bits are zero, and ROM 1.4 sent none, so an upload of whole 64 KB
;; blocks hung the program. upload_check_remainder (FREE SPACE $9776 block, src/text.asm,
;; reached through call_in_bank0) makes the same test and returns B = 0 when there is no
;; remainder; after whole 64 KB blocks it has then already acted out the remainder phase.
;; The JR Z is ROM 1.4's own.
                ld      hl, #upload_check_remainder
                call    call_in_bank0
                ld      a, b
                or      a
                jr      Z, finished_upload
                ld      a, (cmd_param1+1)
                ld      (dma_dest), a
                ld      a, (cmd_param3)
                ld      (dma_dest+1), a
                ld      a, (cmd_param4)
                ld      (dma_dest_bank), a
                ld      a, (cmd_param4+1)
                ld      (dma_count), a
                ld      a, (cmd_param6)
                ld      (dma_count+1), a
                call    upload_chunk

finished_upload:
                ;; Back to the standard VGA memory map, half 1, linear window off.
                ld      a, #5           ; OAK Video Memory Mapping register
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0
                ld      bc, #OAK_DATA
                out     (c), a
                call    access_softswitch1
                ld      a, #0
                out0    (LINEAR_OFF), a
                ret

;; ----------------------------------------------------------------------------------------
;; One UploadData phase. Banks below 8 get 8 added (video address = linear window at
;; $80000), banks 8 and up select half 1 and stay as they are. Erratum E4: the flag-0
;; test (JR Z at $1347) jumps to the add-8 step, so flag 0 ("Z180 memory") always writes
;; video memory. Each phase: DMA channel 1 from port $A0, handshake $01, wait, $00. A phase
;; that crosses video $80000 runs in two pieces (upload_dma, src/text.asm).
;; ----------------------------------------------------------------------------------------
upload_chunk:
                ;; DMA channel 1: from the I/O address in dma_source (port $A0) to the
                ;; memory address in dma_dest.
                ld      a, (dma_source)
                out0    (IAR1L), a      ; DMA I/O Address Register Ch 1L
                ld      a, (dma_source+1)
                out0    (IAR1H), a      ; DMA I/O Address Register Ch 1H
                ld      a, (dma_dest)
                out0    (MAR1L), a      ; DMA Memory Address Register Ch 1L
                ld      a, (dma_dest+1)
                out0    (MAR1H), a      ; DMA Memory Address Register Ch 1H
                ;; Choose the destination bank: see the erratum E4 comment below. Banks 8
                ;; and up are the video window already and select half 1; banks below 8 get
                ;; 8 added.
                ld      a, (cmd_param1) ; 0 = Code (Z180 address space), 1 = Data (VGA address space)
                cp      #0

;; CHANGE (E4): fixes UploadData flag 0 ("Z180 memory"), which ROM 1.4 always writes into
;; video memory: its "jr Z, upload_to_high_vga_memory" here led to the step that adds 8
;; to the bank. Flag 0 goes straight to dma_upload and uses the requested bank as it
;; is: bank $00 or $01 is SRAM, as the IIgs library (VGALOW.ASM) expects. One byte changes:
;; the jump distance at $1348.
                jr      Z, dma_upload

check_for_high_vga_bank:                ; Destination address (0Axxxx)
                ld      a, (dma_dest_bank)
                cp      #8
                jr      C, upload_to_high_vga_memory ; branch if A < 8

; enable high VGA bank
                call    access_softswitch1
                jr      dma_upload

upload_to_high_vga_memory:
                add     a, #8
                ld      (dma_dest_bank), a

dma_upload:
;; CHANGE (512 KB): was ld a, (dma_dest_bank) / out0 (MAR1B), a / ld a, (dma_count), the
;; start of ROM 1.4's transfer, which is one DMA. The Z180's DMA address runs from $FFFFF
;; straight on to $00000, so in ROM 1.4 a phase that crosses video $80000 writes its end
;; into card SRAM, over the firmware; Sequential's documentation tells programs never to
;; upload across 512 KB. upload_dma (FREE SPACE $9776 block, src/text.asm, reached
;; through call_in_bank0 because this command runs inside INT1 under any memory layout)
;; runs the transfer and its $01 / $00 handshake, in two pieces when it crosses video
;; $80000. The rest of ROM 1.4's transfer stays below and is never run.
                ld      hl, #upload_dma
                call    call_in_bank0
                ret
                nop
                nop
                ;; Never run since the 512 KB change: the rest of ROM 1.4's transfer.
                out0    (BCR1L), a      ; DMA Byte Counter Register Ch 1L
                ld      a, (dma_count+1)
                out0    (BCR1H), a
                in0     a, (DCNTL)
                or      #0xA            ; bit 1: DMA channel 1, I/O to memory
                                        ; bit 3: DREQ1 edge-sensed (DMS1)
                and     #0xFA
                ld      a, a
                out0    (DCNTL), a
                in0     a, (DSTAT)
                or      #0x81           ; Enable channel 1
                and     #0xDF
                ld      a, a
                out0    (DSTAT), a
                ld      a, #1
                out0    (CARD_DATA), a

wait_for_dma_completion_loop:
                in0     a, (DSTAT)
                bit     7, a
                jp      NZ, wait_for_dma_completion_loop
                ld      a, #0
                out0    (CARD_DATA), a
                ret

;; ----------------------------------------------------------------------------------------
;; Receives a command's bulk bytes by DMA channel 1 from port $A0 into memory (the job
;; in dma_source...dma_count), with the $01 / $00 handshake. SetPalette and SetUserMode use it.
;; ----------------------------------------------------------------------------------------
copy_api_data_chunk:
                ;; Same DMA setup as upload_chunk, with the bank taken as given.
                ld      a, (dma_source)
                out0    (IAR1L), a      ; DMA I/O Address Register Ch 1L
                ld      a, (dma_source+1)
                out0    (IAR1H), a      ; DMA I/O Address Register Ch 1H
                ld      a, (dma_dest)
                out0    (MAR1L), a      ; DMA Memory Address Register Ch 1L
                ld      a, (dma_dest+1)
                out0    (MAR1H), a      ; DMA Memory Address Register Ch 1H
                ld      a, (dma_dest_bank)
                out0    (MAR1B), a      ; DMA I/O Address Register Ch 1L
                ld      a, (dma_count)
                out0    (BCR1L), a      ; DMA Byte Counter Register Ch 1L
                ld      a, (dma_count+1)
                out0    (BCR1H), a      ; DMA Byte Counter Register Ch 1H
                in0     a, (DCNTL)      ; DMA/WAIT Control Register
                or      #0xA
                and     #0xFA
                ld      a, a
                out0    (DCNTL), a
                in0     a, (DSTAT)
                or      #0x81
                and     #0xDF
                ld      a, a
                out0    (DSTAT), a
                ld      a, #1
                out0    (CARD_DATA), a

wait_for_dma_chunk_loop:
                in0     a, (DSTAT)
                bit     7, a            ; Bit 7: DE1 (DMA enable channel 1)
                jp      NZ, wait_for_dma_chunk_loop
                ld      a, #0
                out0    (CARD_DATA), a
                ret

;; ----------------------------------------------------------------------------------------
;; Command $03, ScrollScreen (source, destination, length): copies video memory with DMA
;; through the linear window, in 64 KB pieces. If no destination byte is smaller than
;; the source byte in the same place it copies downward (copy_memory_block_decrement,
;; from the end); otherwise upward (scroll_up, copy_memory_block). Replies $A5.
;; Errata E8 (ranges at or above 512 KB wrap into the card's own memory) and E9 (the
;; direction test and the downward start address are wrong).
;; ----------------------------------------------------------------------------------------
scroll_screen:
;; CHANGE (E8, E9): was ld a, #0 / out0 (LINEAR_ON), a / call access_softswitch0, the start
;; of ROM 1.4's ScrollScreen. That version selected half 0 once and added 8 to every bank,
;; so bytes at video $80000 or above wrapped into the card's own memory (E8), and it chose
;; the direction byte by byte and started a downward copy one byte past the end (E9).
;; scroll_screen_fixed (FREE SPACE $9776 block, src/text.asm) does the whole command
;; instead: it is reached through call_in_bank0, because commands run inside INT1 under
;; any memory layout, and call_in_bank0 returns to the command dispatcher. The two NOPs
;; and the rest of ROM 1.4's routine below stay in place and are never run;
;; copy_memory_block, copy_memory_block_decrement and scroll_down_done are still used.
                ld      hl, #scroll_screen_fixed
                jp      call_in_bank0
                nop
                nop
                ld      a, #5
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0x19
                ld      bc, #OAK_DATA
                out     (c), a
                ld      a, #0
                ld      (unused_CD2), a
                ;; Pick the direction. Parameters: cmd_param1 / +1 / cmd_param3 = source,
                ;; cmd_param4 / +1 / cmd_param6 = destination (low to high), cmd_param7 /
                ;; +1 / cmd_param9 = length. The test compares the destination with the
                ;; source one byte at a time, high byte first, and takes the upward copy if
                ;; any destination byte is the smaller one (erratum E9).
                ;;
                ;; Never run since the E8/E9 change. ROM 1.4's fault (E9): comparing byte
                ;; by byte picks the wrong direction whenever a lower byte of the
                ;; destination is smaller than the source's, although the destination is
                ;; higher.
                ld      a, (cmd_param3)
                ld      h, a
                ld      a, (cmd_param6)
                cp      h
                jp      C, scroll_up
                ld      a, (cmd_param1+1)
                ld      h, a
                ld      a, (cmd_param4+1)
                cp      h
                jp      C, scroll_up
                ld      a, (cmd_param1)
                ld      h, a
                ld      a, (cmd_param4)
                cp      h
                jp      C, scroll_up
                ;; Downward copy: move source and destination to their ends (address +
                ;; length).
                ;;
                ;; ROM 1.4's fault (E9), never run since the change: the downward copy
                ;; must start at the last byte, address + length - 1; this adds the length
                ;; without subtracting one.
                ld      hl, (cmd_param1)
                ld      bc, (cmd_param7)
                ld      a, (cmd_param9)
                ld      d, a
                ld      a, (cmd_param3)
                scf                     ; set carry flag
                ccf                     ; invert carry flag (i.e. clear)
                add     hl, bc
                adc     a, d
                ld      (cmd_param1), hl
                ld      (cmd_param3), a
                ld      hl, (cmd_param4)
                ld      bc, (cmd_param7)
                ld      a, (cmd_param9)
                ld      d, a
                ld      a, (cmd_param6)
                scf                     ; set carry flag
                ccf                     ; invert carry flag (i.e. clear)
                add     hl, bc
                adc     a, d
                ld      (cmd_param4), hl
                ld      (cmd_param6), a
                ;; The length's high byte counts whole 64 KB pieces. Each piece copies 64
                ;; KB below the current end addresses (+8 turns a video address into the
                ;; linear window at $80000), then both banks go down by one.
                ld      a, (cmd_param9)
                cp      #0
                jp      Z, scroll_down_rest

scroll_down_64k_loop:
                ld      hl, (cmd_param1)
                ld      (dma_source), hl
                ld      a, (cmd_param3)
                add     a, #8
                ld      (dma_source_bank), a
                ld      hl, (cmd_param4)
                ld      (dma_dest), hl
                ld      a, (cmd_param6)
                add     a, #8
                ld      (dma_dest_bank), a
                ld      a, #0
                ld      (dma_count), a
                ld      (dma_count+1), a
                call    copy_memory_block_decrement
                ld      a, (cmd_param3)
                dec     a
                ld      (cmd_param3), a
                ld      a, (cmd_param6)
                dec     a
                ld      (cmd_param6), a
                ld      a, (cmd_param9)
                dec     a
                ld      (cmd_param9), a
                cp      #0
                jp      NZ, scroll_down_64k_loop

scroll_down_rest:
                ;; Then the rest, the length's low 16 bits.
                ld      a, (cmd_param7)
                ld      b, a
                ld      a, (cmd_param7+1)
                or      b
                jp      Z, scroll_down_done
                ld      hl, (cmd_param1)
                ld      (dma_source), hl
                ld      a, (cmd_param3)
                add     a, #8
                ld      (dma_source_bank), a
                ld      hl, (cmd_param4)
                ld      (dma_dest), hl
                ld      a, (cmd_param6)
                add     a, #8
                ld      (dma_dest_bank), a
                ld      a, (cmd_param7)
                ld      (dma_count), a
                ld      a, (cmd_param7+1)
                ld      (dma_count+1), a
                call    copy_memory_block_decrement

scroll_down_done:
                ;; Back to the standard memory map, linear window off, and reply $A5
                ;; (done).
                ld      a, #5
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0
                ld      bc, #OAK_DATA
                out     (c), a
                ld      a, #0
                out0    (LINEAR_OFF), a
                ld      a, #0xA5
                out0    (CARD_DATA), a
                ret

;; ----------------------------------------------------------------------------------------
;; DMA channel 0 memory-to-memory copy with both addresses counting down (the job in
;; dma_source...dma_count). The nullsub calls are empty debug prints.
;; ----------------------------------------------------------------------------------------
copy_memory_block_decrement:
                ;; The empty debug prints show source and destination.
                ld      a, (dma_source_bank)
                call    log_debug_byte
                ld      a, (dma_source+1)
                call    log_debug_byte
                ld      a, (dma_source)
                call    log_debug_byte
                ld      a, #0x20
                call    log_debug_char
                ld      a, (dma_dest_bank)
                call    log_debug_byte
                ld      a, (dma_dest+1)
                call    log_debug_byte
                ld      a, (dma_dest)
                call    log_debug_byte
                ;; DMA channel 0: memory to memory, both addresses counting down, burst
                ;; mode.
                ld      a, (dma_source)
                out0    (SAR0L), a
                ld      a, (dma_source+1)
                out0    (SAR0H), a
                ld      a, (dma_source_bank)
                out0    (SAR0B), a
                ld      a, (dma_dest)
                out0    (DAR0L), a
                ld      a, (dma_dest+1)
                out0    (DAR0H), a
                ld      a, (dma_dest_bank)
                out0    (DAR0B), a
                ld      a, (dma_count)
                out0    (BCR0L), a
                ld      a, (dma_count+1)
                out0    (BCR0H), a
                in0     a, (DMODE)
                or      #0x16           ; Destination = Memory/Decrement, Source = Memory/Decrement
                and     #0xD7
                ld      a, a
                out0    (DMODE), a
                in0     a, (DSTAT)
                or      #0x41
                and     #0xEF
                ld      a, a
                out0    (DSTAT), a
                ret

;; ----------------------------------------------------------------------------------------
;; scroll_screen's upward copy, in 64 KB pieces.
;; ----------------------------------------------------------------------------------------
scroll_up:
                ;; Upward copy, from the start addresses: 64 KB pieces first, both banks
                ;; going up by one after each.
                ld      a, (cmd_param9)
                cp      #0
                jp      Z, scroll_up_rest

scroll_up_64k_loop:
                ld      hl, (cmd_param1)
                ld      (dma_source), hl
                ld      a, (cmd_param3)
                add     a, #8
                ld      (dma_source_bank), a
                ld      hl, (cmd_param4)
                ld      (dma_dest), hl
                ld      a, (cmd_param6)
                add     a, #8
                ld      (dma_dest_bank), a
                ld      a, #0
                ld      (dma_count), a
                ld      (dma_count+1), a
                call    copy_memory_block
                ld      a, (cmd_param3)
                inc     a
                ld      (cmd_param3), a
                ld      a, (cmd_param6)
                inc     a
                ld      (cmd_param6), a
                ld      a, (cmd_param9)
                dec     a
                ld      (cmd_param9), a
                cp      #0
                jp      NZ, scroll_up_64k_loop

scroll_up_rest:
                ;; Then the length's low 16 bits.
                ld      a, (cmd_param7)
                ld      b, a
                ld      a, (cmd_param7+1)
                or      b
                jp      Z, scroll_up_done
                ld      hl, (cmd_param1)
                ld      (dma_source), hl
                ld      a, (cmd_param3)
                add     a, #8
                ld      (dma_source_bank), a
                ld      hl, (cmd_param4)
                ld      (dma_dest), hl
                ld      a, (cmd_param6)
                add     a, #8
                ld      (dma_dest_bank), a
                ld      a, (cmd_param7)
                ld      (dma_count), a
                ld      a, (cmd_param7+1)
                ld      (dma_count+1), a
                call    copy_memory_block

scroll_up_done:
                ;; Back to the standard memory map, linear window off, and reply $A5
                ;; (done).
                ld      a, #5
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0
                ld      bc, #OAK_DATA
                out     (c), a
                ld      a, #0
                out0    (LINEAR_OFF), a
                ld      a, #0xA5
                out0    (CARD_DATA), a
                ret

;; ----------------------------------------------------------------------------------------
;; DMA channel 0 memory-to-memory copy, both addresses counting up.
;; ----------------------------------------------------------------------------------------
copy_memory_block:
                ;; DMA channel 0: memory to memory, both addresses counting up, burst mode.
                ld      a, (dma_source)
                out0    (SAR0L), a
                ld      a, (dma_source+1)
                out0    (SAR0H), a
                ld      a, (dma_source_bank)
                out0    (SAR0B), a
                ld      a, (dma_dest)
                out0    (DAR0L), a
                ld      a, (dma_dest+1)
                out0    (DAR0H), a
                ld      a, (dma_dest_bank)
                out0    (DAR0B), a
                ld      a, (dma_count)
                out0    (BCR0L), a
                ld      a, (dma_count+1)
                out0    (BCR0H), a
                in0     a, (DMODE)
                or      #2              ; Source = Memory, increment source address, burst transfer
                and     #0xC3
                ld      a, a
                out0    (DMODE), a
                in0     a, (DSTAT)
                or      #0x41
                and     #0xEF
                ld      a, a
                out0    (DSTAT), a
                ret

;; ----------------------------------------------------------------------------------------
;; Command $08, SetBorder (palette index): writes the attribute controller's overscan
;; register ($11). The next mode set rewrites it from the mode record.
;; ----------------------------------------------------------------------------------------
set_border:
                ;; Read input status 1 so the next $3C0 write is an index. Index $11
                ;; (overscan color), keeping the palette address source bit as it is, then
                ;; the color.
                call    read_input_status1
                ld      a, (palette_access_flag)
                or      #0x11           ; select overscan color register
                ld      d, a
                ld      a, d
                ld      bc, #VGA_ATTR
                out     (c), a
                ld      a, (cmd_param1) ; set register to passed in value
                ld      bc, #VGA_ATTR
                out     (c), a
                ret

;; ----------------------------------------------------------------------------------------
;; Command $0A, ClearScreen (fill byte, start, length): fills video memory through the
;; linear window in 64 KB blocks (fill_video_mem_block), the fill byte coming from the
;; parameter buffer ($1A08, bank 2 = the SRAM mirror). Replies $A5. Erratum E8: a block
;; that crosses $80000 or $100000 at a nonzero offset wraps into SRAM.
;; ----------------------------------------------------------------------------------------
clear_screen:
;; CHANGE (E8): was ld a, #0 / out0 (LINEAR_ON), a / call access_softswitch0, the start of
;; ROM 1.4's ClearScreen, which filled whole 64 KB blocks from the start address, so a
;; block starting at a nonzero offset in bank 7 or 15 ran across $80000 or $100000 and
;; wrapped into SRAM. clear_screen_fixed (FREE SPACE $9776 block, src/text.asm, reached
;; through call_in_bank0) does the whole command instead, in pieces that end at each
;; 64 KB boundary. The two NOPs and the rest of ROM 1.4's routine below stay in place and
;; are never run; fill_video_mem_block and clear_done are still used.
                ld      hl, #clear_screen_fixed
                jp      call_in_bank0
                nop
                nop
                ld      a, #5
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0x19
                ld      bc, #OAK_DATA
                out     (c), a
                ld      a, #0
                ld      (unused_CD2), a
                ;; The fill byte is cmd_param1, the first parameter: DMA reads it from
                ;; $21A08 (bank 2 is the SRAM mirror, so this is $1A08) with the source
                ;; address held fixed.
                ld      hl, #0x1A08
                ld      (dma_source), hl
                ld      a, #2
                ld      (dma_source_bank), a
                ;; Parameters: cmd_param1+1 / cmd_param3 / cmd_param4 = start address, low
                ;; to high; cmd_param4+1 / cmd_param6 / cmd_param7 = length. The length's
                ;; high byte counts whole 64 KB blocks; each is a DMA count of 0, and the
                ;; bank then goes up by one.
                ld      a, (cmd_param7)
                cp      #0
                jp      Z, clear_rest

clear_64k_loop:
                ld      a, (cmd_param1+1)
                ld      (dma_dest), a
                ld      a, (cmd_param3)
                ld      (dma_dest+1), a
                ld      a, (cmd_param4)
                ld      (dma_dest_bank), a
                ld      a, #0
                ld      (dma_count), a
                ld      (dma_count+1), a
                call    fill_video_mem_block
                ld      a, (cmd_param4)
                inc     a
                ld      (cmd_param4), a
                ld      a, (cmd_param7)
                dec     a
                ld      (cmd_param7), a
                cp      #0
                jp      NZ, clear_64k_loop

clear_rest:
                ;; Then one block for the length's low 16 bits, if they are not zero.
                ld      a, (cmd_param4+1)
                ld      b, a
                ld      a, (cmd_param6)
                or      b
                jr      Z, clear_done
                ld      a, (cmd_param1+1)
                ld      (dma_dest), a
                ld      a, (cmd_param3)
                ld      (dma_dest+1), a
                ld      a, (cmd_param4)
                ld      (dma_dest_bank), a
                ld      a, (cmd_param4+1)
                ld      (dma_count), a
                ld      a, (cmd_param6)
                ld      (dma_count+1), a
                call    fill_video_mem_block

clear_done:
                ;; Back to the standard memory map, half 1, linear window off, and reply
                ;; $A5 (done).
                ld      a, #5
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0
                ld      bc, #OAK_DATA
                out     (c), a
                call    access_softswitch1
                ld      a, #0
                out0    (LINEAR_OFF), a
                ld      a, #0xA5
                out0    (CARD_DATA), a
                ret

;; ----------------------------------------------------------------------------------------
;; One ClearScreen block: banks 8 and up select half 1, banks below 8 get 8 added; DMA
;; channel 0 with a fixed source address (one byte repeated).
;; ----------------------------------------------------------------------------------------
fill_video_mem_block:
                ;; DMA channel 0 source: the fill byte.
                ;;
                ;; One block runs straight across $FFFFF. ROM 1.4's clear_screen gave it
                ;; blocks that could start in bank 7 or 15 at a nonzero offset, which
                ;; wrapped into the card's own memory (erratum E8); clear_screen_fixed
                ;; (src/text.asm) gives it only pieces inside one 64 KB bank.
                ld      a, (dma_source)
                out0    (SAR0L), a
                ld      a, (dma_source+1)
                out0    (SAR0H), a
                ld      a, (dma_source_bank)
                out0    (SAR0B), a

; check if the destination is in the high or low VGA bank
                ld      a, (dma_dest_bank)
                cp      #8
                jr      C, target_is_low_bank
                call    access_softswitch1
                jr      set_destination_address

target_is_low_bank:
                add     a, #8
                ld      (dma_dest_bank), a

set_destination_address:
                ;; Destination and count, then DMODE: source fixed, destination counting
                ;; up, burst mode. The transfer runs before the next instruction; then half
                ;; 0 again.
                ld      a, (dma_dest)
                out0    (DAR0L), a
                ld      a, (dma_dest+1)
                out0    (DAR0H), a
                ld      a, (dma_dest_bank)
                out0    (DAR0B), a
                ld      a, (dma_count)
                out0    (BCR0L), a
                ld      a, (dma_count+1)
                out0    (BCR0H), a
                in0     a, (DMODE)
                or      #0xA            ; Source = Memory, don't increment source, burst transfer
                and     #0xCB
                ld      a, a
                out0    (DMODE), a
                in0     a, (DSTAT)
                or      #0x41
                and     #0xEF
                ld      a, a
                out0    (DSTAT), a
                call    access_softswitch0
                ret

;; ----------------------------------------------------------------------------------------
;; DMA fill: fixed source address, destination counting up.
;; ----------------------------------------------------------------------------------------
fill_memory_block:
                ;; DMA channel 0: source fixed, destination counting up, burst mode.
                ;; Nothing calls it.
                ld      a, (dma_source)
                out0    (SAR0L), a
                ld      a, (dma_source+1)
                out0    (SAR0H), a
                ld      a, (dma_source_bank)
                out0    (SAR0B), a
                ld      a, (dma_dest)
                out0    (DAR0L), a
                ld      a, (dma_dest+1)
                out0    (DAR0H), a
                ld      a, (dma_dest_bank)
                out0    (DAR0B), a
                ld      a, (dma_count)
                out0    (BCR0L), a
                ld      a, (dma_count+1)
                out0    (BCR0H), a
                in0     a, (DMODE)
                or      #0xA            ; Source = Memory, don't increment source, burst transfer
                and     #0xCB
                ld      a, a
                out0    (DMODE), a
                in0     a, (DSTAT)
                or      #0x41
                and     #0xEF
                ld      a, a
                out0    (DSTAT), a
                ret
