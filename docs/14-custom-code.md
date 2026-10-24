# 14 Beyond the firmware: what custom code can use

[Reference index](../README.md) | [Glossary](glossary.md) | [Reference tables](reference/README.md)

The hardware ROM 1.4 leaves unused, and how to reach it: from Z180 code started with
RunCode ([Loading Z180 code](09-host-protocol.md#loading-z180-code)), or from IIgs code
through the stock host commands.

## Contents

- [Z180 resources](#z180-resources): [clock](#clock), [memory](#memory), [DMA](#dma), [timers](#timers), [interrupts](#interrupts), [serial ports](#serial-ports)
- [Video resources](#video-resources): [modes](#modes-beyond-the-firmwares-tables), [building a mode](#building-a-mode), [24-bit width](#24-bit-mode-width), [Oak](#oti-087-features-the-firmware-does-not-use), [Bt481](#bt481-features-the-firmware-does-not-use), [matching the IIgs frame](#matching-the-iigs-frame)
- [Apple-side resources](#apple-side-resources): [protocol](#your-own-command-protocol), [events](#watching-the-apple), [IRQ](#interrupting-the-iigs), [limits](#what-the-iigs-cannot-do)
- [Reaching the card from the IIgs](#reaching-the-card-from-the-iigs): [what the commands reach](#what-the-stock-commands-reach), [writing SRAM](#writing-card-sram-from-the-iigs)
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
                                                        +-> R1 22 ohm -> HCLK -> U15, U17
14.31818 MHz X2 -> OTI-068 -> VCLK (16 choices) -> OTI-087, U8/U12 -> Bt481
                          -> MCLK (40 MHz straps) -> OTI-087 video memory
Apple slot clocks -> Lattice Y0, Y2 (7M) and CPU (PHASE 0) inputs
```

The prototype also had places for X1, a 20 MHz crystal, and R38 from MCLK; production
fits neither. Sources: [netlist](../data/netlist/README.md), [production photo](sources.md#s20).
The Apple clocks: [Lattice clocks](04-capture-logic.md#clocks-and-phase).

36 MHz is 80 percent above the fitted Z8S18020's rating and above the fastest 33 MHz grade
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

**A retrace interrupt on a stock card.** The frame length is fixed by the mode, so PRT0
can stand in for the missing retrace interrupt:

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

**Where the card's beam is.** For tear-free cursor moves, page flips or palette changes:

- **Polling:** Input Status 1 at $3DA (the color address the firmware's modes select)
  reads bit 3 = 1 during vertical retrace and bit 0 = 1 whenever the display is blanked.
  Reading it also resets the attribute-controller flip-flop, as on any VGA.
- **Interrupt, with the INT0 pull-up added:** the Oak's retrace interrupt (CINT) drives
  INT0; CRTC $11 bit 5 = 0 enables it, and writing bit 4 = 0 then 1 clears it.
- **The current line:** the Oak has no readable line counter. Start a PRT timer at vertical
  retrace and divide by the mode's line time, or count the bit-0 blanking pulses. CRTC $18
  (line compare) splits the screen at a chosen line, as on any VGA.
- Write the hardware-cursor position (ext $40-$43) during vertical retrace, so the cursor
  never shows half in the old place.

Sources: [OTI-087 databook](sources.md#s02) pin 90 (CINTn); [IBM VGA Technical Reference](sources.md#s68),
Input Status 1 and CRTC $11, the standard registers the OTI-087 copies.

### Serial ports

The Z180's two serial channels (ASCI0, ASCI1) and its clocked serial port (CSI/O) are on
the chip; the firmware writes trace characters to ASCI0. The drawing connects their pins
to nothing ([connections the drawing leaves out](reference/board-connections.md#connections-the-drawing-leaves-out)).
Source: [netlist](../data/netlist/README.md).

## Video resources

### Modes beyond the firmware's tables

The chips and the card's 1 MB of video RAM support more modes than ROM 1.4's tables hold:
[additional modes](reference/video-modes.md#additional-modes). Send one as a mode record
with SetUserMode, or write its registers from Z180 code. The pixel clock tops out at the
OTI-068's 78 MHz. The board's straps fix the memory clock at 40 MHz, which limits how fast
the CPU reaches video memory in the busiest modes
([Video: ext $20](06-video.md#extended-registers-the-firmware-uses)).

### Building a mode

A mode is the 81 register values SetUserMode sends
([record layout](reference/host-commands.md#setusermode)), or the same registers written
by Z180 code. The standard VGA registers keep their IBM meanings; the Oak's extended
registers are in the [Oak register reference](reference/oti087-registers.md). A mode is
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
   interlace, and ext $15 sets the odd field's vertical sync. Misc output bits 6 and 7 set
   the HSYNC and VSYNC polarity (1 = negative); the RGB connector's composite sync needs
   both negative.
5. **Pixels in memory.** Ext $21 bits 3-2 = 01 selects packed pixels, one byte per pixel
   for 256 colors. Adding ext $21 bit 0 and a 15- or 16-bit Bt481 mode (feature byte bits
   7-4 become Command Register A) gives 32K or 64K colors at two bytes per pixel. In packed
   modes the line pitch is CRTC $13 x 16 bytes. Changing ext $06 or ext $21 needs a
   sequencer reset ([register behavior](reference/oti087-registers.md#register-behavior)).

Sources: [IBM VGA Technical Reference](sources.md#s68) for the standard registers;
[OTI-087 databook](sources.md#s02) pp35-41; [Bt481A datasheet](sources.md#s36).

**Example: a PAL monitor.** The RGB connector can drive a 50 Hz PAL RGB monitor or the RGB
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

### OTI-087 features the firmware does not use

- **Panning, page flipping and interlace:** the
  [timing and display fields](reference/oti087-registers.md#timing-and-display-fields).
  Change the start address while the retrace bit in $3DA is set for tear-free flips. The
  FAQ describes 640 x 400 interlaced output on AppleColor RGB. Source:
  [databook p39-40](sources.md#s02).
- **Hardware cursor:** [Hardware cursor](06-video.md#hardware-cursor).
- **Content-addressable latch and write cache:** the
  [feature-select register](reference/oti087-registers.md#reg-22).

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
   shows 200 IIgs lines in 400 of its 480. Load it with SetUserMode or from Z180 code.
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

With the frames locked, Z180 code can change Bt481 palette entries in step with the IIgs
program's own palette changes, for per-line palette effects. Only the horizontal blank is
free for this: a color changed while a line is drawn changes part way along it. In mode
$53 the blank is at most 160 of the 800 dots, 6.36 us or about 114 Z180 clocks, twice per
IIgs line. One color takes about 90 clocks: selecting the entry at $3C8 and switching to
$3C9 (about 25 clocks), then three DAC writes of about 21 clocks each (`LD A,(HL)` 6,
`INC L` 4, `OUT (C),A` 10, one I/O wait). So one color fits in each blank, two per IIgs
line, less the few clocks each copied IIgs write takes from the Z180's bus. That is
enough for one or two colors per line, such as moving color bars. All 16 colors on every
line, a full 3200-color display, needs about 1,000 clocks of DAC writes per line (one
entry selection, then 48 writes) against about 228 clocks of blank, so it does not fit.
Sources: [Zilog UM0050](sources.md#s39) instruction table; [OTI-087 databook](sources.md#s02)
CRTC and interrupt registers.

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
  card.

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
PC, Oak's VGA BIOS keeps its configuration there, but the OTI-087 never reads it itself;
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
