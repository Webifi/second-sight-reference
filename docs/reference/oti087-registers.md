# OTI-087X extended registers

[Reference tables](README.md) | [Glossary](../glossary.md)

The Oak OTI-087X's extended register fields and the values ROM 1.4 writes to them
([Video](../06-video.md)).

- The card's chip is marked OTI087X ([which Oak chip](../06-video.md#which-oak-chip)).
  Its specification is the February 1993 [OTI-087 databook](../sources.md#s02) with the
  OTI-087X addendum bound into it. Where the addendum changes the book, the addendum wins.
- Oak's [87X Windows drivers](../sources.md#s69) and [87X DOS kit](../sources.md#s79) are
  OTI-087X software. Oak's [TEv1.02 BIOS](../sources.md#s58) serves the 087B and later chips,
  the 087X included. The Paradise [TBv1.01B BIOS](../sources.md#s57) and the
  [87B drivers](../sources.md#s113) are OTI-087B software; facts taken only from them are
  marked that way.

- An extended register is reached by writing its index to `$3DE`, then reading or writing
  its data at `$3DF`. Port `$102` is separate: it enables the chip
  ([OTI-087 databook](../sources.md#s02) pp29-30).
- The chip decodes the Z180's full I/O address itself. The standard VGA registers are at
  their usual ports ([VGA ports](z180-io-ports.md#vga-ports)).

Sources: the [OTI-087 databook](../sources.md#s02), the firmware and mode records, and
for the register pages the databook copy is missing, Oak's own drivers
([87X](../sources.md#s69), [87B](../sources.md#s113), [NT](../sources.md#s114)), BIOS
([TEv1.02](../sources.md#s58)) and the [Programmer's Guide](../sources.md#s61).

## Contents

- [Register index](#register-index)
- [Identification, configuration and bus fields](#identification-configuration-and-bus-fields)
- [Timing and display fields](#timing-and-display-fields)
- [Transfer and color expansion fields](#transfer-and-color-expansion-fields)
- [Cursor fields](#cursor-fields)
- [Register behavior](#register-behavior)
- [Notes on access and scope](#notes-on-access-and-scope)
- [ROM register access](#rom-register-access)
- [Latch access rules](#latch-access-rules)
- [Machine-readable copy](#machine-readable-copy)

## Register index

Page numbers are the databook's printed pages. Pages 31-32 (the `$3DE` index port and
ext $00-$02) are missing from every copy, so those registers come from Oak's BIOS and
drivers. Each register links to its bit fields.

<!-- csv: data/tables/oti087-extended-registers.csv -->
| Index or port | Name | Firmware use | Source |
|---|---|---|---|
| [$102](#reg-102) | Add-on enable | written by enable_oak_add_on_mode | [databook p30](../sources.md#s02) |
| [$3DE](#reg-3de) | Extended index port | every extended access | Oak BIOS and [NT driver](../sources.md#s114); databook pages 31-32 missing |
| [$00](#reg-00) | Product number (read) | never written | Oak's [DOS installers](../sources.md#s79); Oak BIOS and drivers; databook pages 31-32 missing |
| [$01](#reg-01) | Revision (read) | never written | Oak's [DOS installers](../sources.md#s79) and [87X drivers](../sources.md#s69); databook pages 31-32 missing |
| [$02](#reg-02) | Status | $05 in every mode table | Oak BIOS and 87X DOS kit; databook pages 31-32 missing |
| [$03](#reg-03) | Oak test | $10 | [databook p33](../sources.md#s02) |
| [$04](#reg-04) | Local bus control | $07 | [databook p33-34](../sources.md#s02) |
| [$05](#reg-05) | Video memory mapping | $19 linear (1 MB at $100000) or $00 VGA | [databook p34-35](../sources.md#s02) |
| [$06](#reg-06) | Clock select | per mode; set_video_mode writes $3C2 after ext 6, so the misc byte decides CSEL1-0 | [databook p35](../sources.md#s02) |
| [$07](#reg-07) | Configuration 1 (read) | read only | [databook p36](../sources.md#s02) |
| [$08](#reg-08) | Configuration 2 (read) | read only | [databook p37](../sources.md#s02) |
| [$09-$0B](#reg-09-0b) | Scratch | not used | [databook p37](../sources.md#s02) |
| [$0C](#reg-0c) | CRT control | not written | [databook p37](../sources.md#s02) |
| [$0D](#reg-0d) | Oak miscellaneous | not written | [databook p38](../sources.md#s02) |
| [$0E](#reg-0e-0f) | Backward compatibility | not written | [databook p38](../sources.md#s02) |
| [$0F](#reg-0e-0f) | NMI data cache | not written | [databook p38](../sources.md#s02) |
| [$10](#reg-10) | DIP switch (read) | never read | [databook p38](../sources.md#s02) |
| [$11](#reg-11) | Segment | not written | [databook p38-39](../sources.md#s02) |
| [$12](#reg-12) | Configuration | not written | [databook p39](../sources.md#s02) |
| [$13](#reg-13) | Bus control | $C8 | [databook p39](../sources.md#s02) |
| [$14](#reg-14) | Overflow | per mode | [databook p39-40](../sources.md#s02) |
| [$15](#reg-15) | HSYNC/2 start | per mode | [databook p40](../sources.md#s02) |
| [$16](#reg-16) | Oak overflow 2 | not written | [databook p40](../sources.md#s02) |
| [$17](#reg-17) | Extended CRTC | per mode | [databook p40](../sources.md#s02) |
| [$18](#reg-18) | EEPROM control | never written | [databook p40](../sources.md#s02) |
| [$19](#reg-19) | Color palette range | $0F | [databook p41](../sources.md#s02) |
| [$20](#reg-20) | FIFO depth | $01 (text, hires, 320x200) or $05 (VGA $53/$61/$FA/$FE, RGB $61/$FA/$FB/$FE) | [databook p41](../sources.md#s02) |
| [$21](#reg-21) | Mode select | $00 / $04 / $05 / $06 | [databook p41](../sources.md#s02) |
| [$22](#reg-22) | Feature select | $08 / $0C (mode tables), $08 (uploads), $10 / $00 (lores), $1C / $38 (Super Hi-Res); bit 0 never set | [databook p42](../sources.md#s02) |
| [$23](#reg-23) | Extended read segment | used by renderers | [databook p42](../sources.md#s02) |
| [$24](#reg-24) | Extended write segment | used by renderers | [databook p42](../sources.md#s02) |
| [$25](#reg-25) | Extended common read/write | per mode | [databook p42](../sources.md#s02) |
| [$30](#reg-30) | Color expansion control | $0D in render loops | [databook p43](../sources.md#s02) |
| [$31](#reg-31) | Foreground color | per use | [databook p43](../sources.md#s02) |
| [$32](#reg-32) | Background color | per use | [databook p43](../sources.md#s02) |
| [$33](#reg-33) | Color pattern | per use | [databook p44](../sources.md#s02) |
| [$34](#reg-34) | Pixel mask | per use | [databook p44](../sources.md#s02) |
| [$35](#reg-35) | CPU latch index | written by every mode record (bytes 75-80 write $30-$35) | [databook p44](../sources.md#s02) |
| [$36](#reg-36) | CPU latch data | never read or written by ROM 1.4 routines; host GetVGAReg can request it | [databook p44](../sources.md#s02) |
| [$40/$41](#reg-40-41) | Hardware cursor X start (high/low) | never written | [databook p44](../sources.md#s02) |
| [$42/$43](#reg-42-43) | Hardware cursor Y start (high/low) | never written | [databook p45](../sources.md#s02) |
| [$44/$45](#reg-44-45) | Hardware cursor X/Y preset | never written | [databook p45](../sources.md#s02) |
| [$47/$48/$49](#reg-47-48-49) | Hardware cursor pattern address | never written | [databook p45](../sources.md#s02) |
| [$4A/$4B](#reg-4a-4b) | Hardware cursor color 0 / color 1 | never written | [databook p46](../sources.md#s02) |
| [$4C](#reg-4c) | Hardware cursor control | never written | [databook p46](../sources.md#s02) |

## Identification, configuration and bus fields

These fields identify the chip and describe its bus and memory configuration.

<!-- csv: data/tables/oti087-register-bits.csv -->
| Index or port | Field or value | Source |
| --- | --- | --- |
| <a id="reg-102"></a>$102 | Bit 0 enable VGA/palette/VRAM access | [OTI-087 p30](../sources.md#s02) |
| <a id="reg-3de"></a>$3DE | Read/write index. Oak's BIOS and NT driver read it, keep the byte, and write it back to restore the index they found (BIOS file offset $1BF0, NT `OAK.SYS` $2D50-$2DF1). Oak's NT driver finds the chip by writing $11 and checking that bits 4-0 read back $11 | Oak BIOS [TEv1.02](../sources.md#s58); [NT driver](../sources.md#s114); third-party [OAK.TXT](../sources.md#s35) ("bit 0-7 Index", 83/87) |
| <a id="reg-00"></a>$00 | Reads 1 on the OTI-087X. Oak's DOS installers name an 087-family chip (087B, 087D, 087X, 089) only when it reads 1 (`INSTALL.EXE` file offset $2B8B) | Oak [87X DOS kit](../sources.md#s79) and [87B DOS kit](../sources.md#s116); [Programmer's Guide, 1994](../sources.md#s61) section 25.4 and the third-party [XFree86 driver](../sources.md#s63) also take 1 as an OTI-087 |
| $00 | Bit 1 set = OTI-083, clear = OTI-087 | Oak BIOS [TEv1.02](../sources.md#s58) and [TBv1.01B](../sources.md#s57); third-party [OAK.TXT](../sources.md#s35) |
| $00 | Oak's OTI-087X drivers load only when it reads 1 or 2; the OTI-087B drivers accept 1-3, the NT driver 1-4 | [87X drivers](../sources.md#s69); [87B drivers](../sources.md#s113); [NT driver](../sources.md#s114) |
| <a id="reg-01"></a>$01 | Bits 7-4 revision: 0 = 087B, 1 = 087D, 2 = 087X, 3 = 089. The OTI-087X reads $2x. Oak's DOS installers branch on these four values and title themselves "087B", "087D", "087X" or "089 Driver Install" (`INSTALL.EXE` file offsets $2BB1-$2C02, titles $80E7-$8146) | Oak [87X DOS kit](../sources.md#s79) and [87B DOS kit](../sources.md#s116) |
| $01 | Oak's 87X Windows drivers refuse to load when bits 7-4 are 0 (an 087B); Oak's hi-color drivers pick their DAC setting table from the same test | [87X drivers](../sources.md#s69) |
| $01 | Bits 3-0: no Oak program reads them; every reader masks with $F0 | Oak DOS and Windows kits |
| <a id="reg-02"></a>$02 | Bit 0 (read only) 0 = 286 bus, 1 = 386/486 | [OAK.TXT](../sources.md#s35); [Programmer's Guide, 1994](../sources.md#s61) |
| $02 | Bits 2-1 memory size 0=256K 1=512K 2=1MB 3=2MB | Oak BIOS [TEv1.02](../sources.md#s58) and [TBv1.01B](../sources.md#s57); Oak's VESA extension `OTIVBE.COM` in the [87X DOS kit](../sources.md#s79) |
| <a id="reg-03"></a>$03 | Bits 2-0 test mode: 000 "Test CRTC", 010 "Test waveform RAM", 101 "Scan Test Attribute Controller"; 001, 011, 100, 110 and 111 reserved. Oak describes no procedure, output or read-back for 000 and 010, and no other source found does (every OTI-087 databook copy found, VGA Museum's two downloads included, is the same scan and lacks printed pp31-32) | [OTI-087 p33](../sources.md#s02) |
| $03 | Mode 101: in text mode the font data and the attribute data come from system data bits 15-8 and 7-0 instead of video memory; in graphics mode the pixel data comes from bits 15-8. On this card SD8-SD15 are open and SD0-SD7 are the Z180 data bus, so the font and pixel data come from unconnected pins | [OTI-087 p33](../sources.md#s02); [netlist](../../data/netlist/netlist.csv) U28 |
| $03 | Bit 4: flush the write cache immediately after each write. Oak's BIOS writes $10 with bit 7 = 0 (TEv1.02 file offset $1E0E; again $00 then $10 at $1E20 and $1E28 when ext $07 bit 2 is 0), and so do Oak's OS/2 mode tables | [OTI-087 p33](../sources.md#s02); [TEv1.02](../sources.md#s58) |
| $03 | Bit 5 VSYNC test: "This bit will cause the Vsync to toggle when it is changed from 1 to 0 or from 0 to 1" | [OTI-087 p33](../sources.md#s02) |
| $03 | Bit 6 I/O write test: an I/O write command is not clocked by MCLK. Must be 0 in normal operation | [OTI-087 p33](../sources.md#s02) |
| $03 | Bit 7: "Enable global test modes". Must be 0 in normal operation. Default $00 | [OTI-087 p33](../sources.md#s02) |
| $03 | Oak's software writes only $00 and $10. Its Windows drivers, VDD and VESA extension read the byte and write it back unchanged (`STD8_SC.DRX` read at $8DC4, write-back at $8DFC; `VDD87X.38X` $1239 and $1437; `OTIVBE.COM` $497 and $4B5) | [87X drivers](../sources.md#s69); [87X DOS kit](../sources.md#s79) |
| <a id="reg-04"></a>$04 | Bit 0 one wait on first write | [OTI-087 p33-34](../sources.md#s02) |
| $04 | Bit 1 one wait on write hit | [OTI-087 p33-34](../sources.md#s02) |
| $04 | Bit 2 one wait on read hit | [OTI-087 p33-34](../sources.md#s02) |
| $04 | Bit 3 486 minimum wait | [OTI-087 p33-34](../sources.md#s02) |
| $04 | Bit 4 turbo local bus; 0 required on "OTI-087 Rev A and OTI-087 Rev B" | [OTI-087 p34](../sources.md#s02) |
| $04 | Default $0F | [OTI-087 p33-34](../sources.md#s02) |
| <a id="reg-05"></a>$05 | Bit 0 Oak mapping (0 = VGA A0000/B8000 windows) | [OTI-087 p34-35](../sources.md#s02) |
| $05 | Bit 1 DMA access disable | [OTI-087 p34-35](../sources.md#s02) |
| $05 | Bits 3-2 aperture 00=256K 01=512K 10=1M 11=2M | [OTI-087 p34-35](../sources.md#s02) |
| $05 | Bits 7-4 start address in MB | [OTI-087 p34-35](../sources.md#s02) |
| <a id="reg-06"></a>$06 | Bits 3-0 drive CSEL3-0 into the OTI-068. Bits 1-0 are the same storage as misc output ($3C2) bits 3-2, and bit 2 the same as index $0D bit 5, so the last write wins | [OTI-087 p35](../sources.md#s02) |
| <a id="reg-07"></a>$07 | Loaded at reset from the strap lines MD7-MD0. Bit 0 BIOS width | [OTI-087 p36](../sources.md#s02) |
| $07 | Bits 2-1 bus mode (11 = AT-bus add-on) | [OTI-087 p36](../sources.md#s02) |
| $07 | Bits 4-3 DRAM type (10 = 256KxXX) | [OTI-087 p36](../sources.md#s02) |
| $07 | Bit 5 pin 92 function | [OTI-087 p36](../sources.md#s02) |
| $07 | Bit 6 1 = MCLK under 44 MHz | [OTI-087 p36](../sources.md#s02) |
| $07 | Bit 7 CPU clock (local bus) | [OTI-087 p36](../sources.md#s02) |
| <a id="reg-08"></a>$08 | Loaded at reset from the strap lines MD15-MD8. Bits 1-0 local bus type | [OTI-087 p37](../sources.md#s02) |
| $08 | Bits 3-2 color chip type (00 = Bt476-style pass-through) | [OTI-087 p37](../sources.md#s02) |
| $08 | Bit 6 feature connector (local-bus pinouts). On the OTI-087X only bits 6, 1, 0 = 101 and 110 are listed: both put EPCLK on pin 19 and EPDATA on pin 20, and pin 99 does not apply | [OTI-087 p37](../sources.md#s02); [OTI-087X addendum](../sources.md#s02) |
| $08 | Bit 7 reserved on the OTI-087X (the databook's DRAM WE/CAS pin choice) | [OTI-087X addendum](../sources.md#s02); [OTI-087 p37](../sources.md#s02) |
| <a id="reg-09-0b"></a>$09-$0B | 8 scratch bits each | [OTI-087 p37](../sources.md#s02) |
| <a id="reg-0c"></a>$0C | Bits 7-0 not used | [OTI-087 p37](../sources.md#s02) |
| <a id="reg-0d"></a>$0D | Bits 2-0 mirror index $20 | [OTI-087 p38](../sources.md#s02) |
| $0D | Bits 4-3 mirror index $21 bits 3-2 | [OTI-087 p38](../sources.md#s02) |
| $0D | Bit 5 mirrors index $06 bit 2 (CSEL2) | [OTI-087 p38](../sources.md#s02) |
| <a id="reg-0e-0f"></a>$0E, $0F | Bits 7-0 not used | [OTI-087 p38](../sources.md#s02) |
| <a id="reg-10"></a>$10 | Loaded at reset from the strap lines SD7-SD0 | [OTI-087 p38](../sources.md#s02) |
| <a id="reg-11"></a>$11 | Bits 3-0 read segment, 7-4 write segment (compatibility alias of $23/$24) | [OTI-087 p38-39](../sources.md#s02) |
| <a id="reg-12"></a>$12 | Bits 7-0 not used | [OTI-087 p39](../sources.md#s02) |
| <a id="reg-13"></a>$13 | Bit 3 AT-bus zero-wait-state enable | [OTI-087 p39](../sources.md#s02) |
| $13 | Bit 4 16-bit BIOS ROM | [OTI-087 p39](../sources.md#s02) |
| $13 | Bit 5 disable BIOS at C0000 | [OTI-087 p39](../sources.md#s02) |
| $13 | Bit 6 16-bit I/O | [OTI-087 p39](../sources.md#s02) |
| $13 | Bit 7 16-bit memory | [OTI-087 p39](../sources.md#s02) |

## Timing and display fields

These fields control display timing, the start address, clocks and pixel format.
For the mode-setting procedure, see [building a mode](../14-custom-code.md#building-a-mode).

<!-- csv: data/tables/oti087-register-bits.csv -->
| Index or port | Field or value | Source |
| --- | --- | --- |
| <a id="reg-14"></a>$14 | Bit 0 VT bit 10 | [OTI-087 p39-40](../sources.md#s02) |
| $14 | Bit 1 VBS bit 10 | [OTI-087 p39-40](../sources.md#s02) |
| $14 | Bit 2 VRS bit 10 | [OTI-087 p39-40](../sources.md#s02) |
| $14 | Bit 3 start address bit 16, the same bit as ext $17 bit 0 (the databook calls it "High Order Start Address Bit 8") | [OTI-087 p39-40](../sources.md#s02) |
| $14 | Bit 7 interlace | [OTI-087 p39-40](../sources.md#s02) |
| <a id="reg-15"></a>$15 | Odd-field vertical retrace start in interlace (character units) | [OTI-087 p40](../sources.md#s02) |
| <a id="reg-16"></a>$16 | Bits 7-0 not used on the OTI-087 | [OTI-087 p40](../sources.md#s02) |
| <a id="reg-17"></a>$17 | Bits 2-0 start address bits 18-16, above CRTC $0C/$0D (the databook's "High Order Start Address Bit 10-8"); in packed 256-color mode the start address counts 8-byte units | [OTI-087 p40](../sources.md#s02); the 8-byte unit from the third-party [XFree86](../sources.md#s63) `OAKAdjust` and [Programmer's Guide](../sources.md#s61) 25.6, which name no 087 revision |
| <a id="reg-18"></a>$18 | Bit 0 data (read from CSEL0, written to CSEL1) | [OTI-087 p40](../sources.md#s02) |
| $18 | Bit 1 chip select | [OTI-087 p40](../sources.md#s02) |
| $18 | Bit 2 1 = CSEL2-0 drive the EEPROM instead of the clock chip | [OTI-087 p40](../sources.md#s02) |
| $18 | Bit 3 shift clock on CSEL2 | [OTI-087 p40](../sources.md#s02) |
| <a id="reg-19"></a>$19 | Bits 3-0 extra DAC I/O range 3x0-3xF; $F turns the extra range off | [OTI-087 p41](../sources.md#s02) |
| $19 | Default 4: palette reads and writes also answer at $340-$34F until software writes $F | [OTI-087 p41](../sources.md#s02) |
| <a id="reg-20"></a>$20 | Bits 3-0 minimum level the display FIFO must be filled to before a CPU read/write is served (bits 2-0 mirror index $0D bits 2-0) | [OTI-087 p41](../sources.md#s02) |
| $20 | Default 1 | [OTI-087 p41](../sources.md#s02) |
| <a id="reg-21"></a>$21 | Bit 0 hi-color (horizontal timing x2) | [OTI-087 p41](../sources.md#s02) |
| $21 | Bit 1 true color (x3) | [OTI-087 p41](../sources.md#s02) |
| $21 | Bits 3-2 01 = Oak packed pixel modes | [OTI-087 p41](../sources.md#s02) |
| $21 | Bit 7 one refresh per line | [OTI-087 p41](../sources.md#s02) |

## Transfer and color expansion fields

These fields control the video-memory windows, latch, caches and color expansion.
Examples and costs: [drawing with the OTI-087X](../15-oak-drawing.md).

<!-- csv: data/tables/oti087-register-bits.csv -->
| Index or port | Field or value | Source |
| --- | --- | --- |
| <a id="reg-22"></a>$22 | Bit 0 content-addressable 64-bit latch (when bit 4 = 0 and bit 0 = 1 the latch byte written out is selected from the CPU address) | [OTI-087 p42](../sources.md#s02) |
| $22 | Bit 2 read cache | [OTI-087 p42](../sources.md#s02) |
| $22 | Bit 3 write cache (databook: must not be enabled for AT-bus implementations) | [OTI-087 p42](../sources.md#s02) |
| $22 | Bit 4 64-bit graphics latch | [OTI-087 p42](../sources.md#s02) |
| $22 | Bit 5 CPU latch swap | [OTI-087 p42](../sources.md#s02) |
| $22 | Default 0 | [OTI-087 p42](../sources.md#s02) |
| <a id="reg-23"></a>$23 | Bits 4-0 CPU address bits 20-16 for reads in the A0000 window | [OTI-087 p42](../sources.md#s02) |
| <a id="reg-24"></a>$24 | Bits 4-0 CPU address bits 20-16 for writes | [OTI-087 p42](../sources.md#s02) |
| <a id="reg-25"></a>$25 | Writes both $23 and $24; a read returns $24. The Programmer's Guide tells an OTI-087 from other Oak chips by writing $0A to $24 and reading it from $25 | [OTI-087 p42](../sources.md#s02); [Programmer's Guide](../sources.md#s61) listing 25.4 |
| <a id="reg-30"></a>$30 | Bit 0 enable | [OTI-087 p43](../sources.md#s02) |
| $30 | Bit 1 planar (1) / packed (0) | [OTI-087 p43](../sources.md#s02) |
| $30 | Bit 2 use color pattern register | [OTI-087 p43](../sources.md#s02) |
| $30 | Bit 3 pixel mask enable | [OTI-087 p43](../sources.md#s02) |
| $30 | Bit 4 mask bit order: 0 = mask bit 7 is pixel 7, 1 = mask bit 7 is pixel 0. Oak's 87X drivers set it; Oak's 87B drivers keep it 0 ([X versus earlier](../06-video.md#where-the-oti-087x-differs-from-earlier-oti-087s)) | [OTI-087 p43](../sources.md#s02); [87X drivers](../sources.md#s69); [87B drivers](../sources.md#s113) |
| <a id="reg-31"></a>$31 | 8 bits | [OTI-087 p43](../sources.md#s02) |
| <a id="reg-32"></a>$32 | 8 bits | [OTI-087 p43](../sources.md#s02) |
| <a id="reg-33"></a>$33 | 8 bits; bit 7 is the first pixel | [OTI-087 p44](../sources.md#s02) |
| <a id="reg-34"></a>$34 | 8 bits (effective when $30 bit 3 = 1) | [OTI-087 p44](../sources.md#s02) |
| <a id="reg-35"></a>$35 | Bits 2-0 select which byte of the 64-bit latch $36 reads/writes | [OTI-087 p44](../sources.md#s02) |
| <a id="reg-36"></a>$36 | 8 bits | [OTI-087 p44](../sources.md#s02) |

## Cursor fields

These fields position the cursor and select its pattern and colors. Pattern layout,
positioning and display-mode limits: [hardware cursor](../06-video.md#hardware-cursor).

<!-- csv: data/tables/oti087-register-bits.csv -->
| Index or port | Field or value | Source |
| --- | --- | --- |
| <a id="reg-40-41"></a>$40/$41 | Pixels from the start of the display area; top left = (0,0) | [OTI-087 p44](../sources.md#s02) |
| <a id="reg-42-43"></a>$42/$43 | Pixels from the start of the display area | [OTI-087 p45](../sources.md#s02) |
| <a id="reg-44-45"></a>$44/$45 | Starting position inside the 64x64 pattern | [OTI-087 p45](../sources.md#s02) |
| $44/$45 | The cursor always ends at 63, no wrapping | [OTI-087 p45](../sources.md#s02) |
| $44/$45 | Presets skip left/top, not right/bottom | [OTI-087 p45](../sources.md#s02) |
| <a id="reg-47-48-49"></a>$47/$48/$49 | 24-bit pattern address in 8-byte units (256-color packed mode) | [OTI-087 p45](../sources.md#s02) (address registers); [Oak 87X Windows driver](../sources.md#s69) STD8_HC.DRV writes $01FE80 for a pattern at $FF400 ([where the driver puts it](../06-video.md#hardware-cursor)); [OAK.TXT](../sources.md#s35) |
| $47/$48/$49 | $47 = bits 23-16, $48 = bits 15-8, $49 = bits 7-0 | [OTI-087 p45](../sources.md#s02) |
| $47/$48/$49 | 64x64 x 2-bit pattern | [OTI-087 p45](../sources.md#s02) |
| $47/$48/$49 | No index $46 listed | [OTI-087 p45](../sources.md#s02) |
| <a id="reg-4a-4b"></a>$4A/$4B | 8-bit color values | [OTI-087 p46](../sources.md#s02) |
| $4A/$4B | Pattern code 00 shows $4A, code 01 shows $4B ([hardware cursor](../06-video.md#hardware-cursor)) | [Oak 87X Windows driver](../sources.md#s69) STD8_HC.DRV |
| <a id="reg-4c"></a>$4C | Bit 0 "HC color control": 0 = cursor off, 1 = cursor on; power-on 0 | [OTI-087 p46](../sources.md#s02); [Oak 87X Windows driver](../sources.md#s69) writes $15 to show the cursor and $14 to hide it |
| $4C | Bit 1 0 = cursor in overscan mode, 1 = over the overscan | [OTI-087 p46](../sources.md#s02) |
| $4C | Bit 2 bit order inside each byte: 0 = bit 0 is the first pixel, 1 = bit 7 is | [OTI-087 p46](../sources.md#s02) |
| $4C | Bit 3 blink enable | [OTI-087 p46](../sources.md#s02) |
| $4C | Bits 5-4 blink every 4/8/16/32 frames | [OTI-087 p46](../sources.md#s02) |
| $4C | Default $10 | [OTI-087 p46](../sources.md#s02) |

## Register behavior

<!-- csv: data/tables/oti087-register-notes.csv -->
| Index or port | Note | Source |
| --- | --- | --- |
| $00 | Oak's VGA BIOS ([TEv1.02](../sources.md#s58) and [TBv1.01B](../sources.md#s57)) reads bit 1 and prints 087 or 083 from it. TEv1.02 also reads $01 bits 7-4 (offset $1FD6) and runs extra steps only on an 087B; TBv1.01B has no $01 test. | Oak BIOS TEv1.02/TBv1.01B; [OAK.TXT](../sources.md#s35)/[Programmer's Guide](../sources.md#s61); databook pp31-32 missing |
| $02 | Oak's VGA BIOS reads bits 2-1: the sign-on prints the memory size from them. POST writes them while probing memory, so they are writable. Oak's VESA extension in the 87X DOS kit reads the same bits. | Oak BIOS [TBv1.01B](../sources.md#s57)/[TEv1.02](../sources.md#s58); [OAK.TXT](../sources.md#s35)/[Programmer's Guide](../sources.md#s61); databook pp31-32 missing |
| $04 | Local-bus modes only; this card is strapped for the AT bus | [OTI-087 p33-34](../sources.md#s02) |
| $06 | A change needs a software reset | [OTI-087 p35](../sources.md#s02) |
| $07 | Strapped: bits 1, 2, 4 = 1 and bits 3, 5 = 0. Bits 0, 6, 7 are not strapped. | [OTI-087 p36](../sources.md#s02) |
| $08 | The drawing straps bit 0 high and bits 1, 2, 3, 7 low. Production R26 has no resistor body, so the drawing alone does not establish a fitted MD9 pull-down or bit 1's reset level on production. Bits 4-6 have no drawn straps. | [OTI-087 p37](../sources.md#s02); production photos |
| $13 | The databook scan has "1100 1000" handwritten beside this register | [OTI-087 p39](../sources.md#s02) |
| $21 | A change needs a software reset | [OTI-087 p41](../sources.md#s02) |
| $22 | Bit 3 write cache: [Write cache](#write-cache) | [OTI-087 p5](../sources.md#s02), p33, p42 |
| $4C | [Oak's TEv1.02 BIOS](../sources.md#s58) writes $10 | [OTI-087 p46](../sources.md#s02) |

- The OTI-087X reads $00 = 1 and $01 = $2x (bits 7-4 = 2), from Oak's own DOS installers
  ([87X DOS kit](../sources.md#s79)). No Oak program reads $01 bits 3-0.
- ROM 1.4 writes $02 with bits 2-1 = 10 (1 MB). Bit 0 of $02 is read-only and reads 0 in
  AT-bus mode. Oak's VDD87X.386 saves and restores the whole $02 byte.
- The unstrapped bits of $07, $08 and $10 float at reset, and nothing reads them. An
  emulator can return $07 = $56, $08 = $01 and $10 = $FF.
- Ext $20 defaults to 1 (p41; p38 says 0 for its $0D mirror), and Oak's TEv1.02 BIOS
  writes it at power-on (offset $0306).

Sources: [OTI-087 databook](../sources.md#s02); [Oak BIOS TEv1.02](../sources.md#s58);
[Oak 87X drivers](../sources.md#s69); [Programmer's Guide](../sources.md#s61).

## Notes on access and scope

How the card enables the chip:
[OTI-087X: how it is attached](../06-video.md#oti-087x-how-it-is-attached).

### Write cache

With ext $22 bit 3 set, the chip latches a write's address and data and lets the CPU go
on, unless the cache is full or the write falls in a different cache page from the
previous one. Source: [OTI-087 p5](../sources.md#s02), p42.

ROM 1.4 sets the bit for uploads ($08) and Super Hi-Res ($1C, $38). Every mode table also
sets ext $03 = $10, which flushes the cache right after each write, so data and write
order are unchanged. Source: [OTI-087 p33](../sources.md#s02).

The chip's zero-wait output (pin 99, -ZEROWS) goes only to pull-up R14, so the card ends
each cycle through IOCHRDY and U15 ([wait states](../05-z180.md#wait-states)).
Source: [netlist](../../data/netlist/README.md) U28.99 and R14.

[Databook p42](../sources.md#s02) says not to enable the bit on an AT bus, while the
overview on p5 describes the same cache giving zero-wait AT-bus writes.
[Oak's TEv1.02 BIOS](../sources.md#s58) and Oak's 87X Windows driver set the bit
with no bus-type test.
Sources: OTI-087 p5, p42; Oak BIOS TEv1.02 offset $1E31;
[`STD8_HC.DRV`](../sources.md#s69) offset $78D8.

### Beyond ROM 1.4

SetVGAReg, GetVGAReg and custom Z180 code reach every extended and standard VGA
register, the hardware cursor, the CRT interrupt and the EEPROM interface, not only
what ROM 1.4 uses ([Beyond the firmware](../14-custom-code.md)). What each drawing and
display feature does on this card, and its cost:
[Drawing with the OTI-087X](../15-oak-drawing.md). The cursor pixel codes
come from [Oak's 87X Windows driver](../sources.md#s69)
([hardware cursor](../06-video.md#hardware-cursor)).

## ROM register access

- $22 = $1C: 64-bit latch, read cache and write cache. $22 = $38: 64-bit latch, write
  cache and CPU latch swap.
- The Super Hi-Res renderer steps $25 through $08-$0F.
- Text and lores use $30 = $09/$0D.
- ROM 1.4 never writes $00-$01, $07-$12, $16, $18, $1A-$1F, $26-$2F or $36 and above. Its
  mode loop ends before $36 ([`ROM_BEEF.asm:1185-1186`](../sources.md#s27)).
- Its own register reads use $3C2, $3C5, $3D5, $3DA and $3C6/$3C7 (every `in a, (c)` in
  `ROM_BEEF.asm`). GetVGAReg can request other registers.

## Latch access rules

| Operation | Address and data rule | Evidence |
|---|---|---|
| 8-bit read, address E includes ext $23 segment | Load the 32-bit word containing E into both latch halves; readback: [latch rules](../06-video.md#the-64-bit-latch-lane-rule) | The Super Hi-Res loop needs duplicate halves and throws the returned byte away |
| Write mode 1, ext $30 bit 3 = 1 | Address A includes ext $24 segment. Store four bytes at `(A & ~7) + 4*(A & 1)` from latch half `(A & 1) XOR swap`; swap = ext $22 bit 5 | A0 selects the four-byte destination half; A1-A2 cases: [latch rules](../06-video.md#the-64-bit-latch-lane-rule); ext $34 masks individual pixels |
| Write mode 0, pixel mask off | Store the CPU byte at its ordinary chain-4 address | Building the lookup tables needs plain byte stores even with the 64-bit latch on |
| Color expansion, ext $30 bit 0 = 1 | Offset 0 fills pixels 0-3; offset 1 fills pixels 4-7. Pixel p uses bit (7-p) of the CPU byte, or ext $33 if bit 2 selects the pattern | Ext $31 is foreground for 1; $32 background for 0; $34 masks when bit 3 = 1 |

## Machine-readable copy

The tables as CSV:
[`oti087-extended-registers.csv`](../../data/tables/oti087-extended-registers.csv) (the
register index), [`oti087-register-bits.csv`](../../data/tables/oti087-register-bits.csv)
(every bit field) and
[`oti087-register-notes.csv`](../../data/tables/oti087-register-notes.csv) (register
behavior).

---

[Reference tables](README.md) | [Video chapter](../06-video.md)
