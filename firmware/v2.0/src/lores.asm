;; v2.0/src/lores.asm: v1.4/src/lores.asm with the changes for a card with the corrected
;; U7 (fuse map BBB1); SecondSight_v2_0.asm includes it. Every change from
;; v1.4/src/ is marked CHANGE (En). En refers to docs/reference/errata.md.

;; ----------------------------------------------------------------------------------------
;; Lores setup: mode $FE (640 x 200), half 0, the lores palette (DAC entries $10-$1F) and
;; the text palette, screen on, and lores_cache_valid = 0, which makes the first pass redraw every
;; block. (log_debug_string does nothing.)
;; ----------------------------------------------------------------------------------------
set_videomode_lores:
                push    hl
                ld      hl, #aBeginLowResGraphicsShadowing ; "\r\nbegin low res graphics shadowing\r"...
                call    log_debug_string
                jp      set_videomode_lores2
aBeginLowResGraphicsShadowing:
                .db     0xD, 0xA
                .ascii  'begin low res graphics shadowing'
                .db     0xD, 0xA, 0
                .db     0xFF            ;; one byte after the string, never run

set_videomode_lores2:
                pop     hl
                ;; Mode $FE: 640 x 200 in 256 colors (each Apple lores row is a 16 x 4
                ;; pixel block), half 0.
                di
                ld      a, #0xFE        ; 640x200
                call    set_video_mode
                call    access_softswitch0
                ld      hl, #emulate_lores
                ld      (emulate_current_videomode), hl
                ;; Lores colors and text colors into the DAC, screen on.
                call    set_lores_palette
                ld      a, #1
                ld      bc, #VGA_SEQ_INDEX ; Sequencer clocking mode
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
                ;; Make the first pass draw every block.
                ld      a, #0
                ld      (lores_cache_valid), a
                ei
                jp      main_loop

;; ----------------------------------------------------------------------------------------
;; Lores render routine: MMU CBAR $F9, BBR $77, CBR $21 (logical $F000 = SRAM bank 1, the
;; auxiliary text page). Every fourth pass it swaps the flashing text colors
;; (setup_textmode_palette). Two passes of render_lores, then the normal MMU.
;; ----------------------------------------------------------------------------------------
emulate_lores:
                ;; MMU: bank area from logical $9000 (CBAR $F9) at physical $80000 (BBR
                ;; $77: $9000 + $77000), the start of the linear video window; common area
                ;; 1 ($F000) at physical $30000 (CBR $21), SRAM bank 1, where the auxiliary
                ;; text page sits at $F400-$FBFF.
                ld      a, #0xF9
                out0    (CBAR), a
                ld      a, #0x77
                out0    (BBR), a
                ld      a, #0x21
                out0    (CBR), a
                ;; Every fourth pass swap the two flashing text colors.
                ld      a, (flash_counter)
                cp      #3
                jr      NZ, lores_count_pass
                call    setup_textmode_palette
                ld      a, #0xFF

lores_count_pass:
                inc     a
                ld      (flash_counter), a
                ;; Two passes, then the normal MMU layout and back to the main loop.
                call    render_lores
                call    render_lores
                ld      a, #0
                out0    (CBR), a
                ld      a, #0
                out0    (BBR), a
                ld      a, #0xF2
                out0    (CBAR), a
                jp      main_loop

;; ----------------------------------------------------------------------------------------
;; Draws the lores screen: waits for vertical retrace, switches to the linear window with
;; the 64-bit latch and color expansion (Oak $30 = $0D, pixel mask $34 and color pattern
;; $33 = $FF), then draws text rows 0-19 (lores rows 0-39), and either rows 20-23 or the
;; four mixed-mode text lines (40 or 80 columns). After the first pass lores_cache_valid = 1,
;; and only changed blocks are drawn.
;; ----------------------------------------------------------------------------------------
render_lores:
                ;; Wait for vertical retrace (input status 1, bit 3) so the drawing starts
                ;; out of sight.
                ld      bc, #VGA_STATUS1
                in      a, (c)          ; Read VGA Input Status Register #1
                bit     3, a            ; Check vertical retrace
                jr      Z, render_lores
                ;; Linear window on (Oak register 5 = $19). Oak $22 = $10: 64-bit latch.
                ;; Oak $30 = $0D: color expansion with a pixel mask. Under color expansion
                ;; each CPU write fills pixels with the foreground color (Oak $31) where
                ;; the written byte has 1 bits; Oak $34 = $FF lets all pixels through, Oak
                ;; $33 = $FF makes every pixel foreground.
                ld      a, #0
                out0    (LINEAR_ON), a
                ld      a, #5
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0x19
                ld      bc, #OAK_DATA
                out     (c), a
                ld      a, #0x22        ; Oak Feature Select register
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0x10        ; Enable 64-bit graphics latch
                ld      bc, #OAK_DATA
                out     (c), a
                ld      a, #0x30        ; Oak Color expansion control register
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0xD         ; Enable color expansion mode / packed pixels / use colour pattern register / enable pixel mask
                ld      bc, #OAK_DATA
                out     (c), a
                ld      a, #0x34        ; Oak pixel mask register
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0xFF        ; 8 x Pass through pixel data
                ld      bc, #OAK_DATA
                out     (c), a
                ld      a, #0x33        ; Oak color pattern register
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0xFF        ; Pattern = 8 x Foreground colour
                ld      bc, #OAK_DATA
                out     (c), a
                ;; IX walks the redraw cache, one byte per text position, in step with the
                ;; screen.
                ld      ix, #lores_cache
                ld      a, (current_page)
                cp      #1
                jr      NZ, render_top_rows_page1
                call    render_lores_page2_top ; Render lines 0-39 of lores page 2
                jr      check_for_lores_mixed_mode

render_top_rows_page1:
                call    render_lores_page1_top ; Render lines 0-39 of lores page 1

check_for_lores_mixed_mode:
                ;; Rows 20-23: four more lores rows, or four text lines in mixed mode.
                ld      a, (mixed_mode_flag)
                cp      #1
                jr      Z, render_lores_mixed_mode
                ld      a, (current_page)
                cp      #1
                jr      NZ, render_bottom_rows_page1
                call    render_lores_page2_bottom ; Render lines 40-47 of lores page 2
                jr      finished_lores_render

render_bottom_rows_page1:
                call    render_lores_page1_bottom ; Render lines 40-47 of lores page 1
                jr      finished_lores_render

render_lores_mixed_mode:
                ld      a, (text80_enabled_flag)
                cp      #1
                jr      Z, render_lores_mixed_mode_80col
                ld      a, (current_page)
                cp      #1
                jr      NZ, render_mixed_mode_text_page1
                call    render_lores_page2_text40
                jr      finished_lores_render

render_mixed_mode_text_page1:
                call    render_lores_page1_text40
                jr      finished_lores_render

render_lores_mixed_mode_80col:
                call    render_lores_text80

finished_lores_render:
                ;; Next pass: only changed blocks. Then color expansion, the linear window
                ;; and the 64-bit latch off.
                ld      a, #1
                ld      (lores_cache_valid), a
                ld      a, #0x30
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0           ; Disable colour expansion
                ld      bc, #OAK_DATA
                out     (c), a
                ld      a, #5
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0
                ld      bc, #OAK_DATA
                out     (c), a
                ld      a, #0x22
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0
                ld      bc, #OAK_DATA
                out     (c), a
                ld      a, #0           ; Turn off 64-bit latch
                out0    (LINEAR_OFF), a
                ret

; Render lines 0-39 of lores page 1

;; ----------------------------------------------------------------------------------------
;; Text rows 0-19 of page 1 ($0400) or 2 ($0800), in the Apple's interleaved order. BBR
;; picks which part of video memory logical $9000-$CFFF shows; HL = text row address,
;; DE = video address.
;; ----------------------------------------------------------------------------------------
render_lores_page1_top:
                ;; BBR picks which 16 KB of the video window logical $9000-$CFFF shows:
                ;; each step of 5 ($5000 bytes) is four text rows, each text row $1400
                ;; bytes (8 screen lines of 640 pixels). HL = the Apple text row, DE = its
                ;; screen address.
                ld      a, #0x77
                out0    (BBR), a
                ld      hl, #0x400
                ld      de, #0x9000
                call    render_lores_linepair
                ld      hl, #0x480
                ld      de, #0xA400
                call    render_lores_linepair
                ld      hl, #0x500
                ld      de, #0xB800
                call    render_lores_linepair
                ld      hl, #0x580
                ld      de, #0xCC00
                call    render_lores_linepair
                ld      a, #0x7C
                out0    (BBR), a
                ld      hl, #0x600
                ld      de, #0x9000
                call    render_lores_linepair
                ld      hl, #0x680
                ld      de, #0xA400
                call    render_lores_linepair
                ld      hl, #0x700
                ld      de, #0xB800
                call    render_lores_linepair
                ld      hl, #0x780
                ld      de, #0xCC00
                call    render_lores_linepair
                ld      a, #0x81
                out0    (BBR), a
                ld      hl, #0x428
                ld      de, #0x9000
                call    render_lores_linepair
                ld      hl, #0x4A8
                ld      de, #0xA400
                call    render_lores_linepair
                ld      hl, #0x528
                ld      de, #0xB800
                call    render_lores_linepair
                ld      hl, #0x5A8
                ld      de, #0xCC00
                call    render_lores_linepair
                ld      a, #0x86
                out0    (BBR), a
                ld      hl, #0x628
                ld      de, #0x9000
                call    render_lores_linepair
                ld      hl, #0x6A8
                ld      de, #0xA400
                call    render_lores_linepair
                ld      hl, #0x728
                ld      de, #0xB800
                call    render_lores_linepair
                ld      hl, #0x7A8
                ld      de, #0xCC00
                call    render_lores_linepair
                ld      a, #0x8B
                out0    (BBR), a
                ld      hl, #0x450
                ld      de, #0x9000
                call    render_lores_linepair
                ld      hl, #0x4D0
                ld      de, #0xA400
                call    render_lores_linepair
                ld      hl, #0x550
                ld      de, #0xB800
                call    render_lores_linepair
                ld      hl, #0x5D0
                ld      de, #0xCC00
                call    render_lores_linepair
                ret

; Render lines 0-39 of lores page 2

;; render_lores_page2_top: the same for page 2 ($0800).
render_lores_page2_top:
                ld      a, #0x77
                out0    (BBR), a
                ld      hl, #0x800
                ld      de, #0x9000
                call    render_lores_linepair
                ld      hl, #0x880
                ld      de, #0xA400
                call    render_lores_linepair
                ld      hl, #0x900
                ld      de, #0xB800
                call    render_lores_linepair
                ld      hl, #0x980
                ld      de, #0xCC00
                call    render_lores_linepair
                ld      a, #0x7C
                out0    (BBR), a
                ld      hl, #0xA00
                ld      de, #0x9000
                call    render_lores_linepair
                ld      hl, #0xA80
                ld      de, #0xA400
                call    render_lores_linepair
                ld      hl, #0xB00
                ld      de, #0xB800
                call    render_lores_linepair
                ld      hl, #0xB80
                ld      de, #0xCC00
                call    render_lores_linepair
                ld      a, #0x81
                out0    (BBR), a
                ld      hl, #0x828
                ld      de, #0x9000
                call    render_lores_linepair
                ld      hl, #0x8A8
                ld      de, #0xA400
                call    render_lores_linepair
                ld      hl, #0x928
                ld      de, #0xB800
                call    render_lores_linepair
                ld      hl, #0x9A8
                ld      de, #0xCC00
                call    render_lores_linepair
                ld      a, #0x86
                out0    (BBR), a
                ld      hl, #0xA28
                ld      de, #0x9000
                call    render_lores_linepair
                ld      hl, #0xAA8
                ld      de, #0xA400
                call    render_lores_linepair
                ld      hl, #0xB28
                ld      de, #0xB800
                call    render_lores_linepair
                ld      hl, #0xBA8
                ld      de, #0xCC00
                call    render_lores_linepair
                ld      a, #0x8B
                out0    (BBR), a
                ld      hl, #0x850
                ld      de, #0x9000
                call    render_lores_linepair
                ld      hl, #0x8D0
                ld      de, #0xA400
                call    render_lores_linepair
                ld      hl, #0x950
                ld      de, #0xB800
                call    render_lores_linepair
                ld      hl, #0x9D0
                ld      de, #0xCC00
                call    render_lores_linepair
                ret

;; Never reached.
unreached_ret_67C0:
                ret

; Render lines 40-47 of lores page 1

;; ----------------------------------------------------------------------------------------
;; Text rows 20-23 of page 1 or 2, when not in mixed mode.
;; ----------------------------------------------------------------------------------------
render_lores_page1_bottom:
                ld      a, #0x90
                out0    (BBR), a
                ld      hl, #0x650
                ld      de, #0x9000
                call    render_lores_linepair
                ld      hl, #0x6D0
                ld      de, #0xA400
                call    render_lores_linepair
                ld      hl, #0x750
                ld      de, #0xB800
                call    render_lores_linepair
                ld      hl, #0x7D0
                ld      de, #0xCC00
                call    render_lores_linepair
                ret

; Render lines 40-47 of lores page 2

;; render_lores_page2_bottom: the same for page 2.
render_lores_page2_bottom:
                ld      a, #0x90
                out0    (BBR), a
                ld      hl, #0xA50
                ld      de, #0x9000
                call    render_lores_linepair
                ld      hl, #0xAD0
                ld      de, #0xA400
                call    render_lores_linepair
                ld      hl, #0xB50
                ld      de, #0xB800
                call    render_lores_linepair
                ld      hl, #0xBD0
                ld      de, #0xCC00
                call    render_lores_linepair
                ret

;; Never reached.
unreached_ret_6815:
                ret

;; ----------------------------------------------------------------------------------------
;; The four mixed-mode text lines in 40 columns: each character 16 pixels wide, left half
;; with render_text40_left_halves (table $7900), right half with render_text40_right_halves (table $7800).
;; ----------------------------------------------------------------------------------------
render_lores_page1_text40:
                ;; 40-column text: each 8-dot glyph row becomes 16 pixels, left half first
                ;; (high nibble, nibble_double_high), then the right halves (low nibble,
                ;; nibble_double_low) 8 pixels further on.
                ld      a, #0x90
                out0    (BBR), a
                ld      hl, #0x650
                ld      de, #0x9000
                call    render_text40_left_halves
                ld      hl, #0x6D0
                ld      de, #0xA400
                call    render_text40_left_halves
                ld      hl, #0x750
                ld      de, #0xB800
                call    render_text40_left_halves
                ld      hl, #0x7D0
                ld      de, #0xCC00
                call    render_text40_left_halves
                ld      hl, #0x650
                ld      de, #0x9008
                call    render_text40_right_halves
                ld      hl, #0x6D0
                ld      de, #0xA408
                call    render_text40_right_halves
                ld      hl, #0x750
                ld      de, #0xB808
                call    render_text40_right_halves
                ld      hl, #0x7D0
                ld      de, #0xCC08
                call    render_text40_right_halves
                ret

;; render_lores_page2_text40: the same for text page 2.
render_lores_page2_text40:
                ld      a, #0x90
                out0    (BBR), a
                ld      hl, #0xA50
                ld      de, #0x9000
                call    render_text40_left_halves
                ld      hl, #0xAD0
                ld      de, #0xA400
                call    render_text40_left_halves
                ld      hl, #0xB50
                ld      de, #0xB800
                call    render_text40_left_halves
                ld      hl, #0xBD0
                ld      de, #0xCC00
                call    render_text40_left_halves
                ld      hl, #0xA50
                ld      de, #0x9008
                call    render_text40_right_halves
                ld      hl, #0xAD0
                ld      de, #0xA408
                call    render_text40_right_halves
                ld      hl, #0xB50
                ld      de, #0xB808
                call    render_text40_right_halves
                ld      hl, #0xBD0
                ld      de, #0xCC08
                call    render_text40_right_halves
                ret

;; ----------------------------------------------------------------------------------------
;; The four mixed-mode text lines in 80 columns: main-memory characters ($06xx) into the
;; odd 8-pixel cells and auxiliary ones ($F6xx, SRAM bank 1 in this layout) into the even
;; cells, with render_text80_row.
;; ----------------------------------------------------------------------------------------
render_lores_text80:
                ;; 80-column text: the main-memory character goes in the odd 8-pixel cell,
                ;; the auxiliary one (logical $F6xx, SRAM bank 1) in the even cell to its
                ;; left.
                ld      a, #0x90
                out0    (BBR), a
                ld      hl, #0x650
                ld      de, #0x9008
                call    render_text80_row
                ld      hl, #0x6D0
                ld      de, #0xA408
                call    render_text80_row
                ld      hl, #0x750
                ld      de, #0xB808
                call    render_text80_row
                ld      hl, #0x7D0
                ld      de, #0xCC08
                call    render_text80_row
                ld      hl, #0xF650
                ld      de, #0x9000
                call    render_text80_row
                ld      hl, #0xF6D0
                ld      de, #0xA400
                call    render_text80_row
                ld      hl, #0xF750
                ld      de, #0xB800
                call    render_text80_row
                ld      hl, #0xF7D0
                ld      de, #0xCC00
                call    render_text80_row
                ret

                ;; Two bytes nothing reads.
                .db     0
                .db     0

;; ----------------------------------------------------------------------------------------
;; 0 = redraw every lores block on the next pass; 1 = only blocks that changed.
;; ----------------------------------------------------------------------------------------
lores_cache_valid:
                .db     0

;; ----------------------------------------------------------------------------------------
;; Draws one text row of lores: 40 bytes, each two blocks (low nibble = top block, high
;; nibble = bottom block), through color expansion with the block's color as foreground
;; (Oak $31 = nibble + $10, the lores palette entries). A byte equal to its copy in the
;; redraw cache (IX, from $6BC8) is skipped after the first pass.
;; ----------------------------------------------------------------------------------------
render_lores_linepair:
                ;; C = 40 bytes in the row. Each Apple byte holds two blocks: low nibble =
                ;; top block, high nibble = bottom block.
                ld      c, #0x28

lores_byte_loop:
                ;; After the first pass, a byte equal to its copy in the redraw cache is
                ;; skipped.
                ld      b, (hl)
                ld      a, (lores_cache_valid)
                cp      #0
                jr      NZ, lores_check_cache
                ld      a, b
                ex      af, af'
                ld      a, b
                jr      lores_draw_byte

lores_check_cache:
                ld      a, b
                ex      af, af'
                ld      a, b
                cp      0(ix)
                jp      Z, lores_next_byte

lores_draw_byte:
                ;; Top block: foreground color = the nibble + $10 (the lores palette is at
                ;; DAC entries $10-$1F).
                push    de
                and     #0xF
                exx
                add     a, #0x10
                ld      d, a
                ld      a, #0x31
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, d
                ld      bc, #OAK_DATA
                out     (c), a
                ;; The block covers 16 pixels on each of its 4 screen lines. Under color
                ;; expansion a write at offset 0 fills pixels 0-3 of an 8-pixel group and
                ;; offset 1 pixels 4-7 (docs/reference/oti087-registers.md), so the writes
                ;; at 0, 1, 8 and 9 cover the 16 pixels. DE = $277 then steps to the next
                ;; line (640 bytes per line).
                ld      de, #0x277
                pop     hl
                ld      (hl), a
                inc     l
                ld      (hl), a
                ld      a, l
                add     a, #7
                ld      l, a
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                ld      (hl), a
                inc     l
                ld      (hl), a
                ld      a, l
                add     a, #7
                ld      l, a
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                ld      (hl), a
                inc     l
                ld      (hl), a
                ld      a, l
                add     a, #7
                ld      l, a
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                ld      (hl), a
                inc     l
                ld      (hl), a
                ld      a, l
                add     a, #7
                ld      l, a
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                ;; Bottom block: the high nibble, the same way on the next 4 lines.
                exx
                ld      a, (hl)
                srl     a
                srl     a
                srl     a
                srl     a
                exx
                add     a, #0x10
                ld      d, a
                ld      a, #0x31
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, d
                ld      bc, #OAK_DATA
                out     (c), a
                ld      de, #0x277
                ld      (hl), a
                inc     l
                ld      (hl), a
                ld      a, l
                add     a, #7
                ld      l, a
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                ld      (hl), a
                inc     l
                ld      (hl), a
                ld      a, l
                add     a, #7
                ld      l, a
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                ld      (hl), a
                inc     l
                ld      (hl), a
                ld      a, l
                add     a, #7
                ld      l, a
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                ld      (hl), a
                inc     l
                ld      (hl), a
                ld      a, l
                add     a, #7
                ld      l, a
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                ;; Save the byte in the redraw cache.
                exx
                ex      af, af'
                ld      0(ix), a

lores_next_byte:
                ;; Next byte: the screen moves 16 pixels right.
                inc     ix
                ld      a, e
                add     a, #0x10
                ld      e, a
                jr      NC, lores_next_source
                inc     d

lores_next_source:
                inc     hl
                dec     c
                jp      NZ, lores_byte_loop
                ret

;; ----------------------------------------------------------------------------------------
;; One 80-column text row for mixed lores: 40 characters from HL into every other 8-pixel
;; cell, colors from get_text_colour (Oak $31/$32), glyphs from font_table_8x8 through the
;; character map in char_code_table.
;; ----------------------------------------------------------------------------------------
render_text80_row:
                ;; The first instruction does nothing. Oak $30 = $09: color expansion with
                ;; the colors in Oak $31 (foreground, for 1 bits) and $32 (background, for
                ;; 0 bits).
                ld      b, (hl)
                ld      a, #0x30
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #9
                ld      bc, #OAK_DATA
                out     (c), a
                ld      c, #0x28

text80_char_loop:
                ;; Per character: the colors for its screen code, then its 8x8 glyph.
                push    de
                ld      a, (hl)
                exx
                ld      b, a
                call    get_text_colour
                ld      a, #0x31
                ld      bc, #OAK_INDEX
                out     (c), a          ; Select Oak foreground color register
                ld      a, h
                ld      bc, #OAK_DATA
                out     (c), a          ; Set foreground color
                ld      a, #0x32
                ld      bc, #OAK_INDEX
                out     (c), a          ; Select Oak background color register
                ld      a, l
                ld      bc, #OAK_DATA
                out     (c), a          ; Set background color
                exx
                ld      a, (hl)
                exx
                ld      hl, (char_code_table)
                ld      l, a
                ld      b, (hl)
                ld      c, #8
                mlt     bc
                ld      hl, #font_table_8x8
                add     hl, bc
                push    hl
                pop     bc
                ;; The 8 glyph rows go to 8 screen lines; DE = $27F steps one line down.
                ld      de, #0x27F
                pop     hl
                ld      a, (bc)
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                inc     bc
                ld      a, (bc)
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                inc     bc
                ld      a, (bc)
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                inc     bc
                ld      a, (bc)
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                inc     bc
                ld      a, (bc)
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                inc     bc
                ld      a, (bc)
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                inc     bc
                ld      a, (bc)
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                inc     bc
                ld      a, (bc)
                ld      (hl), a
                inc     l
                ld      (hl), a
                exx
                ld      a, e
                add     a, #0x10
                ld      e, a
                jr      NC, text80_next_char
                inc     d

text80_next_char:
                inc     hl
                dec     c
                jp      NZ, text80_char_loop
                ;; Back to Oak $30 = $0D for the lores blocks.
                ld      a, #0x30
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0xD
                ld      bc, #OAK_DATA
                out     (c), a
                ret

;; ----------------------------------------------------------------------------------------
;; Half of one 40-column text row for mixed lores: each glyph byte doubled to 16 pixels
;; through a table (render_text40_right_halves: $7800, the right 8 pixels; render_text40_left_halves: $7900, the left 8).
;; ----------------------------------------------------------------------------------------
;; The same as render_text80_row, with each glyph row widened through nibble_double_low (BC
;; points into the table; C = the glyph row).
render_text40_right_halves:
                ld      b, (hl)
                ld      a, #0x30
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #9
                ld      bc, #OAK_DATA
                out     (c), a
                ld      c, #0x28

text40_right_loop:
                push    de
                ld      a, (hl)
                exx
                ld      b, a
                call    get_text_colour
                ld      a, #0x31
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, h
                ld      bc, #OAK_DATA
                out     (c), a
                ld      a, #0x32
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, l
                ld      bc, #OAK_DATA
                out     (c), a
                exx
                ld      a, (hl)
                exx
                ld      hl, (char_code_table)
                ld      l, a
                ld      b, (hl)
                ld      c, #8
                mlt     bc
                ld      hl, #font_table_8x8
                add     hl, bc
                push    hl
                pop     ix
                ld      de, #0x27F
                pop     hl
                ld      bc, #nibble_double_low
                ld      c, 0(ix)
                ld      a, (bc)
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                ld      c, 1(ix)
                ld      a, (bc)
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                ld      c, 2(ix)
                ld      a, (bc)
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                ld      c, 3(ix)
                ld      a, (bc)
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                ld      c, 4(ix)
                ld      a, (bc)
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                ld      c, 5(ix)
                ld      a, (bc)
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                ld      c, 6(ix)
                ld      a, (bc)
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                ld      c, 7(ix)
                ld      a, (bc)
                ld      (hl), a
                inc     l
                ld      (hl), a
                exx
                ld      a, e
                add     a, #0x10
                ld      e, a
                jr      NC, text40_right_next
                inc     d

text40_right_next:
                inc     hl
                dec     c
                jp      NZ, text40_right_loop
                ld      a, #0x30
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0xD
                ld      bc, #OAK_DATA
                out     (c), a
                ret

;; The same with nibble_double_high: the left halves.
render_text40_left_halves:
                ld      b, (hl)
                ld      a, #0x30
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #9
                ld      bc, #OAK_DATA
                out     (c), a
                ld      c, #0x28

text40_left_loop:
                push    de
                ld      a, (hl)
                exx
                ld      b, a
                call    get_text_colour
                ld      a, #0x31
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, h
                ld      bc, #OAK_DATA
                out     (c), a
                ld      a, #0x32
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, l
                ld      bc, #OAK_DATA
                out     (c), a
                exx
                ld      a, (hl)
                exx
                ld      hl, (char_code_table)
                ld      l, a
                ld      b, (hl)
                ld      c, #8
                mlt     bc
                ld      hl, #font_table_8x8
                add     hl, bc
                push    hl
                pop     ix
                ld      de, #0x27F
                pop     hl
                ld      bc, #nibble_double_high
                ld      c, 0(ix)
                ld      a, (bc)
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                ld      c, 1(ix)
                ld      a, (bc)
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                ld      c, 2(ix)
                ld      a, (bc)
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                ld      c, 3(ix)
                ld      a, (bc)
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                ld      c, 4(ix)
                ld      a, (bc)
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                ld      c, 5(ix)
                ld      a, (bc)
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                ld      c, 6(ix)
                ld      a, (bc)
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                ld      c, 7(ix)
                ld      a, (bc)
                ld      (hl), a
                inc     l
                ld      (hl), a
                exx
                ld      a, e
                add     a, #0x10
                ld      e, a
                jr      NC, text40_left_next
                inc     d

text40_left_next:
                inc     hl
                dec     c
                jp      NZ, text40_left_loop
                ld      a, #0x30
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0xD
                ld      bc, #OAK_DATA
                out     (c), a
                ret

; Returns H = foreground colour, L = background colour

;; ----------------------------------------------------------------------------------------
;; Returns the colors for screen code B: H = foreground and L = background DAC entry.
;; Normal characters (B >= $80): 1 on 0. Inverse (B < $40): 0 on 1. Flashing ($40-$7F):
;; 3 on 2, which setup_textmode_palette swaps. With the alternate set, $40-$5F (MouseText)
;; is normal and the rest below $80 inverse.
;; ----------------------------------------------------------------------------------------
get_text_colour:
                ;; The normal character set first: $80 and up normal (1 on 0), below $40
                ;; inverse (0 on 1), $40-$7F flashing (3 on 2).
                ld      a, (altcharset_flag)
                cp      #0
                jr      NZ, text_colour_alternate
                ld      a, b
                cp      #0x80
                jr      NC, text_colour_normal
                cp      #0x40
                jr      NC, text_colour_flashing
                ld      hl, #1
                ret

text_colour_flashing:
                ld      hl, #0x302
                ret

text_colour_normal:
                ld      hl, #0x100
                ret

text_colour_alternate:
                ;; The alternate set: $80 and up normal; MouseText ($40-$5F) normal; the
                ;; rest inverse.
                ld      a, b
                cp      #0x80
                jr      NC, text_colour_normal
                and     #0x60
                cp      #0x40
                jr      Z, text_colour_normal
                ld      hl, #0x0001
                ret

;; $6BC8-$6F87 (960 bytes).
;; The lores redraw cache: render_lores_linepair keeps the last byte it drew for each
;; lores position here, one byte per position (IX), and skips positions that have not
;; changed since.
lores_cache:
                .ds     960
;; $6F88-$73FF (1,144 bytes).
;; Zero in ROM 1.4.
                .ds     1144
