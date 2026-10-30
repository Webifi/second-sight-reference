;; src/superhires.asm, $A000-$B1FF: the Super Hi-Res renderer (copied to SRAM bank 1 and run there).
;; Part of the ROM 1.4 firmware source; ROM_BEEF.asm includes it.

;; ----------------------------------------------------------------------------------------
;; ==== $A000-$BFFF: the Super Hi-Res renderer. Its setup copies this range to SRAM bank 1
;; ($1A000) and runs that copy (BBR $10 maps logical $A000 to $1A000), so a change here
;; goes into the copy too when Super Hi-Res is already running.
;;
;; Variables: line_scb = the scan-line control byte being drawn; palette_check_src / palette_check_copy =
;; where the palette check (check_palettes) continues; palette_check_entry = its DAC entry counter.
;; ----------------------------------------------------------------------------------------
line_scb:       .db     0
                .assume line_scb - 0xA000 ;; must stay at $A000
palette_check_src:
                .dw     0
palette_check_copy:
                .dw     0
;; One byte nothing reads.
                .db     0
palette_check_entry:
                .db     0

;; ----------------------------------------------------------------------------------------
;; Super Hi-Res setup:
;;   1. DMA copies $A000-$BFFF to SRAM bank 1 $1A000; the MMU (CBAR $F2, BBR $10, CBR $91)
;;      then runs the copy and shows the Apple's bank $E1 copy at logical $2000-$9FFF.
;;   2. Mode $FE (640 x 200), the 64-bit latch and caches, and the conversion tables in
;;      video memory segments 8-15 (build_320_tables for 320-pixel lines, build_640_tables for 640).
;;   3. Chain 4, write mode 1 with the pixel mask, a full redraw (all bands marked), the
;;      palette, screen on, and the scan-line control bytes copied to the cache at $BD00.
;; docs/08-firmware.md, Super Hi-Res.
;; ----------------------------------------------------------------------------------------
set_videomode_superhires:
                .assume set_videomode_superhires - 0xA007 ;; must stay at $A007
                ;; DMA channel 0: $2000 bytes from physical $0A000 (this code, in SRAM bank
                ;; 0) to $1A000 (SRAM bank 1).
                ld      a, #0
                out0    (SAR0L), a
                ld      a, #0xA0
                out0    (SAR0H), a
                ld      a, #0
                out0    (SAR0B), a
                ld      a, #0
                out0    (DAR0L), a
                ld      a, #0xA0
                out0    (DAR0H), a
                ld      a, #1
                out0    (DAR0B), a
                ld      a, #0
                out0    (BCR0L), a
                ld      a, #0x20
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
                ;; MMU: logical $2000-$EFFF at physical $12000 (BBR $10), SRAM bank 1: the
                ;; Apple's bank $E1 copy at $2000-$9FFF (the Super Hi-Res screen) and this
                ;; code's copy at $A000; logical $F000 at physical $A0000 (CBR $91), the
                ;; VGA window. From here on the CPU runs the copy.
                ld      a, #0xF2
                out0    (CBAR), a
                ld      a, #0x10
                out0    (BBR), a
                ld      a, #0x91
                out0    (CBR), a
                ;; Standard VGA memory map, half 1, linear window off, mode $FE (640 x 200,
                ;; 256 colors), DMA waits off.
                ld      a, #5
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0
                ld      bc, #OAK_DATA
                out     (c), a
                call    access_softswitch1
                ld      a, #0
                out0    (LINEAR_OFF), a
                ld      a, #0xFE        ; 640x200
                call    set_video_mode
                ld      a, #0
                out0    (DCNTL), a
                ;; Oak $22 = $1C: 64-bit latch with read and write caches. Then the
                ;; conversion tables into video segments 8-11 (320-pixel lines) and 12-15
                ;; (640-pixel lines).
                ld      a, #0x22        ; Oak Feature Select Register
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0x1C        ; Enable 64-bit graphics latch / read+write cache
                ld      bc, #OAK_DATA
                out     (c), a
                call    build_320_tables
                call    build_640_tables
                ;; Read segment $C, chain 4 with extended memory, Oak $22 = $38 (read cache off), the pixel
                ;; mask on and all pixels enabled, graphics mode $51 (write mode 1).
                ld      a, #0x23
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0xC         ; Set Oak Extended Read Segment Register = 0x0C
                ld      bc, #OAK_DATA
                out     (c), a
                ld      a, #4           ; Select Sequencer Memory Mode
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a
                ld      a, #0xA         ; Memory Mode = Chain Four + Extended memory
                ld      bc, #VGA_SEQ_DATA
                out     (c), a
                ld      a, #0x22        ; Oak Feature Select Register
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0x38        ; 64-bit graphics latch, write cache, CPU latch swap; read cache off
                ld      bc, #OAK_DATA
                out     (c), a
                ld      a, #0x30        ; Select Color Expansion Control Register
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #8           ; Turn on pixel mask
                ld      bc, #OAK_DATA
                out     (c), a
                ld      a, #0x34        ; Select Pixel Mask Register
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0xFF
                ld      bc, #OAK_DATA
                out     (c), a          ; Pixel mask = FF
                ld      a, #5
                ld      bc, #VGA_GC_INDEX ; Select Graphics Controller Mode Register
                out     (c), a
                ld      a, #0x51        ; Mode = Mode 13 Shift Register + Odd/Even + Write Mode 1
                ld      bc, #VGA_GC_DATA
                out     (c), a
                ;; Mark every band changed, draw the whole screen, load the palettes,
                ;; screen on.
                ld      a, #0xFF
                ld      (lower_scb_changed), a
                ld      (upper_scb_changed), a
                call    render_superhires
                call    set_superhires_palette
                ld      a, #1
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a
                ld      bc, #VGA_SEQ_DATA
                in      a, (c)
                res     5, a            ;; clear bit 5: screen on
                ld      d, a
                ld      a, #1
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a
                ld      a, d
                ld      bc, #VGA_SEQ_DATA
                out     (c), a
                ;; Start the palette check at palette entry 0: palette_check_src = $9E00
                ;; (the IIgs palettes), palette_check_copy = $BB00 (the last values sent).
                ld      a, #0
                ld      (palette_check_entry), a
                ld      hl, #0x9E00
                ld      (palette_check_src), hl
                ld      hl, #0xBB00
                ld      (palette_check_copy), hl
                ;; Copy the 200 scan-line control bytes ($9D00) to the cache at $BD00, then
                ;; back to the main loop.
                ld      hl, #0x9D00
                ld      de, #0xBD00
                ld      bc, #0x100
                ldir
                ld      a, #0
                out0    (BBR), a
                ld      a, #0
                out0    (CBR), a
                jp      main_loop

;; ----------------------------------------------------------------------------------------
;; Super Hi-Res render routine: renders again and again until a mode change is pending or
;; emulation is turned off.
;; ----------------------------------------------------------------------------------------
emulate_superhires:
                ;; The Super Hi-Res memory layout, then draw until SetMode turns emulation
                ;; off or a mode change is pending.
                ld      a, #0xF2
                out0    (CBAR), a
                ld      a, #0x10
                out0    (BBR), a
                ld      a, #0x91
                out0    (CBR), a
                call    render_superhires
                ld      a, (emul_flag)
                cp      #1
                jr      Z, shr_exit
                ld      a, (mode_change_pending)
                cp      #0
                jr      Z, emulate_superhires

shr_exit:
                ld      a, #0
                out0    (BBR), a
                ld      a, #0
                out0    (CBR), a
                jp      main_loop

;; ----------------------------------------------------------------------------------------
;; Unrolled Super Hi-Res conversion: 2,220 bytes ($A15C-$AA07).
;; render_band calls shr_convert_high and shr_convert_low in turn. Each call
;; converts 32 bytes of the current line, from the end backwards.
;; On entry: BC = the source byte (the Apple's bank $E1 copy), DE = the screen address in
;; the video window (logical $F000-$FFFF), line_scb = the line's scan-line control byte.
;; Bits 1-0 of that byte pick one of four copies of the loop, one per palette of the four
;; in the line's table group (select_line_tables has already selected the group's read segment).
;; One step:
;;     ld a, (bc)        the source byte
;;     ld h, #0x3C+n     n = palette within the group (0-3)
;;     ld l, a
;;     add hl, hl
;;     add hl, hl        HL = $F000 + n x $400 + 4 x byte: the byte's conversion-table entry
;;     ldd               reads the entry, which loads the VGA latches, and writes (DE) in write
;;                       mode 1, which stores the latches; then BC, DE and HL count down
;; Every four steps, "ld e, #..." sets the low byte of the screen address for the next
;; group, 16 bytes lower. This entry handles screen bytes $xxF9 down to $xx86.
;;
;; BUG (E13): a step takes 42 clocks, 24 of them building the table address, so a full
;; screen redraw takes about 99 ms (about 10 a second) and fast animation is choppy.
;; docs/reference/errata.md, E13.
;; ----------------------------------------------------------------------------------------
shr_convert_high:
                ld      a, (line_scb)
                bit     1, a
                jp      NZ, shr_high_pal2_or_3
                bit     0, a
                jp      NZ, shr_high_pal1

;; ----------------------------------------------------------------------------------------
;; Palette 0 of the group: table page $3C ($F000).
;; ----------------------------------------------------------------------------------------
shr_high_pal0:
                ld      e, #0xF9
                ld      h, #0x3C
                ld      a, (bc)
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0xE9
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0xD9
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0xC9
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0xB9
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0xA9
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x99
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x89
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ret

;; ----------------------------------------------------------------------------------------
;; Palette 1: table page $3D ($F400).
;; ----------------------------------------------------------------------------------------
shr_high_pal1:
                ld      e, #0xF9
                ld      h, #0x3D
                ld      a, (bc)
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0xE9
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0xD9
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0xC9
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0xB9
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0xA9
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x99
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x89
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ret

;; ----------------------------------------------------------------------------------------
;; Palettes 2 and 3: bit 0 decides.
;; ----------------------------------------------------------------------------------------
shr_high_pal2_or_3:
                bit     0, a
                jp      NZ, shr_high_pal3

;; ----------------------------------------------------------------------------------------
;; Palette 2: table page $3E ($F800).
;; ----------------------------------------------------------------------------------------
shr_high_pal2:
                ld      e, #0xF9
                ld      h, #0x3E
                ld      a, (bc)
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0xE9
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0xD9
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0xC9
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0xB9
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0xA9
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x99
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x89
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ret

;; ----------------------------------------------------------------------------------------
;; Palette 3: table page $3F ($FC00).
;; ----------------------------------------------------------------------------------------
shr_high_pal3:
                ld      e, #0xF9
                ld      h, #0x3F
                ld      a, (bc)
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0xE9
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0xD9
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0xC9
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0xB9
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0xA9
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x99
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x89
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ret

;; ----------------------------------------------------------------------------------------
;; The same conversion for screen bytes $xx79 down to $xx06.
;; ----------------------------------------------------------------------------------------
shr_convert_low:
                ld      a, (line_scb)
                bit     1, a
                jp      NZ, shr_low_pal2_or_3
                bit     0, a
                jp      NZ, shr_low_pal1

;; ----------------------------------------------------------------------------------------
;; Palette 0 of the group: table page $3C ($F000).
;; ----------------------------------------------------------------------------------------
shr_low_pal0:
                ld      e, #0x79
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x69
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x59
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x49
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x39
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x29
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x19
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x09
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3C
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ret

;; ----------------------------------------------------------------------------------------
;; Palette 1: table page $3D ($F400).
;; ----------------------------------------------------------------------------------------
shr_low_pal1:
                ld      e, #0x79
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x69
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x59
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x49
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x39
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x29
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x19
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x09
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3D
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ret

;; ----------------------------------------------------------------------------------------
;; Palettes 2 and 3: bit 0 decides.
;; ----------------------------------------------------------------------------------------
shr_low_pal2_or_3:
                bit     0, a
                jp      NZ, shr_low_pal3

;; ----------------------------------------------------------------------------------------
;; Palette 2: table page $3E ($F800).
;; ----------------------------------------------------------------------------------------
shr_low_pal2:
                ld      e, #0x79
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x69
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x59
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x49
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x39
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x29
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x19
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x09
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3E
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ret

;; ----------------------------------------------------------------------------------------
;; Palette 3: table page $3F ($FC00).
;; ----------------------------------------------------------------------------------------
shr_low_pal3:
                ld      e, #0x79
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x69
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x59
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x49
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x39
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x29
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x19
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      e, #0x09
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ld      a, (bc)
                ld      h, #0x3F
                ld      l, a
                add     hl, hl
                add     hl, hl
                ldd
                ret

;; ----------------------------------------------------------------------------------------
;; Takes the next scan-line control byte (IX, going backwards), keeps it in line_scb, and
;; selects the conversion table for it: Oak read segment 8-11 for a 320-pixel line, 12-15
;; for a 640-pixel line (bit 7), by palette number / 4. Erratum E11: bit 5 (color fill)
;; is ignored.
;; ----------------------------------------------------------------------------------------
select_line_tables:
                ;; Read the line's scan-line control byte (IX, then IX moves back one
                ;; line). Bit 7 = 640 pixels per line: tables in segments 12-15, else 8-11.
                ;; Bits 3-2 pick the segment of the group (4 palettes per segment); bits
                ;; 1-0, read by shr_convert_high/low, pick the palette within it.
                ;;
                ;; BUG (E11): only bit 7 (640 pixels) and bits 3-0 (palette) of the control
                ;; byte are used; bit 5, color fill mode, is ignored.
                push    hl
                ld      a, 0(ix)
                ld      (line_scb), a
                dec     ix
                bit     7, a
                ld      h, #0xC
                jr      NZ, select_line_group
                ld      h, #8

select_line_group:
                and     #0xF
                srl     a
                srl     a
                add     a, h
                ld      h, a
                ;; Oak $23 = the read segment: reads of the window see that group's
                ;; tables.
                ld      a, #0x23
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, h
                ld      bc, #OAK_DATA
                out     (c), a
                pop     hl
                ret

;; ----------------------------------------------------------------------------------------
;; Redraws one 4 KB band, from its last line to its first (H lines; L counts the lines
;; between control-byte changes; E indexes the band's write segment in band_write_segment and its
;; CBR value in band_cbr).
;; ----------------------------------------------------------------------------------------
render_band:
                ;; Tables for the band's last line, then the write segment and CBR for the
                ;; screen piece that holds the band's end (E counts pieces down from the
                ;; top).
                inc     ix
                call    select_line_tables
                exx
                exx
                push    hl
                dec     e
                ld      d, #0
                ld      hl, #band_write_segment
                add     hl, de
                ld      a, #0x24
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, (hl)
                ld      bc, #OAK_DATA
                out     (c), a
                ld      hl, #band_cbr
                add     hl, de
                ld      a, (hl)
                out0    (CBR), a
                pop     hl
                exx
                exx

band_loop:
                ;; Each turn converts 64 source bytes: 32 with shr_convert_high and 32 with
                ;; shr_convert_low. A line is 160 bytes, five halves, so L counts the
                ;; halves left in the current line; at 0 the next line's tables are
                ;; selected.
                exx
                call    shr_convert_high
                exx
                dec     l
                jr      NZ, band_low_half
                call    select_line_tables
                ld      l, #5

band_low_half:
                exx
                call    shr_convert_low
                ;; D = the high byte of the screen address in the window. When it falls
                ;; below $F000, the next 4 KB piece of the screen is mapped in, and D
                ;; starts again at $FF.
                dec     d
                ld      a, d
                cp      #0xEF
                jr      NZ, band_next
                exx
                push    hl
                dec     e
                ld      d, #0
                ld      hl, #band_write_segment
                add     hl, de
                ld      a, #0x24
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, (hl)
                ld      bc, #OAK_DATA
                out     (c), a
                ld      hl, #band_cbr
                add     hl, de
                ld      a, (hl)
                out0    (CBR), a
                pop     hl
                exx
                ld      d, #0xFF

band_next:
                ;; H counts the turns left in the band.
                exx
                dec     h
                ret     Z
                dec     l
                jr      NZ, band_loop
                call    select_line_tables
                ld      l, #5
                jr      band_loop

;; ----------------------------------------------------------------------------------------
;; Super Hi-Res renderer: reads the band flags at ports $A5 and $A4 (each read clears
;; them), adds the bands whose scan-line control bytes changed (check_lower_scbs, check_upper_scbs), and
;; redraws only those 4 KB bands (render_band), upper half first; the palette check runs
;; twice per pass (check_palettes). Erratum E3: the $6000-$6FFF band starts from the wrong
;; control byte (LD IX,$9D7F at $AB11). Errata E11 (color fill) and E12 (palettes
;; rewritten mid-frame).
;; ----------------------------------------------------------------------------------------
render_superhires:
                .assume render_superhires - 0xAA9D ;; must stay at $AA9D
                ;; Check a quarter of the palettes. Upper half: the bands written since the
                ;; last pass (port BAND_FLAGS_HI, cleared by the read) and those whose
                ;; control bytes changed.
                ;;
                ;; BUG (E12): palettes are checked a quarter at a time while the screen is
                ;; redrawn, not in step with the IIgs beam, so a picture that rewrites
                ;; palettes during each frame shows wrong colors.
                call    check_palettes
                in0     b, (BAND_FLAGS_HI)
                ld      a, (upper_scb_changed)
                or      b
                ld      (upper_bands), a
                ld      a, #0
                ld      (upper_scb_changed), a
                call    check_lower_scbs
                ;; Band $9000-$9CFF (the rest of that 4 KB holds the control bytes and
                ;; palettes): BC = its last source byte, D = its last screen page, IX = the
                ;; control byte before its last line, L = halves left in that line, H =
                ;; turns (52), E = its piece number + 1.
                ld      a, (upper_bands)
                bit     3, a
                jr      Z, check_band_8000
                exx
                ld      bc, #0x9CFF
                ld      d, #0xF3
                exx
                ld      ix, #0x9DC6
                ld      l, #5
                ld      h, #0x34
                ld      e, #0x20
                call    render_band

check_band_8000:
                ;; Band $8000-$8FFF, 64 turns.
                ld      a, (upper_bands)
                bit     2, a
                jr      Z, check_band_7000
                exx
                ld      bc, #0x8FFF
                ld      d, #0xFF
                exx
                ld      ix, #0x9DB2
                ld      l, #1
                ld      h, #0x40
                ld      e, #0x1C
                call    render_band

check_band_7000:
                ld      a, (upper_bands)
                bit     1, a
                jr      Z, check_band_6000
                exx
                ld      bc, #0x7FFF
                ld      d, #0xFF
                exx
                ld      ix, #0x9D98
                ld      l, #3
                ld      h, #0x40
                ld      e, #0x18
                call    render_band

check_band_6000:
                ld      a, (upper_bands)
                bit     0, a
                jr      Z, check_lower_bands
                exx
                ld      bc, #0x6FFF
                ld      d, #0xFF
                exx
                ;; BUG (E3): render_band increments IX before it reads each control byte,
                ;; so this should be $9D7E, one byte before the band's last line's byte, as
                ;; for the other bands. With $9D7F each line of lines 102-127 takes the
                ;; next line's control byte, palette and 320/640 setting.
                ld      ix, #0x9D7F
                ld      l, #5
                ld      h, #0x40
                ld      e, #0x14
                call    render_band

check_lower_bands:
                ;; Another quarter of the palettes, then the lower half: port BAND_FLAGS_LO
                ;; and the control-byte changes.
                call    check_palettes
                call    check_upper_scbs
                in0     b, (BAND_FLAGS_LO)
                ld      a, (lower_scb_changed)
                or      b
                ld      (lower_bands), a
                ld      a, #0
                ld      (lower_scb_changed), a
                ld      a, (lower_bands)
                bit     3, a
                jr      Z, check_band_4000
                exx
                ld      bc, #0x5FFF
                ld      d, #0xFF
                exx
                ld      ix, #0x9D65
                ld      l, #2
                ld      h, #0x40
                ld      e, #0x10
                call    render_band

check_band_4000:
                ld      a, (lower_bands)
                bit     2, a
                jr      Z, check_band_3000
                exx
                ld      bc, #0x4FFF
                ld      d, #0xFF
                exx
                ld      ix, #0x9D4B
                ld      l, #4
                ld      h, #0x40
                ld      e, #0xC
                call    render_band

check_band_3000:
                ld      a, (lower_bands)
                bit     1, a
                jr      Z, check_band_2000
                exx
                ld      bc, #0x3FFF
                ld      d, #0xFF
                exx
                ld      ix, #0x9D32
                ld      l, #1
                ld      h, #0x40
                ld      e, #8
                call    render_band

check_band_2000:
                ld      a, (lower_bands)
                bit     0, a
                ret     Z
                exx
                ld      bc, #0x2FFF
                ld      d, #0xFF
                exx
                ld      ix, #0x9D18
                ld      l, #3
                ld      h, #0x40
                ld      e, #4
                call    render_band
                ret

;; ----------------------------------------------------------------------------------------
;; Band flags for this pass: upper_bands = upper four bands ($6000-$9FFF, port $A5),
;; lower_bands = lower four ($2000-$5FFF, port $A4); lower_scb_changed / upper_scb_changed = bands to redraw
;; because their scan-line control bytes changed.
;; ----------------------------------------------------------------------------------------
upper_bands:    .db     0
lower_bands:    .db     0
lower_scb_changed:
                .db     0
upper_scb_changed:
                .db     0

;; ----------------------------------------------------------------------------------------
;; Where each piece of the Super Hi-Res screen sits in video memory. The 640 x 200 screen
;; takes 128,000 bytes, in 32 pieces of 4 KB; render_band walks them from the bottom up.
;; Piece n is reached with Oak write segment band_write_segment[n] and logical $F000
;; mapped by CBR band_cbr[n] ($91 = physical $A0000, the VGA window, $92 = $A1000, ...).
;; ----------------------------------------------------------------------------------------
band_write_segment:
                .db     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 ; pieces 0-7: segment 0
                .db     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 ; pieces 8-15
                .db     0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01 ; pieces 16-23: segment 1
                .db     0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01 ; pieces 24-31
band_cbr:
                .db     0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98 ; pieces 0-7
                .db     0x99, 0x9A, 0x9B, 0x9C, 0x9D, 0x9E, 0x9F, 0xA0 ; pieces 8-15
                .db     0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98 ; pieces 16-23
                .db     0x99, 0x9A, 0x9B, 0x9C, 0x9D, 0x9E, 0x9F, 0xA0 ; pieces 24-31

;; ----------------------------------------------------------------------------------------
;; Loads all 256 DAC entries from the 16 IIgs palettes ($E1/9E00, logical $9E00 here):
;; palette n color c is entry n x 16 + c, each 4-bit component times $11. Keeps a copy
;; at $BB00 for check_palettes.
;; ----------------------------------------------------------------------------------------
set_superhires_palette:
                ;; 256 DAC entries from the 16 IIgs palettes (logical $9E00, the bank $E1
                ;; copy): each color word is $0RGB, low byte first; each 4-bit level times
                ;; $11 makes the 8-bit DAC value. The words also go to the copy at $BB00.
                ld      a, #0xFF
                ld      bc, #VGA_PEL_MASK
                out     (c), a
                ld      hl, #0x9E00
                ld      a, #0
                ld      bc, #VGA_DAC_WRITE_INDEX
                out     (c), a
                ld      de, #0xBB00

set_shr_palette_loop:
                inc     hl
                inc     de
                ld      a, (hl)         ; read colour palette entry from 01/9Exx + 1 (Red)
                ld      (de), a
                and     #0xF
                ld      c, a
                ld      b, #0x11        ; convert 4 bit colour to 8 bit colour
                mlt     bc
                ld      a, c
                ld      bc, #VGA_DAC_DATA
                out     (c), a          ; Set Red value
                dec     hl
                dec     de
                ld      a, (hl)         ; read colour palette entry from 01/9Exx + 0 (Green/Blue)
                ld      (de), a
                srl     a
                srl     a
                srl     a
                srl     a
                ld      c, a
                ld      b, #0x11        ; convert 4 bit colour to 8 bit colour
                mlt     bc
                ld      a, c
                ld      bc, #VGA_DAC_DATA
                out     (c), a          ; Set Green value
                ld      a, (hl)
                ld      (de), a
                and     #0xF
                ld      c, a
                ld      b, #0x11        ; convert 4 bit colour to 8 bit colour
                mlt     bc
                ld      a, c
                ld      bc, #VGA_DAC_DATA
                out     (c), a          ; Set Blue value
                inc     hl              ; Move on to next palette entry
                inc     hl
                inc     de
                inc     de
                ld      a, h            ; check if we've copied 16 palettes (address == 01/A000)
                cp      #0xA0
                jp      NZ, set_shr_palette_loop
                ret

;; ----------------------------------------------------------------------------------------
;; Palette check: compares 64 of the 256 palette words with the copy at $BB00 and sends
;; each changed one to the DAC (conversion tables at $BE00 and $BF00), then continues
;; from there next time. Runs twice per pass, so a full check takes two passes.
;; ----------------------------------------------------------------------------------------
check_palettes:
                ;; 64 palette words per call, from where the last call stopped.
                ;; palette_check_entry (B) = the DAC entry of the word at IX.
                push    de
                push    ix
                ld      de, (palette_check_copy)
                ld      ix, (palette_check_src)
                ld      c, #0x40
                ld      a, (palette_check_entry)
                ld      b, a

check_palette_loop:
                ;; Compare the word with the copy; a changed word goes to the copy and to
                ;; the DAC.
                ld      a, (de)
                cp      0(ix)
                jp      NZ, palette_changed
                inc     de
                ld      a, (de)
                cp      1(ix)
                jp      NZ, palette_changed_high

check_palette_next:
                inc     ix
                inc     ix
                inc     de
                inc     b
                dec     c
                ld      a, c
                cp      #0
                jp      NZ, check_palette_loop
                ;; Remember where to go on; after the last of the 256 entries (B back to 0)
                ;; start again at the first.
                ld      a, b
                ld      (palette_check_entry), a
                ld      (palette_check_copy), de
                ld      (palette_check_src), ix
                pop     ix
                pop     de
                cp      #0
                ret     NZ
                ld      hl, #0x9E00
                ld      (palette_check_src), hl
                ld      hl, #0xBB00
                ld      (palette_check_copy), hl
                ret

palette_changed_high:
                dec     de

palette_changed:
                ;; Copy the new word, then send it: shr_level_low[$0R] = red,
                ;; shr_level_high[$GB] = green, shr_level_low[$GB] = blue.
                inc     de
                ld      a, 1(ix)
                ld      (de), a
                dec     de
                ld      a, 0(ix)
                ld      (de), a
                push    bc
                push    de
                ld      a, b
                ld      bc, #VGA_DAC_WRITE_INDEX
                out     (c), a
                ld      h, #0xBF
                ld      d, #0xBE
                ld      l, 1(ix)
                ld      a, (hl)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      e, 0(ix)
                ld      a, (de)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      l, 0(ix)
                ld      a, (hl)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                pop     de
                pop     bc
                inc     de
                jp      check_palette_next

;; ----------------------------------------------------------------------------------------
;; Compares the scan-line control bytes of the lower bands (check_lower_scbs) and upper bands
;; (check_upper_scbs) with the copy at $BD00; a change updates the copy and marks the band in
;; lower_scb_changed / upper_scb_changed.
;; ----------------------------------------------------------------------------------------
check_lower_scbs:
                ;; Only when the band holding the control bytes ($9000-$9FFF) was written.
                ;; For each lower band, compare its lines' control bytes ($9D00 + line)
                ;; with the cache at $BD00; the first difference updates the cache, marks
                ;; the band and moves on to the next band.
                ld      a, (upper_bands)
                bit     3, a
                ret     Z
                ld      b, #0x9D
                ld      c, #0
                ld      h, #0xBD
                ld      l, c

scb_band0_loop:
                ld      a, (bc)
                ld      d, a
                ld      a, (hl)
                cp      d
                jr      Z, scb_band0_next
                ld      a, d
                ld      (hl), a
                ld      a, (lower_scb_changed)
                set     0, a
                ld      (lower_scb_changed), a
                jr      scb_band1

scb_band0_next:
                inc     l
                inc     c
                ld      a, c
                cp      #0x1A
                jr      NZ, scb_band0_loop

scb_band1:
                ld      c, #0x19
                ld      l, c

scb_band1_loop:
                ld      a, (bc)
                ld      d, a
                ld      a, (hl)
                cp      d
                jr      Z, scb_band1_next
                ld      a, d
                ld      (hl), a
                ld      a, (lower_scb_changed)
                set     1, a
                ld      (lower_scb_changed), a
                jr      scb_band2

scb_band1_next:
                inc     l
                inc     c
                ld      a, c
                cp      #0x34
                jr      NZ, scb_band1_loop

scb_band2:
                ld      c, #0x33
                ld      l, c

scb_band2_loop:
                ld      a, (bc)
                ld      d, a
                ld      a, (hl)
                cp      d
                jr      Z, scb_band2_next
                ld      a, d
                ld      (hl), a
                ld      a, (lower_scb_changed)
                set     2, a
                ld      (lower_scb_changed), a
                jr      scb_band3

scb_band2_next:
                inc     l
                inc     c
                ld      a, c
                cp      #0x4D
                jr      NZ, scb_band2_loop

scb_band3:
                ld      c, #0x4C
                ld      l, c

scb_band3_loop:
                ld      a, (bc)
                ld      d, a
                ld      a, (hl)
                cp      d
                jr      Z, scb_band3_next
                ld      a, d
                ld      (hl), a
                ld      a, (lower_scb_changed)
                set     3, a
                ld      (lower_scb_changed), a
                ret

scb_band3_next:
                inc     l
                inc     c
                ld      a, c
                cp      #0x67
                jr      NZ, scb_band3_loop
                ret

;; The same for the upper bands' lines $66-$AF.
check_upper_scbs:
                ld      a, (upper_bands)
                bit     3, a
                ret     Z
                ld      b, #0x9D
                ld      c, #0x66
                ld      h, #0xBD
                ld      l, c

scb_band4_loop:
                ld      a, (bc)
                ld      d, a
                ld      a, (hl)
                cp      d
                jr      Z, scb_band4_next
                ld      a, d
                ld      (hl), a
                ld      a, (upper_scb_changed)
                set     0, a
                ld      (upper_scb_changed), a
                jr      scb_band5

scb_band4_next:
                inc     l
                inc     c
                ld      a, c
                cp      #0x80
                jr      NZ, scb_band4_loop

scb_band5:
                ld      c, #0x7F
                ld      l, c

scb_band5_loop:
                ld      a, (bc)
                ld      d, a
                ld      a, (hl)
                cp      d
                jr      Z, scb_band5_next
                ld      a, d
                ld      (hl), a
                ld      a, (upper_scb_changed)
                set     1, a
                ld      (upper_scb_changed), a
                jr      scb_band6

scb_band5_next:
                inc     l
                inc     c
                ld      a, c
                cp      #0x9A
                jr      NZ, scb_band5_loop

scb_band6:
                ld      c, #0x99
                ld      l, c

scb_band6_loop:
                ld      a, (bc)
                ld      d, a
                ld      a, (hl)
                cp      d
                jr      Z, scb_band6_next
                ld      a, d
                ld      (hl), a
                ld      a, (upper_scb_changed)
                set     2, a
                ld      (upper_scb_changed), a
                ret

scb_band6_next:
                inc     l
                inc     c
                ld      a, c
                cp      #0xB0
                jr      NZ, scb_band6_loop
                ret

;; ----------------------------------------------------------------------------------------
;; Builds the 320-pixel conversion tables in video memory segments 8-11 (Oak $25), four
;; palettes per segment: make_320_table writes one 1 KB table per palette, copy_4k_memory_block
;; spreads it.
;; ----------------------------------------------------------------------------------------
build_320_tables:
                ;; Oak $25 = 8: the CPU's reads and writes in the window go to video
                ;; segment 8. Logical $F000 shows physical $A0000 (CBR $91), the first 4 KB
                ;; of the segment.
                ld      a, #0x25
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #8
                ld      bc, #OAK_DATA
                out     (c), a
                ld      e, #0x91
                ld      a, e
                out0    (CBR), a
                ;; Four tables of 1 KB, one per palette: D = palette x 16, the first DAC
                ;; entry of that palette.
                ld      hl, #0xF000
                ld      d, #0
                call    make_320_table
                ld      d, #0x10
                call    make_320_table
                ld      d, #0x20
                call    make_320_table
                ld      d, #0x30
                call    make_320_table
                ;; Copy those 4 KB to the other fifteen 4 KB pieces of the segment (DMA
                ;; within physical bank $0A). The renderer reads the tables through logical
                ;; $F000 while CBR moves the window over the screen, so the tables must be
                ;; at every 4 KB offset.
                ld      b, #0xA
                ld      de, #0
                ld      hl, #0x1000

spread_320_seg8:
                call    copy_4k_memory_block
                ld      a, h
                add     a, #0x10
                ld      h, a
                cp      #0
                jp      NZ, spread_320_seg8
                ;; Segment 9: palettes 4-7.
                ld      a, #0x25
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #9
                ld      bc, #OAK_DATA
                out     (c), a
                ld      e, #0x91
                ld      a, e
                out0    (CBR), a
                ld      hl, #0xF000
                ld      d, #0x40
                call    make_320_table
                ld      d, #0x50
                call    make_320_table
                ld      d, #0x60
                call    make_320_table
                ld      d, #0x70
                call    make_320_table
                ld      b, #0xA
                ld      de, #0
                ld      hl, #0x1000

spread_320_seg9:
                call    copy_4k_memory_block
                ld      a, h
                add     a, #0x10
                ld      h, a
                cp      #0
                jp      NZ, spread_320_seg9
                ;; Segment 10: palettes 8-11.
                ld      a, #0x25
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0xA
                ld      bc, #OAK_DATA
                out     (c), a
                ld      e, #0x91
                ld      a, e
                out0    (CBR), a
                ld      hl, #0xF000
                ld      d, #0x80
                call    make_320_table
                ld      d, #0x90
                call    make_320_table
                ld      d, #0xA0
                call    make_320_table
                ld      d, #0xB0
                call    make_320_table
                ld      b, #0xA
                ld      de, #0
                ld      hl, #0x1000

spread_320_seg10:
                call    copy_4k_memory_block
                ld      a, h
                add     a, #0x10
                ld      h, a
                cp      #0
                jp      NZ, spread_320_seg10
                ;; Segment 11: palettes 12-15.
                ld      a, #0x25
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0xB
                ld      bc, #OAK_DATA
                out     (c), a
                ld      e, #0x91
                ld      a, e
                out0    (CBR), a
                ld      hl, #0xF000
                ld      d, #0xC0
                call    make_320_table
                ld      d, #0xD0
                call    make_320_table
                ld      d, #0xE0
                call    make_320_table
                ld      d, #0xF0
                call    make_320_table
                ld      b, #0xA
                ld      de, #0
                ld      hl, #0x1000

spread_320_seg11:
                call    copy_4k_memory_block
                ld      a, h
                add     a, #0x10
                ld      h, a
                cp      #0
                jp      NZ, spread_320_seg11
                ret

;; ----------------------------------------------------------------------------------------
;; One 320-mode table: for each byte (two 4-bit pixels), four output bytes.
;; ----------------------------------------------------------------------------------------
make_320_table:
                ;; For each source byte B (two 4-bit pixels), four output bytes: the left
                ;; pixel twice and the right pixel twice, each plus D, so a 320-pixel line
                ;; fills 640 screen pixels.
                ld      b, #0

make_320_loop:
                ld      a, b
                srl     a
                srl     a
                srl     a
                srl     a
                or      d
                ld      (hl), a
                inc     hl
                ld      (hl), a
                inc     hl
                ld      a, b
                and     #0xF
                or      d
                ld      (hl), a
                inc     hl
                ld      (hl), a
                inc     hl
                inc     b
                ld      a, b
                cp      #0
                jp      NZ, make_320_loop
                ret

;; ----------------------------------------------------------------------------------------
;; Builds the 640-pixel conversion tables in segments 12-15 (make_640_table).
;; ----------------------------------------------------------------------------------------
build_640_tables:
                ;; The same for 640-pixel lines in segments 12-15, with make_640_table.
                ld      a, #0x25
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0xC
                ld      bc, #OAK_DATA
                out     (c), a
                ld      a, #0x91
                out0    (CBR), a
                ld      hl, #0xF000
                ld      d, #0
                call    make_640_table
                ld      d, #0x10
                call    make_640_table
                ld      d, #0x20
                call    make_640_table
                ld      d, #0x30
                call    make_640_table
                ld      b, #0xA
                ld      de, #0
                ld      hl, #0x1000

spread_640_seg12:
                call    copy_4k_memory_block
                ld      a, h
                add     a, #0x10
                ld      h, a
                cp      #0
                jp      NZ, spread_640_seg12
                ld      a, #0x25
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0xD
                ld      bc, #OAK_DATA
                out     (c), a
                ld      e, #0x91
                ld      a, e
                out0    (CBR), a
                ld      hl, #0xF000
                ld      d, #0x40
                call    make_640_table
                ld      d, #0x50
                call    make_640_table
                ld      d, #0x60
                call    make_640_table
                ld      d, #0x70
                call    make_640_table
                ld      b, #0xA
                ld      de, #0
                ld      hl, #0x1000

spread_640_seg13:
                call    copy_4k_memory_block
                ld      a, h
                add     a, #0x10
                ld      h, a
                cp      #0
                jp      NZ, spread_640_seg13
                ld      a, #0x25
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0xE
                ld      bc, #OAK_DATA
                out     (c), a
                ld      e, #0x91
                ld      a, e
                out0    (CBR), a
                ld      hl, #0xF000
                ld      d, #0x80
                call    make_640_table
                ld      d, #0x90
                call    make_640_table
                ld      d, #0xA0
                call    make_640_table
                ld      d, #0xB0
                call    make_640_table
                ld      b, #0xA
                ld      de, #0
                ld      hl, #0x1000

spread_640_seg14:
                call    copy_4k_memory_block
                ld      a, h
                add     a, #0x10
                ld      h, a
                cp      #0
                jp      NZ, spread_640_seg14
                ld      a, #0x25
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0xF
                ld      bc, #OAK_DATA
                out     (c), a
                ld      e, #0x91
                ld      a, e
                out0    (CBR), a
                ld      hl, #0xF000
                ld      d, #0xC0
                call    make_640_table
                ld      d, #0xD0
                call    make_640_table
                ld      d, #0xE0
                call    make_640_table
                ld      d, #0xF0
                call    make_640_table
                ld      b, #0xA
                ld      de, #0
                ld      hl, #0x1000

spread_640_seg15:
                call    copy_4k_memory_block
                ld      a, h
                add     a, #0x10
                ld      h, a
                cp      #0
                jp      NZ, spread_640_seg15
                ret

;; ----------------------------------------------------------------------------------------
;; One 640-mode table: for each byte (four 2-bit pixels), four output bytes.
;; ----------------------------------------------------------------------------------------
make_640_table:
                ;; For each source byte B (four 2-bit pixels), four output bytes. As on the
                ;; IIgs, the four pixel positions use different quarters of the palette:
                ;; the first pixel colors 8-11, the second 12-15, the third 0-3, the fourth
                ;; 4-7 (each plus D).
                ld      b, #0

make_640_loop:
                ld      a, b
                srl     a
                srl     a
                srl     a
                srl     a
                srl     a
                srl     a
                add     a, #8
                or      d
                ld      (hl), a
                inc     hl
                ld      a, b
                srl     a
                srl     a
                srl     a
                srl     a
                and     #3
                add     a, #0xC
                or      d
                ld      (hl), a
                inc     hl
                ld      a, b
                srl     a
                srl     a
                and     #3
                or      d
                ld      (hl), a
                inc     hl
                ld      a, b
                and     #3
                add     a, #4
                or      d
                ld      (hl), a
                inc     hl
                inc     b
                ld      a, b
                cp      #0
                jp      NZ, make_640_loop
                ret

; Source = B/DE, Destination = B/HL

;; ----------------------------------------------------------------------------------------
;; DMA 4 KB from B/DE to B/HL.
;; ----------------------------------------------------------------------------------------
copy_4k_memory_block:
                ;; DMA channel 0: 4 KB from bank B, address DE to bank B, address HL, in
                ;; one burst.
                ld      a, b
                out0    (SAR0B), a
                ld      a, d
                out0    (SAR0H), a
                ld      a, e
                out0    (SAR0L), a
                ld      a, b
                out0    (DAR0B), a
                ld      a, h
                out0    (DAR0H), a
                ld      a, l
                out0    (DAR0L), a
                ld      a, #0x10
                out0    (BCR0H), a
                ld      a, #0
                out0    (BCR0L), a
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
                ret

;; FREE SPACE: $B025-$B1FF (475 bytes), zero in ROM 1.4. Part of $A000-$BFFF, which Super
;; Hi-Res setup copies to SRAM bank 1, so only the Super Hi-Res renderer's code can use it.
                .ds     475
