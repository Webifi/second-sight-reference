;; src/hires.asm, $2000-$64B5: the hires pages' place, hires set-up and renderer, mixed-mode text.
;; Part of the ROM 1.4 firmware source; ROM_BEEF.asm includes it.

hires_page1:
                .assume hires_page1 - 0x2000 ;; must stay at $2000
;; $2000-$5FFF (16,384 bytes).
;; Not copied into SRAM at boot. At run time SRAM bank 0 $2000-$5FFF holds the Apple's
;; hires pages 1 and 2 (the screen copy), so these zero EPROM bytes are not free.
                .ds     16384

;; ----------------------------------------------------------------------------------------
;; ==== $6000-$FFFF: renderers, fonts, color tables, palettes and the mode records,
;; copied into SRAM at boot. Each renderer reads the Apple screen copy in SRAM (bank 0 =
;; main, bank 1 = auxiliary) and draws through the Oak's video memory window.
;; docs/08-firmware.md, Renderers.
;;
;; Hires setup: mode $FB (280 x 192), MMU CBAR $C2 and CBR $94 (logical $C000 = the VGA
;; window at physical $A0000), the hires palette, then the hires conversion tables
;; ($B200-$B9FF) copied into the four VGA planes at offsets $0000 and $0100 of segment 1.
;; render_hires_line reads a table entry there (loading the VGA latches) and writes the
;; screen in write mode 1, which stores the latches: one byte in, four planes out.
;; ----------------------------------------------------------------------------------------
set_videomode_hires:
                .assume set_videomode_hires - 0x6000 ;; must stay at $6000
                ;; MMU: common area 1 (logical $C000-$FFFF) at physical $A0000 (CBR $94:
                ;; $C000 + $94000), the VGA chip's standard memory window. CBAR $C2: bank
                ;; area $2000-$BFFF.
                di
                ld      a, #0x94        ; 09/4000
                out0    (CBR), a
                ld      a, #0xC2        ; 0000-1FFF = Common Area 0
                                        ; 2000-BFFF = Bank Area
                                        ; C000-FFFF = Common Area 1
                out0    (CBAR), a
                ;; Video memory half 1, then mode $FB: 280 x 192 in 16 colors, planar.
                call    access_softswitch1
                ld      a, #0xFB        ; 280x192x16
                call    set_video_mode
                ;; Screen on (sequencer register 1, bit 5 clear), then the hires colors.
                ld      a, #1
                ld      bc, #VGA_SEQ_INDEX ; Select Sequencer clocking mode
                out     (c), a
                ld      bc, #VGA_SEQ_DATA
                in      a, (c)
                res     5, a            ;; clear bit 5: screen on
                ld      d, a
                ld      a, #1
                ld      bc, #VGA_SEQ_INDEX ; Select Sequencer clocking mode
                out     (c), a
                ld      a, d
                ld      bc, #VGA_SEQ_DATA
                out     (c), a
                call    setup_hires_palette
                ;; Oak register $24 (write segment) = 1: CPU writes to the window go to
                ;; video memory segment 1, where the color tables live, not to the screen
                ;; in segment 0.
                ld      a, #0x24        ; Oak extended write segment register
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #1
                ld      bc, #OAK_DATA
                out     (c), a
                ;; Copy the color tables into the four planes, one plane at a time:
                ;; sequencer register 2 (map mask) picks the plane the CPU writes.
                ;; hires_odd_table's four pages go to offset $0000, hires_even_table's to
                ;; offset $0100.
                ld      a, #2
                ld      bc, #VGA_SEQ_INDEX ; Select Sequencer map mask
                out     (c), a
                ld      a, #1           ; Write to plane 0
                ld      bc, #VGA_SEQ_DATA
                out     (c), a
                ld      bc, #0x100
                ld      hl, #hires_odd_table
                ld      de, #0xC000     ; Copy $B200-$B2FF to A/0000 (plane 1)
                ldir
                ld      a, #2           ; Select Sequencer map mask
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a
                ld      a, #2           ; Write to plane 2
                ld      bc, #VGA_SEQ_DATA
                out     (c), a
                ld      bc, #0x100
                ld      de, #0xC000     ; Copy $B300-$B3FF -> A/0000 (plane 2)
                ldir
                ld      a, #2           ; Select Sequencer map mask
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a
                ld      a, #4           ; Write to plane 3
                ld      bc, #VGA_SEQ_DATA
                out     (c), a
                ld      bc, #0x100
                ld      de, #0xC000     ; Copy $B400-$B4FF -> A/0000 (plane 3)
                ldir
                ld      a, #2           ; Select Sequencer map mask
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a
                ld      a, #8           ; Write to plane 4
                ld      bc, #VGA_SEQ_DATA
                out     (c), a
                ld      bc, #0x100
                ld      de, #0xC000     ; Copy $B500-$B5FF -> A/0000 (plane 4)
                ldir
                ld      a, #2           ; Select Sequencer map mask
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a
                ld      a, #1           ; Write to plane 1
                ld      bc, #VGA_SEQ_DATA
                out     (c), a
                ld      bc, #0x100
                ld      hl, #hires_even_table
                ld      de, #0xC100     ; Copy $B600-$B6FF -> A/0100 (plane 1)
                ldir
                ld      a, #2           ; Select Sequencer map mask
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a
                ld      a, #2           ; Write to plane 2
                ld      bc, #VGA_SEQ_DATA
                out     (c), a
                ld      bc, #0x100
                ld      de, #0xC100     ; Copy $B700-$B7FF -> A/0100 (plane 2)
                ldir
                ld      a, #2           ; Select Sequencer map mask
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a
                ld      a, #4           ; Write to plane 3
                ld      bc, #VGA_SEQ_DATA
                out     (c), a
                ld      bc, #0x100
                ld      de, #0xC100     ; Copy $B800-$B8FF -> A/0100 (plane 3)
                ldir
                ld      a, #2           ; Select Sequencer map mask
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a
                ld      a, #8           ; Write to plane 4
                ld      bc, #VGA_SEQ_DATA
                out     (c), a
                ld      bc, #0x100
                ld      de, #0xC100     ; Copy $B900-$B9FF -> A/0100 (plane 4)
                ldir
                ;; All four planes writable again. Oak register $23 (read segment) = 1, so
                ;; CPU reads of $C000-$C1FF see the tables, and the write segment back to
                ;; 0, the screen.
                ld      a, #2           ; Select Sequencer map mask
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a
                ld      a, #0xF         ; Write to all planes
                ld      bc, #VGA_SEQ_DATA
                out     (c), a
                ld      a, #0x23        ; Oak extended read segment register
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #1
                ld      bc, #OAK_DATA
                out     (c), a
                ld      a, #0x24        ; Oak extended write segment register
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0
                ld      bc, #OAK_DATA
                out     (c), a
                ei
                jp      main_loop

;; ----------------------------------------------------------------------------------------
;; Hires render routine: write mode 1, eight passes of render_hires, write mode 0.
;; ----------------------------------------------------------------------------------------
emulate_hires:
                ;; Graphics controller register 5 = 1: write mode 1. A write stores the
                ;; four latches, which the last read loaded, into the four planes.
                ld      a, #5
                ld      bc, #VGA_GC_INDEX ; select graphics controller mode register
                out     (c), a
                ld      a, #1
                ld      bc, #VGA_GC_DATA
                out     (c), a          ; select write mode 1
                ;; Draw the page eight times, then write mode 0 again and back to the main
                ;; loop.
                call    render_hires
                call    render_hires
                call    render_hires
                call    render_hires
                call    render_hires
                call    render_hires
                call    render_hires
                call    render_hires
                ld      a, #5
                ld      bc, #VGA_GC_INDEX
                out     (c), a
                ld      a, #0
                ld      bc, #VGA_GC_DATA
                out     (c), a
                jp      main_loop

;; ----------------------------------------------------------------------------------------
;; Draws hires page 1 ($2000) or 2 ($4000): 24 groups of 8 lines, in the Apple's
;; interleaved line order. In mixed mode the last four groups are text lines instead
;; (render_text_line_in_8x8_font, from text page 1 or 2).
;; ----------------------------------------------------------------------------------------
render_hires:
                ;; Page 2 when PAGE2 is on.
                ld      a, (current_page)
                cp      #1
                jp      Z, render_hires_page2

render_hires_page1:
                ;; The Apple's hires lines are interleaved: line groups start at $2000,
                ;; $2080, ... $2380, then $2028, ... and $2050, .... Each call draws 8
                ;; lines; IX = the screen address (VGA segment 0 through logical $C000),
                ;; moved on by render_hires_line.
                ld      hl, #0x2000
                ld      ix, #0xC000
                call    render_8_hires_lines_page1
                ld      hl, #0x2080
                call    render_8_hires_lines_page1
                ld      hl, #0x2100
                call    render_8_hires_lines_page1
                ld      hl, #0x2180
                call    render_8_hires_lines_page1
                ld      hl, #0x2200
                call    render_8_hires_lines_page1
                ld      hl, #0x2280
                call    render_8_hires_lines_page1
                ld      hl, #0x2300
                call    render_8_hires_lines_page1
                ld      hl, #0x2380
                call    render_8_hires_lines_page1
                ld      hl, #0x2028
                call    render_8_hires_lines_page1
                ld      hl, #0x20A8
                call    render_8_hires_lines_page1
                ld      hl, #0x2128
                call    render_8_hires_lines_page1
                ld      hl, #0x21A8
                call    render_8_hires_lines_page1
                ld      hl, #0x2228
                call    render_8_hires_lines_page1
                ld      hl, #0x22A8
                call    render_8_hires_lines_page1
                ld      hl, #0x2328
                call    render_8_hires_lines_page1
                ld      hl, #0x23A8
                call    render_8_hires_lines_page1
                ld      hl, #0x2050
                call    render_8_hires_lines_page1
                ld      hl, #0x20D0
                call    render_8_hires_lines_page1
                ld      hl, #0x2150
                call    render_8_hires_lines_page1
                ld      hl, #0x21D0
                call    render_8_hires_lines_page1
                ;; Mixed mode: the last 32 lines show text lines 20-23 instead.
                ld      a, (mixed_mode_flag)
                cp      #1
                jr      Z, render_mixed_mode_for_hires_page1
                ld      hl, #0x2250
                call    render_8_hires_lines_page1
                ld      hl, #0x22D0
                call    render_8_hires_lines_page1
                ld      hl, #0x2350
                call    render_8_hires_lines_page1
                ld      hl, #0x23D0
                call    render_8_hires_lines_page1
                ret

render_mixed_mode_for_hires_page1:
                ;; Text page 1 lines 20-23 ($0650, $06D0, $0750, $07D0), drawn at screen
                ;; lines 160, 168, 176 and 184 (40 bytes per screen line: $D900 is $C000 +
                ;; 160 x 40).
                ld      hl, #0x650
                ld      de, #0xD900
                call    render_text_line_in_8x8_font
                ld      hl, #0x6D0
                ld      de, #0xDA40
                call    render_text_line_in_8x8_font
                ld      hl, #0x750
                ld      de, #0xDB80
                call    render_text_line_in_8x8_font
                ld      hl, #0x7D0
                ld      de, #0xDCC0
                call    render_text_line_in_8x8_font
                ret

render_hires_page2:
                ld      hl, #0x4000
                ld      ix, #0xC000
                call    render_8_hires_lines_page2
                ld      hl, #0x4080
                call    render_8_hires_lines_page2
                ld      hl, #0x4100
                call    render_8_hires_lines_page2
                ld      hl, #0x4180
                call    render_8_hires_lines_page2
                ld      hl, #0x4200
                call    render_8_hires_lines_page2
                ld      hl, #0x4280
                call    render_8_hires_lines_page2
                ld      hl, #0x4300
                call    render_8_hires_lines_page2
                ld      hl, #0x4380
                call    render_8_hires_lines_page2
                ld      hl, #0x4028
                call    render_8_hires_lines_page2
                ld      hl, #0x40A8
                call    render_8_hires_lines_page2
                ld      hl, #0x4128
                call    render_8_hires_lines_page2
                ld      hl, #0x41A8
                call    render_8_hires_lines_page2
                ld      hl, #0x4228
                call    render_8_hires_lines_page2
                ld      hl, #0x42A8
                call    render_8_hires_lines_page2
                ld      hl, #0x4328
                call    render_8_hires_lines_page2
                ld      hl, #0x43A8
                call    render_8_hires_lines_page2
                ld      hl, #0x4050
                call    render_8_hires_lines_page2
                ld      hl, #0x40D0
                call    render_8_hires_lines_page2
                ld      hl, #0x4150
                call    render_8_hires_lines_page2
                ld      hl, #0x41D0
                call    render_8_hires_lines_page2
                ld      a, (mixed_mode_flag)
                cp      #1
                jr      Z, render_mixed_mode_for_hires_page2
                ld      hl, #0x4250
                call    render_8_hires_lines_page2
                ld      hl, #0x42D0
                call    render_8_hires_lines_page2
                ld      hl, #0x4350
                call    render_8_hires_lines_page2
                ld      hl, #0x43D0
                call    render_8_hires_lines_page2
                ret

render_mixed_mode_for_hires_page2:
                ;; The same from text page 2 ($0A50-$0BD0).
                ld      hl, #0xA50
                ld      de, #0xD900
                call    render_text_line_in_8x8_font
                ld      hl, #0xAD0
                ld      de, #0xDA40
                call    render_text_line_in_8x8_font
                ld      hl, #0xB50
                ld      de, #0xDB80
                call    render_text_line_in_8x8_font
                ld      hl, #0xBD0
                ld      de, #0xDCC0
                call    render_text_line_in_8x8_font
                ret

;; ----------------------------------------------------------------------------------------
;; Draws the 8 Apple lines that start at HL, $0400 apart (one text row's worth).
;; ----------------------------------------------------------------------------------------
render_8_hires_lines_page1:
                ;; The 8 lines of a group are $400 apart. Stop at the end of the page
                ;; ($4000).
                push    hl
                call    render_hires_line
                pop     hl
                ld      a, h
                add     a, #4
                ld      h, a
                cp      #0x40
                jr      C, render_8_hires_lines_page1
                ret

render_8_hires_lines_page2:
                ;; The same for page 2 (ends at $6000).
                push    hl
                call    render_hires_line
                pop     hl
                ld      a, h
                add     a, #4
                ld      h, a
                cp      #0x60
                jr      C, render_8_hires_lines_page2
                ret

;; ----------------------------------------------------------------------------------------
;; Converts one 40-byte hires line, from its last byte to its first: each Apple byte
;; selects a latch table entry ($C100 page for even byte positions, $C000 for odd ones),
;; and LDD copies it to the screen in write mode 1.
;; ----------------------------------------------------------------------------------------
render_hires_line:
                ;; Start at the end of both lines: IX moves to the last of the 40 screen
                ;; bytes (the next line starts at IX + 40 on return), HL to the Apple
                ;; line's last byte.
                ld      bc, #0x27
                add     ix, bc
                push    ix
                inc     ix
                add     hl, bc
                push    hl
                ;; In the other register set: BC = the Apple byte, DE = the screen byte, C
                ;; = 4 passes of 10 bytes each.
                ld      c, #4
                exx
                pop     bc
                pop     de
                exx

render_hires_line_loop:
                ;; For each Apple byte from the last to the first: L = the byte, H = the
                ;; table page (even byte positions use $C1, odd ones $C0). LDD reads the
                ;; table entry, which loads the VGA latches, writes it to the screen (write
                ;; mode 1 stores the latches), and moves DE and BC back one byte; HL's
                ;; change does not matter.
                exx
                ld      a, (bc)         ; read byte from hires screen area (2000-3FFF or 4000-5FFF)
                ld      l, a            ; use C100-C1FF as a lookup table for even bytes
                ld      h, #0xC1
                ldd                     ; write remapped byte to C000-DDFF
                ld      a, (bc)
                ld      l, a
                ld      h, #0xC0        ; use C000-C0FF as a lookup table for odd bytes
                ldd
                ld      a, (bc)
                ld      l, a
                ld      h, #0xC1
                ldd
                ld      a, (bc)
                ld      l, a
                ld      h, #0xC0
                ldd
                ld      a, (bc)
                ld      l, a
                ld      h, #0xC1
                ldd
                ld      a, (bc)
                ld      l, a
                ld      h, #0xC0
                ldd
                ld      a, (bc)
                ld      l, a
                ld      h, #0xC1
                ldd
                ld      a, (bc)
                ld      l, a
                ld      h, #0xC0
                ldd
                ld      a, (bc)
                ld      l, a
                ld      h, #0xC1
                ldd
                ld      a, (bc)
                ld      l, a
                ld      h, #0xC0
                ldd
                exx
                dec     c
                jr      NZ, render_hires_line_loop
                ret

;; ----------------------------------------------------------------------------------------
;; Draws one 40-character text line of mixed-mode hires in the 8 x 8 font, in write mode 0,
;; then switches back to write mode 1. Erratum E6: the text is drawn in hires palette
;; colors, not the $C022 colors.
;; ----------------------------------------------------------------------------------------
render_text_line_in_8x8_font:
                .assume render_text_line_in_8x8_font - 0x6354 ;; must stay at $6354
                ;; The first instruction does nothing (B is loaded again below). Write mode
                ;; 0, and C = 40 characters.
                ld      b, (hl)
                ld      a, #5
                ld      bc, #VGA_GC_INDEX
                out     (c), a
                ld      a, #0
                ld      bc, #VGA_GC_DATA
                out     (c), a
                ld      c, #0x28

render_text_line_loop:
                ;; Per character: get_text_colour sets the colors from the screen code,
                ;; then the glyph is font_table_8x8 + 8 x (the VGA character for the screen
                ;; code).
                ;;
                ;; BUG (E6): the glyph is written into the same planes as the hires
                ;; picture, so the text shows hires palette colors, not the $C022 colors;
                ;; get_text_colour's result is not used.
                push    de
                ld      a, (hl)
                exx
                ld      b, a
                call    get_text_colour
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
                ;; Its 8 rows go to 8 screen lines, 40 bytes apart.
                ld      de, #0x28
                pop     hl
                ld      a, (bc)
                ld      (hl), a
                add     hl, de
                inc     bc
                ld      a, (bc)
                ld      (hl), a
                add     hl, de
                inc     bc
                ld      a, (bc)
                ld      (hl), a
                add     hl, de
                inc     bc
                ld      a, (bc)
                ld      (hl), a
                add     hl, de
                inc     bc
                ld      a, (bc)
                ld      (hl), a
                add     hl, de
                inc     bc
                ld      a, (bc)
                ld      (hl), a
                add     hl, de
                inc     bc
                ld      a, (bc)
                ld      (hl), a
                add     hl, de
                inc     bc
                ld      a, (bc)
                ld      (hl), a
                ;; Next character, one byte to the right. Write mode 1 again at the end,
                ;; for the hires lines that follow.
                exx
                inc     de
                inc     hl
                dec     c
                jp      NZ, render_text_line_loop
                ld      a, #5
                ld      bc, #VGA_GC_INDEX
                out     (c), a
                ld      a, #1
                ld      bc, #VGA_GC_DATA
                out     (c), a
                ret

;; ----------------------------------------------------------------------------------------
;; The six hires colors, red, green, blue (8-bit DAC values). setup_hires_palette loads
;; them into DAC entries 0-7 in the order the hires tables number them.
;; ----------------------------------------------------------------------------------------
hires_colour_0:
                .db     0x00, 0x00, 0x00 ; black
hires_colour_1:
                .db     0xFF, 0xFF, 0xFF ; white
hires_colour_2:
                .db     0xFF, 0x00, 0xFF ; magenta
hires_colour_3:
                .db     0x00, 0xFF, 0x00 ; green
hires_colour_4:
                .db     0xFF, 0x94, 0x00 ; orange
hires_colour_5:
                .db     0x00, 0x00, 0xFF ; blue
                                        ; Blue

;; ----------------------------------------------------------------------------------------
;; Loads DAC entries 0-7 for hires: black, magenta, green, white, black, blue, orange,
;; white (the colors by palette bit and dot phase), and entry 15 white.
;; ----------------------------------------------------------------------------------------
setup_hires_palette:
                ;; DAC entries 0-7: black, magenta, green, white, black, blue, orange,
                ;; white. Entry 15 white.
                ld      a, #0xFF
                ld      bc, #VGA_PEL_MASK
                out     (c), a
                ld      a, #0
                ld      bc, #VGA_DAC_WRITE_INDEX
                out     (c), a
                ld      a, (hires_colour_0)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (hires_colour_0+1)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (hires_colour_0+2)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (hires_colour_2)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (hires_colour_2+1)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (hires_colour_2+2)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (hires_colour_3)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (hires_colour_3+1)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (hires_colour_3+2)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (hires_colour_1)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (hires_colour_1+1)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (hires_colour_1+2)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (hires_colour_0)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (hires_colour_0+1)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (hires_colour_0+2)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (hires_colour_5)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (hires_colour_5+1)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (hires_colour_5+2)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (hires_colour_4)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (hires_colour_4+1)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (hires_colour_4+2)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (hires_colour_1)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (hires_colour_1+1)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (hires_colour_1+2)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, #0xF
                ld      bc, #VGA_DAC_WRITE_INDEX
                out     (c), a
                ld      a, (hires_colour_1)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (hires_colour_1+1)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (hires_colour_1+2)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ret
