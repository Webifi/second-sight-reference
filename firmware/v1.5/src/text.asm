;; v1.5/src/text.asm: v1.4/src/text.asm with the changes for a card with the original
;; U7 (fuse map BE8C); SecondSight_v1_5.asm includes it. Every change from
;; v1.4/src/ is marked CHANGE (En). En refers to docs/reference/errata.md.

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
;; CHANGE (E26): fixes flashing in 80 columns. ROM 1.4 clears text80_palette_colour here, so
;; the next pass reloads the text colors and undoes the flashing swap at once. These five
;; bytes are NOPs: the colors are reloaded only when $C022 changes, as in 40 columns.
                nop
                nop
                nop
                nop
                nop
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
;; ----------------------------------------------------------------------------------------
;; CHANGE (E16, E17): corrects SetUserMode's record (user_mode_record) before
;; program_mode_registers writes it. set_user_video_mode jumps here; it runs from the main
;; loop, where BBR = 0.
;; E17 first, while the record is still as received: if all 81 bytes equal the mode file
;; M640X48016M (m640x48016m_record), the feature byte (byte $02) becomes $F0, so Bt481
;; Command Register A = $F0 (true color) instead of $00 (8-bit palette), and CRTC $01
;; (byte $07) becomes $4F instead of $4E. Ext $21 = $06 alone does not identify this
;; record: any 24-bit user record sets it, with its own DAC setting and width.
;;
;; E16: Oak $06 (byte $41) bits 1-0 are copied into the misc output byte's (byte $00)
;; clock-select bits 3-2, so the misc write, which comes second, selects the same clock.
;; The record is changed in place; a second SetMode $FF finds it already corrected.
;; ----------------------------------------------------------------------------------------
user_mode_fixup:
                ld      hl, #user_mode_record
                ld      de, #m640x48016m_record
                ld      b, #0x51

user_mode_compare_loop:
                ld      a, (de)
                cp      (hl)
                jr      NZ, user_mode_clock_fix
                inc     hl
                inc     de
                djnz    user_mode_compare_loop
                ld      a, #0xF0        ; Bt481 Command Register A: true color
                ld      (user_mode_record+2), a
                ld      a, #0x4F        ; CRTC $01: 640 pixels
                ld      (user_mode_record+7), a

user_mode_clock_fix:
                ld      a, (user_mode_record+0x41)
                and     #3
                add     a, a
                add     a, a
                ld      b, a
                ld      a, (user_mode_record)
                and     #0xF3
                or      b
                ld      (user_mode_record), a
                ld      hl, #user_mode_record
                jp      program_mode_registers

;; The 81-byte register record of M640X48016M (SECOND/MISC/VGA on ss.source.082395.po),
;; the library's 640 x 480 true-color mode file, as SetUserMode receives it.
m640x48016m_record:
                .db     0xEB, 0x01, 0x00, 0x0F, 0x00, 0x0E, 0x62, 0x4E
                .db     0x50, 0x85, 0x54, 0x80, 0x0B, 0x3E, 0x00, 0x40
                .db     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xEA, 0x8C
                .db     0xDF, 0x78, 0x00, 0xE7, 0x04, 0xC3, 0xFF, 0x00
                .db     0x00, 0x00, 0x00, 0x00, 0x40, 0x05, 0x0F, 0xFF
                .db     0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07
                .db     0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F
                .db     0x01, 0x00, 0x0F, 0x00, 0x00, 0x05, 0x10, 0x07
                .db     0x00, 0x0A, 0xC8, 0x00, 0x00, 0x00, 0x0F, 0x05
                .db     0x06, 0x0C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                .db     0x00

;; ----------------------------------------------------------------------------------------
;; CHANGE (E1, E19): UploadData's window set-up, called from upload_data through
;; call_in_bank0. It first keeps the length's high byte (whole 64 KB blocks) in
;; upload_had_blocks for upload_check_remainder.
;;
;; E1: a picture upload in mode $13 is flag 1 (video memory), destination bank 0, Apple
;; emulation off (emul_flag = 1), vga_mode = $13 and a length of at most 64 KB. The mode
;; number alone is not enough: SetMode stores it even when Apple emulation stays on, and
;; other uploads carry code or data. For such an upload: linear window off (port
;; LINEAR_OFF), half 1 (access_softswitch1), Oak register 5 = $00 (the standard VGA map),
;; and destination bank 2, which upload_chunk turns into bank $0A: byte n goes to Z180
;; $A0000 + n, Oak's $A0000 window, where the two low address bits choose the plane.
;; Any other upload gets ROM 1.4's set-up: linear window on, half 0, Oak register 5 = $19.
;; ----------------------------------------------------------------------------------------
upload_select_window:
                ld      a, (cmd_param7)
                ld      (upload_had_blocks), a
                ld      a, (cmd_param1)
                cp      #1
                jr      NZ, upload_linear_window
                ld      a, (cmd_param4)
                cp      #0
                jr      NZ, upload_linear_window
                ld      a, (emul_flag)
                cp      #1
                jr      NZ, upload_linear_window
                ld      a, (vga_mode)
                cp      #0x13
                jr      NZ, upload_linear_window
                ;; At most 64 KB: no whole block, or exactly one and nothing more.
                ld      a, (cmd_param7)
                cp      #0
                jr      Z, upload_standard_window
                cp      #1
                jr      NZ, upload_linear_window
                ld      a, (cmd_param4+1)
                ld      b, a
                ld      a, (cmd_param6)
                or      b
                jr      NZ, upload_linear_window

upload_standard_window:
                ld      a, #2
                ld      (cmd_param4), a
                ld      a, #0
                out0    (LINEAR_OFF), a
                call    access_softswitch1
                ld      a, #5           ; OAK Video Memory Mapping register
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0           ; the standard VGA memory map
                ld      bc, #OAK_DATA
                out     (c), a
                ret

upload_linear_window:
                ld      a, #0
                out0    (LINEAR_ON), a
                call    access_softswitch0
                ld      a, #5           ; OAK Video Memory Mapping register
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0x19        ; Oak memory mapping, 1 MB window at $80000
                ld      bc, #OAK_DATA
                out     (c), a
                ret

upload_had_blocks:
                .db     0

;; ----------------------------------------------------------------------------------------
;; CHANGE (E19, E25): UploadData's remainder test, called from upload_data through
;; call_in_bank0. Returns B = the length's low 16 bits ORed together, as ROM 1.4's test
;; computed in A: B = 0 means no remainder. The IIgs library before August 1996 ends each
;; 64 KB block by waiting for $00 at $C0B8, then waits for $01 and $00 again for a
;; remainder phase, even when there is no remainder. So after whole 64 KB blocks with no
;; remainder this acts out that phase: wait about 1 ms, so that the program sees the $00
;; that ended the last block before the $01 replaces it, write $01, wait about 1 ms, write
;; $00. The card cannot see the IIgs read $C0B8, so the waits are a guess; a program held
;; up longer than 1 ms can still miss a step.
;; ----------------------------------------------------------------------------------------
upload_check_remainder:
                ld      a, (cmd_param4+1)
                ld      b, a
                ld      a, (cmd_param6)
                or      b
                ld      b, a
                ret     NZ
                ld      a, (upload_had_blocks)
                cp      #0
                ret     Z
                call    wait_1ms
                ld      a, #1
                out0    (CARD_DATA), a
                call    wait_1ms
                ld      a, #0
                out0    (CARD_DATA), a
                ld      b, #0
                ret

;; ----------------------------------------------------------------------------------------
;; CHANGE (E19): waits about 1 ms by counting, so no timer is touched: PRT0 and PRT1 stay
;; free for programs. One pass of the loop is 20 clocks (DEC BC 4, LD 4, OR 4, JR taken
;; 8; SRAM has no wait states), so 900 passes are 1 ms at the firmware's 18 MHz. A program
;; that switches the Z180 to 36 MHz halves the wait. Uses A only.
;; ----------------------------------------------------------------------------------------
wait_1ms:
                push    bc
                ld      bc, #900

wait_1ms_loop:
                dec     bc
                ld      a, b
                or      c
                jr      NZ, wait_1ms_loop
                pop     bc
                ret

;; ----------------------------------------------------------------------------------------
;; CHANGE (E8, E9): command $03, ScrollScreen (source, destination, length), rewritten.
;; scroll_screen jumps here through call_in_bank0. ROM 1.4 selected video half 0 once
;; and added 8 to every bank, so a byte at video $80000 or above wrapped into the card's
;; own memory (E8); it chose the direction byte by byte and started a downward copy one
;; byte past the end (E9).
;;
;; Copy steps:
;; 1. Takes the source and destination as 20-bit video addresses (the four bank bits the
;;    DMA uses) and cuts the length so that neither range runs past $FFFFF, the end of
;;    video memory.
;; 2. Copies downward only when the destination is higher than the source, comparing the
;;    whole addresses; a downward copy starts at address + length - 1.
;; 3. Moves the data in pieces of at most 4 KB that never cross $80000, so each piece lies
;;    in one video half. A piece whose source and destination are in the same half is one
;;    DMA through the linear window with that half selected, as before. A piece between
;;    halves, at most 1 KB, goes through scroll_buffer: source half selected and the piece
;;    copied into the buffer, then destination half selected and copied out.
;;    The halves are different memory, so such a piece cannot overlap itself; the order of
;;    the pieces follows the copy direction.
;;
;; Ends with half 0, standard memory map, linear window off, reply $A5.
;; IX is saved and restored, because this runs inside INT1.
;; ----------------------------------------------------------------------------------------
scroll_screen_fixed:
                ;; IX is kept for the code this command interrupted: the event handler
                ;; saves only AF, HL, BC and DE.
                push    ix
                ld      hl, #cmd_param1
                ld      de, #sc_src
                ld      bc, #9
                ldir
                ld      a, (sc_src+2)
                and     #0xF
                ld      (sc_src+2), a
                ld      a, (sc_dst+2)
                and     #0xF
                ld      (sc_dst+2), a
                ;; Linear window on, Oak register 5 = $19, as in upload_data.
                ld      a, #0
                out0    (LINEAR_ON), a
                ld      a, #5
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0x19
                ld      bc, #OAK_DATA
                out     (c), a
                ld      ix, #sc_src
                call    video_cut_length
                ld      ix, #sc_dst
                call    video_cut_length
                ;; sc_down = 1 when the destination is not below the source.
                ld      hl, (sc_dst)
                ld      de, (sc_src)
                or      a
                sbc     hl, de
                ld      a, (sc_src+2)
                ld      b, a
                ld      a, (sc_dst+2)
                sbc     a, b
                ld      a, #0
                jr      C, scroll_set_direction
                ld      a, #1

scroll_set_direction:
                ld      (sc_down), a
                cp      #0
                jr      Z, scroll_piece_loop
                ;; Downward: both addresses to the last byte, address + length - 1. With a
                ;; length of 0 nothing is copied, so the addresses do not matter.
                ld      hl, (sc_len)
                ld      a, (sc_len+2)
                ld      de, #1
                or      a
                sbc     hl, de
                sbc     a, #0
                ld      c, a
                ex      de, hl
                ld      ix, #sc_src
                call    add24
                ld      ix, #sc_dst
                call    add24

scroll_piece_loop:
                ld      hl, (sc_len)
                ld      a, (sc_len+2)
                or      h
                or      l
                jp      Z, scroll_finished
                ;; The piece: at most 4 KB, the rest of the length, and the room before
                ;; each address reaches a half boundary in the copy direction.
                ld      hl, #0x1000
                ld      a, (sc_len+2)
                cp      #0
                jr      NZ, scroll_piece_room
                ld      de, (sc_len)
                call    min16

scroll_piece_room:
                ld      ix, #sc_src
                call    scroll_room
                ld      ix, #sc_dst
                call    scroll_room
                ld      (sc_piece), hl
                ld      (dma_count), hl
                ;; Same half (bank bit 3): one DMA.
                ld      a, (sc_dst+2)
                ld      b, a
                ld      a, (sc_src+2)
                xor     b
                and     #8
                jr      NZ, scroll_between_halves
                ld      a, (sc_src+2)
                call    select_video_half
                ld      de, #0
                ld      ix, #sc_src
                call    video_z180_address
                ld      (dma_source), hl
                ld      (dma_source_bank), a
                ld      ix, #sc_dst
                call    video_z180_address
                ld      (dma_dest), hl
                ld      (dma_dest_bank), a
                ld      a, (sc_down)
                cp      #0
                jr      NZ, scroll_piece_down
                call    copy_memory_block
                jr      scroll_next_piece

scroll_piece_down:
                call    copy_memory_block_decrement
                jr      scroll_next_piece

scroll_between_halves:
                ;; At most 1 KB, the size of scroll_buffer.
                ld      hl, (sc_piece)
                ld      de, #0x400
                call    min16
                ld      (sc_piece), hl
                ld      (dma_count), hl
                ;; Through the buffer, upward from each range's lowest byte: the address
                ;; itself, or for a downward copy address - (piece - 1).
                ld      de, #0
                ld      a, (sc_down)
                cp      #0
                jr      Z, scroll_buffer_in
                ld      de, (sc_piece)
                dec     de

scroll_buffer_in:
                push    de
                ld      a, (sc_src+2)
                call    select_video_half
                ld      ix, #sc_src
                call    video_z180_address
                ld      (dma_source), hl
                ld      (dma_source_bank), a
                ld      hl, #scroll_buffer
                ld      (dma_dest), hl
                ld      a, #0           ; SRAM bank 0
                ld      (dma_dest_bank), a
                call    copy_memory_block
                ld      a, (sc_dst+2)
                call    select_video_half
                pop     de
                ld      ix, #sc_dst
                call    video_z180_address
                ld      (dma_dest), hl
                ld      (dma_dest_bank), a
                ld      hl, #scroll_buffer
                ld      (dma_source), hl
                ld      a, #0
                ld      (dma_source_bank), a
                ld      hl, (sc_piece)
                ld      (dma_count), hl
                call    copy_memory_block

scroll_next_piece:
                ;; Length down by the piece; both addresses up or down by it.
                ld      de, (sc_piece)
                ld      c, #0
                ld      ix, #sc_len
                call    sub24
                ld      a, (sc_down)
                cp      #0
                ld      ix, #sc_src
                jr      NZ, scroll_addresses_down
                call    add24
                ld      ix, #sc_dst
                call    add24
                jp      scroll_piece_loop

scroll_addresses_down:
                call    sub24
                ld      ix, #sc_dst
                call    sub24
                jp      scroll_piece_loop

scroll_finished:
                ;; Half 0, as ROM 1.4 left it; then ROM 1.4's ending (standard map, linear
                ;; window off, reply $A5).
                call    access_softswitch0
                call    scroll_down_done
                pop     ix
                ret

;; HL = the smaller of HL and the room before the address at IX reaches a half boundary
;; ($80000 or $100000) in sc_down's direction. Upward the room is $80000 - (address &
;; $7FFFF), under 4 KB only in the last 4 KB of a half; downward it is (address & $7FFFF)
;; + 1, under 4 KB only in the first 4 KB.
scroll_room:
                ld      a, (sc_down)
                cp      #0
                jr      NZ, scroll_room_down
                ld      a, 2(ix)
                and     #7
                cp      #7
                ret     NZ
                ld      e, 0(ix)
                ld      d, 1(ix)
                push    hl
                ld      hl, #0
                or      a
                sbc     hl, de          ; $10000 - the low 16 bits
                ex      de, hl
                pop     hl
                ld      a, d
                or      e
                ret     Z               ; low 16 bits 0: 64 KB of room
                jr      min16

scroll_room_down:
                ld      a, 2(ix)
                and     #7
                ret     NZ
                ld      e, 0(ix)
                ld      d, 1(ix)
                inc     de
                ld      a, d
                or      e
                ret     Z               ; low 16 bits $FFFF: 64 KB of room

;; HL = the smaller of HL and DE (16-bit, unsigned).
min16:
                push    hl
                or      a
                sbc     hl, de
                pop     hl
                ret     C
                ex      de, hl
                ret

;; Selects the video half for bank byte A: bit 3 = 1 (video $80000 and up) half 1.
select_video_half:
                bit     3, a
                jp      NZ, access_softswitch1
                jp      access_softswitch0

;; The Z180 address of video address (IX) - DE, in the linear window: HL = the low 16
;; bits, A = the DMA bank, bank bits 2-0 + 8 (the half is selected apart).
video_z180_address:
                ld      l, 0(ix)
                ld      h, 1(ix)
                or      a
                sbc     hl, de
                ld      a, 2(ix)
                sbc     a, #0
                and     #7
                or      #8
                ret

;; Cuts sc_len so that the range from the video address at IX ends by $FFFFF.
video_cut_length:
                ld      hl, #0
                ld      e, 0(ix)
                ld      d, 1(ix)
                or      a
                sbc     hl, de
                ld      a, #0x10
                sbc     a, 2(ix)        ; C:DE = $100000 - the address
                ld      c, a
                ex      de, hl
                ld      hl, (sc_len)
                or      a
                sbc     hl, de
                ld      a, (sc_len+2)
                sbc     a, c
                ret     C
                ld      (sc_len), de
                ld      a, c
                ld      (sc_len+2), a
                ret

;; (IX) = (IX) + C:DE and (IX) = (IX) - C:DE, 24-bit, low byte first. Keep C and DE.
add24:
                ld      l, 0(ix)
                ld      h, 1(ix)
                add     hl, de
                ld      0(ix), l
                ld      1(ix), h
                ld      a, 2(ix)
                adc     a, c
                ld      2(ix), a
                ret

sub24:
                ld      l, 0(ix)
                ld      h, 1(ix)
                or      a
                sbc     hl, de
                ld      0(ix), l
                ld      1(ix), h
                ld      a, 2(ix)
                sbc     a, c
                ld      2(ix), a
                ret

;; ScrollScreen's and ClearScreen's working copy of the parameters, 24 bits each, low
;; byte first: source, destination (ClearScreen's start), length. Then the direction (1 =
;; downward) and the current piece.
sc_src:         .db     0, 0, 0
sc_dst:         .db     0, 0, 0
sc_len:         .db     0, 0, 0
sc_down:        .db     0
sc_piece:       .dw     0

;; ScrollScreen's 1 KB buffer for pieces between the video halves: SRAM bank 0 $0A600,
;; where the bank 0 master copy of the Super Hi-Res renderer's block has 1 KB that no
;; code uses (converter_page_tables, src/superhires.asm). It is firmware memory, so a
;; scroll takes none of the memory the firmware documentation leaves free for programs.
scroll_buffer = converter_page_tables

;; ----------------------------------------------------------------------------------------
;; CHANGE (E8): command $0A, ClearScreen (fill byte, start, length), rewritten.
;; clear_screen jumps here through call_in_bank0. ROM 1.4 filled whole 64 KB blocks from
;; the start address, so a block that started at a nonzero offset in bank 7 or 15 ran
;; across $80000 or $100000 in one DMA and wrapped into SRAM. This version takes the start
;; as a 20-bit video address, cuts the length at $FFFFF, and fills in pieces that end at
;; each 64 KB boundary of the video address, so no DMA crosses $80000. Each piece goes
;; through ROM 1.4's fill_video_mem_block, which selects the half; the fill byte is read
;; from cmd_param1 by DMA ($21A08) as before. Ends with ROM 1.4's clear_done (half 1,
;; standard map, linear window off, reply $A5).
;; ----------------------------------------------------------------------------------------
clear_screen_fixed:
                push    ix              ; kept for the interrupted code, as in ScrollScreen
                ;; Linear window on, half 0, Oak register 5 = $19, as ROM 1.4 did.
                ld      a, #0
                out0    (LINEAR_ON), a
                call    access_softswitch0
                ld      a, #5
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, #0x19
                ld      bc, #OAK_DATA
                out     (c), a
                ld      hl, #0x1A08
                ld      (dma_source), hl
                ld      a, #2
                ld      (dma_source_bank), a
                ;; Start and length into sc_dst and sc_len.
                ld      hl, #cmd_param1+1
                ld      de, #sc_dst
                ld      bc, #6
                ldir
                ld      a, (sc_dst+2)
                and     #0xF
                ld      (sc_dst+2), a
                ld      ix, #sc_dst
                call    video_cut_length

clear_piece_loop:
                ld      hl, (sc_len)
                ld      a, (sc_len+2)
                or      h
                or      l
                jr      Z, clear_finished
                ;; C:DE = the room to the next 64 KB boundary: $10000 - the low 16 bits.
                ld      de, (sc_dst)
                ld      hl, #0
                or      a
                sbc     hl, de
                ex      de, hl
                ld      c, #0
                ld      a, d
                or      e
                jr      NZ, clear_piece_length
                inc     c

clear_piece_length:
                ;; The piece is the smaller of that and the length.
                ld      hl, (sc_len)
                or      a
                sbc     hl, de
                ld      a, (sc_len+2)
                sbc     a, c
                jr      NC, clear_piece_fill
                ld      de, (sc_len)
                ld      a, (sc_len+2)
                ld      c, a

clear_piece_fill:
                ;; A DMA count of 0 is 64 KB.
                ld      (dma_count), de
                ld      hl, (sc_dst)
                ld      (dma_dest), hl
                ld      a, (sc_dst+2)
                ld      (dma_dest_bank), a
                push    bc
                push    de
                call    fill_video_mem_block
                pop     de
                pop     bc
                ld      ix, #sc_len
                call    sub24
                ld      ix, #sc_dst
                call    add24
                jr      clear_piece_loop

clear_finished:
                call    clear_done
                pop     ix
                ret

;; ----------------------------------------------------------------------------------------
;; CHANGE (512 KB): starts one piece of an UploadData transfer for upload_dma (below, at
;; $9C75): DMA channel 1 count = HL, then the channel on, I/O to memory. C = $0A gives
;; edge-sensed requests (DMS1 = 1), as ROM 1.4's dma_upload sets them; C = $02 gives
;; level-sensed ones. MAR1 must already be set. Uses A.
;; ----------------------------------------------------------------------------------------
upload_dma_start:
                ld      a, l
                out0    (BCR1L), a
                ld      a, h
                out0    (BCR1H), a
                in0     a, (DCNTL)
                and     #0xF2           ; DMS1, DMS0 and DIM0 cleared
                or      c               ; DIM1: I/O to memory; DMS1 from C
                out0    (DCNTL), a
                in0     a, (DSTAT)
                or      #0x81           ; DE1 = 1, DME = 1, DWE1 = 0
                and     #0xDF
                out0    (DSTAT), a
                ret

;; ----------------------------------------------------------------------------------------
;; CHANGE (E29): get_emulation_routine's choice while Apple emulation is off. The event
;; handlers for TEXT, HIRES, 80VID, AN3 and NEWVIDEO request a mode change whatever the
;; emulation flag says, and ROM 1.4 then ran set_native_mode: the SetMode mode was
;; programmed again, so registers changed with SetVGAReg went back to the mode record,
;; ScreenOff was undone, and $A5 went to the handshake latch unasked. Here set_native_mode
;; runs only when SetMode asked for it (setmode_reply_owed = 1); a change from an Apple
;; switch goes straight back to main_loop. Returns HL = set-up, DE = renderer.
;; ----------------------------------------------------------------------------------------
native_mode_check:
                ld      de, #emulation_disabled
                ld      hl, #set_native_mode
                ld      a, (setmode_reply_owed)
                or      a
                ret     NZ
                ld      hl, #main_loop
                ret

                .org    0x9C00
;; ----------------------------------------------------------------------------------------
;; CHANGE (E6): fixes mixed-hires text ignoring the $C022 colors. ROM 1.4 writes each glyph
;; byte into all four planes, so a text pixel is hires entry 15 (white) or 0 (black)
;; whatever $C022 says. render_text_line_in_8x8_font ($6354) jumps here for each of
;; the four text lines. This loads the $C022 colors into DAC entries 14 (background, the
;; low nibble of text_colour) and 15 (text, the high nibble) from apple_colour_table, as
;; set_textmode_palette loads entries 0 and 1. The hires tables never set plane 3, so the
;; picture uses entries 0-7 only and keeps its colors. Graphics controller registers 0
;; (set/reset) and 1 (enable set/reset) = $0E then make every write mode 0 write put 1 in
;; planes 1-3, while plane 0 still takes the glyph byte: a glyph pixel is 15 and a blank
;; one 14.
;;
;; The rest of the routine draws the line; both registers are 0 again after it, as
;; the mode record leaves them. text_colour is read for every line, so a later $C022
;; change shows at once. It runs from the hires renderer, where BBR = 0.
;; ----------------------------------------------------------------------------------------
hires_text_line_c022:
                ;; DAC entry 14 = the background color, 15 = the text color. HL (the text
                ;; line) and DE (the screen address) are kept for the routine.
                push    hl
                push    de
                ld      a, #14
                ld      bc, #VGA_DAC_WRITE_INDEX
                out     (c), a
                ld      a, (text_colour)
                and     #0xF
                call    hires_text_dac_colour
                ld      a, (text_colour)
                rrca
                rrca
                rrca
                rrca
                and     #0xF
                call    hires_text_dac_colour
                pop     de
                pop     hl
                ;; Set/reset and enable set/reset = $0E: planes 1-3 take 1 in write mode 0.
                ld      a, #0
                ld      bc, #VGA_GC_INDEX
                out     (c), a
                ld      a, #0xE
                ld      bc, #VGA_GC_DATA
                out     (c), a
                ld      a, #1
                ld      bc, #VGA_GC_INDEX
                out     (c), a
                ld      a, #0xE
                ld      bc, #VGA_GC_DATA
                out     (c), a
                ;; The rest of render_text_line_in_8x8_font, after the JP: A = 5 (the
                ;; graphics mode register index), as the replaced LD A did.
                ld      a, #5
                call    render_text_line_in_8x8_font+3
                ;; Set/reset and enable set/reset back to 0.
                ld      a, #0
                ld      bc, #VGA_GC_INDEX
                out     (c), a
                ld      a, #0
                ld      bc, #VGA_GC_DATA
                out     (c), a
                ld      a, #1
                ld      bc, #VGA_GC_INDEX
                out     (c), a
                ld      a, #0
                ld      bc, #VGA_GC_DATA
                out     (c), a
                ret

hires_text_dac_colour:
                ;; A = an IIgs color number: its red, green and blue bytes from
                ;; apple_colour_table to the next DAC entry.
                ld      e, a
                ld      d, #3
                mlt     de
                ld      hl, #apple_colour_table
                add     hl, de
                ld      bc, #VGA_DAC_DATA
                ld      a, (hl)
                out     (c), a
                inc     hl
                ld      a, (hl)
                out     (c), a
                inc     hl
                ld      a, (hl)
                out     (c), a
                ret

;; ----------------------------------------------------------------------------------------
;; CHANGE (512 KB): one UploadData phase's transfer, from dma_upload (src/commands.asm)
;; through call_in_bank0. upload_chunk has set MAR1L/MAR1H from dma_dest, put the Z180
;; bank in dma_dest_bank and selected the video half; dma_count is the count (0 = 64 KB).
;;
;; ROM 1.4 runs the phase as one DMA. The Z180's DMA address has 20 bits and runs from
;; $FFFFF on to $00000, so a phase that crosses video $80000 (Z180 bank $0F, nonzero
;; offset) writes its end into card SRAM from $00000, over the firmware. Sequential's
;; firmware documentation (UploadData, "Caution!") tells programs never to upload across
;; 512 KB, and says a later _UploadData may split such a transfer itself. This does that.
;; Example: a 640-byte row uploaded to video $7FF80 has 128 bytes below $80000; ROM 1.4
;; writes the other 512 to SRAM $00000-$001FF instead of video $80000-$801FF.
;;
;; Here such a phase runs in two pieces: up to $FFFFF, then the rest from Z180 $80000
;; in the other video half, which is where the video address goes on. From half 0 that
;; is video $80000 and up; from half 1 (past the end of the 1 MB, a host error) it wraps
;; to video $00000, so the bytes stay in video memory either way. The host sees one
;; phase: $01, all its bytes, $00. Nothing is written to port $A0 between the pieces: a
;; port $A0 access acknowledges the pending event, so it would drop a byte the host has
;; already sent. Until the second piece starts, U7 holds the IIgs with RDY.
;;
;; The second piece uses level-sensed requests. When it starts, the host's next byte is
;; usually waiting already, with DREQ1 low, so an edge-sensed request never comes. Level
;; sense cannot take a byte twice: the DMA samples DREQ1 during the memory write, after
;; its read of port $A0 has released U7's request (Zilog UM0050 pp107-108).
;; ----------------------------------------------------------------------------------------
upload_dma:
                ld      de, #0          ; DE = the second piece: none yet
                ld      bc, (dma_dest)
                ld      hl, #0
                or      a
                sbc     hl, bc          ; HL = $10000 - dma_dest: the room up to $FFFFF
                ld      b, h
                ld      c, l            ; BC = that room
                ld      hl, (dma_count) ; HL = the count
                jr      Z, upload_dma_first     ; offset 0: 64 KB of room, always enough
                ld      a, (dma_dest_bank)
                and     #0x0F
                cp      #0x0F
                jr      NZ, upload_dma_first    ; below Z180 bank $0F: cannot reach $FFFFF
                ld      a, h
                or      l
                jr      Z, upload_dma_cut       ; a count of 0 is 64 KB: more than the room
                push    hl
                sbc     hl, bc          ; carry is clear after OR
                pop     hl
                jr      C, upload_dma_first     ; ends below $FFFFF
                jr      Z, upload_dma_first     ; ends at $FFFFF

upload_dma_cut:
                or      a
                sbc     hl, bc
                ex      de, hl          ; DE = the second piece: the count - the room
                ld      h, b
                ld      l, c            ; HL = the first piece: the room

upload_dma_first:
                ;; The first piece, with ROM 1.4's start: bank, count, channel on, $01.
                ld      a, (dma_dest_bank)
                out0    (MAR1B), a
                ld      c, #0x0A        ; edge-sensed, as ROM 1.4
                call    upload_dma_start
                ld      a, #1
                out0    (CARD_DATA), a
                call    upload_dma_wait
                ld      a, d
                or      e
                jr      Z, upload_dma_done
                ;; The other video half. Flag 0, and flag 1 with a bank below 8, ran in
                ;; half 0, so the rest goes to half 1; flag 1 with bank 8 and up ran in
                ;; half 1, so the rest goes to half 0. select_video_half takes bit 3.
                ld      a, (cmd_param1)
                or      a
                ld      a, #8
                jr      Z, upload_dma_half
                ld      a, (cmd_param4)
                cp      #8
                ld      a, #8
                jr      C, upload_dma_half
                xor     a

upload_dma_half:
                call    select_video_half       ; uses A only
                ;; The second piece, from Z180 $80000.
                xor     a
                out0    (MAR1L), a
                out0    (MAR1H), a
                ld      a, #8
                out0    (MAR1B), a
                ex      de, hl
                ld      c, #0x02        ; level-sensed
                call    upload_dma_start
                call    upload_dma_wait
                in0     a, (DCNTL)
                or      #0x08           ; edge-sensed again, as ROM 1.4 leaves DCNTL
                out0    (DCNTL), a

upload_dma_done:
                xor     a
                out0    (CARD_DATA), a  ; $00: the phase is finished
                ret

;; Waits until DMA channel 1 has moved its last byte (DSTAT bit 7, DE1, back to 0).
upload_dma_wait:
                in0     a, (DSTAT)
                bit     7, a
                jr      NZ, upload_dma_wait
                ret

                .org    0x9D00
;; ----------------------------------------------------------------------------------------
;; CHANGE (E7): double lores, $9D00-$9ECC. ROM 1.4 shows double lores as single lores
;; (erratum E7). get_emulation_routine's lores test (emulate_lores_dlr_check) jumps
;; here.
;;
;; double_lores_check: lores with AN3 off (doublewidth_flag) and 80-column video
;; (text80_enabled_flag) is double lores, the same condition as double hires. It returns
;; HL = set_videomode_double_lores and DE = emulate_double_lores; any other lores goes
;; back to emulate_single_lores. It runs from main_loop, in the usual layout (BBR = 0).
;; ----------------------------------------------------------------------------------------
double_lores_check:
                ld      a, (doublewidth_flag)
                cp      #0
                jp      Z, emulate_single_lores
                ld      a, (text80_enabled_flag)
                cp      #0
                jp      Z, emulate_single_lores
                ld      hl, #set_videomode_double_lores
                ld      de, #emulate_double_lores
                ret

;; ----------------------------------------------------------------------------------------
;; CHANGE (E7): double lores setup, the same steps as set_videomode_lores2: mode $FE (640 x
;; 200), half 0, the lores palette (DAC entries $10-$1F) and the text palette, screen on.
;; main_loop has already stored emulate_double_lores in emulate_current_videomode. No
;; redraw flag is needed: emulate_double_lores draws every block on every pass.
;; ----------------------------------------------------------------------------------------
set_videomode_double_lores:
                di
                ld      a, #0xFE        ; 640x200
                call    set_video_mode
                call    access_softswitch0
                call    set_lores_palette
                call    screen_on
                ei
                jp      main_loop

;; ----------------------------------------------------------------------------------------
;; CHANGE (E7): double lores render routine. MMU CBAR $FA, BBR $76, CBR $21: the bank area
;; starts at logical $A000 instead of $9000 as in emulate_lores, so common area 0 runs to
;; $9FFF and keeps this code ($9Dxx) mapped while the bank area shows video memory. Each
;; BBR step of 5 then puts four text rows ($5000 bytes) at $A000-$EFFF. Common area 1
;; ($F000) is SRAM bank 1, as in emulate_lores, so the auxiliary text page is at
;; $F400-$F7FF and the main page at $0400-$07FF. flash_counter and setup_textmode_palette
;; ($93FE, $93FF) are in common area 0 in this layout, so the flash count reads and runs
;; SRAM.
;;
;; Every fourth pass swaps the flashing text colors, as emulate_lores does.
;; One pass of render_double_lores, then the normal MMU: each pass redraws the whole screen and takes several frames, so one pass is about
;; as long as the two cached passes of emulate_lores, and a mode change is noticed sooner.
;; ----------------------------------------------------------------------------------------
emulate_double_lores:
                ld      a, #0xFA
                out0    (CBAR), a
                ld      a, #0x76
                out0    (BBR), a
                ld      a, #0x21
                out0    (CBR), a
                ld      a, (flash_counter)
                cp      #3
                jr      NZ, double_lores_count_pass
                call    setup_textmode_palette
                ld      a, #0xFF

double_lores_count_pass:
                inc     a
                ld      (flash_counter), a
                call    render_double_lores
                ld      a, #0
                out0    (CBR), a
                ld      a, #0
                out0    (BBR), a
                ld      a, #0xF2
                out0    (CBAR), a
                jp      main_loop

;; ----------------------------------------------------------------------------------------
;; CHANGE (E7): draws the double lores screen with the same window, latch and color
;; expansion settings as render_lores: waits for vertical retrace, linear window on, Oak
;; $22 = $10, $30 = $0D, $34 = $FF, $33 = $FF. Then text rows 0-19, and either rows 20-23
;; or, in mixed mode, the four text lines in 80 columns with render_text80_row, as
;; render_lores_text80 draws them. Always text page 1: the 80-column renderers
;; (render_text80, render_lores_text80) and double hires show page 1 only, because with
;; 80STORE on, PAGE2 selects auxiliary memory for the Apple's writes, and the capture
;; logic never reports 80STORE, so current_page can change while a program writes the
;; auxiliary page.
;; ----------------------------------------------------------------------------------------
render_double_lores:
                ld      bc, #VGA_STATUS1
                in      a, (c)          ; Read VGA Input Status Register #1
                bit     3, a            ; Check vertical retrace
                jr      Z, render_double_lores
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
                ld      a, #0xD         ; Color expansion, color pattern register, pixel mask
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
                ;; Text rows 0-19, four at a time: HL = the first Apple row of the four, A
                ;; = the BBR that puts their screen rows at $A000-$EFFF.
                ld      hl, #0x400
                ld      a, #0x76
                call    double_lores_four_rows
                ld      hl, #0x600
                ld      a, #0x7B
                call    double_lores_four_rows
                ld      hl, #0x428
                ld      a, #0x80
                call    double_lores_four_rows
                ld      hl, #0x628
                ld      a, #0x85
                call    double_lores_four_rows
                ld      hl, #0x450
                ld      a, #0x8A
                call    double_lores_four_rows
                ;; Rows 20-23: four more rows of blocks, or four text lines in mixed mode.
                ld      a, (mixed_mode_flag)
                cp      #1
                jr      Z, double_lores_mixed_text
                ld      hl, #0x650
                ld      a, #0x8F
                call    double_lores_four_rows
                jr      double_lores_finished

double_lores_mixed_text:
                ;; 80-column text: for each line the main-memory characters (HL) into the
                ;; odd 8-pixel cells (DE + 8), then the auxiliary ones (HL + $F000, SRAM
                ;; bank 1) into the even cells (DE).
                ld      a, #0x8F
                out0    (BBR), a
                ld      hl, #0x650
                ld      de, #0xA000
                ld      b, #4

double_lores_text_line:
                push    bc
                push    hl
                push    de
                set     3, e
                call    render_text80_row
                pop     de
                pop     hl
                push    hl
                push    de
                ld      a, h
                add     a, #0xF0
                ld      h, a
                call    render_text80_row
                pop     de
                pop     hl
                ld      bc, #0x80       ; next Apple text line
                add     hl, bc
                ex      de, hl
                ld      bc, #0x1400     ; next screen row (8 lines of 640 bytes)
                add     hl, bc
                ex      de, hl
                pop     bc
                djnz    double_lores_text_line

double_lores_finished:
                ;; Color expansion, the linear window and the 64-bit latch off, as at the
                ;; end of render_lores.
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

;; ----------------------------------------------------------------------------------------
;; CHANGE (E7): four text rows of double lores. In: HL = the first Apple row's address in
;; the main page, A = BBR for these four rows. Rows follow at HL + $80, the screen rows at
;; $A000, $B400, $C800 and $DC00 ($1400 bytes, 8 screen lines of 640 bytes, apart).
;; ----------------------------------------------------------------------------------------
double_lores_four_rows:
                out0    (BBR), a
                ld      de, #0xA000
                ld      b, #4

double_lores_next_row:
                ;; IX = the same row in the auxiliary page: logical $F000 higher, SRAM bank
                ;; 1 through CBR $21.
                push    bc
                push    hl
                push    de
                push    hl
                pop     ix
                ld      bc, #0xF000
                add     ix, bc
                call    double_lores_row
                pop     de
                pop     hl
                ld      bc, #0x80       ; next Apple text row
                add     hl, bc
                ex      de, hl
                ld      bc, #0x1400     ; next screen row
                add     hl, bc
                ex      de, hl
                pop     bc
                djnz    double_lores_next_row
                ret

;; ----------------------------------------------------------------------------------------
;; CHANGE (E7): one text row of double lores, 80 blocks: for each of the 40 byte positions
;; the auxiliary byte (IX) in the left 8-pixel cell (DE), then the main byte (HL) in the
;; right cell (DE + 8). Each cell is 8 pixels wide, half the width of a single lores
;; block. An auxiliary nibble holds its color rotated one bit to the right (the Apple IIe
;; double lores rule), so both of its nibbles are rotated one bit to the left first. The
;; drawing runs in the alternate registers, as in render_lores_linepair.
;; ----------------------------------------------------------------------------------------
double_lores_row:
                ld      c, #0x28

double_lores_byte_loop:
                ;; Rotate each nibble of the auxiliary byte one bit to the left: B = the
                ;; byte rotated left, which is right except bits 0 and 4; those come from
                ;; B with its nibbles swapped (old bits 3 and 7).
                ld      a, 0(ix)
                rlca
                ld      b, a
                rrca
                rrca
                rrca
                rrca
                xor     b
                and     #0x11
                xor     b
                push    de
                exx
                pop     hl
                call    double_lores_cell
                exx
                ;; The main byte, 8 pixels to the right (the cell address is a multiple
                ;; of 16, so setting bit 3 adds 8).
                ld      a, (hl)
                push    de
                exx
                pop     hl
                set     3, l
                call    double_lores_cell
                exx
                ;; Next byte: the screen moves 16 pixels right.
                inc     ix
                inc     hl
                ld      a, e
                add     a, #0x10
                ld      e, a
                jr      NC, double_lores_next_byte
                inc     d

double_lores_next_byte:
                dec     c
                jr      NZ, double_lores_byte_loop
                ret

;; ----------------------------------------------------------------------------------------
;; CHANGE (E7): one cell of double lores: A = the color byte, HL = the cell's screen
;; address. The low nibble is the top block (4 screen lines), the high nibble the bottom
;; block (4 more), each through color expansion with Oak $31 = nibble + $10, the lores
;; palette entries, as render_lores_linepair draws its blocks. Under color expansion a
;; write at offset 0 fills pixels 0-3 of an 8-pixel group and offset 1 pixels 4-7, so the
;; writes at 0 and 1 cover the cell; DE = $27F then steps to the next line. Uses BC, DE
;; and HL.
;; ----------------------------------------------------------------------------------------
double_lores_cell:
                push    af
                call    double_lores_block
                pop     af
                rrca
                rrca
                rrca
                rrca

double_lores_block:
                and     #0xF
                add     a, #0x10
                ld      d, a
                ld      a, #0x31
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, d
                ld      bc, #OAK_DATA
                out     (c), a
                ld      de, #0x27F
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                ld      (hl), a
                inc     l
                ld      (hl), a
                add     hl, de
                ret

;; ----------------------------------------------------------------------------------------
;; CHANGE (E10): command $0F, SetTextFont (font number and two more parameter bytes, size
;; $04 in Sequential's firmware documentation). command_0f_check ($1FEC, src/mainloop.asm)
;; calls this through call_in_bank0. It receives the three parameter bytes into
;; cmd_param1 with copy_api_data_chunk (DMA from port $A0 with the $01 / $00 handshake,
;; as check_for_api_call receives parameters), keeps the font number in text_font, and,
;; if an Apple text mode is on screen, sets mode_change_pending, so the main loop runs
;; the text set-up again and its copy_font loads the new font. The documentation asks for
;; the change to take place at once in a text mode; reloading from the main loop does that
;; without touching the VGA registers from inside the interrupt. Font numbers: $00 the
;; standard ROM font, $01 the alternate ROM font, $02 the PC ANSI font, $03 the user font
;; at SRAM $0F000. ROM 1.4 holds one built-in font, so $01 and $02 load it too.
;; ----------------------------------------------------------------------------------------
set_text_font:
                ld      hl, #3
                ld      (dma_count), hl
                ld      hl, #0xA0
                ld      (dma_source), hl
                ld      hl, #cmd_param1
                ld      (dma_dest), hl
                ld      a, #0
                ld      (dma_dest_bank), a
                call    copy_api_data_chunk
                ld      a, (cmd_param1)
                ld      (text_font), a
                ld      hl, (emulate_current_videomode)
                ld      de, #emulate_text40
                or      a
                sbc     hl, de
                jr      Z, set_text_font_reload
                ld      hl, (emulate_current_videomode)
                ld      de, #emulate_text80
                or      a
                sbc     hl, de
                ret     NZ

set_text_font_reload:
                ld      a, #1
                ld      (mode_change_pending), a
                ret

;; The font SetTextFont chose; 0 (the built-in font) from reset.
text_font:      .db     0

;; ----------------------------------------------------------------------------------------
;; CHANGE (E10): copy_font jumps here first. It runs from the text set-ups
;; (set_videomode_text40 and set_videomode_text80), where logical $9xxx is common area 0.
;; With font $03 it loads the user font; with any other it goes back to copy_font, which
;; loads the built-in font as before.
;; ----------------------------------------------------------------------------------------
copy_font_select:
                ld      a, (text_font)
                cp      #3
                jr      Z, copy_user_font
                ld      bc, #VGA_STATUS0
                jp      copy_font+3

;; ----------------------------------------------------------------------------------------
;; CHANGE (E10): loads SetTextFont's user font from SRAM $0F000 into plane 2, the way
;; copy_font loads the built-in one: 256 characters indexed by VGA character code, 16
;; bytes each on a VGA monitor (8 x 16, $0F000-$0FFFF) or 8 bytes each on AppleColor RGB
;; (8 x 8, $0F000-$0F7FF), each into its 32-byte character cell. Plane 2 is opened and
;; closed with copy_font's register values and shows at logical $F000 through CBR $A9
;; (characters $00-$7F) and $AA ($80-$FF). The user font, at physical $0F000, cannot be
;; read there at the same time, so CBAR $FA and BBR $05 show it at logical $A000 while
;; this code, below $A000, stays in common area 0. The glyphs are copied with copy_font's
;; own copy_font_8x16 and copy_font_8x8. BBR and CBAR are restored; CBR is left at $A9,
;; as copy_font leaves it.
;; ----------------------------------------------------------------------------------------
copy_user_font:
                ld      bc, #VGA_SEQ_INDEX
                ld      de, #0x0204     ; map mask: plane 2 only
                call    vga_out_pair
                ld      de, #0x0406     ; memory mode: plain addressing
                call    vga_out_pair
                ld      bc, #VGA_GC_INDEX
                ld      de, #0x0500     ; graphics mode: write mode 0, no odd/even
                call    vga_out_pair
                in0     a, (BBR)
                push    af
                in0     a, (CBAR)
                push    af
                ld      a, #0xFA
                out0    (CBAR), a
                ld      a, #5
                out0    (BBR), a        ; logical $A000 = physical $0F000
                ld      a, #0xA9
                out0    (CBR), a        ; logical $F000 = plane 2, characters $00-$7F
                ld      bc, #VGA_STATUS0
                in      a, (c)
                bit     4, a            ; 1 = VGA monitor: the 8 x 16 font
                ld      de, #0xA000
                ld      hl, #0xF000
                ld      c, #0x80
                jr      Z, copy_user_font_8x8
                call    copy_font_8x16
                ld      a, #0xAA
                out0    (CBR), a        ; characters $80-$FF
                ld      hl, #0xF000
                ld      c, #0x80
                call    copy_font_8x16
                jr      copy_user_font_done

copy_user_font_8x8:
                call    copy_font_8x8
                ld      a, #0xAA
                out0    (CBR), a
                ld      hl, #0xF000
                ld      c, #0x80
                call    copy_font_8x8

copy_user_font_done:
                pop     af
                out0    (CBAR), a
                pop     af
                out0    (BBR), a
                ;; Back to the text-mode plane settings, as at the end of copy_font.
                ld      bc, #VGA_SEQ_INDEX
                ld      de, #0x0203     ; map mask: planes 0 and 1
                call    vga_out_pair
                ld      de, #0x0402     ; memory mode 2
                call    vga_out_pair
                ld      bc, #VGA_GC_INDEX
                ld      de, #0x0510     ; graphics mode: odd/even on
                call    vga_out_pair
                ld      a, #0xA9
                out0    (CBR), a
                ret

;; Writes index D and value E to the index port in BC and the data port after it.
vga_out_pair:
                out     (c), d
                inc     c
                out     (c), e
                dec     c
                ret

                .org    0xA000
