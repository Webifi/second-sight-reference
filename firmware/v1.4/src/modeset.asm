;; src/modeset.asm, $0CE2-$1031: SetMode, the mode lists, set_video_mode and the VGA register helpers.
;; Part of the ROM 1.4 firmware source; ROM_BEEF.asm includes it.

;; ----------------------------------------------------------------------------------------
;; Command $01, SetMode (mode, emulation flag). Stores the mode in vga_mode and the flag in
;; emul_flag (0 = show the Apple's video, 1 = show the VGA mode). Sets
;; mode_change_pending and setmode_reply_owed for the main loop.
;; With emulation off, set_native_mode sets the mode and sends $A5, or $A6 for
;; an unknown mode. docs/reference/host-commands.md, SetMode.
;; ----------------------------------------------------------------------------------------
set_mode:
                ;; The two parameter bytes: cmd_param1 = mode number, cmd_param1+1 =
                ;; emulation flag.
                ld      a, (cmd_param1+1)
                ld      (emul_flag), a
                ld      a, (cmd_param1)
                ld      (vga_mode), a
                ;; Mode change pending, and a completion byte owed to the host. The main
                ;; loop sees both.
                ld      a, #1
                ld      (mode_change_pending), a
                ld      (setmode_reply_owed), a
                ret

; Converts an integer mode value into a set of VGA register values suitable for a 31kHz+ VGA monitor

;; ----------------------------------------------------------------------------------------
;; The mode numbers set_video_mode knows on a VGA monitor (searched from the end with
;; CPDR); vga_mode_register_table holds the address of each mode's 81-byte register
;; record, in the same order. The AppleColor RGB pair follows. The records themselves are
;; at $C000-$C5AF. docs/reference/video-modes.md.
;; ----------------------------------------------------------------------------------------
vga_modes_table:
                .db     1
                                        ; 01 - 40x25
                .db     3               ; 03 - 80x25
                .db     0x13            ; 13 - 320x200x256
                .db     0x53            ; 53 - 640x480x256
                .db     0x61            ; 61 - 640x400x256
                .db     0xFA            ; FA - 560x192x16
                .db     0xFB            ; FB - 280x192x16
                .db     0xFC            ; FC = 40x24
                .db     0xFD            ; FD = 80x24
                .db     0xFE            ; FE = 640x200
vga_mode_register_table:
                .dw     vga_regs_01
                .dw     vga_regs_03
                .dw     vga_regs_13
                .dw     vga_regs_53
                .dw     vga_regs_61
                .dw     vga_regs_FA
                .dw     vga_regs_FB
                .dw     vga_regs_FC
                .dw     vga_regs_FD
                .dw     vga_regs_FE

; Converts an integer mode value into a set of VGA register values suitable for an AppleColor RGB monitor

;; ----------------------------------------------------------------------------------------
;; The mode numbers set_video_mode knows on the AppleColor RGB monitor (15.7 kHz), and
;; their records. Mode $13 is not among them (erratum E1).
;; ----------------------------------------------------------------------------------------
;; BUG (E1): mode $13 is missing from this list, so on an AppleColor RGB monitor SetMode
;; $13 is refused and the previous mode stays.
applecolor_rgb_modes_table:
                .db     1
                                        ; 01 - 40x25
                .db     3               ; 03 - 80x25
                .db     0x61            ; 61 - 640x400x256
                .db     0xFA            ; FA - 560x192x16
                .db     0xFB            ; FB - 280x192x16
                .db     0xFC            ; FC = 40x24
                .db     0xFD            ; FD = 80x24
                .db     0xFE            ; FE = 640x200
applecolor_mode_register_table:
                .dw     gs_regs_01
                .dw     gs_regs_03
                .dw     gs_regs_61
                .dw     gs_regs_FA
                .dw     gs_regs_FB
                .dw     gs_regs_FC
                .dw     gs_regs_FD
                .dw     gs_regs_FE

;; ----------------------------------------------------------------------------------------
;; The mode number set_video_mode is setting.
;; ----------------------------------------------------------------------------------------
mode_number:    .db     0
mode_record:
;; $0D2E-$0D81 (84 bytes).
;; set_video_mode's buffer: the current mode's 81-byte register record, copied here
;; from the EPROM by DMA.
                .ds     84

; A = video mode (13 = 320x200x256, 53 = 640x480x256, etc)

;; ----------------------------------------------------------------------------------------
;; Programs the Oak OTI-087 for the mode number in A:
;;   1. Mode $FF uses SetUserMode's record at $179A. Otherwise the monitor sense bit
;;      (Input Status 0 bit 4: 1 = VGA monitor, 0 = AppleColor RGB) picks the mode list,
;;      and an unknown mode returns without changing anything.
;;   2. DMA copies the mode's 81-byte record from the EPROM itself (physical $6xxxx,
;;      source bank 6) into the buffer at $0D2E. So a change to a record in SRAM has no
;;      effect: only a new EPROM changes the records (erratum E1).
;;   3. Writes, from the record: clock select (Oak $06) and miscellaneous output, Oak mode
;;      select ($21), the sequencer, the clock path (port $A8 for the VGA clock or $A9 for
;;      the RGB clock), PEL mask and feature control; a pause (delay_loop); then the CRTC,
;;      graphics and attribute controllers and the Oak extended registers.
;; Record layout: docs/reference/video-modes.md.
;; ----------------------------------------------------------------------------------------
set_video_mode:
                .assume set_video_mode - 0x0D82 ;; must stay at $0D82
                ;; Mode $FF: the record SetUserMode received, at user_mode_record.
                cp      #0xFF
                jr      Z, set_user_video_mode
                ;; Pick the mode list for the monitor: input status 0 bit 4 is 1 for a VGA
                ;; monitor, 0 for AppleColor RGB.
                ld      (mode_number), a
                ld      bc, #VGA_STATUS0 ; Fetch Input Status 0 register
                in      a, (c)
                bit     4, a            ; Check Sense Switch (1 = 31kHz+ VGA monitor, 0 = AppleColor RGB)
                jr      NZ, set_for_vga_monitor
                ld      hl, #applecolor_rgb_modes_table+7
                ld      bc, #8
                ld      de, #applecolor_mode_register_table
                ld      a, (mode_number)
                jr      copy_register_values

set_for_vga_monitor:
                ld      hl, #vga_modes_table+9
                ld      bc, #0xA
                ld      de, #vga_mode_register_table
                ld      a, (mode_number)

copy_register_values:
                ;; Search the list from its last entry for the mode number (CPDR stops on a
                ;; match or after BC bytes). On a match, BC = the entry's index, and the
                ;; record address is word BC of the matching register table.
                cpdr
                jr      NZ, invalid_video_mode
                ld      l, c
                ld      h, #2
                mlt     hl
                add     hl, de
                ld      a, (hl)
                ld      c, a
                inc     hl
                ld      a, (hl)
                ld      b, a
                ;; DMA channel 0 copies the 81-byte record from the EPROM (bank 6: physical
                ;; $6xxxx) into mode_record, in one burst.
                ld      a, c            ; DMA Source Address (Channel 0) = 00cc
                out0    (SAR0L), a
                ld      a, b            ; DMA Source Address (Channel 0) = bbcc
                out0    (SAR0H), a
                ld      a, #6           ; DMA Source Address (Channel 0) = 06/bbcc
                out0    (SAR0B), a
                ld      a, #<mode_record
                out0    (DAR0L), a      ; DMA Destination Address (Channel 0) = 002E
                ld      a, #>mode_record
                out0    (DAR0H), a      ; DMA Destination Address (Channel 0) = 0D2E
                ld      a, #0
                out0    (DAR0B), a      ; DMA Destination Address (Channel 0) = 00/0D2E
                ld      a, #0x51
                out0    (BCR0L), a      ; DMA Byte count = 0051
                ld      a, #0
                out0    (BCR0H), a      ; DMA Byte count = 0051
                in0     a, (DMODE)      ; Read DMA Mode register
                or      #2              ; DMA Memory Mode = BURST (DMA Controller takes control of bus)
                and     #0xC3           ; Source Mode = Memory (increment)
                                        ; Destination Mode = Memory (increment)
                ld      a, a
                out0    (DMODE), a      ; Set DMA Mode register
                in0     a, (DSTAT)      ; Get DMA Status register
                or      #0x41           ; DE0 (Enable Channel 0), DME (DMA Main Enable)
                and     #0xEF           ; Bit Write Enable 0 (allow write to DE0)
                ld      a, a
                out0    (DSTAT), a      ; Set DMA status register
                ld      hl, #mode_record
                jr      program_mode_registers

invalid_video_mode:
                ret

set_user_video_mode:
                ;; HL = the record. The rest of the routine reads it in order;
                ;; set_video_mode's record layout is in docs/reference/video-modes.md.
                ld      hl, #user_mode_record
                jr      program_mode_registers

program_mode_registers:
                ;; Hold the sequencer in reset while the clock and timing registers change.
                call    enable_oak_add_on_mode
                call    reset_vga_sequencer
                push    hl
                pop     ix
                ;; Record byte $41: the Oak clock select register (Oak $06). Byte $00:
                ;; miscellaneous output (sync polarity, clock select, I/O address select).
                ld      d, 0x41(ix)
                ld      a, #6
                ld      bc, #OAK_INDEX
                out     (c), a          ; Select Oak clock select register
                ld      a, d
                ld      bc, #OAK_DATA
                out     (c), a          ; Oak clock select register = values[0x41]
                ;; BUG (E16): this misc output write sets clock-select bits 1-0 again after
                ;; Oak $06, so the misc byte decides the clock. A SetUserMode record whose
                ;; two bytes name different clocks runs at the misc byte's clock.
                ld      a, (hl)
                ld      bc, #VGA_MISC
                out     (c), a          ; Miscellaneous output register = values[0x00]
                inc     hl
                ;; Record byte $48: the Oak mode select register (Oak $21). Byte $01:
                ;; sequencer register 1, clocking mode.
                ld      d, 0x48(ix)
                ld      a, #0x21
                ld      bc, #OAK_INDEX
                out     (c), a          ; Select Oak mode select register
                ld      a, d
                ld      bc, #OAK_DATA
                out     (c), a          ; Oak mode select register = values[0x48]
                ld      a, #1
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a          ; Select sequencer clocking mode register
                ld      a, (hl)
                ld      bc, #VGA_SEQ_DATA
                out     (c), a          ; Sequencer clocking mode register = values[0x01]
                inc     hl
                ;; Record byte $02, the feature byte. Bit 0: the pixel clock path. 1 = the
                ;; divided clock for an AppleColor RGB monitor (CLOCK_RGB), 0 = the clock
                ;; straight from the VGA chip (CLOCK_VGA).
                ld      a, (hl)
                bit     0, a
                jr      Z, select_vga_clock
                ld      a, #0
                out0    (CLOCK_RGB), a
                jr      set_pel_mask_and_feature

select_vga_clock:
                ld      a, #0
                out0    (CLOCK_VGA), a

set_pel_mask_and_feature:
                ;; Feature byte bits 7-4: the Bt481 color chip's Command Register A (the
                ;; color mode). On the Bt481, a read of $3C7 followed by four reads of $3C6
                ;; makes the next $3C6 access reach Command Register A instead of the pixel
                ;; mask (docs/reference/bt481-modes.md).
                ld      a, (hl)
                and     #0xF0
                ld      e, a
                ld      bc, #VGA_DAC_STATE
                in      a, (c)          ; Read DAC state register
                ld      bc, #VGA_PEL_MASK
                in      a, (c)          ; Read PEL mask register
                ld      bc, #VGA_PEL_MASK
                in      a, (c)
                ld      bc, #VGA_PEL_MASK
                in      a, (c)
                ld      bc, #VGA_PEL_MASK
                in      a, (c)
                ld      a, e
                ld      bc, #VGA_PEL_MASK
                out     (c), a          ;; Bt481 Command Register A = feature byte & $F0
                ;; Feature byte bits 3-1: feature control.
                ld      a, (hl)
                and     #0xE
                ld      a, a
                ld      bc, #VGA_FEATURE
                out     (c), a          ; Feature control register = values[0x02] & 0x0E
                ;; Bytes $03-$05: sequencer registers 2 (map mask), 3 (character map) and 4
                ;; (memory mode).
                inc     hl
                ld      a, #2
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a          ; Select sequencer map mask register
                ld      a, (hl)
                ld      bc, #VGA_SEQ_DATA
                out     (c), a          ; Sequencer map mask register = values[0x03]
                inc     hl
                ld      a, #3
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a          ; Select sequencer character map select register
                ld      a, (hl)
                ld      bc, #VGA_SEQ_DATA
                out     (c), a          ; Sequencer character map select register = values[0x04]
                inc     hl
                ld      a, #4
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a          ; Select sequencer memory mode register
                ld      a, (hl)
                ld      bc, #VGA_SEQ_DATA
                out     (c), a          ; Sequencer memory mode register = values[0x05]
                inc     hl
                ;; Let the sequencer run, then wait before the CRTC changes.
                call    release_vga_sequencer_reset
                ld      de, #0x7FFF

;; ----------------------------------------------------------------------------------------
;; Busy wait of 32,767 passes after the sequencer restarts, before the CRTC is programmed.
;; ----------------------------------------------------------------------------------------
delay_loop:
                .assume delay_loop - 0x0EAE ;; must stay at $0EAE
                dec     de
                ld      a, e
                or      d
                cp      #0
                jr      NZ, delay_loop
                ;; Bytes $06-$1E: CRTC registers 0-$18. Registers 0-7 are write-protected
                ;; until CRTC register $11 bit 7 is cleared.
                call    disable_crtc_write_protect
                ld      d, #0
                ld      e, #0x19

set_crtc_registers_loop:
                ld      a, d
                ld      bc, #VGA_CRTC_INDEX
                out     (c), a          ; Select CRTC register
                ld      a, (hl)
                ld      bc, #VGA_CRTC_DATA
                out     (c), a          ; Update CRTC register value
                inc     hl
                inc     d
                ld      a, d
                cp      e
                jp      NZ, set_crtc_registers_loop
                ;; Bytes $1F-$27: graphics controller registers 0-8.
                ld      d, #0
                ld      e, #9

set_graphics_controller_registers_loop:
                ld      a, d
                ld      bc, #VGA_GC_INDEX
                out     (c), a          ; Select graphics controller register
                ld      a, (hl)
                ld      bc, #VGA_GC_DATA
                out     (c), a          ; Update graphics controller register value
                inc     hl
                inc     d
                ld      a, d
                cp      e
                jp      NZ, set_graphics_controller_registers_loop
                ;; Bytes $28-$3C: attribute controller registers 0-$14. Each pair of writes
                ;; to $3C0 is an index and a value; reading input status 1 first makes the
                ;; next write an index.
                ld      d, #0
                ld      e, #0x15

set_attribute_controller_registers_loop:
                call    read_input_status1
                ld      a, d
                ld      bc, #VGA_ATTR
                out     (c), a          ; Select attribute controller register
                ld      a, (hl)
                ld      bc, #VGA_ATTR
                out     (c), a          ; Update attribute controller register value
                inc     hl
                inc     d
                ld      a, d
                cp      e
                jp      NZ, set_attribute_controller_registers_loop
                ;; Bytes $3D-$40: Oak extended registers 2-5. Byte $41 (clock select,
                ;; already written) is skipped.
                ld      d, #2
                ld      e, #6

set_oak_extended_registers_loop:
                ld      a, d
                ld      bc, #OAK_INDEX
                out     (c), a          ; Select Oak extended register
                ld      a, (hl)
                ld      bc, #OAK_DATA
                out     (c), a          ; Update Oak extended register value
                inc     hl
                inc     d
                ld      a, d
                cp      e
                jp      NZ, set_oak_extended_registers_loop
                inc     hl
                ;; Bytes $42-$44: Oak registers $13-$15. Then one byte each for Oak $17
                ;; (extended CRTC), $19 (color palette range) and $20 (FIFO depth); byte
                ;; $48 (mode select, already written) is skipped; then Oak $22 (feature
                ;; select) and $25 (extended common read/write).
                ld      d, #0x13
                ld      e, #0x16

set_oak_extended_registers_loop2:
                ld      a, d
                ld      bc, #OAK_INDEX
                out     (c), a          ; Select Oak extended register
                ld      a, (hl)
                ld      bc, #OAK_DATA
                out     (c), a          ; Update Oak extended register value
                inc     hl
                inc     d
                ld      a, d
                cp      e
                jp      NZ, set_oak_extended_registers_loop2
                ld      a, #0x17
                ld      bc, #OAK_INDEX
                out     (c), a          ; Select extended CRTC register
                ld      a, (hl)
                ld      bc, #OAK_DATA
                out     (c), a
                inc     hl
                ld      a, #0x19
                ld      bc, #OAK_INDEX
                out     (c), a          ; Select color palette range register
                ld      a, (hl)
                ld      bc, #OAK_DATA
                out     (c), a
                inc     hl
                ld      a, #0x20
                ld      bc, #OAK_INDEX
                out     (c), a          ; Select FIFO depth register
                ld      a, (hl)
                ld      bc, #OAK_DATA
                out     (c), a
                inc     hl
                inc     hl
                ld      a, #0x22
                ld      bc, #OAK_INDEX
                out     (c), a          ; Select feature select register
                ld      a, (hl)
                ld      bc, #OAK_DATA
                out     (c), a
                inc     hl
                ld      a, #0x25
                ld      bc, #OAK_INDEX
                out     (c), a          ; Select extended common read/write register
                ld      a, (hl)
                ld      bc, #OAK_DATA
                out     (c), a
                inc     hl
                ;; Bytes $4B-$50: Oak registers $30-$35.
                ld      d, #0x30
                ld      e, #0x36

set_oak_extended_registers_loop3:
                ld      a, d
                ld      bc, #OAK_INDEX
                out     (c), a          ; Select Oak extended register
                ld      a, (hl)
                ld      bc, #OAK_DATA
                out     (c), a          ; Update Oak extended register value
                inc     hl
                inc     d
                ld      a, d
                cp      e
                jp      NZ, set_oak_extended_registers_loop3
                ;; Give the palette back to the display. Without this the screen stays
                ;; blank.
                call    enable_palette_access_from_display_only
                ret

;; ----------------------------------------------------------------------------------------
;; Reads Input Status 1 ($3DA). The read also resets the attribute controller's
;; index/data flip-flop, so the next write to $3C0 is an index.
;; ----------------------------------------------------------------------------------------
read_input_status1:
                ld      bc, #VGA_STATUS1
                in      a, (c)
                ret

;; ----------------------------------------------------------------------------------------
;; Enables the OTI-087 in add-on mode: the sequence on p29 of the Oak databook ($46E8,
;; $102, $46E8). The unlabeled routine after it would disable the chip again.
;; ----------------------------------------------------------------------------------------
enable_oak_add_on_mode:
                ;; The add-on enable sequence from the OTI-087 databook, page 29: $46E8 =
                ;; $10 opens port $102, $102 = 1 enables the chip, $46E8 = $08 enables its
                ;; I/O and memory.
                ld      a, #0x10

; See Page 29 of the OTI-087 databook.
; This code follows the exact sequence described there.
                ld      bc, #VGA_SETUP  ; Enable access to location 0102 in VGA chip
                out     (c), a
                ld      a, #1
                ld      bc, #VGA_ENABLE ; Enable VGA chip
                out     (c), a
                ld      a, #8
                ld      bc, #VGA_SETUP  ; Activate read/write access to VGA interface
                out     (c), a
                ret

;; Never reached: the add-on disable sequence ($46E8 = $10, $102 = 0).
disable_oak:
                ld      a, #0x10
                ld      bc, #VGA_SETUP
                out     (c), a
                ld      a, #0
                ld      bc, #VGA_ENABLE
                out     (c), a
                ret

;; ----------------------------------------------------------------------------------------
;; Sequencer reset register 0 = $00 (reset) / $03 (run).
;; ----------------------------------------------------------------------------------------
reset_vga_sequencer:
                ld      a, #0
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a
                ld      a, #0
                ld      bc, #VGA_SEQ_DATA
                out     (c), a
                ret

;; release_vga_sequencer_reset: sequencer register 0 = $03, the sequencer runs again.
release_vga_sequencer_reset:
                ld      a, #0
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a
                ld      a, #3
                ld      bc, #VGA_SEQ_DATA
                out     (c), a
                ret

;; ----------------------------------------------------------------------------------------
;; CRTC register $11 bit 7 clear / set: unlocks / locks CRTC registers 0-7.
;; ----------------------------------------------------------------------------------------
disable_crtc_write_protect:
                ;; CRTC register $11 bit 7 protects registers 0-7. Read it, clear bit 7,
                ;; write it back.
                ld      a, #0x11
                ld      bc, #VGA_CRTC_INDEX
                out     (c), a          ; Select CRTC vertical retrace end register
                ld      bc, #VGA_CRTC_DATA
                in      a, (c)          ; Read CRTC vertical retrace end register
                res     7, a            ; Bit 7 = "PR: Protect Registers 0-7"
                ld      d, a
                ld      a, #0x11
                ld      bc, #VGA_CRTC_INDEX
                out     (c), a
                ld      a, d
                ld      bc, #VGA_CRTC_DATA
                out     (c), a          ; Enable writing to CRTC registers 0-7
                ret

enable_crtc_write_protect:
                ld      a, #0x11
                ld      bc, #VGA_CRTC_INDEX
                out     (c), a
                ld      bc, #VGA_CRTC_DATA
                in      a, (c)
                set     7, a
                ld      d, a
                ld      a, #0x11
                ld      bc, #VGA_CRTC_INDEX
                out     (c), a
                ld      a, d
                ld      bc, #VGA_CRTC_DATA
                out     (c), a
                ret

;; ----------------------------------------------------------------------------------------
;; Writes the attribute index register's palette address source bit (bit 5): $20 hands
;; the palette to the display (normal operation), $00 lets the CPU change it.
;; ----------------------------------------------------------------------------------------
enable_palette_access_from_display_only:
                ;; Read input status 1 so the next write to $3C0 is an index. Writing an
                ;; index with bit 5 set hands the palette to the display.
                call    read_input_status1
                ld      a, #0x20
                ld      (palette_access_flag), a
                ld      a, a
                ld      bc, #VGA_ATTR
                out     (c), a
                ret

;; enable_palette_access_from_host_only: index bit 5 clear, so the CPU may change the
;; attribute controller's palette registers (the screen shows the overscan color
;; meanwhile).
enable_palette_access_from_host_only:
                call    read_input_status1
                ld      a, #0
                ld      (palette_access_flag), a
                ld      a, a
                ld      bc, #VGA_ATTR
                out     (c), a
                ret
