# 14 Beyond the firmware: what custom code can use

[Reference index](../README.md) | [Glossary](glossary.md) | [Reference tables](reference/README.md)

The hardware ROM 1.4 leaves unused, and how to reach it: from Z180 code started with
RunCode ([Loading Z180 code](09-host-protocol.md#loading-z180-code)), or from IIgs code
through the stock host commands.

## Contents

- [Z180 resources](#z180-resources)
  - [Clock](#clock), [memory](#memory), [DMA](#dma) and [timers](#timers)
  - [Interrupts](#interrupts), [retrace timing](#a-retrace-interrupt-on-a-stock-card) and [beam position](#where-the-cards-beam-is)
  - [Serial ports](#serial-ports)
- [Video resources](#video-resources)
  - [Modes](#modes-beyond-the-firmwares-tables), [building a mode](#building-a-mode) and [24-bit width](#24-bit-mode-width)
  - [Drawing with the Oak](#drawing-with-the-oti-087x) and [Bt481](#bt481-features-the-firmware-does-not-use)
  - [Matching the IIgs frame](#matching-the-iigs-frame) and [per-line palette effects](#per-line-palette-effects)
- [Apple-side resources](#apple-side-resources)
  - [Protocol](#your-own-command-protocol) and [bulk data](#moving-bulk-data)
  - [Events](#watching-the-apple), [IRQ](#interrupting-the-iigs) and [limits](#what-the-iigs-cannot-do)
- [Reaching the card from the IIgs](#reaching-the-card-from-the-iigs)
  - [What the commands reach](#what-the-stock-commands-reach) and [writing SRAM](#writing-card-sram-from-the-iigs)
- [Storage: the serial EEPROM](#storage-the-serial-eeprom)
- [Wiring rules for custom code](#wiring-rules-for-custom-code)

## Z180 resources

### Clock

CCR port $1F bit 7 switches the 36 MHz input from /2 (18 MHz, the reset value) to /1
(36 MHz). That is the only faster setting with the fitted oscillator: CMR port $1E bit 7
multiplies only 10-16 MHz inputs, into 20-32 MHz. Sources: Z8S180 PS0140, CMR/CCR;
[UM0050](sources.md#s39).

```
36.000 MHz oscillator -> Z8S180 EXTAL -> CCR /2 or /1 -> PHI (pin 68)
                                                        | 18 or 36 MHz
                                                        +-> CPU bus, DMA, ASCI, timers
                                                        +-> R1 -> HCLK -> U15, U17
14.31818 MHz X2 -> OTI-068 -> VCLK (16 choices) -> OTI-087X, U8/U12 -> Bt481
                          -> MCLK (40 MHz straps) -> OTI-087X video memory
Apple slot clocks -> Lattice Y0, Y2 (7M) and CPU (PHASE 0) inputs
```

The prototype also had places for X1, a 20 MHz crystal, and R38 from MCLK; production
fits neither. Sources: [netlist](../data/netlist/README.md), [production photo](sources.md#s20).
The Apple clocks: [Lattice clocks](04-capture-logic.md#clocks-and-phase).

36 MHz is 80 percent above the Z8S18020 rating on s20/s108/s109 and 125 percent above
the Z8S18016 rating on [s128](sources.md#s128). It is also above the fastest 33 MHz grade
([PS0140](sources.md#s62) Table 8: minimum clock periods 50 ns and 30 ns; 36 MHz is
27.8 ns), so the CPU is not specified to run at it. Even if it runs, **36 MHz cannot run
the board's video path reliably**: no wait states repair the VGA address-setup limit
([timing at 18 and 36 MHz](reference/clocks.md#timing-at-18-and-36-mhz),
[wait states](05-z180.md#wait-states)). The pixel and video-memory clocks, U12's RGB
divider and the Apple-side clocks do not change with CCR.

### Memory

Which SRAM is free, and when: the
[SRAM ownership map](reference/z180-memory-map.md#sram-ownership). Two separate switches
decide it: SetShadow 4 stops the copy of the Apple's video writes, and SetMode with flag
1 stops the firmware's emulation of the Apple screen. All of bank 1 is free only with
both off. RunCode's [MMU settings](reference/host-commands.md#runcode) keep the command handler
mapped while custom code runs. The EPROM overlay and the video controls are in the
[physical memory map](reference/z180-memory-map.md#memory-map).

### DMA

- **Channel 0** is free whenever the firmware is not using it: memory to memory, or memory
  to I/O. In burst mode it copies SRAM to video memory at bus speed.
- **Channel 1** has its request line (DREQ1) wired to the Apple event signal (INT1), so it
  can stream bytes to or from the IIgs ([Host protocol](09-host-protocol.md)). Source:
  [netlist](../data/netlist/README.md).

### Timers

- Two 16-bit programmable reload timers, PRT0 and PRT1, with interrupts. They count the
  Z180 clock divided by 20, 1.11 us per step at 18 MHz, and reload from a 16-bit value, so
  one period lasts up to 65,536 steps (72.8 ms). Sources: [Zilog UM0050](sources.md#s39)
  PRT chapter; [HD64180 User's Manual](sources.md#s80) pp84-87 (TMDR, RLDR, reset values,
  interrupt flag).
- Use them for interrupts only. Their output pin TOUT is also address pin A18, which this
  board needs: turning TOUT on breaks memory above 256 KB. Sources: [UM0050](sources.md#s39),
  [netlist](../data/netlist/README.md).
- PRT1's output flip-flop flips at every PRT1 timeout, even while TCR bits TOC1-TOC0 = 00
  keep the pin on A18. Selecting TOUT shows it: high after an even number of timeouts
  since reset (none counts as even), low after an odd number. From then on, toggle mode
  (01) flips it at each timeout, and forced 0 (10) or forced 1 (11) sets it at the next
  timeout, not when TCR is written. Source: [HD64180 User's Manual](sources.md#s80) p88,
  "PRT Operation Notes"; UM0050 p165 gives the same rule without its table.

### Interrupts

The Z180's interrupt inputs on this card:
[Z180 interrupt inputs](reference/z180-io-ports.md#z180-interrupt-inputs).

- **INT1:** the Lattice's Apple event signal, used by the firmware's event handler.
- **INT0, the Oak's vertical-retrace interrupt:** not usable on a stock card. The line has
  no pull-up resistor; adding one makes it work
  ([INT0 has no pull-up](reference/board-connections.md#int0-has-no-pull-up)).
- **INT2 and NMI:** not usable. INT2 has no connection on the drawing; R15 holds NMI
  inactive and nothing drives it.
- **Inside the Z180:** PRT0, PRT1, the end of a transfer on either DMA channel, the clocked
  serial port (CSI/O) and the two serial ports (ASCI0, ASCI1). Their vectors follow INT1
  and INT2 in the firmware's vector table at $0C00 (I = $0C): PRT0 $0C04, PRT1 $0C06,
  DMA0 $0C08, DMA1 $0C0A, CSI/O $0C0C, ASCI0 $0C0E, ASCI1 $0C10. ROM 1.4 leaves them zero,
  and the table is in SRAM, so code writes its handler's address there. Source:
  [ROM_BEEF.asm](sources.md#s27) `interrupt_vector_table`, `set_interrupt_vector`.

#### A retrace interrupt on a stock card

The frame length is fixed by the mode, so PRT0 can stand in for the missing retrace
interrupt:

1. With PRT0 stopped, load both of its registers. The counter (TMDR0) gets the frame
   length in timer steps minus a small lead; it starts at $FFFF after reset, so it must be
   written. The reload register (RLDR0) gets one frame: the counter steps down to 0 and
   then reloads, so a reload value of N gives a period of N + 1 steps. The 69.4 Hz Super
   Hi-Res mode's frame lasts 14.41 ms, about 12,970 steps.
2. Poll $3DA bit 3 for the start of a vertical retrace and start PRT0 at that moment, with
   its interrupt on (TCR bits 0 and 4). The first interrupt comes the lead ahead of the
   next retrace, and each later one a full frame after the one before.
3. The handler clears the interrupt flag (it reads TCR, then TMDR0), polls bit 3 for the
   few microseconds until it sets, then does its frame work. When that wait grows or
   shrinks from frame to frame, it moves the reload value by one step, so the period
   follows the Oak's clock.

This costs a few microseconds of polling per frame. PRT1, started from the same retrace,
can fire at any chosen line, for split-screen or palette effects.

#### Where the card's beam is

For tear-free cursor moves, page flips or palette changes:

- **Polling:** Input Status 1 at $3DA (the color address the firmware's modes select)
  reads bit 3 = 1 during vertical retrace and bit 0 = 1 whenever the display is blanked.
  Reading it also resets the attribute-controller flip-flop, as on any VGA.
- **Interrupt, with the INT0 pull-up added:** the Oak's retrace interrupt (CINT) drives
  INT0; CRTC $11 bit 5 = 0 enables it, and writing bit 4 = 0 then 1 clears it.
- **The current line:** no register is known to return it. The OTI-087X's register
  definitions and IBM's VGA reference describe none, and no Oak BIOS or driver code reads
  one: they wait on $3DA bits 0 and 3 only ([87X drivers](sources.md#s69),
  [87X DOS kit](sources.md#s79), [TEv1.02 BIOS](sources.md#s58)). Some VGA clones return the
  moving display address in CRTC $10/$11 while CRTC $03 bit 7 is 0, the EGA light-pen
  readback. On a real OTI-087X card, a 2023 test that clears that bit and reads CRTC $11 64
  times found 16 or fewer different values ([VOGONS report](sources.md#s122);
  [test program](sources.md#s123) `RNG.CPP`, `init_rng`).
- **Finding the line by timing:** wait for the vertical retrace, then count the bit-0
  blanking pulses ("monitor the VGA status counting the lines as you go",
  [PC Underground](sources.md#s124)), or start a PRT timer at the retrace and divide by the
  mode's line time. CRTC $18 (line compare) splits the screen at a chosen line, as on any
  VGA. The test modes of ext $03: [register reference](reference/oti087-registers.md#reg-03).
- Write the hardware-cursor position (ext $40-$43) during vertical retrace, so the cursor
  never shows half in the old place.

Sources: [OTI-087 databook](sources.md#s02) pin 90 (CINTn); [IBM VGA Technical Reference](sources.md#s68),
Input Status 1 and CRTC $11, the standard registers the OTI-087X copies.

### Serial ports

The Z180's two serial channels (ASCI0, ASCI1) and its clocked serial port (CSI/O) are on
the chip; the firmware writes trace characters to ASCI0. The drawing connects their pins
to nothing ([connections the drawing leaves out](reference/board-connections.md#connections-the-drawing-leaves-out)).
Source: [netlist](../data/netlist/README.md).

## Video resources

### Modes beyond the firmware's tables

The firmware's mode tables are not a limit. Z180 code started with RunCode, or the IIgs
alone through SetVGAReg ([the stock commands](#what-the-stock-commands-reach)),
writes every register of the Oak, the OTI-068 clock select and the Bt481. So any timing
those chips allow is available without firmware support; SetUserMode is just one way to
deliver the same register values. Turn Apple emulation off first (SetMode with flag 1).
In ROM 1.4 an Apple display switch can still reprogram the mode
([E29](reference/errata.md#e29-apple-display-switches-reset-a-native-vga-mode)).

What limits a mode is the hardware and the monitor:

- **Pixel clock:** 16 [OTI-068 frequencies](reference/clocks.md#frequency-table), up to
  78 MHz.
- **Memory:** 1 MB of video RAM. The board's straps fix the memory clock at 40 MHz, which
  limits how fast the CPU reaches video memory in the busiest modes
  ([Video: ext $20](06-video.md#extended-registers-the-firmware-uses)).
- **AppleColor RGB monitor:** it scans at about 15.7 kHz, so a 60 Hz field has about 262
  lines. With the usual 20 or so lines for vertical retrace, about 240 show. Interlace
  (ext $14 bit 7) alternates two such fields, for about 480 lines at 30 frames per second.
  ROM 1.4's RGB mode $61 is already 640 x 400 interlaced.
  - Apple's specification: 15.734 kHz lines at 60 Hz, 15.659 kHz at 50 Hz; negative
    composite sync, 4.0 +/- 1.0 V; video flat to 6.5 MHz, 3 dB down at 8 MHz; vertical
    size, vertical hold and horizontal hold on the back panel
    ([TIL01930](sources.md#s110)).
  - Owners drive it with 240p and 480i at 60 Hz and with 50 Hz PAL timing (which needs the
    vertical size and hold adjusted). It shows nothing at 31 kHz. Shifting the picture far
    right with the horizontal control makes it lose sync and whine on mode changes
    ([2026 adapter guide](sources.md#s111)).
  - The firmware's own RGB modes, used by every owner of this monitor, run at 15.58-16.54
    kHz and 60-70 Hz ([AppleColor RGB records](reference/video-modes.md#built-in-applecolor-rgb-records)).
- **VGA monitor:** a fixed 31.5 kHz monitor shows 480 lines. An SVGA monitor also takes
  600 (Sequential's `M800X600.36M`) and 768: 1024 x 768 x 256 colors fits in 786,432
  bytes, and the OTI-068 has the 65 MHz (60 Hz) and 44.9 MHz (87 Hz interlaced) clocks.

More combinations: [additional modes](reference/video-modes.md#additional-modes).

### Building a mode

A mode is a set of register values, written directly by Z180 code or SetVGAReg, or sent
as the 81-byte record SetUserMode takes
([record layout](reference/host-commands.md#setusermode)). The standard VGA registers
keep their IBM meanings; the Oak's extended registers are in the
[Oak register reference](reference/oti087-registers.md). A mode is
five choices:

1. **Connector.** Feature byte bit 0 = 0 selects the VGA connector: separate HSYNC and
   VSYNC, and the Oak gets the selected clock as it is. Bit 0 = 1 selects the AppleColor
   RGB connector: U12's composite sync, and the Oak gets half the clock.
2. **Pixel clock.** Ext $06 bits 3-0 pick one of the 16
   [OTI-068 frequencies](reference/clocks.md#frequency-table). The misc output byte
   repeats the low two bits in its bits 3-2, so the two must agree. When they disagree,
   ROM 1.4 uses the misc byte's bits, which it writes last; firmware 1.5 and 2.0 use ext
   $06's ([E16](firmware-fixes.md#e16-library-mode-files-run-at-the-wrong-clock)).
3. **Dot clock.** Sequencer register 1 bit 3 halves the clock, and bit 0 picks 8- or 9-dot
   characters. Ext $21 bit 0 (hi-color) or bit 1 (true color) spends 2 or 3 clocks on each
   pixel.
4. **Counts.** Line rate = dot clock / horizontal total. The horizontal total is
   (CRTC $00 + 5) characters and (CRTC $01 + 1) of them are shown; CRTC $02-$05 place the
   blanking and the sync pulse. Frame rate = line rate / vertical total. The vertical total
   is CRTC $06 + 2 lines, with bits 8 and 9 in CRTC $07 and bit 10 in ext $14 bit 0;
   (CRTC $12 + 1) lines are shown; CRTC $10/$11 place the vertical sync and $15/$16 the
   vertical blanking; CRTC $09 bit 7 shows every line twice. Ext $14 bit 7 turns on
   interlace, and ext $15 sets the odd field's vertical sync; ROM 1.4's AppleColor RGB mode
   $61 uses it for 640 x 400 ([video modes](reference/video-modes.md#built-in-mode-codes)).
   Misc output bits 6 and 7 set
   the HSYNC and VSYNC polarity (1 = negative); the RGB connector's composite sync needs
   both negative.
5. **Pixels in memory.** Ext $21 bits 3-2 = 01 selects packed pixels, one byte per pixel
   for 256 colors. Adding ext $21 bit 0 and a 15- or 16-bit Bt481 mode (feature byte bits
   7-4 become Command Register A) gives 32K or 64K colors at two bytes per pixel. In packed
   modes the line pitch is CRTC $13 x 16 bytes. Changing ext $06 or ext $21 needs a
   sequencer reset ([register behavior](reference/oti087-registers.md#register-behavior)).

Sources: [IBM VGA Technical Reference](sources.md#s68) for the standard registers;
[OTI-087 databook](sources.md#s02) pp35-41; [Bt481A datasheet](sources.md#s36).

#### Example: a PAL monitor

The RGB connector can drive a 50 Hz PAL RGB monitor or the RGB
input of a SCART television:

- Clock code $C, 63 MHz, halved by U12 and again by the sequencer: 15.75 MHz dots, the
  same clocking as the firmware's 640-wide RGB modes.
- 126 characters per line (CRTC $00 = $79): 1,008 dots, 64.0 us, 15.625 kHz. 80
  characters shown (CRTC $01 = $4F): 640 pixels. The 4.7 us sync pulse is about 9
  characters.
- 312 lines per frame (CRTC $06 = $36 with CRTC $07 bit 0 set): 50.08 Hz. 256 lines shown
  (CRTC $12 = $FF), 640 x 256 in all.
- 625-line interlace instead: ext $14 bit 7 on, with ext $15 placing the odd field's sync.
- PAL RGB inputs expect black at 0 V, which JP3 fitted gives (no 7.5 IRE pedestal). U12's
  composite sync has no serration pulses; PAL RGB monitors generally accept that.

The card cannot produce PAL composite or S-video: the Bt481 outputs only RGB, and the card
has no color encoder.

### 24-bit mode width

`M640X48016M` selects 78 MHz and ext $21 = $06 (x3 timing) but leaves the Bt481 in 8-bit
palette mode, so it cannot show 24-bit color as written. It also sets CRTC $01
(horizontal display end) to $4E: 79 character positions, 632 pixels. The standard
640-pixel value is $4F, which the file's blanking start $50 already follows; the library's
32K-color files use the matching full-width value, $9F for 1,280 byte clocks.

**Bt481 Command Register A = $F0 and CRTC $01 = $4F** give a 640 x 480, 24-bit mode; the
record's clock and total counts give 60.1 Hz
([true-color horizontal timing](reference/video-modes.md#true-color-horizontal-timing)).
Writing them from the host:
[E17](reference/errata.md#e17-the-true-color-mode-file-shows-palette-colors).

### Drawing with the OTI-087X

Every drawing and display assist the Oak has, how each behaves on this card's 8-bit bus,
and what it costs: latch copies, the pixel mask, color expansion, latch-register fills,
the VGA graphics controller, the caches, hardware scrolling, split screen, page flipping,
the hardware cursor and palette tricks
([Drawing with the OTI-087X](15-oak-drawing.md)).

### Bt481 features the firmware does not use

Color modes, Command Register B and the overlay registers:
[Bt481 controls](reference/bt481-modes.md). The overlay inputs OL0-OL3 are grounded, so no
pixel can select an overlay color; the overlay registers can still be read and written.
Source: [netlist](../data/netlist/README.md).

### Matching the IIgs frame

The card's frame rate is set by its mode, not by the IIgs. Custom code can lock the two
frames together:

1. **Run at the IIgs rate.** A mode record sets the pixel clock (one of the 16 OTI-068
   frequencies, from ext $06 and misc output) and the CRTC horizontal and vertical totals,
   so a mode can run at about 60 Hz instead of Super Hi-Res's 70 Hz. The firmware's
   640 x 480 mode $53 already runs at 59.9 Hz; a record with that timing and doubled lines
   shows 200 IIgs lines in 400 of its 480. Write it from Z180 code, or send it with
   SetUserMode.
2. **Get a reference from the IIgs.** The card cannot see the IIgs beam, so the IIgs must
   say when its frame starts: a IIgs routine waits for vertical blank (the VBL interrupt,
   or bit 7 of $C019) and then reads or writes a card register in $C0B0-$C0B7. Every such
   access is an event, so Z180 code gets INT1 at that moment and stamps it with a PRT
   timer. A IIgs vertical-blank interrupt task does this every frame, even under programs
   that know nothing of the card, as long as they leave interrupts on; a program that
   turns interrupts off must make the access itself.
3. **Measure the card's own frame.** The retrace bit ($3DA bit 3) marks the start of the
   card's frame (or INT0, with the pull-up added).
4. **Pull the frames together.** The aim is for each picture's first visible line to start
   at the same moment. The IIgs's vertical blank and the card's vertical retrace each come
   a different, fixed time before their picture's first line, so the code aims at the
   offset those two times give. When the card's frame comes too early or too late, Z180
   code makes one card frame a few lines longer or shorter (CRTC $06 vertical total, with
   its overflow bits in $07). CRTC $00-$07 are write-protected while CRTC $11 bit 7 is set,
   and modes $53 and $FE leave it set ($8C and $81 in their records), so the code clears
   bit 7 first and restores it after. It keeps correcting every few frames, because the
   IIgs crystal and the card's 14.318 MHz crystal (X2) differ slightly.

The lines match closely too. An IIgs line is 65 slow-bus cycles, 912 periods of 14.318
MHz, about 63.7 us; two lines of mode $53 (800 dots at 25.175 MHz each) take 63.56 us. The
card's beam gains about 0.14 us per IIgs line, about 28 us over the 200 picture lines,
less than one card line. Sources: [Apple IIgs Hardware Reference](sources.md#s78) video
timing; [IBM VGA Technical Reference](sources.md#s68) CRTC $11; ROM mode records.

#### Per-line palette effects

With the frames locked, Z180 code can change Bt481 palette entries in step with the IIgs
program's own palette changes, for per-line palette effects.

Only the horizontal blank is free for this: a color changed while a line is drawn changes
part way along it. In mode $53 the blank is at most 160 of the 800 dots, 6.36 us or about
114 Z180 clocks, twice per IIgs line.

One color takes about 90 clocks: selecting the entry at $3C8 and switching to
$3C9 (about 25 clocks), then three DAC writes of about 21 clocks each (`LD A,(HL)` 6,
`INC L` 4, `OUT (C),A` 10, one I/O wait). So one color fits in each blank, two per IIgs
line, less the few clocks each copied IIgs write takes from the Z180's bus. That is
enough for one or two colors per line, such as moving color bars.

All 16 colors on every line, a full 3200-color display, needs about 1,000 clocks of DAC
writes per line (one entry selection, then 48 writes) against about 228 clocks of blank,
so it does not fit. Sources: [Zilog UM0050](sources.md#s39) instruction table; [OTI-087
databook](sources.md#s02) CRTC and interrupt registers.

## Apple-side resources

### Your own command protocol

- Every read or write of **$C0B0-$C0B7** interrupts the Z180, which reads which of the
  eight addresses it was (ports $A6/$A7). A write also delivers its data byte (port $A0).
  The Z180 cannot tell a read from a write: the Lattice keeps only the address.
- Reads of **$C0B8-$C0BF** return the Z180's output byte without raising an event, for
  status polling.
- The **RDY stall** holds the 65816 on the next event until the Z180 acknowledges the last
  one, so the IIgs can write as fast as it likes without losing bytes.
- [Second.Sight.Info.txt](sources.md#s40) quotes about 1 MB per second from the IIgs to the
  card. That is the slot's own limit: back-to-back slow cycles take about 980 ns
  ([Apple TN #68](sources.md#s43)).

### Moving bulk data

Three ways carry data in, one carries it out:

| Path | Direction | Z180 work per byte | IIgs work per byte | Flow control |
|---|---|---|---|---|
| [Screen copy](#in-through-the-screen-copy) | In, to fixed SRAM windows | None: U17 borrows the bus for one write | An ordinary write to screen memory | None. The Z180 must keep its bus cycles short |
| [Event bytes with DMA1](#in-through-event-bytes-and-dma1) | In, to any SRAM | One DMA1 transfer, 7 clocks of bus time | A write to $C0B0-$C0B7 | RDY holds the IIgs until the byte is taken |
| UploadData | In | DMA1, with the firmware waiting inside INT1 | Command phases, then writes | RDY. The firmware's main loop is stopped for the whole upload ([UploadData](reference/host-commands.md#uploaddata)) |
| [U3 with DMA1](#out-through-u3-and-dma1) | Out | One DMA1 transfer, 7 clocks of bus time | A read of $C0B0-$C0B7 and a store | RDY holds the IIgs until the next byte is loaded |

The screen copy is the only path that needs neither Z180 code nor DMA for each byte, and
the only one where the IIgs never waits for the card. The card cannot write IIgs memory
itself ([What the IIgs cannot do](#what-the-iigs-cannot-do)), so every byte out costs the
IIgs a read.

#### The Z180 as a coprocessor

For work on chunks of data in SRAM (decoding, decompressing,
transforming, computing) that does not draw, the screen copy is the way in. The IIgs writes
each chunk at full slot speed and never waits; the Z180 runs no code to receive it and
keeps computing on the previous chunk, losing only the bus cycle each copy borrows. The
screen copy's one rule, no Oak access while a block arrives, costs such a program nothing.

Results go back through [U3 with DMA1](#out-through-u3-and-dma1), again with no Z180 code
per byte. The [block protocol](#a-block-protocol) below runs this with two buffers.

At 18 MHz, a DMA1 transfer between SRAM and port $A0 is a 3-clock memory cycle plus a
4-clock I/O cycle: 0.39 us of bus time, with no code. Sources: [UM0050](sources.md#s39) DMA
and bus cycle timing; [`commands.asm`](../firmware/v1.4/src/commands.asm) GetStatus and
UploadData, which use DMA1 this way.

#### In through the screen copy

With copying on, U7 and U17 write every qualifying IIgs write into card SRAM at the same
16-bit address ([Copying video writes](04-capture-logic.md#copying-video-writes)). With
RAMWRT and 80STORE off, the windows are:

| IIgs writes to | Lands in SRAM | Size |
|---|---|---|
| $E0/0400-0BFF | $00400-$00BFF | 2 KB |
| $E0/2000-5FFF | $02000-$05FFF | 16 KB |
| $E1/0400-0BFF | $10400-$10BFF | 2 KB |
| $E1/2000-9FFF | $12000-$19FFF | 32 KB |

Writes to $E0/6000-9FFF are not copied, and nothing outside these ranges is. The bank 1
window $12000-$19FFF (the IIgs Super Hi-Res buffer) is the useful one: in bank 0 the
firmware's own code and data sit around the small windows. Writes through banks $00/$01
count only when the IIgs shadows them to $E0/$E1 (shadow register $C035): a shadowed
write still makes one slow cycle on the slot. Sources: [Apple IIgs Hardware
Reference](sources.md#s78) pp19-21; [Apple TN #68](sources.md#s43).

Set the card and the IIgs up as follows:

- **Card:** Apple emulation off (SetMode with flag 1), so the firmware does not draw the
  windows; copying on (SetShadow 0). The two switches are separate
  ([Memory](#memory)).
- **IIgs:** 80STORE off for the whole transfer: with it on, U7 can copy $4000-$9FFF into
  bank 0, over the firmware
  ([E28](reference/errata.md#e28-with-80store-on-u7-picks-the-copys-bank-without-looking-at-the-address)).
  Direct $E1 writes need RAMWRT off: with it on they land in bank 0 and $6000-$9FFF is
  lost ([E14](reference/errata.md#e14-direct-e1-writes-with-ramwrt-on-are-not-copied-above-6000)).
  Bank $00 writes that RAMWRT sends to bank $01 are copied into bank 1 correctly; that is
  how stack writes reach the window. Do not mix the two methods in one block.
- These are real IIgs memory writes: they change the IIgs's own Super Hi-Res buffer, so
  the IIgs must not be showing it.

**The timing rule.** U2, U5 and U6 hold one copy at a time, and a copy does not stall the
IIgs. The next copied write can come about 980 ns later, and the two bytes of a 16-bit
store always do. A copy starts only when the Z180 ends its current bus cycle, waits
included, and an access to the Oak (video memory or a VGA register, by the CPU or by DMA)
can stretch that cycle while the Oak holds IOCHRDY
([Copy timing budget](07-glue-logic.md#copy-timing-budget)). A later write then
replaces the earlier one before it is copied.

So **while the IIgs is writing a block, the Z180 and its DMA make no Oak access**. Work in
SRAM runs normally: the copy only borrows the bus. A coprocessor program that never
touches the Oak meets this rule all the time, so the IIgs can send block after block
without waiting.

Keep other events away during a block. A captured write that RDY holds behind a pending
event is copied with the event's byte until the write completes
([RDY](04-capture-logic.md#rdy-no-lost-events)), so SRAM is right only at the end.

#### In through event bytes and DMA1

When the Z180 must keep drawing during a transfer, use events instead: inhibit the copy
(SetShadow 4), point DMA1 from port $A0 to SRAM for N bytes, and have the IIgs write the N
bytes to $C0B1. A 16-bit store writes $C0B1 and $C0B2, two bytes. RDY holds the IIgs
whenever DMA1 has not taken the previous byte, so nothing is lost, and the Z180 runs
between transfers, Oak work included. The cost is 0.39 us of bus time per byte and IIgs
waits whenever the Z180 is slow to free the bus.

#### Signals between the two programs

| Signal | How | Side effects |
|---|---|---|
| Z180 to IIgs: a status byte | The Z180 writes port $A0; the IIgs polls $C0B8, which reads U3 without an event | Any Z180 access to port $A0 also acknowledges a pending event. Write a status byte only when the IIgs is waiting for it |
| Z180 to IIgs: interrupt | The Z180 accesses port $AC to raise the IIgs IRQ, $AD to release it ([Apple IRQ](reference/z180-io-ports.md#apple-irq)) | The line stays low until the card releases it. A IIgs handler must check that the card raised it |
| IIgs to Z180: doorbell | An access to $C0B0-$C0B7: INT1, the low address byte at ports $A6/$A7 (so the address itself can carry a code), and for a write the data byte at $A0 | After a screen-copy block, ring with a **read**: a write event replaces U2, which can still hold the last byte waiting to be copied |
| IIgs to Z180: what changed | Band flags, ports $A4/$A5: one bit per 4 KB block of $2000-$9FFF that had a copied write | Set when a write qualifies, before the copy lands. Both banks share them. Reading clears them. A hint, not proof of completion |

The doorbell and the copy take separate paths, so the doorbell does not prove that the
block's last byte has landed. End each block with a commit byte that the Z180 clears before
it opens the window and the IIgs writes last; after the doorbell, the Z180 waits for it.

#### A block protocol

These steps keep each side's rules, with two buffers in the $E1 window: A at $E1/2000-5FFF
(SRAM $12000-$15FFF) and B at $E1/6000-9FFF (SRAM $16000-$19FFF). Each buffer holds a
header (length, sequence number) and ends with its commit byte.

1. **Request.** The IIgs writes a token to $C0B0 (buffer A or B and a sequence number),
   then polls $C0B8. The Z180 reads the token at port $A0, which acknowledges the event.
2. **Grant.** When that buffer is free, the Z180 finishes and stops all Oak access, clears
   the buffer's commit byte, and writes "ready + token" to port $A0.
3. **Write.** The IIgs writes the header and data, and the commit byte last. Meanwhile the
   Z180 can work on the other buffer in SRAM.
4. **Commit.** The IIgs makes one 8-bit read of $C0B2 for A or $C0B3 for B, ignores the
   value, and polls $C0B8. The Z180 sees the event, reads $A0 to acknowledge it, and waits for the
   commit byte.
5. **Accept.** The Z180 checks the header, writes "accepted + token" to port $A0, and may
   use the Oak again. "Accepted" means the data arrived, not that the buffer is free:
   the next grant for that buffer gives it back.

While the IIgs fills B, the Z180 can process A in SRAM. If processing A needs the Oak, do
it between grants. One request is outstanding at a time, and each side waits for the
other's answer before it sends the next signal, so no status write ever acknowledges an
unseen event.

#### Out through U3 and DMA1

The IIgs reads U3 at $C0B0-$C0BF ([host registers](03-apple-interface.md#the-host-registers)).
A read of $C0B0-$C0B7 also raises an event, so DMA1, pointed from SRAM to port $A0, loads
the next byte for each read, as GetStatus does
([GetStatus](reference/host-commands.md#getstatus)). Reads of $C0B8-$C0BF return the same
byte again and do not advance.

1. Inhibit the copy and keep other events away: any access to $C0B0-$C0B7, a write
   included, takes the next byte.
2. Arm DMA1 for the N bytes **plus one spare byte**, then write "ready" to port $A0. The
   IIgs polls $C0B8 for it.
3. The IIgs reads $C0B2 once and ignores the value: that read asks for byte 0.
4. The IIgs makes N reads. Each returns the byte in U3 and asks for the next. The last
   read loads the spare byte, so when DMA1 finishes, the IIgs has read all N.

A 16-bit load from $C0B2 reads $C0B2 then $C0B3: two events and two successive bytes,
because RDY holds the second read until DMA1 has loaded it. Store into fast RAM that is
not shadowed, so the stores make no slow cycles and no copies.

#### Speeds

On a stock IIgs a fast cycle is 350 ns, a slow cycle about 980 ns when it follows another
slow cycle, and about 1.5 us on average when it does not, because the fast side waits to
synchronize ([Apple TN #68](sources.md#s43)). The slot therefore carries at most about
1 MB/s. From those cycle times and the 65816's cycle counts
([W65C816S data sheet](sources.md#s125)):

| IIgs code | Per 2 bytes | Rate | IIgs time per KB |
|---|---|---|---|
| In: 16-bit `LDA dp` from fast RAM, `STA abs` to $E1 | 4.93 us | 406 KB/s | 2.5 ms |
| In: `PEI dp` onto the stack, RAMWRT on, so the writes go to shadowed bank $01 | 3.88 us | 515 KB/s | 2.0 ms |
| Out: 16-bit `LDA $B2` with D = $C000, `STA abs` to fast RAM | 4.93 us | 406 KB/s | 2.5 ms |
| Out: `PEI $B2` with D = $C000, onto the stack in unshadowed bank $00 RAM | 3.88 us | 515 KB/s | 2.0 ms |

These count the instructions only, not loop overhead or RAM refresh. A logic-analyzer test
of `PEI` on a real IIgs measured 4.46 us per word, about 450 KB/s
([PEI measurement](sources.md#s126)). `PEI` stores each word below the last, so the data
must be laid out for that, and both `PEI` methods borrow the stack: turn interrupts off and
restore S and D afterwards. An accelerator speeds up the code, but screen memory and the
slot stay at 1 MHz ([TransWarp GS article](sources.md#s127)).

### Watching the Apple

Z180 code sees the Apple's display changes as
[events](reference/z180-io-ports.md#state-observable-by-z180-software), and which screen
regions changed from the [band flags](reference/z180-io-ports.md#band-flag-layout).

Keep MODE_D3 set on a IIgs: clearing it turns off the /M2SEL check, so invalid slow-side
accesses would count
([configuration bits](reference/z180-io-ports.md#configuration-and-open-reads)).

### Interrupting the IIgs

The [Apple IRQ ports](reference/z180-io-ports.md#port-table) raise and release the
interrupt; the IIgs cannot clear the card's latch ([IRQ wiring](03-apple-interface.md#irq)).
Source: [netlist](../data/netlist/README.md).

### What the IIgs cannot do

- The card has **no slot ROM**, so it cannot give the IIgs a driver or boot code. Source:
  [netlist](../data/netlist/README.md), /IOSELECT unused.
- The card never takes over the Apple bus (/DMA unused), so the Z180 cannot read Apple
  memory; it sees only what the screen copy catches and what the IIgs sends.

## Reaching the card from the IIgs

With ROM 1.4, a IIgs program reaches the whole card through a few host commands; the
[errata](reference/errata.md) workarounds use them.

### What the stock commands reach

- **SetVGAReg and GetVGAReg reach every I/O port.** `set_vga_reg` ([`ROM_BEEF.asm:1631`](sources.md#s27))
  is two raw `OUT (C)` writes and `get_vga_reg` (line 1579) is `OUT (C)` then `IN (C)`.
  The 16-bit port numbers come from the command and are not checked.
- That covers the VGA chips, the card's own ports $A0-$AF, and the Z180's internal
  registers at $0000-$003F (DMA, timers, serial ports, MMU). The internal block stays at
  $0000-$003F because the ROM never writes the I/O control register at $3F, and the Z180
  clears it at reset. Source: [Z8S180 product specification](sources.md#s62), I/O control
  register.
- Each call first writes its "index" byte to its "index port". For a plain register write,
  pick a harmless index port such as $03CE (the VGA graphics-controller index, which the
  firmware sets before each use).
- **RunCode calls any logical address** with the CBR, CBAR and BBR values given, so it can
  run one of the ROM's own routines where it lives. ROM 1.4 sends no completion byte
  afterwards ([E5](reference/errata.md#e5-runcode-never-reports-completion)).
- **Every command runs inside the Z180's INT1 handler**, with interrupts off, between two
  steps of whatever the main loop was doing. A command that changes registers the main
  loop is using (DMA channel 0 in the renderers, the MMU) can corrupt that work, so take
  the card out of Apple emulation first (SetMode to a VGA mode with the emulation flag 1).
  Source: ROM `handle_event`, `check_for_api_call`.

Never write the MMU registers ($38-$3A) this way: the handler's own code would move.
Never read port $A1: every access loads the two configuration bits from the data bus, and
a read leaves that bus undriven. Writing $A1 sets them, as SetShadow does (the firmware
always includes bit 3): [configuration bits](reference/z180-io-ports.md#configuration-and-open-reads).
Never write $A4-$A7: the card drives those ports even on a write
([access limits](reference/z180-io-ports.md#access-limits-and-aliasing)).

### Writing card SRAM from the IIgs

Two methods, neither needing code on the card. Both follow from the ROM code and the Z180
manual.

**Method 1: UploadData with flag 1 and bank $10-$13.** This is route 3 of
[Loading Z180 code](09-host-protocol.md#loading-z180-code): bank $10 lands in SRAM $0xxxx
and $11 in $1xxxx.

**Method 2: Z180 DMA channel 0 through SetVGAReg.** This copies bytes that already exist
on the card, such as EPROM bytes, into SRAM:

1. Take the card out of Apple emulation (SetMode with the emulation flag 1).
2. Read DSTAT with GetVGAReg (data port $0030).
3. With SetVGAReg, write the source address to SAR0 ($0020-$0022), the destination to DAR0
   ($0023-$0025), the byte count to BCR0 ($0026-$0027), and $02 to DMODE ($0031): memory
   to memory, both addresses counting up, burst mode.
4. Write DSTAT ($0030) = (value from step 2 OR $41) AND $EF. That starts channel 0 without
   touching channel 1, as the ROM does. The Z180 stops until the copy ends.

Useful source bytes: the EPROM's upper 64 KB (physical $70000-$7FFFF) is all $00, and the
EPROM holds the ROM's tables at their usual places (physical $60000 + ROM offset).

## Storage: the serial EEPROM

The card carries a 93C46 serial EEPROM: 64 words of 16 bits that survive power-off. On a
PC, Oak's VGA BIOS (TEv1.02) keeps its configuration there, but the OTI-087X never reads it itself;
only software reaches it, through ext $18 ([Video: the serial EEPROM](06-video.md#the-serial-eeprom)).
ROM 1.4 and the Sequential library never touch ext $18, so all 64 words are free, for
example to remember the user's monitor choice or start-up mode.

- Z180 code reaches it directly; IIgs code with SetVGAReg and GetVGAReg on ports
  $03DE/$03DF ([Reaching the card](#reaching-the-card-from-the-iigs)).
- The picture glitches while the EEPROM is in use, because the clock chip shares its
  lines. Use it during a mode change or with the screen off (ScreenOff).
- Read and keep a card's existing contents before writing.

## Wiring rules for custom code

Several card decoders look only at the address, so a read can have the same side effect as
a write. Card ports repeat every 256 I/O addresses.

- **Port $A1:** any access, a read included, loads the two configuration bits from the
  data bus ([configuration bits](reference/z180-io-ports.md#configuration-and-open-reads)).
- **Ports $A4-$A7:** the card drives their low nibble on any access, so a write collides
  with the Z180's data and is lost
  ([access limits](reference/z180-io-ports.md#access-limits-and-aliasing)).
- **EPROM:** U15 enables the EPROM on any access to its area. Never write $60000-$7FFFF,
  or $00000-$1FFFF while the boot overlay is on
  ([EPROM write contention](reference/z180-memory-map.md#eprom-write-contention)).
- **Apple IRQ:** any access to $AC raises the IIgs interrupt line; any access to $AD
  releases it ([Apple IRQ](reference/z180-io-ports.md#apple-irq)).
- **Undriven reads** return the last value on the bus
  ([undriven reads](reference/z180-io-ports.md#configuration-and-open-reads)).

---

Previous: [13 Method](13-method.md) | [Reference index](../README.md)
