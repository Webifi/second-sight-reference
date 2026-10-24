;; for_corrected_u7/src/textsetup.asm: src/textsetup.asm with the changes for a card with the corrected
;; U7 (fuse map BBB1); SecondSight_for_corrected_u7.asm includes it. Every change from
;; src/ is marked CHANGE (En). En refers to docs/reference/errata.md.

;; ----------------------------------------------------------------------------------------
;; Loads the text font into VGA plane 2 (the character generator), mapped at logical
;; $F000 by CBR $A9 / $AA: 8 x 16 glyphs on a VGA monitor, 8 x 8 on AppleColor RGB.
;; 128 glyphs, then the language-specific glyphs and MouseText, then back to text-mode
;; plane and memory settings.
;; ----------------------------------------------------------------------------------------
copy_font:
                ;; The monitor sense bit picks the font size: 8x16 on a VGA monitor, 8x8 on
                ;; AppleColor RGB.
;; CHANGE (E10): was ld bc, #VGA_STATUS0. copy_font_select (FREE SPACE $9776 block,
;; src/text.asm) loads SetTextFont's user font when font $03 is chosen; otherwise it does
;; this LD and comes back to the instruction after it, copy_font+3.
                jp      copy_font_select
                in      a, (c)          ; read from input status #0
                bit     4, a            ; test if AppleColor RGB is connected
                jp      Z, copy_font_applecolor_rgb
                ;; Open plane 2, where the VGA chip keeps its character shapes: sequencer
                ;; map mask = 4 (write plane 2 only), memory mode = 6 (plain addressing, no
                ;; odd/even), graphics mode register = 0 (write mode 0, no odd/even).
                ld      a, #2
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a
                ld      a, #4
                ld      bc, #VGA_SEQ_DATA
                out     (c), a
                ld      a, #4
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a
                ld      a, #6
                ld      bc, #VGA_SEQ_DATA
                out     (c), a
                ld      a, #5
                ld      bc, #VGA_GC_INDEX
                out     (c), a
                ld      a, #0
                ld      bc, #VGA_GC_DATA
                out     (c), a
                ;; Plane 2 appears at logical $F000 (CBR $A9: physical $B8000, the
                ;; text-mode window). Characters are 32-byte cells, so characters $00-$7F
                ;; fill $F000-$FFFF; CBR $AA moves the window up 4 KB for characters
                ;; $80-$FF.
                ld      a, #0xA9
                out0    (CBR), a
                ld      de, #font_table_8x16
                ld      hl, #0xF000
                ld      c, #0x80
                call    copy_font_8x16
                ld      a, #0xAA
                out0    (CBR), a
                ld      hl, #0xF020
                ld      de, #hex81
                ld      c, #0x1E
                call    copy_font_8x16
                ld      hl, #0xF800
                ld      de, #hexC0
                ld      b, #0x10
                ld      c, #1
                call    copy_font_8x16
                ;; Characters $C1-$DF get the font's glyphs 1-31 again: MouseText for the
                ;; alternate set.
                ld      hl, #0xF820
                ld      c, #0x1F
                ld      de, #font_table_8x16+16
                call    copy_font_8x16
                ;; Back to text-mode plane and memory settings (map mask 3, memory mode 2,
                ;; odd/even on in the graphics mode register) and the usual window.
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
                ld      a, #0xA9
                out0    (CBR), a
                ret

;; ----------------------------------------------------------------------------------------
;; Copies C glyphs of 16 bytes (DE) into 32-byte character cells (HL).
;; ----------------------------------------------------------------------------------------
copy_font_8x16:
                ;; Copies one glyph's 16 rows, then skips the other 16 bytes of the 32-byte
                ;; cell.
                ld      b, #0x10

copy_font_8x16_loop:
                ld      a, (de)
                ld      (hl), a
                inc     de
                inc     hl
                dec     b
                jr      NZ, copy_font_8x16_loop
                push    bc
                ld      bc, #0x10
                add     hl, bc
                pop     bc
                dec     c
                jr      NZ, copy_font_8x16
                ret

copy_font_applecolor_rgb:
                ;; The same steps with the 8x8 font.
                ld      a, #2
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a
                ld      a, #4
                ld      bc, #VGA_SEQ_DATA
                out     (c), a
                ld      a, #4
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a
                ld      a, #6
                ld      bc, #VGA_SEQ_DATA
                out     (c), a
                ld      a, #5
                ld      bc, #VGA_GC_INDEX
                out     (c), a
                ld      a, #0
                ld      bc, #VGA_GC_DATA
                out     (c), a
                ld      a, #0xA9
                out0    (CBR), a
                ld      de, #font_table_8x8
                ld      hl, #0xF000
                ld      c, #0x80
                call    copy_font_8x8
                ld      a, #0xAA
                out0    (CBR), a
                ld      hl, #0xF020
                ld      de, #hex81_8    ; Pound sign (French + UK/Spanish/Italian) - U+00A3
                ld      c, #0x1E
                call    copy_font_8x8
                ld      hl, #0xF800
                ld      de, #hexC0_8
                ld      c, #1
                call    copy_font_8x8
                ld      hl, #0xF820
                ld      c, #0x1F
                ld      de, #font_table_8x8+8
                call    copy_font_8x8
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
                ld      a, #0xA9
                out0    (CBR), a
                ret

;; ----------------------------------------------------------------------------------------
;; Copies C glyphs of 8 bytes (DE) into 32-byte character cells (HL).
;; ----------------------------------------------------------------------------------------
copy_font_8x8:
                ;; Copies one glyph's 8 rows, then skips the other 24 bytes of the 32-byte
                ;; cell.
                ld      b, #8

copy_font_8x8_loop:
                ld      a, (de)
                ld      (hl), a
                inc     de
                inc     hl
                dec     b
                jr      NZ, copy_font_8x8_loop
                push    bc
                ld      bc, #0x18
                add     hl, bc
                pop     bc
                dec     c
                jr      NZ, copy_font_8x8
                ret

;; ----------------------------------------------------------------------------------------
;; Fills 80 x 25 x 2 bytes of planes 0 and 1 (characters and attributes) with $10.
;; ----------------------------------------------------------------------------------------
clear_text_framebuffer:
                ;; Plane 1 holds the attributes in text mode, plane 0 the characters. Fill
                ;; 4,000 bytes of each (80 x 25 x 2) with $10 through the window at logical
                ;; $F000.
                ld      a, #2
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a          ; Select sequencer map mask register
                ld      a, #2
                ld      bc, #VGA_SEQ_DATA ; Write to plane 1
                out     (c), a
                ld      a, #4
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a          ; Select sequencer memory mode register
                ld      a, #6
                ld      bc, #VGA_SEQ_DATA
                out     (c), a          ; Memory mode = Chain 4/Sequential
                ld      a, #4
                ld      bc, #VGA_GC_INDEX
                out     (c), a          ; Select graphics controller read map select register
                ld      a, #1
                ld      bc, #VGA_GC_DATA
                out     (c), a          ; Read from plane 1
                ld      a, #5
                ld      bc, #VGA_GC_INDEX
                out     (c), a          ; Select graphics controller mode register
                ld      a, #0
                ld      bc, #VGA_GC_DATA
                out     (c), a          ; Select read mode 0 / write mode 0
                ld      a, #0xA9
                out0    (CBR), a

; Fill 0B/8000 - 0B/8F9F in plane 1
; Text character attribute = 0x10 (Background colour = 1 / Foreground colour = 0 / No blink)
                ld      hl, #0xF000
                ld      (hl), #0x10     ; Byte to fill with (text attribute 0x10)
                ld      de, #0xF001
                ld      bc, #0xF9F      ; Bytes to copy (80x25x2 - 1)
                ldir
                ld      a, #2
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a          ; Select sequencer map mask register
                ld      a, #1
                ld      bc, #VGA_SEQ_DATA
                out     (c), a          ; Write to plane 0
                ld      a, #4
                ld      bc, #VGA_SEQ_INDEX
                out     (c), a          ; Select sequencer memory mode register
                ld      a, #6
                ld      bc, #VGA_SEQ_DATA
                out     (c), a          ; Memory mode = Chain 4/Sequential
                ld      a, #4
                ld      bc, #VGA_GC_INDEX
                out     (c), a          ; Select graphics controller read map select register
                ld      a, #1
                ld      bc, #VGA_GC_DATA
                out     (c), a          ; Read from plane 1
                ld      a, #5
                ld      bc, #VGA_GC_INDEX
                out     (c), a          ; Select graphics controller mode register
                ld      a, #0
                ld      bc, #VGA_GC_DATA
                out     (c), a          ; Select read mode 0 / write mode 0

; Fill 0B/8000 - 0B/8F9F in plane 0
; Text character attribute = 0x10
                ld      hl, #0xF000
                ld      (hl), #0x10     ; Byte to fill with (text attribute 0x10)
                ld      de, #0xF001
                ld      bc, #0xF9F      ; Bytes to copy (80x25x2 - 1)
                ldir
                ret

;; ----------------------------------------------------------------------------------------
;; Loads the text palette from $C022 (text_colour): DAC entry 0 = background, 1 = text,
;; 2 = text and 3 = background (the flashing pair, which setup_textmode_palette swaps),
;; 4 = black. The 16 IIgs colors come from apple_colour_table ($7E04), red, green, blue
;; bytes per color.
;; ----------------------------------------------------------------------------------------
set_textmode_palette:
                .assume set_textmode_palette - 0x7CE2 ;; must stay at $7CE2
                ;; PEL mask $FF; DAC writes start at entry 0.
                ld      a, #0xFF
                ld      bc, #VGA_PEL_MASK
                out     (c), a          ; PEL Mask Register = 0xFF
                ld      a, #0
                ld      bc, #VGA_DAC_WRITE_INDEX
                out     (c), a
                ;; Background color = the low nibble of $C022, looked up in
                ;; apple_colour_table.
                ld      a, (text_colour)
                and     #0xF
                ld      e, a
                ld      d, #3
                mlt     de
                ld      hl, #apple_colour_table
                add     hl, de
                ld      a, (hl)
                ld      (text_bg_red), a
                inc     hl
                ld      a, (hl)
                ld      (text_bg_green), a
                inc     hl
                ld      a, (hl)
                ld      (text_bg_blue), a
                ;; Text color = the high nibble.
                ld      a, (text_colour)
                and     #0xF0
                srl     a
                srl     a
                srl     a
                srl     a
                ld      e, a
                ld      d, #3
                mlt     de
                ld      hl, #apple_colour_table
                add     hl, de
                ld      a, (hl)
                ld      (text_fg_red), a
                inc     hl
                ld      a, (hl)
                ld      (text_fg_green), a
                inc     hl
                ld      a, (hl)
                ld      (text_fg_blue), a
                ;; DAC entry 0 = background, 1 = text, 2 = text, 3 = background, 4 = black.
                ld      a, #0
                ld      bc, #VGA_DAC_WRITE_INDEX
                out     (c), a
                ld      a, (text_bg_red)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (text_bg_green)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (text_bg_blue)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (text_fg_red)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (text_fg_green)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (text_fg_blue)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (text_fg_red)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (text_fg_green)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (text_fg_blue)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (text_bg_red)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (text_bg_green)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, (text_bg_blue)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
;; CHANGE (E26): fixes flashing characters ignoring $C022. The flashing pair
;; (background_r...) gets the colors just loaded: text_palette_tail (FREE SPACE $1EC4
;; block, src/mainloop.asm) writes entry 4 black as these lines did, then copies them. Its
;; JP and two NOPs take the place of the first LD A and LD BC; the rest stays, never run.
                jp      text_palette_tail
                nop
                nop
                out     (c), a
                ld      a, #0
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ld      a, #0
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                ret

text_bg_red:    .db     0
text_bg_green:  .db     0
text_bg_blue:   .db     0
text_fg_red:    .db     0
text_fg_green:  .db     0
text_fg_blue:   .db     0

;; ----------------------------------------------------------------------------------------
;; Loads 16 DAC entries from a table of red, green, blue bytes: double hires at entry 0
;; (double_hires_palette), lores at entry $10 (lores_palette, after the text palette).
;; ----------------------------------------------------------------------------------------
set_double_hires_palette:
                ;; Double hires: 16 colors from DAC entry 0.
                ld      a, #0xFF
                ld      bc, #VGA_PEL_MASK
                out     (c), a          ; PEL Mask Register = 0xFF
                ld      a, #0
                ld      bc, #VGA_DAC_WRITE_INDEX ; Palette Address (Write Mode) Register = 0
                out     (c), a
                ld      hl, #double_hires_palette
                ld      d, #0x10
                jr      set_16colour_palette_loop

;; Lores: the text palette first (entries 0-4), then 16 colors from entry $10.
set_lores_palette:
                call    set_textmode_palette
                ld      a, #0xFF
                ld      bc, #VGA_PEL_MASK
                out     (c), a          ; PEL Mask Register = 0xFF
                ld      a, #0x10
                ld      bc, #VGA_DAC_WRITE_INDEX ; Palette Address (Write Mode) Register = 0x10
                out     (c), a
                ld      hl, #lores_palette
                ld      d, #0x10

set_16colour_palette_loop:
                ;; D colors of three bytes each, from HL to the DAC.
                ld      a, (hl)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                inc     hl
                ld      a, (hl)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                inc     hl
                ld      a, (hl)
                ld      bc, #VGA_DAC_DATA
                out     (c), a
                inc     hl
                dec     d
                jp      NZ, set_16colour_palette_loop
                ret

;; $7DF8-$7E03: 12 bytes no instruction reads: a blue (00 00 D0) and white (FF FF FF)
;; color pair, twice, the same values as the start-up flashing pair at $9484.
                .db     0x00, 0x00, 0xD0, 0xFF, 0xFF, 0xFF
                .db     0xFF, 0xFF, 0xFF, 0x00, 0x00, 0xD0

;; ----------------------------------------------------------------------------------------
;; The 16 IIgs colors as 8-bit DAC values, red, green, blue, in IIgs color number
;; order ($C022 and lores numbering). set_textmode_palette reads the $C022 colors here.
;; ----------------------------------------------------------------------------------------
apple_colour_table:
                .db     0x00, 0x00, 0x00 ; $0 black
                .db     0xFF, 0x00, 0x00 ; $1 deep red
                .db     0x00, 0x00, 0xC0 ; $2 dark blue
                .db     0xFF, 0x00, 0xFF ; $3 purple
                .db     0x00, 0x80, 0x00 ; $4 dark green
                .db     0x40, 0x40, 0x40 ; $5 dark gray
                .db     0x00, 0x00, 0xFF ; $6 medium blue
                .db     0x00, 0xFF, 0xFF ; $7 light blue
                .db     0x80, 0x40, 0x10 ; $8 brown
                .db     0xFF, 0x84, 0x00 ; $9 orange
                .db     0xC0, 0xC0, 0xC0 ; $A light gray
                .db     0xFF, 0x80, 0x80 ; $B pink
                .db     0x00, 0xFF, 0x00 ; $C green
                .db     0xFF, 0xFF, 0x00 ; $D yellow
                .db     0x00, 0xFF, 0x80 ; $E aquamarine
                .db     0xFF, 0xFF, 0xFF ; $F white

;; ----------------------------------------------------------------------------------------
;; The lores colors, red, green, blue, in lores color order (the same 16 colors).
;; ----------------------------------------------------------------------------------------
lores_palette:
                .db     0x00, 0x00, 0x00 ; $0 black
                .db     0xFF, 0x00, 0x00 ; $1 deep red
                .db     0x00, 0x00, 0xC0 ; $2 dark blue
                .db     0xFF, 0x00, 0xFF ; $3 purple
                .db     0x00, 0x80, 0x00 ; $4 dark green
                .db     0x40, 0x40, 0x40 ; $5 dark gray
                .db     0x00, 0x00, 0xFF ; $6 medium blue
                .db     0x00, 0xFF, 0xFF ; $7 light blue
                .db     0x80, 0x40, 0x10 ; $8 brown
                .db     0xFF, 0x84, 0x00 ; $9 orange
                .db     0xC0, 0xC0, 0xC0 ; $A light gray
                .db     0xFF, 0x80, 0x80 ; $B pink
                .db     0x00, 0xFF, 0x00 ; $C green
                .db     0xFF, 0xFF, 0x00 ; $D yellow
                .db     0x00, 0xFF, 0x80 ; $E aquamarine
                .db     0xFF, 0xFF, 0xFF ; $F white

;; ----------------------------------------------------------------------------------------
;; The double hires colors, red, green, blue, by dot-pattern value (bit 0 = the
;; leftmost dot). The color names are the ones in MKCTAB.C's comment. Several differ
;; from the IIgs's own colors: docs/08-firmware.md, Double hires.
;; ----------------------------------------------------------------------------------------
double_hires_palette:
                .db     0x00, 0x00, 0x00 ; %0000 black
                .db     0xFF, 0x00, 0x00 ; %0001 magenta
                .db     0x80, 0x40, 0x10 ; %0010 brown
                .db     0xFF, 0x84, 0x00 ; %0011 orange
                .db     0x00, 0x80, 0x00 ; %0100 dark green
                .db     0x40, 0x40, 0x40 ; %0101 gray 1
                .db     0x00, 0xFF, 0x00 ; %0110 green
                .db     0xFF, 0xFF, 0x00 ; %0111 yellow
                .db     0x00, 0x00, 0xC0 ; %1000 dark blue
                .db     0xFF, 0x00, 0xFF ; %1001 purple
                .db     0xC0, 0xC0, 0xC0 ; %1010 gray 2
                .db     0xFF, 0x80, 0x80 ; %1011 pink
                .db     0x00, 0x00, 0xFF ; %1100 medium blue
                .db     0x00, 0xFF, 0xFF ; %1101 light blue
                .db     0x00, 0xFF, 0x80 ; %1110 aqua
                .db     0xFF, 0xFF, 0xFF ; %1111 white
