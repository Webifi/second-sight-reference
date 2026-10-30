;; v1.5/src/superhires.asm: v1.4/src/superhires.asm with the changes for a card with the original
;; U7 (fuse map BE8C); SecondSight_v1_5.asm includes it. Every change from
;; v1.4/src/ is marked CHANGE (En). En refers to docs/reference/errata.md.

;; ----------------------------------------------------------------------------------------
;; ==== $A000-$BFFF: the Super Hi-Res renderer. Its setup copies this range to SRAM bank 1
;; ($1A000) and runs that copy (BBR $10 maps logical $A000 to $1A000), so a change here
;; goes into the copy too when Super Hi-Res is already running.
;;
;; Variables: line_scb = bits 7 and 3-0 of the control byte whose tables select_line last
;; selected; palette_check_src / palette_check_copy = where the palette check
;; (check_palettes) continues; palette_check_entry = its DAC entry counter.
;; CHANGE (E13): ROM 1.4 keeps the whole control byte of the line being drawn in line_scb.
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
;; Super Hi-Res band renderer: render_superhires calls render_band once for each 4 KB band
;; that needs redrawing. render_band converts the band from its first source byte to its
;; last, one 256-byte screen page (64 source bytes) at a time, and selects each line's
;; tables when the line starts (select_line). One step converts two source bytes:
;;     pop  hl          9  L = byte b0, H = the next byte b1 (SP is the source pointer)
;;     ld   a, h        4  keep b1
;;     ld   h, b        4  B = the line's page table, $C0 + (palette AND 3) (SRAM)
;;     ld   h, (hl)     6  H = $F0 + 4n + (b0 AND 3), the VGA table page of b0's entry
;;     ldi             12  reads the table word at H:b0, which loads the VGA latches with
;;                         b0's four output pixels, and writes (DE) in write mode 1,
;;                         which stores them; DE moves on one
;;     ld   l, a        4  the same for b1
;;     ld   h, b        4
;;     ld   h, (hl)     6
;;     ldi             12
;; A VGA read loads the whole 4-byte word that contains its address, so L = b needs no
;; shifting: its low two bits pick a byte inside the word. make_320_table and
;; make_640_table put byte b's entry for palette n at word (b AND $FC) of page
;; $F0 + 4n + (b AND 3); build_page_tables fills the page tables.
;; Every four source bytes, "ld e, #..." moves the screen address to the next 16 window
;; bytes: each store fills four pixels chosen by address bit 0 and bits 3 and up, so the
;; four bytes go to offsets 6, 7, 8 and 9 (docs/06-video.md, The 64-bit latch lane rule).
;;
;; While SP walks the source, an interrupt would push its return address into the Apple
;; screen copy, so the conversion runs with interrupts off. At every line end and screen
;; piece change the real stack comes back and EI / NOP / DI lets a waiting interrupt in
;; (the Z180 takes none at the end of EI itself). An event therefore waits up to one line,
;; about 0.35 ms; meanwhile the Lattice holds the Apple's next copy or event on RDY.
;;
;; CHANGE (E13): ROM 1.4 ($A15C-$AA9C) walked each band backwards, 32 bytes per call to
;; one of eight unrolled copies (one per palette of a group and half line), with the step
;; ld a,(bc) / ld h,#0x3C+n / ld l,a / add hl,hl / add hl,hl / ldd: 42 clocks a byte,
;; and tables at $F000 + n x $400 + 4 x b. This version takes 30.5 clocks a byte, and
;; the page table in B lets one copy of the code serve all 16 palettes, so the per-call
;; palette dispatch goes too. A full screen takes about 75 ms instead of about
;; 99 ms. docs/reference/errata.md, E13.
;; ----------------------------------------------------------------------------------------
;; While converting: band_source = where the source continues when SP is the firmware's
;; own stack again; main_sp = the firmware's stack pointer while SP walks the source.
band_source:    .dw     0
main_sp:        .dw     0

;; ----------------------------------------------------------------------------------------
;; Redraws one 4 KB band, from its first source byte to its last.
;; In: BC' = the band's first source byte, D' = $F0 (the first screen page of a piece),
;; IX = the control byte of the band's first line, L = halves (32 source bytes) left in
;; that line, H = screen pages to draw (64 source bytes each), E = the band's first 4 KB
;; screen piece (map_piece). Uses every register; returns with interrupts on.
;; ----------------------------------------------------------------------------------------
render_band:
                ;; Counters to the alternate set, kept there while converting: B' = pages left,
                ;; C' = halves left in the line, E' = the screen piece. The first source byte
                ;; waits in band_source; D (from D') = the screen page.
                exx
                ld      (band_source), bc
                exx
                ld      b, h
                ld      c, l
                ld      a, e
                exx
                call    map_piece
                ;; Select the first line's tables whatever line_scb holds: a control byte masked
                ;; by select_line never equals $70.
                ld      a, #0x70
                ld      (line_scb), a
                call    select_line
                ;; C counts down once per LDI; starting each line at $FF keeps B, the page
                ;; table, from changing (a line is 160 bytes).
                ld      c, #0xFF
                ld      hl, (band_source)
                di
                ld      (main_sp), sp
                ld      sp, hl

band_page:
                ;; The first half of a screen page: 32 source bytes to window offsets $06-$79.
                ld      e, #0x06
                pop     hl
                ld      a, h
                ld      h, b
                ld      h, (hl)
                ldi
                ld      l, a
                ld      h, b
                ld      h, (hl)
                ldi
                pop     hl
                ld      a, h
                ld      h, b
                ld      h, (hl)
                ldi
                ld      l, a
                ld      h, b
                ld      h, (hl)
                ldi
                ld      e, #0x16
                pop     hl
                ld      a, h
                ld      h, b
                ld      h, (hl)
                ldi
                ld      l, a
                ld      h, b
                ld      h, (hl)
                ldi
                pop     hl
                ld      a, h
                ld      h, b
                ld      h, (hl)
                ldi
                ld      l, a
                ld      h, b
                ld      h, (hl)
                ldi
                ld      e, #0x26
                pop     hl
                ld      a, h
                ld      h, b
                ld      h, (hl)
                ldi
                ld      l, a
                ld      h, b
                ld      h, (hl)
                ldi
                pop     hl
                ld      a, h
                ld      h, b
                ld      h, (hl)
                ldi
                ld      l, a
                ld      h, b
                ld      h, (hl)
                ldi
                ld      e, #0x36
                pop     hl
                ld      a, h
                ld      h, b
                ld      h, (hl)
                ldi
                ld      l, a
                ld      h, b
                ld      h, (hl)
                ldi
                pop     hl
                ld      a, h
                ld      h, b
                ld      h, (hl)
                ldi
                ld      l, a
                ld      h, b
                ld      h, (hl)
                ldi
                ld      e, #0x46
                pop     hl
                ld      a, h
                ld      h, b
                ld      h, (hl)
                ldi
                ld      l, a
                ld      h, b
                ld      h, (hl)
                ldi
                pop     hl
                ld      a, h
                ld      h, b
                ld      h, (hl)
                ldi
                ld      l, a
                ld      h, b
                ld      h, (hl)
                ldi
                ld      e, #0x56
                pop     hl
                ld      a, h
                ld      h, b
                ld      h, (hl)
                ldi
                ld      l, a
                ld      h, b
                ld      h, (hl)
                ldi
                pop     hl
                ld      a, h
                ld      h, b
                ld      h, (hl)
                ldi
                ld      l, a
                ld      h, b
                ld      h, (hl)
                ldi
                ld      e, #0x66
                pop     hl
                ld      a, h
                ld      h, b
                ld      h, (hl)
                ldi
                ld      l, a
                ld      h, b
                ld      h, (hl)
                ldi
                pop     hl
                ld      a, h
                ld      h, b
                ld      h, (hl)
                ldi
                ld      l, a
                ld      h, b
                ld      h, (hl)
                ldi
                ld      e, #0x76
                pop     hl
                ld      a, h
                ld      h, b
                ld      h, (hl)
                ldi
                ld      l, a
                ld      h, b
                ld      h, (hl)
                ldi
                pop     hl
                ld      a, h
                ld      h, b
                ld      h, (hl)
                ldi
                ld      l, a
                ld      h, b
                ld      h, (hl)
                ldi
                ;; C' counts the halves left in the line.
                exx
                dec     c
                exx
                jp      Z, band_line_a

band_half:
                ;; The second half: window offsets $86-$F9.
                ld      e, #0x86
                pop     hl
                ld      a, h
                ld      h, b
                ld      h, (hl)
                ldi
                ld      l, a
                ld      h, b
                ld      h, (hl)
                ldi
                pop     hl
                ld      a, h
                ld      h, b
                ld      h, (hl)
                ldi
                ld      l, a
                ld      h, b
                ld      h, (hl)
                ldi
                ld      e, #0x96
                pop     hl
                ld      a, h
                ld      h, b
                ld      h, (hl)
                ldi
                ld      l, a
                ld      h, b
                ld      h, (hl)
                ldi
                pop     hl
                ld      a, h
                ld      h, b
                ld      h, (hl)
                ldi
                ld      l, a
                ld      h, b
                ld      h, (hl)
                ldi
                ld      e, #0xA6
                pop     hl
                ld      a, h
                ld      h, b
                ld      h, (hl)
                ldi
                ld      l, a
                ld      h, b
                ld      h, (hl)
                ldi
                pop     hl
                ld      a, h
                ld      h, b
                ld      h, (hl)
                ldi
                ld      l, a
                ld      h, b
                ld      h, (hl)
                ldi
                ld      e, #0xB6
                pop     hl
                ld      a, h
                ld      h, b
                ld      h, (hl)
                ldi
                ld      l, a
                ld      h, b
                ld      h, (hl)
                ldi
                pop     hl
                ld      a, h
                ld      h, b
                ld      h, (hl)
                ldi
                ld      l, a
                ld      h, b
                ld      h, (hl)
                ldi
                ld      e, #0xC6
                pop     hl
                ld      a, h
                ld      h, b
                ld      h, (hl)
                ldi
                ld      l, a
                ld      h, b
                ld      h, (hl)
                ldi
                pop     hl
                ld      a, h
                ld      h, b
                ld      h, (hl)
                ldi
                ld      l, a
                ld      h, b
                ld      h, (hl)
                ldi
                ld      e, #0xD6
                pop     hl
                ld      a, h
                ld      h, b
                ld      h, (hl)
                ldi
                ld      l, a
                ld      h, b
                ld      h, (hl)
                ldi
                pop     hl
                ld      a, h
                ld      h, b
                ld      h, (hl)
                ldi
                ld      l, a
                ld      h, b
                ld      h, (hl)
                ldi
                ld      e, #0xE6
                pop     hl
                ld      a, h
                ld      h, b
                ld      h, (hl)
                ldi
                ld      l, a
                ld      h, b
                ld      h, (hl)
                ldi
                pop     hl
                ld      a, h
                ld      h, b
                ld      h, (hl)
                ldi
                ld      l, a
                ld      h, b
                ld      h, (hl)
                ldi
                ld      e, #0xF6
                pop     hl
                ld      a, h
                ld      h, b
                ld      h, (hl)
                ldi
                ld      l, a
                ld      h, b
                ld      h, (hl)
                ldi
                pop     hl
                ld      a, h
                ld      h, b
                ld      h, (hl)
                ldi
                ld      l, a
                ld      h, b
                ld      h, (hl)
                ldi
                exx
                dec     c
                exx
                jp      Z, band_line_b

band_page_end:
                ;; B' counts the pages left in the band. D moves to the next screen page; past
                ;; $FF the next 4 KB piece is mapped at $F000 and D starts again at $F0.
                exx
                dec     b
                exx
                jp      Z, band_done
                inc     d
                jp      NZ, band_page
                ld      (band_source), sp
                ld      sp, (main_sp)
                ei
                nop
                di
                ld      d, #0xF0
                exx
                inc     e
                ld      a, e
                exx
                call    map_piece
                ld      sp, (band_source)
                jp      band_page

band_line_a:
                ;; The line ends halfway through the page: the real stack back, a waiting
                ;; interrupt in, C' = 5 halves and the next line's tables, then the second half.
                ld      (band_source), sp
                ld      sp, (main_sp)
                ei
                nop
                di
                exx
                ld      c, #5
                exx
                call    select_line
                ld      c, #0xFF
                ld      sp, (band_source)
                jp      band_half

band_line_b:
                ;; The line ends with the page: the same, then the end of the page.
                ld      (band_source), sp
                ld      sp, (main_sp)
                ei
                nop
                di
                exx
                ld      c, #5
                exx
                call    select_line
                ld      c, #0xFF
                ld      sp, (band_source)
                jp      band_page_end

band_done:
                ld      sp, (main_sp)
                ei
                ret

;; ----------------------------------------------------------------------------------------
;; Takes the next line's scan-line control byte (IX, which then moves on one line). When
;; its 640-pixel bit or palette differs from line_scb, the line whose tables are selected,
;; selects the new line's: Oak $23 = the read segment that holds the palette's table
;; (8 + palette / 4 for a 320-pixel line, 12 + palette / 4 for 640), and B = the page of
;; its page table, converter_page_tables + (palette AND 3) pages. Uses A and HL, and C when
;; the tables change.
;; ----------------------------------------------------------------------------------------
select_line:
                ;; Only bit 7 (640 pixels) and bits 3-0 (palette) of the control byte
                ;; choose the tables.
;; CHANGE (E11): was ld a, 0(ix). ROM 1.4 ignored bit 5, color fill mode. fill_line_check
;; (free space at $A480, in the renderer's copy) returns the same control byte in A and,
;; for a 320-pixel line with bit 5 set, first points the converter at a filled copy of
;; the line.
                call    fill_line_check
                inc     ix
                and     #0x8F
                ld      hl, #line_scb
                cp      (hl)
                ret     Z
                ld      (hl), a
                ld      h, #0xC
                bit     7, a
                jr      NZ, select_line_group
                ld      h, #8

select_line_group:
                ld      l, a
                and     #0xF
                srl     a
                srl     a
                add     a, h
                ld      h, a
                ld      a, #0x23
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, h
                ld      bc, #OAK_DATA
                out     (c), a
                ld      a, l
                and     #3
                add     a, #>converter_page_tables
                ld      b, a
                ret

;; ----------------------------------------------------------------------------------------
;; Maps 4 KB screen piece A (0-31) at logical $F000: Oak $24, the write segment, =
;; band_write_segment[A], and CBR = band_cbr[A] (32 bytes further on). Keeps BC and DE;
;; uses A and HL.
;; ----------------------------------------------------------------------------------------
map_piece:
                push    bc
                ld      hl, #band_write_segment
                ld      c, a
                ld      b, #0
                add     hl, bc
                ld      a, #0x24
                ld      bc, #OAK_INDEX
                out     (c), a
                ld      a, (hl)
                ld      bc, #OAK_DATA
                out     (c), a
                ld      bc, #32
                add     hl, bc
                ld      a, (hl)
                out0    (CBR), a
                pop     bc
                ret

;; FREE SPACE: from here to $AA9C, part of ROM 1.4's converter, select_line_tables and
;; render_band, which the E13 change replaces. Part of $A000-$BFFF, which Super Hi-Res
;; setup copies to SRAM bank 1, so only that renderer's code can use it. Its end holds
;; fill_line_buffer and converter_page_tables (at $A600).
free_e13:
                .org    0xA480
;; ----------------------------------------------------------------------------------------
;; CHANGE (E11): color fill mode. select_line calls this first, at the start of every line
;; render_band draws, with the firmware's own stack and before it reads the control byte.
;; Returns A = the line's control byte (IX), as the replaced LD A did; keeps BC, DE and IX.
;; On a 320-pixel line whose control byte has bit 5 set, the IIgs shows each pixel of
;; value 0 in the color of the pixel before it. The converter cannot carry a color from
;; pixel to pixel, so this first copies the line into fill_line_buffer, left to right,
;; with every 0 pixel replaced by the last nonzero pixel before it on the line (0 until
;; there is one), and points band_source, where the converter's source pointer resumes,
;; at the same place in the buffer. The converter then reads the buffer for the rest of
;; the line.
;;
;; At the next line start fill_resume, the real line's end, goes back into
;; band_source. A line that a band starts part way through is copied from its real start,
;; so the fill color carries over the band boundary. At a band's first line (line_scb =
;; $70, which render_band sets) a pending fill_resume belongs to the band before and is
;; dropped. Lines without bit 5, and 640-pixel lines, take ROM 1.4's path unchanged.
;;
;; Interrupts are on during the copy, which takes about 1 ms: the stack is the
;; firmware's own here, as at the EI / NOP / DI of each line end.
;; ----------------------------------------------------------------------------------------
fill_line_check:
                push    bc
                push    de
                ld      a, (line_scb)
                cp      #0x70
                jr      Z, fill_new_band
                ld      a, (fill_active)
                cp      #0
                jr      Z, fill_test_line
                ld      hl, (fill_resume)
                ld      (band_source), hl

fill_new_band:
                ld      a, #0
                ld      (fill_active), a

fill_test_line:
                ld      a, 0(ix)
                and     #0xA0           ; bit 7 = 640 pixels, bit 5 = color fill
                cp      #0x20
                jr      NZ, fill_line_return
                ;; The line's first source byte: $2000 + 160 x line, where line = the low
                ;; byte of IX (the control bytes start at $9D00).
                push    ix
                pop     hl
                ld      e, l
                ld      d, #160
                mlt     de
                ld      hl, #0x2000
                add     hl, de
                ld      de, #160
                add     hl, de
                ld      (fill_resume), hl
                or      a
                sbc     hl, de
                ex      de, hl          ; DE = the line's first byte
                ld      hl, (band_source)
                or      a
                sbc     hl, de          ; how far into the line the converter is
                ld      bc, #fill_line_buffer
                add     hl, bc
                ld      (band_source), hl
                ex      de, hl          ; HL = the line, DE = the buffer
                ld      de, #fill_line_buffer
                ld      a, #1
                ld      (fill_active), a
                ;; Two pixels a byte, the left one in the high nibble. C = the fill color
                ;; in both nibbles.
                ld      b, #160
                ld      c, #0
                ei

fill_line_loop:
                ld      a, (hl)
                and     #0xF0
                jr      Z, fill_left_pixel
                ld      c, a
                rrca
                rrca
                rrca
                rrca
                or      c
                ld      c, a

fill_left_pixel:
                ld      a, c
                and     #0xF0
                ld      (de), a
                ld      a, (hl)
                and     #0xF
                jr      Z, fill_right_pixel
                ld      c, a
                rlca
                rlca
                rlca
                rlca
                or      c
                ld      c, a

fill_right_pixel:
                ld      a, c
                and     #0xF
                ex      de, hl
                or      (hl)
                ld      (hl), a
                ex      de, hl
                inc     hl
                inc     de
                djnz    fill_line_loop
                di

fill_line_return:
                pop     de
                pop     bc
                ld      a, 0(ix)
                ret

;; fill_active = 1 while the converter reads fill_line_buffer; fill_resume = the real
;; source address after that line.
fill_active:    .db     0
fill_resume:    .dw     0

;; The filled copy of one 320-pixel line, 160 bytes. It lies in the renderer's own block,
;; as converter_page_tables does, so it takes none of the memory the firmware
;; documentation leaves free for programs.
fill_line_buffer:
                .ds     160

;; CHANGE (E13): the converter's page tables (build_page_tables), 1 KB in the renderer's
;; own block. The firmware documentation reserves bank 1 $A000-$BFFF for the Super Hi-Res
;; renderer while it runs, and each Super Hi-Res setup copies the block there and then
;; builds the tables, so a program that used the space while the renderer was off loses
;; nothing. The tables must start on a page: the converter's ld h,(hl) step reads an
;; entry's page from them with L = the source byte. In bank 0 the same 1 KB is
;; command_buffer (src/text.asm), used by ScrollScreen and SetPalette: setup copies it
;; over before it builds the tables, so they never meet.
                .org    0xA600
converter_page_tables:
                .ds     0x400

                .org    0xAA9D

;; ----------------------------------------------------------------------------------------
;; Super Hi-Res renderer: reads the band flags at ports $A5 and $A4 (each read clears
;; them), adds the bands whose scan-line control bytes changed (check_lower_scbs, check_upper_scbs), and
;; redraws only those 4 KB bands (render_band), upper half first; the palette check runs
;; twice per pass (check_palettes). Errata E11 (color fill) and E12 (palettes rewritten
;; mid-frame); E3 and E13 are changed in the band settings below.
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
                ;; palettes): BC' = its first source byte, D' = the first screen page,
                ;; IX = its first line's control byte (line 179), L = halves left in that
                ;; line, H = screen pages (52), E = its first 4 KB screen piece.
                ;;
                ;; CHANGE (E13): ROM 1.4 drew each band backwards: BC' = its last source
                ;; byte ($9CFF), D' = its last screen page ($F3), IX = the control byte
                ;; before its last line ($9DC6), L = halves into that line (5), H = 32-byte
                ;; turns ($34), E = its last piece + 1 ($20). Every band below changes the
                ;; same way.
                ld      a, (upper_bands)
                bit     3, a
                jr      Z, check_band_8000
                exx
                ld      bc, #0x9000
                ld      d, #0xF0
                exx
                ld      ix, #0x9DB3
                ld      l, #4
                ld      h, #0x34
                ld      e, #0x1C
                call    render_band

check_band_8000:
                ;; Band $8000-$8FFF, 64 pages.
                ld      a, (upper_bands)
                bit     2, a
                jr      Z, check_band_7000
                exx
                ld      bc, #0x8000
                ld      d, #0xF0
                exx
                ld      ix, #0x9D99
                ld      l, #2
                ld      h, #0x40
                ld      e, #0x18
                call    render_band

check_band_7000:
                ld      a, (upper_bands)
                bit     1, a
                jr      Z, check_band_6000
                exx
                ld      bc, #0x7000
                ld      d, #0xF0
                exx
                ld      ix, #0x9D80
                ld      l, #5
                ld      h, #0x40
                ld      e, #0x14
                call    render_band

check_band_6000:
                ld      a, (upper_bands)
                bit     0, a
                jr      Z, check_lower_bands
                exx
                ld      bc, #0x6000
                ld      d, #0xF0
                exx
;; CHANGE (E3): fixes lines 102-127 taking the next line's control byte, palette and
;; 320/640 setting. ROM 1.4's backward render_band incremented IX before reading each
;; control byte, so a band had to start one byte before its last line's byte, as the other
;; bands do; ROM 1.4 loads $9D7F here instead of $9D7E. The E13 renderer starts each band
;; at its first line's own byte: line 102, $9D66.
                ld      ix, #0x9D66
                ld      l, #3
                ld      h, #0x40
                ld      e, #0x10
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
                ld      bc, #0x5000
                ld      d, #0xF0
                exx
                ld      ix, #0x9D4C
                ld      l, #1
                ld      h, #0x40
                ld      e, #0xC
                call    render_band

check_band_4000:
                ld      a, (lower_bands)
                bit     2, a
                jr      Z, check_band_3000
                exx
                ld      bc, #0x4000
                ld      d, #0xF0
                exx
                ld      ix, #0x9D33
                ld      l, #4
                ld      h, #0x40
                ld      e, #8
                call    render_band

check_band_3000:
                ld      a, (lower_bands)
                bit     1, a
                jr      Z, check_band_2000
                exx
                ld      bc, #0x3000
                ld      d, #0xF0
                exx
                ld      ix, #0x9D19
                ld      l, #2
                ld      h, #0x40
                ld      e, #4
                call    render_band

check_band_2000:
                ld      a, (lower_bands)
                bit     0, a
                ret     Z
                exx
                ld      bc, #0x2000
                ld      d, #0xF0
                exx
                ld      ix, #0x9D00
                ld      l, #5
                ld      h, #0x40
                ld      e, #0
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
                ;; CHANGE (E13): first the converter's page tables in SRAM (build_page_tables).
                call    build_page_tables
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
;; CHANGE (E13): each entry goes to word (B AND $FC) of page $F0 + 4n + (B AND 3), where n
;; = palette number AND 3 (D / 16 AND 3), the layout the converter's ld h,(hl) step reads.
;; ROM 1.4 wrote the entries one after another from HL ($F000 + n x $400 + 4 x B).
;; ----------------------------------------------------------------------------------------
make_320_table:
                ;; For each source byte B (two 4-bit pixels), four output bytes: the left
                ;; pixel twice and the right pixel twice, each plus D, so a 320-pixel line
                ;; fills 640 screen pixels. C = $F0 + 4n, the palette's first table page.
                call    first_table_page
                ld      b, #0

make_320_loop:
                call    point_at_entry
                ld      a, b
                srl     a
                srl     a
                srl     a
                srl     a
                or      d
                ld      (hl), a
                inc     l
                ld      (hl), a
                inc     l
                ld      a, b
                and     #0xF
                or      d
                ld      (hl), a
                inc     l
                ld      (hl), a
                inc     b
                ld      a, b
                cp      #0
                jp      NZ, make_320_loop
                ret

;; ----------------------------------------------------------------------------------------
;; CHANGE (E13): C = $F0 + 4n, the first of palette n's four table pages; n = (D / 16) AND
;; 3, the palette's place in its group of four.
;; ----------------------------------------------------------------------------------------
first_table_page:
                ld      a, d
                rrca
                rrca
                and     #0xC
                add     a, #0xF0
                ld      c, a
                ret

;; ----------------------------------------------------------------------------------------
;; CHANGE (E13): HL = byte B's table entry: page C + (B AND 3), word (B AND $FC).
;; ----------------------------------------------------------------------------------------
point_at_entry:
                ld      a, b
                and     #3
                add     a, c
                ld      h, a
                ld      a, b
                and     #0xFC
                ld      l, a
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
;; CHANGE (E13): entries at the same places as make_320_table's (point_at_entry).
;; ----------------------------------------------------------------------------------------
make_640_table:
                ;; For each source byte B (four 2-bit pixels), four output bytes. As on the
                ;; IIgs, the four pixel positions use different quarters of the palette:
                ;; the first pixel colors 8-11, the second 12-15, the third 0-3, the fourth
                ;; 4-7 (each plus D).
                call    first_table_page
                ld      b, #0

make_640_loop:
                call    point_at_entry
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

;; ----------------------------------------------------------------------------------------
;; CHANGE (E13): builds the converter's page tables, one 256-byte page per palette n of a
;; group: converter_page_tables + n x $100 + B holds $F0 + 4n + (B AND 3), the VGA table
;; page of byte B's entry. It runs in Super Hi-Res setup after the renderer's block has
;; been copied to SRAM bank 1, with the Super Hi-Res MMU mapping (BBR $10), so the tables
;; go into bank 1.
;; ----------------------------------------------------------------------------------------
build_page_tables:
                ld      hl, #converter_page_tables

build_page_loop:
                ld      a, h
                sub     #>converter_page_tables
                add     a, a
                add     a, a
                add     a, #0xF0
                ld      b, a
                ld      a, l
                and     #3
                add     a, b
                ld      (hl), a
                inc     hl
                ld      a, h
                cp      #>(converter_page_tables + 0x400)
                jr      NZ, build_page_loop
                ret

;; FREE SPACE: the rest of $B025-$B1FF, $B05D-$B1FF after the E13 change (419 bytes), zero
;; in ROM 1.4. Part of $A000-$BFFF, which Super Hi-Res setup copies to SRAM bank 1.
                .org    0xB200
