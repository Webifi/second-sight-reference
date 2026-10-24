;; for_original_u7/src/dhires.asm: src/dhires.asm with the changes for a card with the original
;; U7 (fuse map BE8C); SecondSight_for_original_u7.asm includes it. Every change from
;; src/ is marked CHANGE (En). En refers to docs/reference/errata.md.

;; ----------------------------------------------------------------------------------------
;; Double hires setup. Erratum E2: it switches the MMU to the double-hires layout first
;; (CBAR $C9, BBR $08, CBR $94: logical $9000-$9DFF shows the lookup tables) and then
;; calls routines that lie at $90A9 and up, so the Z180 runs table data and hangs.
;; The rest: mode $FA (560 x 192), screen on, the double hires palette, the repack tables
;; to SRAM bank 1 (copy_double_hires_a_b_lookup_tables), video memory cleared, the color
;; table into VGA memory (copy_double_hires_colour_lookup_tables), read segment 1, write
;; segment 0. docs/08-firmware.md, Double hires setup defect.
;; ----------------------------------------------------------------------------------------
set_videomode_double_hires:
                .assume set_videomode_double_hires - 0x8D7E ;; must stay at $8D7E
                di

; 0000-1FFF - Common Area 0 (no translation)
; 2000-3FFF - Common Area 0 (00/2000 - 00/3FFF aka Main DHR)
; 4000-8FFF - Common Area 0 (no translation)
; 9000-9FFF - Bank Area (01/1000 - 01/1FFF)
; A000-BFFF - Bank Area (01/2000 - 01/3FFF aka Aux DHR)
; C000-FFFF - Common Area 1 (0A/0000 - 0A/3FFF aka VRAM)
                ;; The double hires memory layout (the comments above): main memory's hires
                ;; page at logical $2000, SRAM bank 1 (auxiliary memory) at $9000-$BFFF
                ;; through BBR 8, so the repack tables appear at $9000-$9DFF and the
                ;; auxiliary hires page at $A000, and the VGA window at $C000 (CBR $94).
;; CHANGE (E2): fixes the hang when double hires starts. ROM 1.4 switches to the double
;; hires memory layout here (the three MMU writes below), and with that layout on, the
;; calls to the table copiers at $90A9 and $90E8 run table memory instead of code. Nothing
;; in this set-up needs the layout: the table copies and the screen clear are DMA transfers
;; with physical addresses, and the rest is port writes; emulate_double_hires sets the
;; layout itself on every pass. So this JR over the 15 bytes of MMU writes takes the place
;; of their first two bytes; the rest stays in place, never run.
                jr      dhr_setup_after_mmu
                out0    (CBAR), a
                ld      a, #8
                out0    (BBR), a
                ld      a, #0x94
                out0    (CBR), a
dhr_setup_after_mmu:
                ;; Half 1, mode $FA (560 x 192 in 16 colors), screen on.
                call    access_softswitch1
                ld      a, #0xFA        ; 560x192x16
                call    set_video_mode
                ld      a, #1
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a          ; Select sequencer clocking mode register
                ld      bc, #VGA_SEQ_DATA
                in      a, (c)
                res     5, a            ;; clear bit 5: screen on
                ld      d, a
                ld      a, #1
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a          ; Select sequencer clocking mode register
                ld      a, d
                ld      bc, #VGA_SEQ_DATA
                out     (c), a
                ;; The double hires colors, and the repack tables into SRAM bank 1.
                call    set_double_hires_palette
                call    copy_double_hires_a_b_lookup_tables
                ;; Clear the screen: all four planes writable, then DMA a zero byte
                ;; (zero_byte, source held fixed) over 64 KB of physical $A0000.
                ld      a, #2
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a          ; Select sequencer map mask register
                ld      a, #0xF         ; Write to all planes
                ld      bc, #VGA_SEQ_DATA
                out     (c), a
                ld      hl, #zero_byte  ; Source address = 00/8E13
                ld      (dma_source), hl
                ld      a, #0
                ld      (dma_source_bank), a
                ld      hl, #0          ; Destination address = 0A/0000
                ld      (dma_dest), hl
                ld      (dma_count), hl
                ld      a, #0xA
                ld      (dma_dest_bank), a
                call    fill_memory_block
                ;; The color table into video segment 1. Then plane 0 only, read segment 1
                ;; (the color table) and write segment 0 (the screen).
                call    copy_double_hires_colour_lookup_tables
                ld      a, #2
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a          ; Select sequencer map mask register
                ld      a, #1
                ld      bc, #VGA_SEQ_DATA
                out     (c), a          ; Write to plane 0
                ld      a, #0x23
                ld      bc, #OAK_INDEX
                out     (c), a          ; Select Oak Extended Read Segment register
                ld      a, #1
                ld      bc, #OAK_DATA
                out     (c), a          ; Extended Read Segment = 1
                ld      a, #0x24
                ld      bc, #OAK_INDEX
                out     (c), a          ; Select Oak Extended Write Segment register
                ld      a, #0
                ld      bc, #OAK_DATA
                out     (c), a          ; Extended Write Segment = 0
                ei
                jp      main_loop
zero_byte:      .db     0

;; ----------------------------------------------------------------------------------------
;; Double hires render routine: the double-hires MMU layout; write mode 1 for color
;; (NEWVIDEO bit 5 = 0); two passes of render_dhires_rows; then the normal MMU, plane 0
;; and write mode 0.
;; ----------------------------------------------------------------------------------------
emulate_double_hires:
                ;; The double hires memory layout again. Color uses write mode 1 (latches),
                ;; monochrome write mode 0.
                ld      a, #0xC9
                out0    (CBAR), a
                ld      a, #8
                out0    (BBR), a
                ld      a, #0x94
                out0    (CBR), a
                ld      a, (newvideo_flag)
                bit     5, a
                jr      NZ, emulate_double_hires2

; select write mode 1 for colour double hi-res
                ld      a, #5
                ld      bc, #VGA_GC_INDEX ; select graphics controller mode register
                out     (c), a
                ld      a, #1           ; select write mode 1
                ld      bc, #VGA_GC_DATA
                out     (c), a

emulate_double_hires2:
                ;; All four planes writable; two passes; then the normal MMU, plane 0 and
                ;; write mode 0.
                ld      a, #2
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a          ; Select sequencer map mask register
                ld      a, #0xF
                ld      bc, #VGA_SEQ_DATA
                out     (c), a          ; Enable all planes
                call    render_dhires_rows
                call    render_dhires_rows
                ld      a, #0
                out0    (CBR), a
                ld      a, #0
                out0    (BBR), a
                ld      a, #0xF2
                out0    (CBAR), a
                ld      a, #2
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a          ; Select sequencer map mask register
                ld      a, #1
                ld      bc, #VGA_SEQ_DATA
                out     (c), a          ; Enable plane 0 only
                ld      a, #5
                ld      bc, #VGA_GC_INDEX ; select graphics controller mode register
                out     (c), a
                ld      a, #0           ; select write mode 0
                ld      bc, #VGA_GC_DATA
                out     (c), a
                jp      main_loop

;; ----------------------------------------------------------------------------------------
;; 24 groups of 8 lines: IX = main memory line ($2000...), IY = auxiliary line (logical
;; $A000, SRAM bank 1 $2000 in this layout), DE = video address (logical $C000 window).
;; ----------------------------------------------------------------------------------------
render_dhires_rows:
                ;; IX = the main-memory line, IY = the same line in auxiliary memory, DE =
                ;; the screen. The 24 groups of 8 lines are in the Apple's interleaved
                ;; order.
                ld      ix, #0x2000
                ld      iy, #0xA000
                ld      de, #0xC000
                call    dhires_row
                ld      ix, #0x2080
                ld      iy, #0xA080
                call    dhires_row
                ld      ix, #0x2100
                ld      iy, #0xA100
                call    dhires_row
                ld      ix, #0x2180
                ld      iy, #0xA180
                call    dhires_row
                ld      ix, #0x2200
                ld      iy, #0xA200
                call    dhires_row
                ld      ix, #0x2280
                ld      iy, #0xA280
                call    dhires_row
                ld      ix, #0x2300
                ld      iy, #0xA300
                call    dhires_row
                ld      ix, #0x2380
                ld      iy, #0xA380
                call    dhires_row
                ld      ix, #0x2028
                ld      iy, #0xA028
                call    dhires_row
                ld      ix, #0x20A8
                ld      iy, #0xA0A8
                call    dhires_row
                ld      ix, #0x2128
                ld      iy, #0xA128
                call    dhires_row
                ld      ix, #0x21A8
                ld      iy, #0xA1A8
                call    dhires_row
                ld      ix, #0x2228
                ld      iy, #0xA228
                call    dhires_row
                ld      ix, #0x22A8
                ld      iy, #0xA2A8
                call    dhires_row
                ld      ix, #0x2328
                ld      iy, #0xA328
                call    dhires_row
                ld      ix, #0x23A8
                ld      iy, #0xA3A8
                call    dhires_row
                ld      ix, #0x2050
                ld      iy, #0xA050
                call    dhires_row
                ld      ix, #0x20D0
                ld      iy, #0xA0D0
                call    dhires_row
                ld      ix, #0x2150
                ld      iy, #0xA150
                call    dhires_row
                ld      ix, #0x21D0
                ld      iy, #0xA1D0
                call    dhires_row
                ld      ix, #0x2250
                ld      iy, #0xA250
                call    dhires_row
                ld      ix, #0x22D0
                ld      iy, #0xA2D0
                call    dhires_row
                ld      ix, #0x2350
                ld      iy, #0xA350
                call    dhires_row
                ld      ix, #0x23D0
                ld      iy, #0xA3D0
                call    dhires_row
                ret

                .db     0xC9            ;; a second RET after render_dhires_rows, never reached

;; ----------------------------------------------------------------------------------------
;; Draws one 8-line group of double hires. NEWVIDEO ($C029) bit 5 = 1 means monochrome
;; (mono_dhires_line), 0 color (colour_dhires_line). The s27 disassembly has these two
;; labels the other way round.
;; ----------------------------------------------------------------------------------------
dhires_row:
                ;; C = 8 lines per group.
                ld      a, (newvideo_flag)
                bit     5, a
                jr      Z, colour_row
                ld      a, #8
                ld      (dhires_row_counter), a

mono_row_loop:
;; CHANGE (E2): fixes the double hires lines running table memory as code. mono_dhires_line
;; runs into or lies in $9000 and up, where the double hires layout shows the repack
;; tables; this calls its copy at $1F10 (FREE SPACE $1EC4 block, src/mainloop.asm).
                call    mono_dhires_line_low
                ;; Next line: 80 bytes further on screen; $3D8 further in Apple memory
                ;; ($400 to the next line of the group, minus the 40 bytes the line routine
                ;; moved IX and IY on).
                ld      hl, #0x50
                add     hl, de
                push    hl
                pop     de
                ld      bc, #0x3D8
                add     ix, bc
                add     iy, bc
                ld      a, (dhires_row_counter)
                dec     a
                ret     Z
                ld      (dhires_row_counter), a
                jr      mono_row_loop

colour_row:
                ld      a, #8
                ld      (dhires_row_counter), a

colour_row_loop:
;; CHANGE (E2): fixes the double hires lines running table memory as code. colour_dhires_line
;; runs into or lies in $9000 and up, where the double hires layout shows the repack
;; tables; this calls its copy at $1F6F (FREE SPACE $1EC4 block, src/mainloop.asm).
                call    colour_dhires_line_low
                ld      hl, #0x50
                add     hl, de
                push    hl
                pop     de
                ld      bc, #0x3D8
                add     ix, bc
                add     iy, bc
                ld      a, (dhires_row_counter)
                dec     a
                ret     Z
                ld      (dhires_row_counter), a
                jr      colour_row_loop

dhires_row_counter:
                .db     0

;; ----------------------------------------------------------------------------------------
;; Monochrome line: repacks the 80 Apple bytes (auxiliary and main
;; in turn, 7 dots each) into 70 bytes of 8 dots with tables A7...A1 and B7...B1
;; (logical $9600 down and $9D00 down), and writes them to all four planes: dot on =
;; color 15, off = 0.
;; ----------------------------------------------------------------------------------------
mono_dhires_line:
                ;; C = 10 passes. Each pass takes four byte pairs (auxiliary, main) = 56
                ;; dots and writes 7 bytes of 8 dots: 70 screen bytes per line. The second
                ;; copy of DE in the other register set is not used.
                ld      c, #0xA
                push    de
                push    de
                exx
                pop     de
                exx

mono_byte_loop:
                ;; Output byte n = T_A(7-n)[left byte] OR T_B(7-n)[right byte]: the dots of
                ;; the left byte that fall into this output byte, and the first dots of the
                ;; byte to its right. B and H hold the table pages ($96 = T_A7 and $9D =
                ;; T_B7 at logical $9xxx) and count down one table per output byte; C and L
                ;; hold the two Apple bytes.
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
                ;; Next 8 Apple bytes (4 in each memory).
                exx
                ld      de, #4
                add     ix, de
                add     iy, de
                dec     c
                jr      NZ, mono_byte_loop
                pop     de
                ret

;; ----------------------------------------------------------------------------------------
;; Color line: repacks as mono_dhires_line does, then reads VGA
;; address $C000 + byte (read segment 1 holds the color table), which loads that entry's
;; four plane bytes into the latches, and writes the screen in write mode 1: eight
;; 16-color pixels per byte. The color rule: docs/08-firmware.md, Double hires.
;; ----------------------------------------------------------------------------------------
colour_dhires_line:
                ;; The same repacking, with D = $C0: each repacked byte E reads $C0xx, the
                ;; color table in read segment 1, which loads its four plane bytes into the
                ;; latches; the write that follows (write mode 1) stores them on the
                ;; screen: eight 4-bit pixels.
                ld      c, #0xA
                push    de
                push    de
                exx
                pop     de
                exx

colour_byte_loop:
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
                jr      NZ, colour_byte_loop
                pop     de
                ret

;; ----------------------------------------------------------------------------------------
;; DMA $E00 bytes of repack tables from the EPROM (physical $6D000) to SRAM bank 1
;; $1000-$1DFF, where the double-hires layout shows them at logical $9000-$9DFF.
;; ----------------------------------------------------------------------------------------
copy_double_hires_a_b_lookup_tables:
                ;; DMA channel 0: $E00 bytes from the EPROM (bank 6: physical $6D000, T_A1)
                ;; to SRAM bank 1 $1000 (physical $11000), in one burst.
                ld      a, #<(T_A1)
                out0    (SAR0L), a
                ld      a, #>(T_A1)
                out0    (SAR0H), a
                ld      a, #6
                out0    (SAR0B), a
                ld      a, #0
                out0    (DAR0L), a
                ld      a, #0x10
                out0    (DAR0H), a
                ld      a, #1
                out0    (DAR0B), a
                ld      a, #0
                out0    (BCR0L), a
                ld      a, #0xE
                out0    (BCR0H), a

; Copy $E00 bytes from 06/D000 to 01/1000
; A1 : 01/1000 - 01/10FF
; A2 : 01/1100 - 01/11FF
; A3 : 01/1200 - 01/12FF
; A4 : 01/1300 - 01/13FF
; A5 : 01/1400 - 01/14FF
; A6 : 01/1500 - 01/15FF
; A7 : 01/1600 - 01/16FF
; B1 : 01/1700 - 01/17FF
; B2 : 01/1800 - 01/18FF
; B3 : 01/1900 - 01/19FF
; B4 : 01/1A00 - 01/1AFF
; B5 : 01/1B00 - 01/1BFF
; B6 : 01/1C00 - 01/1CFF
; B7 : 01/1D00 - 01/1DFF
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

;; ----------------------------------------------------------------------------------------
;; Copies the 1 KB color table (colour_dhr_lookup_table) into VGA memory segment 1, one
;; 256-byte page per plane, for colour_dhires_line's latch lookups.
;; ----------------------------------------------------------------------------------------
copy_double_hires_colour_lookup_tables:
                ;; DMA channel 0 source: the color table in the EPROM (physical $6DE00).
                ;; Write segment 1, then one 256-byte page into each plane.
                ld      a, #<(colour_dhr_lookup_table)
                out0    (SAR0L), a
                ld      a, #>(colour_dhr_lookup_table)
                out0    (SAR0H), a
                ld      a, #6
                out0    (SAR0B), a
                ld      a, #0x24
                ld      bc, #OAK_INDEX
                out     (c), a          ; Select Oak extended write segment register
                ld      a, #1
                ld      bc, #OAK_DATA
                out     (c), a          ; Write segment = 1
                ld      a, #2
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a          ; Select sequencer map mask register
                ld      a, #1
                ld      bc, #VGA_SEQ_DATA
                out     (c), a          ; Write to plane 0
                call    copy_one_page_to_A0000
                ld      a, #2
                ld      bc, #VGA_SEQ_INDEX ; Select sequencer map mask register
                out     (c), a
                ld      a, #2
                ld      bc, #VGA_SEQ_DATA
                out     (c), a          ; Write to plane 1
                call    copy_one_page_to_A0000
                ld      a, #2
                ld      bc, #VGA_SEQ_INDEX ; Select sequencer map mask register
                out     (c), a
                ld      a, #4
                ld      bc, #VGA_SEQ_DATA
                out     (c), a          ; Write to plane 2
                call    copy_one_page_to_A0000
                ld      a, #2
                ld      bc, #VGA_SEQ_INDEX ; Select sequencer map mask register
                out     (c), a
                ld      a, #8
                ld      bc, #VGA_SEQ_DATA
                out     (c), a          ; Write to plane 3
                call    copy_one_page_to_A0000
                ret

;; ----------------------------------------------------------------------------------------
;; DMA 256 bytes to physical $A0000 (the next page of the source).
;; ----------------------------------------------------------------------------------------
copy_one_page_to_A0000:
                ;; Destination physical $A0000 (the window start, segment 1 through the
                ;; write segment), 256 bytes. The source address carries on from the last
                ;; page.
                ld      a, #0
                out0    (DAR0L), a
                ld      a, #0
                out0    (DAR0H), a
                ld      a, #0xA
                out0    (DAR0B), a
                ld      a, #0
                out0    (BCR0L), a
                ld      a, #1
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
                ret
