# 15 Drawing with the OTI-087X: every hardware assist and what it costs

[Reference index](../README.md) | [Glossary](glossary.md) | [Reference tables](reference/README.md)

The OTI-087X is a 1993 PC graphics chip with hardware that helps the CPU draw faster.
On this card the Z180 is that CPU. Use this chapter to choose a drawing method:
it covers every drawing and display feature, how each works with this card's wiring,
and its cost in Z180 clocks.

Custom code reaches all of it: every register of the Oak, the OTI-068 and the Bt481, in
any combination ([Beyond the firmware](14-custom-code.md)). Nothing here depends on the
firmware. Mode timing (lines, refresh, monitors) is in
[Modes beyond the firmware's tables](14-custom-code.md#modes-beyond-the-firmwares-tables)
and [Building a mode](14-custom-code.md#building-a-mode).

Sources:

- Oak features: the [OTI-087 databook](sources.md#s02).
- Standard VGA registers: IBM's [VGA reference](sources.md#s68), which the databook
  directs readers to use (p29).
- Feature use: Oak's [87X Windows drivers](sources.md#s69) and [87X DOS kit](sources.md#s79),
plus the third-party [XFree86 driver](sources.md#s63) and [Ferraro's chapter on
Oak](sources.md#s61). The latter two name no 087 revision.
- Card wiring: the [netlist](../data/netlist/README.md).
- Instruction clocks: Zilog's [UM0050](sources.md#s39).

Clock counts here are computed from those sources.

## Contents

- [The limit is the Z180's bus](#the-limit-is-the-z180s-bus)
- [Reaching video memory](#reaching-video-memory)
- [The latch: copying 4 pixels per access](#the-latch-copying-4-pixels-per-access)
- [The pixel mask: transparency for latch writes](#the-pixel-mask-transparency-for-latch-writes)
- [Color expansion: 4 pixels from 4 bits](#color-expansion-4-pixels-from-4-bits)
- [Filling from the latch registers](#filling-from-the-latch-registers)
- [Unchained 256-color mode: copies with `ldi` and DMA](#unchained-256-color-mode-copies-with-ldi-and-dma)
- [The standard VGA graphics controller](#the-standard-vga-graphics-controller)
- [Caches](#caches)
- [Display features that cost no drawing](#display-features-that-cost-no-drawing)
- [Color tricks](#color-tricks)
- [Cost table](#cost-table)
- [Example: a vertical scrolling shooter](#example-a-vertical-scrolling-shooter)

## The limit is the Z180's bus

The chip side is fast. Video memory is 32 bits wide (eight 256K x 4 DRAMs) on a 40 MHz
memory clock. A page-mode cycle takes two memory clocks, 50 ns for 4 bytes, about 80 MB/s,
shared between the display refresh and the CPU. Sources: [databook](sources.md#s02) p6
("80 Mbyte/sec Video") and pp55-56 (tPC = 2 tMP); [memory-clock straps](reference/clocks.md#memory-clock-straps).

The Z180 side is slow:

- **One byte per access.** The Z180's data bus is 8 bits wide, and the firmware's Super
  Hi-Res renderer, which runs on production cards, relies on each write storing one
  4-byte latch half ([the 64-bit latch lane rule](06-video.md#the-64-bit-latch-lane-rule)).
  The prototype drawing shows the wiring behind it: SD8-SD15 open and -BHE (pin 100) tied
  to +5 V ([netlist](../data/netlist/README.md) U28). The chip's 16-bit paths, which
  store both latch halves in one cycle ("MOVSW instructions can replace MOVSB", databook
  p6), never run on this card.
- **Waits.** At 18 MHz a video memory access takes at least 2 wait states, and a write
  needs 3 to meet the chip's worst-case timing
  ([VGA bus timing](reference/clocks.md#vga-bus-timing)). The Oak's IOCHRDY adds more
  while its display FIFO is filling (ext $20) and while it cannot serve the access at once
  ([how long IOCHRDY holds an access](05-z180.md#how-long-iochrdy-holds-an-access)).
  Register writes to the VGA ports take one I/O wait. The clock counts below use the
  counts for an access that meets no display fetch or refresh
  ([fixed waits](05-z180.md#a-functional-timing-estimate)): 3 on a write the write cache
  takes or a read the read cache holds, 5 on any other read, 5 on a write with the write
  cache off. An access behind a display fetch or a refresh cycle waits longer.

At 18 MHz, with ROM 1.4's usual cache setting (write cache on, read cache off):

| Access | Clocks |
|---|---|
| `ld a,(hl)` from video memory | 6 + 5 = 11 |
| `ld (hl),a` or `ld (de),a` to video memory | 7 + 3 = 10 |
| `ld (hl),n` to video memory | 9 + 3 = 12 |
| `ldi`, video memory to video memory | 12 + 5 + 3 = 20 |
| `out (c),r` to an Oak or VGA register | 10 + 1 = 11 |
| DMA0 burst, SRAM to video memory, per byte | 3 + 6 = 9 |
| DMA0 burst, video memory to video memory, per byte | 6 + 5 + 3 = 14 |
| One 59.64 Hz frame | 301,800 |

With the write cache off, each video memory write takes 2 clocks more.

So the Z180 moves about 2 MB/s, a fortieth of what the chip can take. Every feature that
moves more pixels per access is a direct speedup.

## Reaching video memory

Two windows reach the 1 MB ([video RAM window](06-video.md#the-video-ram-window)):

- **Linear:** 512 KB at Z180 $80000-$FFFFF, plus the half switch for the other 512 KB.
  This is the Oak's linear window (ext $05 = $19). The latch, the pixel mask, the logical
  functions and color expansion all work through it: Oak's linear driver `LIN8_SC.DRV`
  turns it on and does all its drawing through it ([87X drivers](sources.md#s69), file
  offsets $8E23-$8E3E).
- **VGA window:** 64 KB at $A0000. Ext $23 sets the 64 KB bank for **reads** and ext $24
  the bank for **writes**, independently (ext $25 sets both). Source: databook p42;
  Ferraro: the write segment "controls all CPU Memory writes, and the Read Segment
  controls all CPU Memory reads".

Separate banks make page-to-page copies cheap: with ext $23 = source page and ext $24 =
destination page, `ld a,(hl)` then `ld (hl),a` copies between pages with one pointer.

## The latch: copying 4 pixels per access

**What it is.** A VGA keeps a latch: 4 bytes, one per memory plane. A read of video
memory fills it, and a write in write mode 1 (graphics register 5 bits 1-0 = 01) stores
it back, ignoring the CPU's data. With ext $22 bit 4 the Oak widens it to 64 bits, two
4-byte halves. Ext $35 picks one of the 8 latch bytes and ext $36 reads or writes it; the
index steps by one on each $36 access. Sources: databook p1, pp42-44; [IBM](sources.md#s68).

**How it behaves on this card**, in Oak packed 256-color mode (ext $21 = $04, chain-4,
ext $22 bit 4 = 1, pixel mask on), from Oak's drivers and the chip's register
definitions ([latch access rules](reference/oti087-registers.md#latch-access-rules)):

```
read  at E:  both latch halves  <- the 4 bytes of the aligned word holding E
write at A:  4 bytes at (A & ~7) + 4*(A & 1)  <- latch half (A & 1) XOR swap
             (A1 and A2 are ignored; ext $22 bit 5 is the swap)

pixels:   0 1 2 3 | 4 5 6 7 | 8 9 ...
write at:    A=0  |   A=1   |  A=8 ...
```

So one read and one write copy 4 pixels from anywhere in video memory to anywhere else.
In packed mode that costs:

- **Two pointers** (source in HL, stepping by 4; destination in DE, stepping +1 and +7):
  `ld a,(hl)` 8, `ld (de),a` 10, and two register steps, about 29 clocks per 4 pixels.
- **One pointer**, when source and destination sit at the same offset in two banks (ext
  $23 and $24, for example restoring a page from a clean copy): read and write at P = 0,
  then P = 5 (the word at 4 goes to pixels 4-7), then 8, 13, 16, 21 and so on, about 24
  clocks per 4 pixels.
- Byte stores take about 64 for the same 4 pixels.

Rules that follow:

- **Same alignment.** The latch holds whole aligned 4-byte words, and the swap bit only
  exchanges halves. A source must sit at the same position inside its word as its
  destination. A sprite drawn at any x is kept as 4 copies, shifted by 0-3 pixels, in
  spare video memory (1 MB holds 18 screens of 224 x 256).
- **Not with LDIR or DMA in packed mode.** Both step addresses by one, so 3 of every 4
  transfers rewrite the same group. Packed-mode latch copies need explicit or compiled
  code that steps the source by 4 and the destination by +1, +7.
  [Unchained mode](#unchained-256-color-mode-copies-with-ldi-and-dma) removes this limit.
- **Unaligned edges** are handled by the pixel mask, not by a different routine.

## The pixel mask: transparency for latch writes

Ext $30 bit 3 turns on the pixel mask. Ext $34 then has one bit per pixel of an 8-pixel
group, and a 0 leaves that pixel unchanged. While it is on, the map mask and packed-mode
address masking are off. Ext $30 bit 4 sets the bit order
([pixel-mask bit order](06-video.md#pixel-mask-bit-order)). Source: databook pp43-44: the
mask "speeds masked bitblt functions".

A latch write stores one 4-pixel half, so the 4 mask bits of that half decide which of its
pixels change. That gives transparent sprites: copy each group from the sprite's shifted
copy with the mask set to its opaque pixels.

The cost is the mask change: `ld a,n` and `out (c),a` (17 clocks) when the next group needs
a different mask. Keep $3DE pointing at $34 and BC at $03DF, and change only the data.
Per 4-pixel group with k opaque pixels:

| Opaque pixels in the group | Byte stores (about 16 per pixel) | Masked latch copy, two pointers |
|---|---|---|
| 4 | 64 | 29, mask unchanged |
| 3 | 48 | 46 |
| 2 | 32 | 29 if the mask is unchanged, else 46 |
| 1 | 16 | 46 |
| 0 | 0 | 0: skip the group |

A compiled sprite picks per group. Solid interiors run as latch copies with no mask
change. Single pixels on the edges are cheaper as stores, but stores need write mode 0
and the pixel mask off, about four register writes each way, so a sprite does its latch
groups in one pass and its single pixels in a second.

**Masked fills in write mode 0.** With the mask on and color expansion off, a write-mode-0
store gives every enabled pixel of its 4-pixel half the stored byte; address bit 0 picks
the half, as for every 8-bit store on this card. Oak's linear driver fills wide rectangles
this way, with one 16-bit store of the fill color per 8-pixel group
([87X drivers](sources.md#s69) `LIN8_SC.DRV` $1AFD-$1B96).

## Color expansion: 4 pixels from 4 bits

With ext $30 bit 0 on and bit 1 off (packed), a write turns bits into pixels: a 1 bit
writes the foreground color (ext $31), a 0 bit the background color (ext $32). With ext
$30 bit 2, the color pattern register (ext $33) supplies the bits instead of the CPU.
The pixel mask applies, so masked-off pixels stay unchanged. Source: databook pp6, 43-44
("allow eight consecutive bytes to be expanded from one byte").

On this card each write fills one 4-pixel half: the write at offset 0 of a group fills
pixels 0-3, offset 1 fills pixels 4-7, each pixel from its bit of the CPU byte
([latch access rules](reference/oti087-registers.md#latch-access-rules)). No read is
needed. The third-party XFree86 driver fills rectangles this way: ext $30 = $1D, pattern $FF,
foreground = the color, two writes per 8 pixels (`oti87_fill.c`).

Uses:

- **Clears and solid fills:** 4 pixels per write, about 3.5 clocks per pixel.
- **Text and one-color shapes:** an 8 x 8 character is 16 writes. With the mask set to
  the shape's bits, the background shows through.
- **Two-color shapes, shadows, bullets.**

## Filling from the latch registers

Ext $36 writes the latch directly. Load the 8 latch bytes with 8 pixel colors, then every
write-mode-1 write stores 4 of them, with no read and no CPU data: half 0 at even
addresses, half 1 at odd. That is a multicolor 8-pixel pattern fill at the color
expansion's speed, for tiled backgrounds. Any read of video memory reloads the latch, so
the fill loop must not read.

Ext $22 bit 0 (content-addressable latch, with bit 4 off): the low CPU address bits pick
which latch byte a write stores, so each pixel takes the pattern byte for its own column.
That is one pixel per write. Source: databook p42, p1 ("special 256 color pattern and fill
modes").

## Unchained 256-color mode: copies with `ldi` and DMA

IBM's VGA can also hold 256-color pixels with chain 4 off. The OTI-087X supports it: Oak's
databook says the chip "is completely compatible with the IBM VGA standard and implements
all registers and data paths" (p1), and every register this mode uses is IBM's own.

**The layout.**

```
CPU address A  ->  plane 0    plane 1    plane 2    plane 3
shown as           pixel 4A   pixel 4A+1 pixel 4A+2 pixel 4A+3
map mask bit       0          1          2          3
```

- Sequencer register 4 bit 3 = 0 (chain 4 off): each CPU address reaches the same offset in
  all four planes, and the map mask (sequencer register 2) picks the planes a write
  changes ([IBM](sources.md#s68) pp2-51, 2-54).
- The display shows the four plane bytes at one address as four neighboring pixels:
  graphics register 5 bit 6 (256-color shift, p2-84), attribute mode bit 6, and the CRTC
  in byte mode (CRTC $17 bit 6 = 1, CRTC $14 bit 6 = 0; address mapping p2-75).
- Oak packed mode stays off (ext $21 bits 3-2 = 00) and so does the 64-bit latch (ext
  $22 bit 4 = 0).

**Why it is faster.** Four neighboring pixels share one address, so a latch copy is a read
and a write at the next address each time, which is exactly what `ldi`, `ldir` and DMA do:

- IBM describes this use: "Data scrolling operations can be enhanced by enabling all maps
  and writing the display buffer address with the data stored in the system data
  latches" (p2-51). In write mode 1 "each memory map is written with the contents of the
  system latches", which "are loaded by a system read operation" (p2-85).
- `ldi` copies 4 pixels in 17 clocks and steps both pointers itself; `ldir` takes 19.
  Oak packed mode needs 24-29 for the same 4 pixels, because its source and destination
  addresses step differently ([the latch](#the-latch-copying-4-pixels-per-access)).
- DMA0 in burst mode moves "each byte ... every 6 clock cycles" plus the waits
  ([UM0050](sources.md#s39), DMA controller): 11 clocks per 4 pixels. Setting up a run
  takes about ten DMA register writes, roughly 150 clocks, so DMA wins for runs longer than
  about 25 groups (100 pixels), such as whole lines and page copies.
- Fills: with all four planes enabled, one write-mode-0 byte sets all four pixels ("the
  system can write its 8-bit value to all four maps in a single memory cycle", p2-51).
  DMA0 with a fixed source byte and a rising destination (UM0050 table 14) fills at 9
  clocks per 4 pixels.
- Transparency: the map mask picks which of the four pixels a write changes, for latch
  writes and plain writes alike. With the sequencer index left at 2, a change is
  `ld a,n` and `out (c),a` to $3C5 (17 clocks). `ldi` counts BC down, so BC is reloaded
  first (9 more).

**Position and pitch.** The start address counts 4-pixel groups, and attribute register
$13 adds a shift of 0-3 pixels (values 0, 2, 4, 6; IBM p2-95, the mode 13h column). In
byte mode each row starts 2 x CRTC $13 addresses (8 x CRTC $13 pixels) after the one before
(p2-71).

**Limits.**

- IBM's 256-color path samples the four planes "twice to produce eight bit-plane values"
  for each pixel (p2-22), so it shows one pixel per two dot clocks: half the width of Oak
  packed mode at the same clock. On the AppleColor RGB monitor's 15-16 kHz lines that is
  still about 320 pixels.
- The 64 KB CPU window reaches 64K addresses, 256 KB of video memory. Ext $23/$24 supply
  CPU address bits 20-16 (databook p42). With chain 4 off the CPU address is the offset
  inside each plane, the same addressing Oak's own 16-color 1024 x 768 modes use, and
  those hold 96 KB per plane (p2). So each segment step moves the window by 64K
  addresses, 256 KB, and four steps reach all 1 MB. The start address, with ext $17,
  reaches all of video memory too.
- The pixel mask (ext $34), color expansion and the 64-bit latch rule are Oak packed-mode
  features. In this mode the map mask does the masking.

**Per 4-pixel group, compared:**

| Job | Oak packed mode | Unchained mode |
|---|---|---|
| Copy, no mask | 24-29 | 17 (`ldi`), 11 (DMA) |
| Copy with a mask change | about 46 | about 43 |
| Fill one color | about 14 (color expansion) | 14 (`ld (hl),a` + `inc hl`), 9 (DMA) |

## The standard VGA graphics controller

The chip "implements all registers and data paths" of the IBM VGA (databook p1). The
graphics controller can combine each written byte with the latch: set/reset and its
enable (registers 0, 1), data rotate and the function (register 3: replace, AND, OR,
XOR), the bit mask (register 8, bits taken from the latch where 0), write modes 0-3, and
read mode 1, which compares pixels with a color (registers 2 and 7). Source:
[IBM](sources.md#s68).

In write mode 0 with the pixel mask off, a write stores one byte at its own address. Under
IBM's rules the logical functions and the bit mask then work one pixel per write: an XOR
sprite, or a write that changes only some bits of each pixel. That second use is what
makes [split-bit layers](#color-tricks) work: with the bit mask set to the sprite's bits,
a write keeps the background's bits from the latch, after one read per 4-pixel group.

With the 64-bit latch and the pixel mask on, the function, the bit mask and set/reset work
on each latch byte as IBM's write path does on its four latches. The chip implements all of
IBM's registers and data paths (databook p1), and the pixel mask turns off only the map
mask and the packed-mode address masking (p43). Oak's linear driver draws XOR this way:
graphics controller $03 = $18, latch and pixel mask on, a read of each 8-byte group before
its write ([87X drivers](sources.md#s69) `LIN8_SC.DRV` $2736-$2773).

## Caches

- **Read cache** (ext $22 bit 2): a read of data already in the cache ends at once,
  which speeds block moves (databook p5).
- **Write cache** (ext $22 bit 3): the chip takes a write's address and data and lets the
  CPU go on, unless the cache is full or the write is in a different cache page
  ([write cache](reference/oti087-registers.md#write-cache)). Ext $03 bit 4 flushes it after
  every write.

The databook gives neither cache's size, which addresses the read cache holds beyond the
next one in a block move, or what empties either cache. The 32-bit DRAM bus lets one read
bring in 4 bytes, but that does not show the cache holds 4. The 64-bit graphics latch is
separate from both caches.

On this card neither cache shortens an access below the waits U15 forces. They save the
Oak's DRAM time: a read-cache hit or a cached write takes 3 waits instead of 5, and more
when the DRAM is busy with display fetch or refresh
([how long IOCHRDY holds an access](05-z180.md#how-long-iochrdy-holds-an-access)).

ROM 1.4's Super Hi-Res renderer sets ext $22 = $1C while it builds its conversion tables,
which it spreads with sequential DMA block copies, then $38 for drawing
([`superhires.asm:88-119`](../firmware/v1.4/src/superhires.asm)). $38 turns the read
cache off and the CPU latch swap (bit 5) on; the 64-bit latch and the write cache stay on.
The table spreading reads addresses in order, the access the read cache is built for
(databook p5). Each drawing read fetches the table entry chosen by the next Super Hi-Res
byte, so the reads follow the picture, not the address order; a repeated byte reads the
same entry again. The swap lines up the latch halves when the table entry and the screen
destination are unaligned; the databook places it on CPU writes (p42). The databook does
not say whether a read-cache hit loads the graphics latches the way a DRAM read does, and
no Oak document requires the read cache off with the swap, the 64-bit latch or write
mode 1. So the register values do not show why the firmware turns the read cache off.

## Display features that cost no drawing

Each of these replaces drawing with one to three register writes per frame.

- [Hardware scrolling](#hardware-scrolling)
- [A playfield bigger than the screen](#a-playfield-bigger-than-the-screen)
- [Horizontal pixel panning](#horizontal-pixel-panning)
- [Split screen](#split-screen)
- [A scrolling ring buffer with no double drawing](#a-scrolling-ring-buffer-with-no-double-drawing)
- [Scrolling sideways through a long playfield](#scrolling-sideways-through-a-long-playfield)
- [Page flipping](#page-flipping)
- [Bands that start anywhere](#bands-that-start-anywhere)
- [Line doubling](#line-doubling)
- [Interlace](#interlace)
- [A free sprite: the hardware cursor](#a-free-sprite-the-hardware-cursor)
- [Frame timing](#frame-timing)

### Hardware scrolling

The start address (CRTC $0C/$0D, bits 18-16 in ext $17 bits 2-0)
picks the first byte shown. In packed 256-color mode it counts 8-byte units: the
third-party XFree86 driver sets it to (y x pitch + x) / 8 (`OAKAdjust`); in unchained mode it
counts 4-pixel groups. Three register writes scroll the whole screen vertically by any
number of lines, or horizontally in 8- or 4-pixel steps.

The display address has no 64K limit: it counts on past bit 15, from one row to the next
and inside a row. Oak's 16-color modes 56h (1024 x 768) and 58h (1280 x 1024 interlaced)
(databook p2) use byte mode with CRTC $13 = $40 and $50 ([TEv1.02](sources.md#s58) mode
tables at file offsets $16B2 and $17F2), so their rows are 128 and 160 addresses long. A
frame from address 0 then needs 96K or 160K addresses in each plane, and row 409 of the
1280 mode runs from address 65,440 to 65,599.

The shown page stays inside $00000-$FFFFF: the chip strobes the second megabyte with RASHn
(pin 125, databook p22), which is open on this card
([netlist](../data/netlist/netlist.csv) U28.125), so display addresses from $100000 show
no memory and do not wrap to $00000.

### A playfield bigger than the screen

The line pitch is CRTC $13 x 16 bytes in packed mode ([packed-pixel
mode](06-video.md#packed-pixel-mode-and-the-crtc)) and CRTC $13 x 8 pixels in unchained
mode, independent of the shown width. A wide or tall playfield is drawn once and panned.

### Horizontal pixel panning

Attribute register $13 shifts the picture by single pixels within the start address's step
([IBM](sources.md#s68)). Oak packed mode is an 8-dot mode (attribute $10 bit 6 = 0), so
the value is the shift: to show the picture from pixel X, write start address X / 8 and
attribute $13 = X mod 8 (IBM p2-95, the 8-dot column).

Oak's BIOS sets attribute $10 = $01 and $13 = 0 in all its packed
256-color modes, and $13 = 8 only in its 9-dot text modes ([TEv1.02](sources.md#s58)
mode tables, file offsets $1472-$1BB1, $0C32 and $1032-$10F1).

Oak's VESA extension writes the 9-dot encoding in every mode, 8 when X mod 8 is 0 and
otherwise (X mod 8) - 1 ([87X DOS kit](sources.md#s79) `OTIVBE.COM` $3A5-$3EC), so in
packed mode it shows the picture from pixel X - 1 whenever X mod 8 is 1-7.

IBM latches only the start address, at the start of vertical retrace
([Page flipping](#page-flipping)), and describes no latch for attribute $13 (p2-95). So
write the start address during the active display, then attribute $13 right after vertical
sync starts, as Abrash's page-flip code does: "Set horizontal panning now, just as new
start address takes effect" ([Abrash](sources.md#s134), Listing 23.1). A delay before the
$13 write leaves the start address and the pan mismatched.

### Split screen

CRTC $18 (line compare, bit 8 in CRTC $07 bit 4, bit 9 in CRTC $09
bit 6) restarts the display at address 0 below a chosen line: a fixed status bar under
a scrolling playfield. The fixed part can only be at the bottom: rows above the line follow
the start address, and rows below it always start at address 0. Attribute $10 bit 5 keeps
the bar out of the pixel panning ([IBM](sources.md#s68) pp2-77, 2-92, 2-103).

### A scrolling ring buffer with no double drawing

The lower part of a split always starts at address 0, and IBM notes it "can be smoothly
scrolled onto the display by updating the Line Compare register" (p2-103). A playfield
buffer that starts at address 0 can therefore wrap: the top of the screen shows the buffer
from the start address down to its end, and line compare, moved each frame, continues it
from address 0. Only a buffer at address 0 can wrap this way, so this suits one shown
buffer, not two pages.

### Scrolling sideways through a long playfield

A playfield too wide to store whole still scrolls with one new column drawn per step. The
display address never wraps ([Hardware scrolling](#hardware-scrolling)), so the layout
moves forward through memory instead:

- Store column X of row r at base + r x P + X. A column is one start-address step (4
  pixels in unchained mode, 8 in packed mode), and P is the row pitch in columns
  (2 x CRTC $13).
- Show the playfield from column X0 with start address base + X0. Each step adds or
  subtracts 1 and draws the one new column in every row.
- Make P at least W + 2, where W is the screen width in columns: a nonzero pan shows one
  more column, and the new column is drawn before the start address moves. Each row's new
  column then overwrites only columns of the rows above and below that are off the screen.
- Memory used is rows x P plus the distance scrolled right, not rows x the playfield
  width. It must stay inside the 1 MB.

### Page flipping

"The CRT controller latches the start address at the start of the
vertical retrace. These register values should be loaded during the active display
time" (IBM p2-67). So write the new page's start address while the old page is still
showing, then wait for the vertical retrace ($3DA bit 3) before drawing into the old
page.

### Bands that start anywhere

"Each subsequent row address is determined by the 16-bit addition of the start-of-line
latch and the Offset register" (IBM p2-103). IBM's VGA has 64 KB per plane; on the Oak the
addition carries past bit 15 ([Hardware scrolling](#hardware-scrolling)). A new CRTC $13
written between two rows, timed from PRT1, moves where the following rows start: bands of
the screen taken from different parts of memory, or, with $13 = 0, one row shown again and
again.

### Line doubling

CRTC $09 bit 7 shows every line twice: half the drawing for the same
screen height.

### Interlace

Ext $14 bit 7, odd-field sync in ext $15: twice the lines on a 15 kHz
monitor ([Building a mode](14-custom-code.md#building-a-mode)).

### A free sprite: the hardware cursor

64 x 64, 2 colors plus transparent and invert, positioned anywhere by ext $40-$43, over
the picture, at no drawing cost. Its pattern can sit at any 8-byte boundary in video
memory (ext $47-$49), so animation frames switch with three register writes. It is the
chip's only hardware sprite. The databook calls ext $4A/$4B "sprite color 0" and "sprite
color 1" ([hardware cursor](06-video.md#hardware-cursor)).

### Frame timing

The retrace interrupt needs a pull-up the stock card lacks; PRT0 can
stand in, and PRT1 can fire at any line
([retrace interrupt on a stock card](14-custom-code.md#interrupts)).

## Color tricks

- **No overlay plane.** The Bt481's overlay inputs OL0-OL3 are tied to ground
  ([netlist](../data/netlist/README.md)).

- **No known way to mix in outside pixels.** J3 is a 2 x 13 header the manual calls a VGA
  feature connector, but its wiring is not drawn
  ([board connections](reference/board-connections.md)), and the OTI-087X addendum drops
  the chip's integrated feature connector support (databook addendum).

- **Split-bit layers.** Give the background some bits of each pixel and the sprites the
  rest, and fill the palette so any nonzero sprite bits win. Sprites then draw and erase
  with the bit mask without touching the background. The cost is colors: 4 + 4 bits gives
  16 background and 15 sprite colors. The Bt481's pixel mask ($3C6) hides a whole layer
  at once.

- **More than 256 colors.** Palette writes ($3C8 index, then three $3C9 writes) between
  lines change colors down the screen. A 15.7 kHz line is about 1,146 Z180 clocks, room
  for about 25 entries per line at 44 clocks each, timed from PRT1.

- **Hi-color.** Ext $21 bit 0 with a 15- or 16-bit Bt481 mode shows 32K or 64K colors with
  no palette. Each pixel is two bytes, so it costs the Z180 twice as much.

## Cost table

Z180 clocks at 18 MHz for 256 colors, from the access table above. "Unchained" and
"packed" are the two 256-color layouts: [unchained](#unchained-256-color-mode-copies-with-ldi-and-dma)
and Oak packed mode.

| Job | Method | Clocks per pixel |
|---|---|---|
| Scroll the screen | Start address | 3 register writes per frame |
| Copy a rectangle in video memory | Unchained: `ldi`, or DMA for long runs | about 4.3, or 2.75 |
| Copy a rectangle in video memory | Packed: latch copy | about 6 (one pointer) to 7.3 (two) |
| Transparent sprite, full 4-pixel groups | Unchained: `ldi` | about 4.3 |
| Transparent sprite, partial groups | Unchained: map mask change, then `ldi` | about 11 |
| Transparent sprite | Packed: masked latch copy | about 7.3 to 11.5 |
| Transparent sprite, scattered pixels | Packed: compiled `ld (hl),n` stores | about 16 per opaque pixel |
| Solid fill or clear | Unchained: DMA from one fixed byte | 2.25 |
| Solid fill or clear | Packed: color expansion | about 3.5 |
| Patterned fill, 8 colors | Packed: latch-register fill | about 4 |
| Text, one-color shapes | Packed: color expansion with the mask; unchained: the glyph's bits as the map mask | about 4, plus mask changes |
| Copy from SRAM | DMA0 burst | 9 |
| Copy from SRAM | `ldir` | 17 |

## Example: a vertical scrolling shooter

A 224 x 256 playfield, 256 colors, on the AppleColor RGB monitor
([line counts](14-custom-code.md#modes-beyond-the-firmwares-tables)), in unchained mode:
56 four-pixel groups per line, 14,336 per screen.

1. Two pages, each 512 lines tall. Each frame, copy the new background line from tile
   graphics kept in video memory twice, at y and y + 256, so the 256 lines shown are
   always one unbroken block (2 x 56 `ldi`, about 2,200 clocks with the tile steps).
   Scroll with the start address, written while the old page still shows.
2. A clean copy of the background in the same layout. Before drawing a page, restore the
   background under its old sprites with `ldi` from the clean copy. The three buffers
   take 86,016 addresses, 344 KB, spread over two 64K-address segments.
3. Sprites as compiled copies from 4 shifted copies each: `ldi` for full groups, a map
   mask change for partial ones.
4. Score and text: the glyph's bits as the map mask, one byte write per 4 pixels.

A 16 x 16 sprite at any x spans 80 groups. With 48 full and 32 partial groups it costs
about 2,400 clocks to draw and 1,600 to restore, about 4,000 in all: a 301,800-clock frame
has room for about 75 with nothing else running. The same sprite in Oak packed mode costs
about 5,300 to 5,700 (about 55 per frame).

---

[Reference index](../README.md) | [Beyond the firmware](14-custom-code.md) | [Video](06-video.md)
