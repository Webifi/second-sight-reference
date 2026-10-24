;; src/text.asm, $917A-$9FFF: the text renderers, flashing, the language tables, FREE SPACE $9776.
;; Part of the ROM 1.4 firmware source; ROM_BEEF.asm includes it.

;; ----------------------------------------------------------------------------------------
;; 80-column text setup: mode $FD, MMU CBAR $FE, BBR $22, CBR $A9 (logical $F000 = VGA
;; text memory), font, palette, cleared screen, language character changes, text-mode plane
;; settings, screen on.
;; ----------------------------------------------------------------------------------------
set_videomode_text80:
                ;; Half 1, mode $FD (80 x 24). MMU: CBAR $FE, BBR $22 (logical $E000 =
                ;; physical $30000, SRAM bank 1: the auxiliary text page at $E400), CBR $A9
                ;; (logical $F000 = the text-mode window at physical $B8000).
                call    access_softswitch1
                ld      a, #0xFD        ; 80x24
                call    set_video_mode
                ld      a, #0xFE
                out0    (CBAR), a
                ld      a, #0x22
                out0    (BBR), a
                ld      a, #0xA9
                out0    (CBR), a
                ;; Font, text colors, a cleared screen and the language characters.
                call    copy_font
                call    set_textmode_palette
                call    clear_text_framebuffer
                call    remap_charset_for_language
                ;; Text-mode plane settings: map mask 3 (planes 0 and 1: characters and
                ;; attributes), memory mode 2, odd/even on. Screen on, BBR 0, back to the
                ;; main loop.
                ld      a, #2
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a
                ld      a, #3
                ld      bc, #VGA_SEQ_DATA
                out     (c), a
                ld      a, #4
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a
                ld      a, #2
                ld      bc, #VGA_SEQ_DATA
                out     (c), a
                ld      a, #5
                ld      bc, #VGA_GC_INDEX
                out     (c), a
                ld      a, #0x10
                ld      bc, #VGA_GC_DATA
                out     (c), a
                call    screen_on
                ld      a, #0
                out0    (BBR), a
                jp      main_loop

;; ----------------------------------------------------------------------------------------
;; 80-column render routine: every sixth pass swaps the flashing colors (not with the
;; alternate set), then four passes of render_text80.
;; ----------------------------------------------------------------------------------------
emulate_text80:
                ;; Every sixth pass swap the flashing colors, except with the alternate set
                ;; (no flashing characters there).
                ld      a, #0x22
                out0    (BBR), a
                ld      a, (altcharset_flag)
                cp      #1
                jr      Z, text80_count_pass
                ld      a, (flash_counter)
                cp      #5
                jr      NZ, text80_count_pass
                call    setup_textmode_palette
                ld      a, #0xFF

text80_count_pass:
                inc     a
                ld      (flash_counter), a
                ;; Four passes.
                call    render_text80
                call    render_text80
                call    render_text80
                call    render_text80
                ld      a, #0
                out0    (BBR), a
                ;; BUG (E26): text80_palette_colour = 0 makes the next pass reload the text
                ;; colors, which undoes the flashing swap at once: in 80 columns flashing
                ;; characters never flash and show as inverse characters in the $C022
                ;; colors (unless $C022 is $00).
                ld      a, #0
                ld      (text80_palette_colour), a
                jp      main_loop
text80_palette_colour:
                .db     0

;; ----------------------------------------------------------------------------------------
;; Draws 24 rows of 80 columns: for each row, main memory (HL, $0400...) and auxiliary
;; memory (BC, $E400..., SRAM bank 1 through BBR $22) interleaved into DE. Reloads the
;; palette when $C022 changed.
;; ----------------------------------------------------------------------------------------
render_text80:
                ;; Reload the text colors when $C022 differs from the value they were
                ;; loaded for.
                ld      a, (text80_palette_colour)
                ld      b, a
                ld      a, (text_colour)
                cp      b
                jp      Z, render_text80_rows
                ld      (text80_palette_colour), a
                call    set_textmode_palette

render_text80_rows:
                ;; 24 rows in the Apple's interleaved order. HL = the main-memory row, BC =
                ;; the same row in auxiliary memory (logical $E4xx, SRAM bank 1 through BBR
                ;; $22), DE = the screen row in the text-mode window: 160 bytes per row (80
                ;; characters, each a character byte and an attribute byte).
                ld      hl, #0x400
                ld      bc, #0xE400
                ld      de, #0xF000
                call    render_text80_line
                ld      hl, #0x480
                ld      bc, #0xE480
                ld      de, #0xF0A0
                call    render_text80_line
                ld      hl, #0x500
                ld      bc, #0xE500
                ld      de, #0xF140
                call    render_text80_line
                ld      hl, #0x580
                ld      bc, #0xE580
                ld      de, #0xF1E0
                call    render_text80_line
                ld      hl, #0x600
                ld      bc, #0xE600
                ld      de, #0xF280
                call    render_text80_line
                ld      hl, #0x680
                ld      bc, #0xE680
                ld      de, #0xF320
                call    render_text80_line
                ld      hl, #0x700
                ld      bc, #0xE700
                ld      de, #0xF3C0
                call    render_text80_line
                ld      hl, #0x780
                ld      bc, #0xE780
                ld      de, #0xF460
                call    render_text80_line
                ld      hl, #0x428
                ld      bc, #0xE428
                ld      de, #0xF500
                call    render_text80_line
                ld      hl, #0x4A8
                ld      bc, #0xE4A8
                ld      de, #0xF5A0
                call    render_text80_line
                ld      hl, #0x528
                ld      bc, #0xE528
                ld      de, #0xF640
                call    render_text80_line
                ld      hl, #0x5A8
                ld      bc, #0xE5A8
                ld      de, #0xF6E0
                call    render_text80_line
                ld      hl, #0x628
                ld      bc, #0xE628
                ld      de, #0xF780
                call    render_text80_line
                ld      hl, #0x6A8
                ld      bc, #0xE6A8
                ld      de, #0xF820
                call    render_text80_line
                ld      hl, #0x728
                ld      bc, #0xE728
                ld      de, #0xF8C0
                call    render_text80_line
                ld      hl, #0x7A8
                ld      bc, #0xE7A8
                ld      de, #0xF960
                call    render_text80_line
                ld      hl, #0x450
                ld      bc, #0xE450
                ld      de, #0xFA00
                call    render_text80_line
                ld      hl, #0x4D0
                ld      bc, #0xE4D0
                ld      de, #0xFAA0
                call    render_text80_line
                ld      hl, #0x550
                ld      bc, #0xE550
                ld      de, #0xFB40
                call    render_text80_line
                ld      hl, #0x5D0
                ld      bc, #0xE5D0
                ld      de, #0xFBE0
                call    render_text80_line
                ld      hl, #0x650
                ld      bc, #0xE650
                ld      de, #0xFC80
                call    render_text80_line
                ld      hl, #0x6D0
                ld      bc, #0xE6D0
                ld      de, #0xFD20
                call    render_text80_line
                ld      hl, #0x750
                ld      bc, #0xE750
                ld      de, #0xFDC0
                call    render_text80_line
                ld      hl, #0x7D0
                ld      bc, #0xE7D0
                ld      de, #0xFE60
                call    render_text80_line
                ret

;; ----------------------------------------------------------------------------------------
;; One 80-column row: for each of 40 positions, the auxiliary character, then the main
;; one, each as VGA character and attribute through the tables in char_code_table/char_attr_table.
;; The table pointer char_attr_table is read with interrupts off because the event handlers
;; change both pointers.
;; ----------------------------------------------------------------------------------------
render_text80_line:
                ;; C (other register set) = 40 positions, each two screen characters.
                exx
                ld      c, #0x28
                exx

render_text80_line_loop:
                ;; Auxiliary character first (the left one): the VGA character, then its
                ;; attribute. The attribute table pointer is read with interrupts off: the
                ;; ALTCHARSET handlers change the two pointers, and a half-read pointer
                ;; would point anywhere.
                ld      a, (bc)
                exx
                ld      hl, (char_code_table)
                ld      l, a
                ld      a, (hl)
                exx
                ld      (de), a
                inc     de
                ld      a, (bc)
                exx
                di
                ld      hl, (char_attr_table)
                ei
                ld      l, a
                ld      a, (hl)
                exx
                ld      (de), a
                inc     de
                inc     bc
                ;; Then the main-memory character to its right.
                ld      a, (hl)
                exx
                ld      hl, (char_code_table)
                ld      l, a
                ld      a, (hl)
                exx
                ld      (de), a
                inc     de
                ld      a, (hl)
                exx
                di
                ld      hl, (char_attr_table)
                ei
                ld      l, a
                ld      a, (hl)
                exx
                ld      (de), a
                inc     de
                inc     hl
                exx
                dec     c
                exx
                jp      NZ, render_text80_line_loop
                ret

;; ----------------------------------------------------------------------------------------
;; 40-column text setup (also the start-up mode): mode $FC, MMU CBAR $FE, BBR 0, CBR $A9,
;; font, palette, cleared screen, language character changes, screen on.
;; ----------------------------------------------------------------------------------------
set_videomode_text40:
                ;; Half 1, mode $FC (40 x 24). MMU: BBR 0, CBAR $FE, CBR $A9 (logical $F000
                ;; = the text-mode window at physical $B8000).
                call    access_softswitch1
                ld      a, #0xFC        ; 40x24
                call    set_video_mode
                ld      a, #0
                out0    (BBR), a
                ld      a, #0xFE
                out0    (CBAR), a
                ld      a, #0xA9
                out0    (CBR), a
                ;; Font, text colors, a cleared screen and the language characters, then
                ;; the text-mode plane settings and screen on.
                call    copy_font
                call    set_textmode_palette
                call    clear_text_framebuffer
                call    remap_charset_for_language
                ld      a, #2
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a
                ld      a, #3
                ld      bc, #VGA_SEQ_DATA
                out     (c), a
                ld      a, #4
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a
                ld      a, #2
                ld      bc, #VGA_SEQ_DATA
                out     (c), a
                ld      a, #5
                ld      bc, #VGA_GC_INDEX
                out     (c), a
                ld      a, #0x10
                ld      bc, #VGA_GC_DATA
                out     (c), a
                call    screen_on
                ;; Make the first pass reload the text colors.
                ld      a, #0
                ld      (text40_palette_colour), a
                jp      main_loop
text40_palette_colour:
                .db     0

;; ----------------------------------------------------------------------------------------
;; 40-column render routine: every sixth pass swaps the flashing colors (not with the
;; alternate set), then eight passes of render_text40.
;; ----------------------------------------------------------------------------------------
emulate_text40:
                ;; Every sixth pass swap the flashing colors, except with the alternate set
                ;; (no flashing characters there). Then eight passes.
                ld      a, (altcharset_flag)
                cp      #1
                jr      Z, text40_count_pass
                ld      a, (flash_counter)
                cp      #5
                jr      NZ, text40_count_pass
                call    setup_textmode_palette
                ld      a, #0xFF

text40_count_pass:
                inc     a
                ld      (flash_counter), a
                call    render_text40
                call    render_text40
                call    render_text40
                call    render_text40
                call    render_text40
                call    render_text40
                call    render_text40
                call    render_text40
                jp      main_loop

;; ----------------------------------------------------------------------------------------
;; Pass counter for the flashing characters (text and lores renderers).
;; ----------------------------------------------------------------------------------------
flash_counter:  .db     0

;; ----------------------------------------------------------------------------------------
;; Flashing: swaps the two colors in background_r...foreground_b and writes them to DAC
;; entries 2 and 3 at the next vertical retrace.
;; ----------------------------------------------------------------------------------------
setup_textmode_palette:
                ;; Swap the stored pair (background_r... and foreground_r...) through
                ;; flash_swap. The first two writes (PEL mask, DAC read index) are not
                ;; needed for this.
                ;;
                ;; BUG (E26): the pair this swaps is never loaded from $C022: it starts as
                ;; blue and white, so after the first swap flashing characters alternate
                ;; between white on blue and blue on white whatever the text and background
                ;; colors are.
                ld      a, #0xFF
                ld      bc, #VGA_PEL_MASK
                out     (c), a          ; Write to PEL Mask register
                ld      a, #2
                ld      bc, #VGA_DAC_READ_INDEX
                out     (c), a          ; Write to DAC Address Read Mode register
                ld      a, (background_r)
                ld      (flash_swap), a
                ld      a, (background_g)
                ld      (flash_swap+1), a
                ld      a, (background_b)
                ld      (flash_swap+2), a
                ld      a, (foreground_r)
                ld      (background_r), a
                ld      a, (foreground_g)
                ld      (background_g), a
                ld      a, (foreground_b)
                ld      (background_b), a
                ld      a, (flash_swap)
                ld      (foreground_r), a
                ld      a, (flash_swap+1)
                ld      (foreground_g), a
                ld      a, (flash_swap+2)
                ld      (foreground_b), a

wait_for_vbl_loop:
                ;; Wait for vertical retrace, then write the pair to DAC entries 2 and 3.
                ld      bc, #VGA_STATUS1
                in      a, (c)          ; Read VGA Input Status Register #1
                bit     3, a            ; Bit 3 = Vertical Retrace
                jr      Z, wait_for_vbl_loop

; Setup palette
                ld      a, #2           ; Starting address = 2
                ld      bc, #VGA_DAC_WRITE_INDEX
                out     (c), a          ; Write to DAC Address Write Mode register
                ld      a, (foreground_r)
                ld      bc, #VGA_DAC_DATA
                out     (c), a          ; Write to DAC Data register (auto-increment)
                ld      a, (foreground_g)
                ld      bc, #VGA_DAC_DATA
                out     (c), a          ; Write to DAC Data register (auto-increment)
                ld      a, (foreground_b)
                ld      bc, #VGA_DAC_DATA
                out     (c), a          ; Write to DAC Data register (auto-increment)
                ld      a, (background_r)
                ld      bc, #VGA_DAC_DATA
                out     (c), a          ; Write to DAC Data register (auto-increment)
                ld      a, (background_g)
                ld      bc, #VGA_DAC_DATA
                out     (c), a          ; Write to DAC Data register (auto-increment)
                ld      a, (background_b)
                ld      bc, #VGA_DAC_DATA
                out     (c), a          ; Write to DAC Data register (auto-increment)
                ret

;; The flashing pair setup_textmode_palette swaps and writes to DAC entries 2 and 3,
;; red, green, blue each (8-bit DAC values). They start as blue ($00 $00 $D0) and white.
background_r:
                .db     0x00
background_g:
                .db     0x00
background_b:
                .db     0xD0
foreground_r:
                .db     0xFF
foreground_g:
                .db     0xFF
foreground_b:
                .db     0xFF
flash_swap:
                .db     0x00            ; swap space, 3 bytes
                .db     0x00
                .db     0x00

;; ----------------------------------------------------------------------------------------
;; Draws 24 rows of 40 columns from page 1 ($0400) or 2 ($0800). Reloads the palette when
;; $C022 changed (text40_palette_colour holds the last value).
;; ----------------------------------------------------------------------------------------
render_text40:
                ;; Reload the text colors when $C022 changed.
                ld      a, (text40_palette_colour)
                ld      b, a
                ld      a, (text_colour)
                cp      b
                jp      Z, render_text40_page
                ld      (text40_palette_colour), a
                call    set_textmode_palette

render_text40_page:
                ld      a, (current_page)
                cp      #1
                jp      Z, render_text40_page2

render_text40_page1:
                ;; 24 rows in the Apple's interleaved order; 80 bytes per screen row (40
                ;; characters and attributes).
                ld      hl, #0x400
                ld      de, #0xF000
                call    render_text40_line
                ld      hl, #0x480
                ld      de, #0xF050
                call    render_text40_line
                ld      hl, #0x500
                ld      de, #0xF0A0
                call    render_text40_line
                ld      hl, #0x580
                ld      de, #0xF0F0
                call    render_text40_line
                ld      hl, #0x600
                ld      de, #0xF140
                call    render_text40_line
                ld      hl, #0x680
                ld      de, #0xF190
                call    render_text40_line
                ld      hl, #0x700
                ld      de, #0xF1E0
                call    render_text40_line
                ld      hl, #0x780
                ld      de, #0xF230
                call    render_text40_line
                ld      hl, #0x428
                ld      de, #0xF280
                call    render_text40_line
                ld      hl, #0x4A8
                ld      de, #0xF2D0
                call    render_text40_line
                ld      hl, #0x528
                ld      de, #0xF320
                call    render_text40_line
                ld      hl, #0x5A8
                ld      de, #0xF370
                call    render_text40_line
                ld      hl, #0x628
                ld      de, #0xF3C0
                call    render_text40_line
                ld      hl, #0x6A8
                ld      de, #0xF410
                call    render_text40_line
                ld      hl, #0x728
                ld      de, #0xF460
                call    render_text40_line
                ld      hl, #0x7A8
                ld      de, #0xF4B0
                call    render_text40_line
                ld      hl, #0x450
                ld      de, #0xF500
                call    render_text40_line
                ld      hl, #0x4D0
                ld      de, #0xF550
                call    render_text40_line
                ld      hl, #0x550
                ld      de, #0xF5A0
                call    render_text40_line
                ld      hl, #0x5D0
                ld      de, #0xF5F0
                call    render_text40_line
                ld      hl, #0x650
                ld      de, #0xF640
                call    render_text40_line
                ld      hl, #0x6D0
                ld      de, #0xF690
                call    render_text40_line
                ld      hl, #0x750
                ld      de, #0xF6E0
                call    render_text40_line
                ld      hl, #0x7D0
                ld      de, #0xF730
                call    render_text40_line
                ret

render_text40_page2:
                ld      hl, #0x800
                ld      de, #0xF000
                call    render_text40_line
                ld      hl, #0x880
                ld      de, #0xF050
                call    render_text40_line
                ld      hl, #0x900
                ld      de, #0xF0A0
                call    render_text40_line
                ld      hl, #0x980
                ld      de, #0xF0F0
                call    render_text40_line
                ld      hl, #0xA00
                ld      de, #0xF140
                call    render_text40_line
                ld      hl, #0xA80
                ld      de, #0xF190
                call    render_text40_line
                ld      hl, #0xB00
                ld      de, #0xF1E0
                call    render_text40_line
                ld      hl, #0xB80
                ld      de, #0xF230
                call    render_text40_line
                ld      hl, #0x828
                ld      de, #0xF280
                call    render_text40_line
                ld      hl, #0x8A8
                ld      de, #0xF2D0
                call    render_text40_line
                ld      hl, #0x928
                ld      de, #0xF320
                call    render_text40_line
                ld      hl, #0x9A8
                ld      de, #0xF370
                call    render_text40_line
                ld      hl, #0xA28
                ld      de, #0xF3C0
                call    render_text40_line
                ld      hl, #0xAA8
                ld      de, #0xF410
                call    render_text40_line
                ld      hl, #0xB28
                ld      de, #0xF460
                call    render_text40_line
                ld      hl, #0xBA8
                ld      de, #0xF4B0
                call    render_text40_line
                ld      hl, #0x850
                ld      de, #0xF500
                call    render_text40_line
                ld      hl, #0x8D0
                ld      de, #0xF550
                call    render_text40_line
                ld      hl, #0x950
                ld      de, #0xF5A0
                call    render_text40_line
                ld      hl, #0x9D0
                ld      de, #0xF5F0
                call    render_text40_line
                ld      hl, #0xA50
                ld      de, #0xF640
                call    render_text40_line
                ld      hl, #0xAD0
                ld      de, #0xF690
                call    render_text40_line
                ld      hl, #0xB50
                ld      de, #0xF6E0
                call    render_text40_line
                ld      hl, #0xBD0
                ld      de, #0xF730
                call    render_text40_line
                ret

;; ----------------------------------------------------------------------------------------
;; One 40-column row: each screen code becomes a VGA character (char_code_table table) and
;; attribute (char_attr_table table).
;; ----------------------------------------------------------------------------------------
render_text40_line:
                ;; C = 40 characters. Each screen byte gives a VGA character byte and an
                ;; attribute byte.
                ld      c, #40

render_text40_line_loop:
                ld      a, (hl)         ; read text screen character into 'a'
                exx
                ld      hl, (char_code_table)
                ld      l, a
                ld      a, (hl)
                exx
                ld      (de), a         ; write text character to screen
                inc     de
                ld      a, (hl)
                exx
                ld      hl, (char_attr_table)
                ld      l, a
                ld      a, (hl)
                exx
                ld      (de), a         ; write text attribute to screen
                inc     de
                inc     hl
                dec     c
                jp      NZ, render_text40_line_loop
                ret

;; ----------------------------------------------------------------------------------------
;; Rewrites the character tables for the IIgs language ($C02B bits 7-5): ten characters
;; per language (language_char_mapping_table, ten bytes per language) go to the screen
;; code positions listed in charmap_offset_table (normal set) and charmap_offset_table2
;; (alternate set); $FF ends each position list.
;; ----------------------------------------------------------------------------------------
remap_charset_for_language:
                ;; Language number = $C02B bits 7-5; IX = its row of
                ;; language_char_mapping_table.
                ld      a, (language)
                srl     a
                srl     a
                srl     a
                srl     a
                srl     a
                and     #7
                ld      e, a
                ld      d, #10
                mlt     de
                ld      ix, #language_char_mapping_table
                add     ix, de          ; ix = $96DD + (language * 10)
                ld      e, #10
                ;; For each of the ten characters: store the language's character at every
                ;; screen code in the character's position list, up to the $FF.
                ld      bc, #charmap_offset_table

remap_charset_loop:
                ld      a, (bc)
                cp      #0xFF
                jr      Z, move_to_next_substitution
                ld      l, a
                ld      h, #>(normal_char_codes)
                ld      a, 0(ix)
                ld      (hl), a
                inc     bc
                jr      remap_charset_loop

move_to_next_substitution:
                inc     bc
                inc     ix
                dec     e
                jr      NZ, remap_charset_loop

                ;; The same for the alternate set's code table.
                ld      a, (language)
                srl     a
                srl     a
                srl     a
                srl     a
                srl     a
                and     #7
                ld      e, a
                ld      d, #10
                mlt     de
                ld      ix, #language_char_mapping_table
                add     ix, de
                ld      e, #10
                ld      bc, #charmap_offset_table2

remap_charset_loop2:
                ld      a, (bc)
                cp      #0xFF
                jr      Z, move_to_next_substitution2
                ld      l, a
                ld      h, #>(alt_char_codes)
                ld      a, 0(ix)
                ld      (hl), a
                inc     bc
                jr      remap_charset_loop2

move_to_next_substitution2:
                inc     bc
                inc     ix
                dec     e
                jr      NZ, remap_charset_loop2
                ret

;; ----------------------------------------------------------------------------------------
;; The language tables (remap_charset_for_language). The IIgs language setting ($C02B)
;; changes ten characters. Each row holds the VGA characters a language shows for them;
;; $81-$9E are the language glyphs (hex81). INTL.FONT (SECOND/FIRM) has the same table
;; with the same column heading; ROM 1.4 differs from it for German # and Swedish ] }.
;; ----------------------------------------------------------------------------------------
language_char_mapping_table:
;        #     @     [     \     ]     `     {     |     }     ~
                .db     0x23, 0x40, 0x5B, 0x5C, 0x5D, 0x60, 0x7B, 0x7C, 0x7D, 0x7E ; English (US)
                .db     0x81, 0x40, 0x5B, 0x5C, 0x5D, 0x60, 0x7B, 0x7C, 0x7D, 0x7E ; UK
                .db     0x81, 0x82, 0x83, 0x84, 0x85, 0x60, 0x86, 0x87, 0x88, 0x89 ; French
                .db     0x23, 0x40, 0x8A, 0x8B, 0x8C, 0x60, 0x8D, 0x8E, 0x8F, 0x7E ; Danish
                .db     0x81, 0x85, 0x90, 0x91, 0x92, 0x60, 0x83, 0x93, 0x84, 0x7E ; Spanish
                .db     0x81, 0x85, 0x83, 0x84, 0x86, 0x87, 0x82, 0x94, 0x88, 0x95 ; Italian
                .db     0x81, 0x85, 0x96, 0x97, 0x98, 0x60, 0x99, 0x9A, 0x9B, 0x9C ; German
                .db     0x23, 0x40, 0x96, 0x97, 0x9D, 0x60, 0x99, 0x9A, 0x9E, 0x7E ; Swedish

;; ----------------------------------------------------------------------------------------
;; Where each of the ten characters sits in normal_char_codes: a list of screen codes per
;; character, each list ending in $FF. charmap_offset_table2 is the same for
;; alt_char_codes, where $40-$7F hold MouseText and lowercase instead.
;; ----------------------------------------------------------------------------------------
charmap_offset_table:
                .db     0x23, 0x63, 0xA3, 0xFF ; #
                .db     0x00, 0x40, 0x80, 0xC0, 0xFF ; @
                .db     0x1B, 0x5B, 0x9B, 0xDB, 0xFF ; [
                .db     0x1C, 0x5C, 0x9C, 0xDC, 0xFF ; \
                .db     0x1D, 0x5D, 0x9D, 0xDD, 0xFF ; ]
                .db     0x60, 0xE0, 0xFF ; `
                .db     0x7B, 0xFB, 0xFF ; {
                .db     0x7C, 0xFC, 0xFF ; |
                .db     0x7D, 0xFD, 0xFF ; }
                .db     0x7E, 0xFE, 0xFF ; ~
charmap_offset_table2:
                .db     0x23, 0xA3, 0xFF ; #
                .db     0x00, 0x80, 0xC0, 0xFF ; @
                .db     0x1B, 0x9B, 0xDB, 0xFF ; [
                .db     0x1C, 0x9C, 0xDC, 0xFF ; \
                .db     0x1D, 0x9D, 0xDD, 0xFF ; ]
                .db     0x60, 0xE0, 0xFF ; `
                .db     0x7B, 0xFB, 0xFF ; {
                .db     0x7C, 0xFC, 0xFF ; |
                .db     0x7D, 0xFD, 0xFF ; }
                .db     0x7E, 0xFE, 0xFF ; ~

; free space

;; ========================================================================================
;; FREE SPACE $9776-$9FFF (2,186 bytes). Zero in ROM 1.4; the original disassembly
;; marks it "free space". It is copied into SRAM bank 0 at boot, but code here runs only
;; while the firmware's usual memory layout is on (BBR = 0): during double hires and
;; Super Hi-Res rendering, logical $9xxx shows other memory. Code those renderers call
;; belongs in the $1EC4 block instead.
;; Put new code or data between the label and the .org; the .org keeps what follows
;; at $A000.
;; ========================================================================================
free_9776:
                .org    0xA000
