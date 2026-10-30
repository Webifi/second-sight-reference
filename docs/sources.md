# Sources

Every document this reference cites, with a public link. A quoted title is the document's
own.

Browse key sources by topic:

- Board and wiring: [schematic](#s26), [production photos](#s18), [front view](#s20), [pinouts](#s13).
- Oak graphics: [databook and OTI-087X addendum](#s02), [87X Windows drivers](#s69), [87X DOS kit](#s79).
- Video clocks and colors: [OTI-068](#s01), [Bt481A](#s36), [IBM VGA](#s68).
- Firmware and host commands: [Sequential's command documentation](#s15), [ROM image](#s25), [disassembly](#s27), [library source](#s29).
- Apple bus and video: [IIgs hardware reference](#s78), [slot timing](#s43).
- Z180 and capture logic: [Z180 manual](#s39), [Lattice data book](#s85), [Lattice fitter manual](#s76).

## Index

| ID | Document |
|---|---|
| [s01](#s01) | OTI-068.pdf: Oak OTI-068 dual clock synthesizer databook (April 1993), 6 pages |
| [s02](#s02) | OTI-087.pdf: Oak OTI-087 local-bus VGA controller databook (Feb 1993) plus OTI-087X addendum, 79 scanned pages; printed pages 31-32 missing |
| [s03](#s03) | VGA Registers.pdf: "VGA Registers": "A description of the standard VGA register set", one of the documents listed in Second Sight - Summary.pdf |
| [s04](#s04) | gview.025c.po: GView 0.25c ProDOS disk image |
| [s05](#s05) | gview.025c.txt: Text note accompanying the GView 0.25c disk image |
| [s06](#s06) | ss.source.082395.po: ProDOS disk image; the name ends in 082395 (23 August 1995) |
| [s07](#s07) | sslib082696.po: ProDOS disk image; the name ends in 082696 (26 August 1996) |
| [s08](#s08) | SView1.0a5.po: SecondView 1.0a5 ProDOS disk image |
| [s09](#s09) | Third View 3.5.po: Third View 3.5-inch ProDOS disk image |
| [s10](#s10) | Third View 3.5.txt: Text note accompanying the Third View disk images |
| [s11](#s11) | Third View 5.25po.po: Third View 5.25-inch ProDOS disk image |
| [s12](#s12) | viewdl20.po: ViewDL 2.0 ProDOS disk image |
| [s13](#s13) | Second Sight - Pinouts.doc: Word document titled "VGA Cable Pinouts": the VGA and RGB cables, from the card's IDC header pins to the D-sub... |
| [s14](#s14) | Second Sight - Concepts.pdf: "Second Sight Programmer's Library Documentation", July 14, 1995; this part is "Basic and Introductory Concepts" |
| [s15](#s15) | Second Sight - Firmware.pdf: "SecondSight VGA Low-Level Command Interface & Firmware Documentation", August 10, 1995 |
| [s16](#s16) | Second Sight - Manual.pdf: The card's manual, June 21, 1995 (scanned) |
| [s17](#s17) | Second Sight - Summary.pdf: Two-page list of Sequential's programmer documents and software, each with a one-line description: "Second Sight... |
| [s18](#s18) | Second Sight VGA Card - Back.jpg: Rear view of the 1995 production board |
| [s19](#s19) | Second Sight VGA Card - Box.jpg: Box for the 1995 production board |
| [s20](#s20) | Second Sight VGA Card - Front.jpg: Front view of the 1995 production board |
| [s21](#s21) | Second Sight VGA Card - Front Blank.jpg: Front of a bare 1995 production board, no parts fitted |
| [s22](#s22) | Second Sight VGA Card - RGB connector.jpg: The RGB connector of the 1995 production board |
| [s23](#s23) | Second Sight VGA Card - VGA connector.jpg: The VGA connector of the 1995 production board |
| [s24](#s24) | isplsi1016_BE8C.bin: Lattice ispLSI1016 (U7) JEDEC fuse file read with Max Loader, QF15360, checksum BE8C |
| [s25](#s25) | ROM_BEEF.bin: 27C1000 EPROM dump, label "rev. 1.4-BEEF", byte sum $BEEF |
| [s26](#s26) | Second Sight - Schematics.pdf: Prototype schematic "discQUEST VGA Board", Rev x, 4/28/94, 5 sheets, CCITT G4 scans |
| [s27](#s27) | ROM_BEEF.asm: Third-party IDA disassembly of ROM_BEEF.bin with partial annotations |
| [s28](#s28) | Second-Sight-Card-API.md: Host protocol notes derived from VGALOW.ASM and the disassembly (third party) |
| [s29](#s29) | VGALOW.ASM: VGALOW.ASM from sslib082696.po with CR line ends changed to LF: the low-level routines of the Second Sight VGA Library ("Low-level VGA... |
| [s30](#s30) | VGA.H: VGA.H from sslib082696.po with CR line ends changed to LF: the library header with the status record and vga_mode_rec layout |
| [s31](#s31) | VGALIB.C: VGALIB.C from sslib082696.po with CR line ends changed to LF: the library's C routines |
| [s32](#s32) | NOTES: NOTES from sslib082696.po with CR line ends changed to LF: the library's dated change notes, 7 July 1995 to 26 August 1996 |
| [s33](#s33) | VGA.Lib.s: "Bibliotheque des appels SecondSight", (c) 1995 Brutal Deluxe: Brutal Deluxe's own library of the card's commands for the Merlin 16+... |
| [s34](#s34) | OTI-087_Feb1993.pdf: Oak OTI-087 databook, a separate 300 dpi scan of the same document; also lacks printed pages 31-32 |
| [s35](#s35) | OAK.TXT: VGA register notes for Oak chips (VGADOC), covering OTI-087 index $00 and $02 |
| [s36](#s36) | btl481a_c.pdf: Brooktree Bt481A RAMDAC datasheet, document L481A_C |
| [s37](#s37) | ispLSI1016_datasheet.pdf: Lattice ispLSI1016 datasheet (architecture, pinouts) |
| [s38](#s38) | 1994_Lattice_Handbook.pdf: Lattice 1994 handbook: ispLSI 1000 family architecture, GLB, clock distribution |
| [s39](#s39) | um0050.pdf: Zilog Z8018x Family MPU User Manual UM0050 (UM005004-0918): Z8S180 registers, DMA, wait states (DCNTL tables 3 and 4), MMU |
| [s40](#s40) | Second.Sight.Info.txt: "SecondSight SVGA Board Specifications & Features" with "Common Questions and Answers", from Sequential Systems, about 1994-95 |
| [s41](#s41) | SecondSight.Card.INFO.txt: "SecondSight Card INFO": owners' messages "Compiled from the A2 Delphi forum", 10/8/98 |
| [s42](#s42) | comp.sys.apple2-faq-part13.txt: comp.sys.apple2 FAQ part 13: Apple II slot pin meanings per machine |
| [s43](#s43) | tn-iigs-068.html: Apple IIgs Technical Note #68: M2SEL, M2B0 timing, RDY and DMA on IIgs slots |
| [s44](#s44) | Apple Schematics: Second Sight VGA Schematic |
| [s45](#s45) | Apple Video Docs: Second Sight VGA Manual v1 |
| [s46](#s46) | Apple Video Docs: Second Sight VGA ProgLib |
| [s47](#s47) | Brutal Deluxe Software: Second Sight page |
| [s48](#s48) | jawaidbazyar2/secondsight |
| [s49](#s49) | eventcatcher/startrack: PLD Design |
| [s50](#s50) | Lattice patent describing the 192 x 80 ispLSI JEDEC array layout |
| [s51](#s51) | Lattice routing-pool patent |
| [s52](#s52) | Lattice patent on PLD resource allocation |
| [s53](#s53) | Scanned Apple IIgs technical notes 65-79 |
| [s54](#s54) | Zilog Z8S180/Z8L180 specification |
| [s55](#s55) | Lattice ispLEVER Classic licensing |
| [s57](#s57) | Oak VGA BIOS for the OTI-087, Paradise TBv1.01B |
| [s58](#s58) | Oak VGA87 BIOS TEv1.02 |
| [s59](#s59) | Oak OTI-087 Product Overview, August 1992, 16 pages |
| [s60](#s60) | Oak Technology video FAQ |
| [s61](#s61) | Programmer's Guide to the EGA, VGA, and Super VGA Cards, 3rd edition (1994), chapter 25 |
| [s62](#s62) | Zilog Z8S180 product specification |
| [s63](#s63) | XFree86 3.3.6 Oak driver |
| [s64](#s64) | OTI-64107/64105 Spitfire Preliminary Specification |
| [s66](#s66) | GAL16V8 and PEEL18CV8 data sheets |
| [s67](#s67) | Oak packed-pixel mode tables in XFree86, svgalib and the Oak BIOS |
| [s68](#s68) | IBM VGA XGA Technical Reference Manual (preliminary draft, 19 May 1992) |
| [s69](#s69) | Oak Windows 3.1 drivers for the OTI-087X (87xwin.zip, 1993) |
| [s70](#s70) | GenieLamp A2, December 1995: "NEW SECONDSIGHT ROM" |
| [s71](#s71) | comp.sys.apple2 thread on the Second Sight ROM upgrade (February 1996) |
| [s72](#s72) | comp.sys.apple2 thread "Need info on Second Sight card" (June 1996) |
| [s73](#s73) | secondsight.rgb display note (Iowa archive) |
| [s74](#s74) | GEnie A2 message "Second Sight software" (October 1998) |
| [s75](#s75) | 1992 Lattice pLSI and ispLSI Data Book and Handbook |
| [s76](#s76) | Lattice pDS+ Fitter User Manual (December 1994) |
| [s77](#s77) | IBM PC AT Technical Reference (6183355, March 1986) |
| [s78](#s78) | Apple IIgs Hardware Reference, 2nd edition |
| [s79](#s79) | Oak OTI-087X DOS driver kit (87xdos.zip, 1993-94) |
| [s80](#s80) | Hitachi HD64180 User's Manual (October 1985) |
| [s81](#s81) | GS FlicSS 0.7 (Neon Software, Michael Searl, 1996) |
| [s82](#s82) | Apple II File Type Note $C1/$0002, Super Hi-Res 3200 color screen image (September 1990) |
| [s83](#s83) | Double Lo-Res Graphics |
| [s84](#s84) | Elnec device page: Lattice ispLSI1016 [PLCC44] |
| [s85](#s85) | Lattice 1996 Data Book: pDS software (section 6) and ISP Architecture and Programming (section 8) |
| [s86](#s86) | ispLSI and pLSI 1016 data sheet (1996 ISP Encyclopedia, February 1997) |
| [s87](#s87) | Lattice programming cable user's guides (UG48 rev 24.3, November 2011; FPGA-UG-02042-26.6, November 2023) |
| [s88](#s88) | Lattice answer 6212: cables for 5 V devices |
| [s89](#s89) | Using Proprietary Lattice ISP Devices (Lattice, August 2001) |
| [s90](#s90) | Third-Party Programmer Support for Lattice Devices (Lattice, Rev 5.00, November 2008) |
| [s91](#s91) | Xeltek: Programming Lattice devices on Xeltek programmers |
| [s92](#s92) | XGecu T56 device support list (software V13.16, 17 March 2026) |
| [s93](#s93) | ispLEVER Classic 1.6 Installation Notice (Lattice, September 2012) |
| [s94](#s94) | ispCODE v5.001 (Lattice, 1997), RISC OS port by Theo Markettos (2000) |
| [s95](#s95) | Lattice pLSI and ispLSI Data Book Supplement (September 1992) |
| [s96](#s96) | Lattice software licensing table |
| [s97](#s97) | ispLSI 1016EA Data Sheet (Lattice, November 2007) |
| [s98](#s98) | Apple IIgs Technical Note #63: Master Color Values |
| [s99](#s99) | 1996 Lattice ISP Synario Starter Software and ISP Encyclopedia (CD-ROM) |
| [s100](#s100) | wwerst/EE52: DRAM controller for the ispLSI1016E |
| [s101](#s101) | xpessoles PTSI designs for the ispLSI1016 |
| [s102](#s102) | a2fpga/a2fpga_core (A2FPGA Multicard) |
| [s103](#s103) | Sipeed Tang Nano 20K |
| [s104](#s104) | Y80e |
| [s105](#s105) | mmu180 |
| [s106](#s106) | ao486 |
| [s107](#s107) | NESTang |
| [s108](#s108) | Second Sight owner's photos, r/apple2 (2021) |
| [s109](#s109) | Second Sight photo, Applefritter (2026) |
| [s110](#s110) | Apple TIL01930: AppleColor RGB Monitor specifications |
| [s111](#s111) | Adapting Apple's RGB Color Monitor for Analogue & MiSTer (2026) |
| [s112](#s112) | Oak Technology graphics drivers page (1997) |
| [s113](#s113) | Oak Windows 3.1 drivers for the OTI-087B (87bwin.zip, 1993) |
| [s114](#s114) | Oak Windows NT 3.1 driver for the OTI-087 (87winnt.zip, 1993) |
| [s115](#s115) | EDN, 3 February 1992: "Graphics IC quintuples Windows performance" |
| [s116](#s116) | Oak OTI-087B DOS driver kit (87bdos.zip, 1993-94) |
| [s117](#s117) | WHATVGA 2.00 documentation (Finn Thoegersen, 29 September 1995) |
| [s118](#s118) | AVANCE.TXT: VGADOC register notes for Avance Logic chips |
| [s119](#s119) | IBM patent EP0422300B1, "Display system with graphics cursor" (filed 1989) |
| [s120](#s120) | IBM PS/2 Hardware Interface Technical Reference, Video Subsystem (October 1990) |
| [s121](#s121) | VESA Display Monitor Timing Standard, version 1.0, revision 10 |
| [s122](#s122) | VOGONS report: CRT Terminator RNG test on an OTI-087X card (22 August 2023) |
| [s123](#s123) | CRT Terminator `RNG.CPP`, the light-pen readback test (commit 02d7048) |
| [s124](#s124) | PC Underground (Abacus, 1995) |
| [s125](#s125) | WDC W65C816S data sheet |
| [s126](#s126) | PEI timing on a real IIgs (Ian Brumby, 2021) |
| [s127](#s127) | "Accelerate Your TransWarp GS", AppleWorks Forum, March 1991 |
| [s128](#s128) | ReactiveMicro Second Sight 600-dpi front/back production-card scans |
| [s129](#s129) | Zilog, Z180 Family Questions and Answers (March 1994) |
| [s130](#s130) | "Second Sight Features", comp.sys.apple2, 8 May 1995 |
| [s131](#s131) | AMI PEEL18CV8 data sheet (February 1993) |
| [s132](#s132) | BI Technologies 627/628 series resistor networks (January 2008) |
| [s133](#s133) | Oak OTI-037 VGA controller data sheet |

## Documents

<a id="s01"></a>

### OTI-068.pdf

Oak OTI-068 dual clock synthesizer databook (April 1993), 6 pages

- **Kind:** original document.
- **Public source:** <https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Interface%20Cards/Video/Sequential%20Systems%20Second%20Sight/Datasheets/OTI-068.pdf>.

<a id="s02"></a>

### OTI-087.pdf

Oak OTI-087 local-bus VGA controller databook (Feb 1993) plus OTI-087X addendum, 79 scanned pages; printed pages 31-32 missing

The addendum, bound in right after the cover, "describes changes to the OTI-087 February
1993 databook for OTI-087X parts", so the book plus its addendum is the OTI-087X's
specification. The back cover carries Oak's document number 087C-021093-001.

- **Kind:** original document.
- **Public source:** <https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Interface%20Cards/Video/Sequential%20Systems%20Second%20Sight/Datasheets/OTI-087.pdf>.
- A second scan of the same edition, with a text layer: [s34](#s34).

<a id="s03"></a>

### VGA Registers.pdf

"VGA Registers": "A description of the standard VGA register set", one of the documents
listed in [Second Sight - Summary.pdf](#s17).

- **Kind:** original document.
- **Public source:** <https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Interface%20Cards/Video/Sequential%20Systems%20Second%20Sight/Datasheets/VGA%20Registers.pdf>.

<a id="s04"></a>

### gview.025c.po

GView 0.25c ProDOS disk image.

- **Kind:** original document.
- **Public source:** <https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Interface%20Cards/Video/Sequential%20Systems%20Second%20Sight/Disk%20Images/gview.025c.po>.

<a id="s05"></a>

### gview.025c.txt

Text note accompanying the GView 0.25c disk image.

- **Kind:** original document.
- **Public source:** <https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Interface%20Cards/Video/Sequential%20Systems%20Second%20Sight/Disk%20Images/gview.025c.txt>.

<a id="s06"></a>

### ss.source.082395.po

ProDOS disk image; the name ends in 082395 (23 August 1995). It holds Sequential's
source files: VGALOW.ASM, VGALIB.C, VGA.H, mode files, the SecondView source, the ZMAC
assembler, and the firmware's table sources and notes (MODES.S, MKTAB.C, MKCTAB.C,
FONT.TAB, FONT8.TAB, CFONT.C, INTL.FONT, HIRES.ALGO, DHIRES.ALGO, RC.TXT), which
[firmware/original](../firmware/original/README.md) copies. It does not hold the firmware
program itself.

- **Kind:** original document.
- **Public source:** <https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Interface%20Cards/Video/Sequential%20Systems%20Second%20Sight/Disk%20Images/ss.source.082395.po>.

<a id="s07"></a>

### sslib082696.po

ProDOS disk image; the name ends in 082696 (26 August 1996). It holds the Second Sight VGA
Library: VGALOW.ASM, VGALOW.MAC, VGALIB.C, VGALIB.H, VGA.H, MODES.H, SS.MODES, NOTES,
MAKEFILE and the built library LVGA.

- **Kind:** original document.
- **Public source:** <https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Interface%20Cards/Video/Sequential%20Systems%20Second%20Sight/Disk%20Images/sslib082696.po>.

<a id="s08"></a>

### SView1.0a5.po

SecondView 1.0a5 ProDOS disk image.

- **Kind:** original document.
- **Public source:** <https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Interface%20Cards/Video/Sequential%20Systems%20Second%20Sight/Disk%20Images/SView1.0a5.po>.

<a id="s09"></a>

### Third View 3.5.po

Third View 3.5-inch ProDOS disk image.

- **Kind:** original document.
- **Public source:** <https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Interface%20Cards/Video/Sequential%20Systems%20Second%20Sight/Disk%20Images/Third%20View%203.5.po>.

<a id="s10"></a>

### Third View 3.5.txt

Text note accompanying the Third View disk images.

- **Kind:** original document.
- **Public source:** <https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Interface%20Cards/Video/Sequential%20Systems%20Second%20Sight/Disk%20Images/Third%20View%203.5.txt>.

<a id="s11"></a>

### Third View 5.25po.po

Third View 5.25-inch ProDOS disk image.

- **Kind:** original document.
- **Public source:** <https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Interface%20Cards/Video/Sequential%20Systems%20Second%20Sight/Disk%20Images/Third%20View%205.25po.po>.

<a id="s12"></a>

### viewdl20.po

ViewDL 2.0 ProDOS disk image.

- **Kind:** original document.
- **Public source:** <https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Interface%20Cards/Video/Sequential%20Systems%20Second%20Sight/Disk%20Images/viewdl20.po>.

<a id="s13"></a>

### Second Sight - Pinouts.doc

Word document titled "VGA Cable Pinouts": the VGA and RGB cables, from the card's IDC
header pins to the D-sub connector pins. No author is named; its pictures were saved
with Photoshop CS2 on 2 November 2006.

- **Kind:** another author's account.
- **Public source:** <https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Interface%20Cards/Video/Sequential%20Systems%20Second%20Sight/Documentation/Second%20Sight%20-%20Pinouts.doc>.

<a id="s14"></a>

### Second Sight - Concepts.pdf

"Second Sight Programmer's Library Documentation", July 14, 1995; this part is "Basic and
Introductory Concepts"

- **Kind:** original document.
- **Public source:** <https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Interface%20Cards/Video/Sequential%20Systems%20Second%20Sight/Manuals/Second%20Sight%20-%20Concepts.pdf>.

<a id="s15"></a>

### Second Sight - Firmware.pdf

"SecondSight VGA Low-Level Command Interface & Firmware Documentation", August 10, 1995

- **Kind:** original document.
- **Public source:** <https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Interface%20Cards/Video/Sequential%20Systems%20Second%20Sight/Manuals/Second%20Sight%20-%20Firmware.pdf>.

<a id="s16"></a>

### Second Sight - Manual.pdf

The card's manual, June 21, 1995 (scanned)

- **Kind:** original document.
- **Public source:** <https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Interface%20Cards/Video/Sequential%20Systems%20Second%20Sight/Manuals/Second%20Sight%20-%20Manual.pdf>.

<a id="s17"></a>

### Second Sight - Summary.pdf

Two-page list of Sequential's programmer documents and software, each with a one-line
description: "Second Sight Low-Level Commands Docs", "Second Sight VGA Library Docs", "VGA
Registers", the Oak OTI-087 and OTI-068 manuals, the schematic, and "Software" (the
SecondView source, the Second Sight VGA Library and a Z80 assembler and disassembler).
The second page gives where library updates could be downloaded.

- **Kind:** original document.
- **Public source:** <https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Interface%20Cards/Video/Sequential%20Systems%20Second%20Sight/Manuals/Second%20Sight%20-%20Summary.pdf>.

<a id="s18"></a>

### Second Sight VGA Card - Back.jpg

Rear view of the 1995 production board.

- **Kind:** original document.
- **Public source:** <https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Interface%20Cards/Video/Sequential%20Systems%20Second%20Sight/Photos/Second%20Sight%20VGA%20Card%20-%20Back.jpg>.

<a id="s19"></a>

### Second Sight VGA Card - Box.jpg

Box for the 1995 production board.

- **Kind:** original document.
- **Public source:** <https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Interface%20Cards/Video/Sequential%20Systems%20Second%20Sight/Photos/Second%20Sight%20VGA%20Card%20-%20Box.jpg>.

<a id="s20"></a>

### Second Sight VGA Card - Front.jpg

Front view of the 1995 production board.

- **Kind:** original document.
- **Public source:** <https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Interface%20Cards/Video/Sequential%20Systems%20Second%20Sight/Photos/Second%20Sight%20VGA%20Card%20-%20Front.jpg>.

<a id="s21"></a>

### Second Sight VGA Card - Front Blank.jpg

Front of a bare 1995 production board, no parts fitted.

- **Kind:** original document.
- **Public source:** <https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Interface%20Cards/Video/Sequential%20Systems%20Second%20Sight/Photos/Second%20Sight%20VGA%20Card%20-%20Front%20Blank.jpg>.

<a id="s22"></a>

### Second Sight VGA Card - RGB connector.jpg

The RGB connector of the 1995 production board.

- **Kind:** original document.
- **Public source:** <https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Interface%20Cards/Video/Sequential%20Systems%20Second%20Sight/Photos/Second%20Sight%20VGA%20Card%20-%20RGB%20connector.jpg>.

<a id="s23"></a>

### Second Sight VGA Card - VGA connector.jpg

The VGA connector of the 1995 production board.

- **Kind:** original document.
- **Public source:** <https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Interface%20Cards/Video/Sequential%20Systems%20Second%20Sight/Photos/Second%20Sight%20VGA%20Card%20-%20VGA%20connector.jpg>.

<a id="s24"></a>

### isplsi1016_BE8C.bin

Lattice ispLSI1016 (U7) JEDEC fuse file read with Max Loader, QF15360, checksum BE8C

- **Kind:** original document.
- **Public source:** <https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Interface%20Cards/Video/Sequential%20Systems%20Second%20Sight/ROM%20Images/isplsi1016_BE8C.bin>.
- **Copy in this repository:** [`original/isplsi1016_BE8C.bin`](../original/isplsi1016_BE8C.bin).

<a id="s25"></a>

### ROM_BEEF.bin

27C1000 EPROM dump, label "rev. 1.4-BEEF", byte sum $BEEF

- **Kind:** original document.
- **Public source:** <https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Interface%20Cards/Video/Sequential%20Systems%20Second%20Sight/ROM%20Images/ROM_BEEF.bin>.
- **Copy in this repository:** [`original/ROM_BEEF.bin`](../original/ROM_BEEF.bin).

<a id="s26"></a>

### Second Sight - Schematics.pdf

Prototype schematic "discQUEST VGA Board", Rev x, 4/28/94, 5 sheets, CCITT G4 scans

- **Kind:** original document.
- **Public source:** <https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Interface%20Cards/Video/Sequential%20Systems%20Second%20Sight/Schematics/Second%20Sight%20-%20Schematics.pdf>.

<a id="s27"></a>

### ROM_BEEF.asm

Third-party IDA disassembly of ROM_BEEF.bin with partial annotations

- **Kind:** another author's account.
- **Public source:** <https://raw.githubusercontent.com/jawaidbazyar2/secondsight/780abcb754ce4ed516980925230ddbb4581107f0/ROM_BEEF.asm>.

<a id="s28"></a>

### Second-Sight-Card-API.md

Host protocol notes derived from VGALOW.ASM and the disassembly (third party)

- **Kind:** another author's account.
- **Public source:** <https://raw.githubusercontent.com/jawaidbazyar2/secondsight/780abcb754ce4ed516980925230ddbb4581107f0/Second-Sight-Card-API.md>.

<a id="s29"></a>

### VGALOW.ASM

VGALOW.ASM from [sslib082696.po](#s07) with CR line ends changed to LF: the low-level
routines of the Second Sight VGA Library ("Low-level VGA Board Interface Routines,
Copyright 1994, Sequential Systems")

- **Kind:** original document.
- **Public source:** <https://raw.githubusercontent.com/jawaidbazyar2/secondsight/780abcb754ce4ed516980925230ddbb4581107f0/VGALOW.ASM>.

<a id="s30"></a>

### VGA.H

VGA.H from [sslib082696.po](#s07) with CR line ends changed to LF: the library header
with the status record and vga_mode_rec layout

- **Kind:** original document.
- **Public source:** <https://raw.githubusercontent.com/jawaidbazyar2/secondsight/780abcb754ce4ed516980925230ddbb4581107f0/VGA.H>.

<a id="s31"></a>

### VGALIB.C

VGALIB.C from [sslib082696.po](#s07) with CR line ends changed to LF: the library's C
routines

- **Kind:** original document.
- **Public source:** <https://raw.githubusercontent.com/jawaidbazyar2/secondsight/780abcb754ce4ed516980925230ddbb4581107f0/VGALIB.C>.

<a id="s32"></a>

### NOTES

NOTES from [sslib082696.po](#s07) with CR line ends changed to LF: the library's dated
change notes, 7 July 1995 to 26 August 1996

- **Kind:** original document.
- **Public source:** <https://raw.githubusercontent.com/jawaidbazyar2/secondsight/780abcb754ce4ed516980925230ddbb4581107f0/NOTES>.

<a id="s33"></a>

### VGA.Lib.s

"Bibliotheque des appels SecondSight", (c) 1995 Brutal Deluxe: Brutal Deluxe's own library
of the card's commands for the Merlin 16+ assembler, not a copy of Sequential's library.
Their page calls it "Our Second Sight Library for Merlin 16+ users".

- **Kind:** another author's account.
- **Public source:** <https://www.brutaldeluxe.fr/documentation/secondsight/VGA.Lib.s>.

<a id="s34"></a>

### OTI-087_Feb1993.pdf

Oak OTI-087 databook, a separate 300 dpi scan of the same document; also lacks printed pages 31-32

74 pages with a text layer, including the OTI-087X addendum (PDF page 2) and the
back-cover document number 087C-021093-001. SHA-256
`30a261a36da4dc5bc33e1f35e0383acc91fc5b62cb55797f6d659c29fbb9a3cb`.

- **Kind:** original document.
- **Public source:** <http://bitsavers.informatik.uni-stuttgart.de/components/oakTechnology/OTI-087_Feb1993.pdf>.

<a id="s35"></a>

### OAK.TXT

VGA register notes for Oak chips (covers OTI-087 index 00h and 02h)

Third party. Its 087 entries are headed "(83/87)" and name no 087 revision; it never
mentions the OTI-087B or OTI-087X.

- **Kind:** another author's account.
- **Public source:** <http://bitsavers.informatik.uni-stuttgart.de/components/oakTechnology/OAK.TXT>.

<a id="s36"></a>

### btl481a_c.pdf

Brooktree Bt481A RAMDAC datasheet, document L481A_C

- **Kind:** original document.
- **Public source:** <http://www.pldworld.com/_hdl/1/erc.msstate.edu/www/~reese/EE4993/data_sheets/btl481a_c.pdf>.

<a id="s37"></a>

### ispLSI1016_datasheet.pdf

Lattice ispLSI1016 datasheet (architecture, pinouts)

- **Kind:** original document.
- **Public source:** <https://ftcelectronics.jp/datasheets-18/ISPLSI-1016-60LT44I.pdf>.

<a id="s38"></a>

### 1994_Lattice_Handbook.pdf

Lattice 1994 handbook: ispLSI 1000 family architecture, GLB, clock distribution

- **Kind:** original document.
- **Public source:** <https://ftpmirror.your.org/pub/misc/bitsavers/components/latticeSemiconductor/_dataBooks/1994_Lattice_Handbook.pdf>.

<a id="s39"></a>

### um0050.pdf

Zilog Z8018x Family MPU User Manual UM0050 (UM005004-0918): Z8S180 registers, DMA, wait states (DCNTL tables 3 and 4), MMU

- **Kind:** original document.
- **Public source:** <https://www.zilog.com/docs/z180/um0050.pdf>.

<a id="s40"></a>

### Second.Sight.Info.txt

"SecondSight SVGA Board Specifications & Features" with "Common Questions and Answers",
from Sequential Systems, about 1994-95

- **Kind:** original document.
- **Public source:** <http://apple2.org.za/gswv/a2zine/GS.WorldView/v1999/Sep/A2.Best.of.Usenet/Second.Sight.Info.txt>.

<a id="s41"></a>

### SecondSight.Card.INFO.txt

"SecondSight Card INFO": owners' messages "Compiled from the A2 Delphi forum", 10/8/98

- **Kind:** another author's account.
- **Public source:** <https://mirrors.apple2.org.za/apple.cabi.net/FAQs.and.INFO/CPUandMore/SecondSight.Card.INFO.txt>.

<a id="s42"></a>

### comp.sys.apple2-faq-part13.txt

comp.sys.apple2 FAQ part 13: Apple II slot pin meanings per machine

- **Kind:** another author's account.
- **Public source:** <https://ftp.cs.utoronto.ca/pub/usenet/comp.answers/apple2/faq/part13>.

<a id="s43"></a>

### tn-iigs-068.html

Apple IIgs Technical Note #68: M2SEL, M2B0 timing, RDY and DMA on IIgs slots

- **Kind:** original document.
- **Public source:** <https://apple2.gs/technotes/tn-iigs-068/>.

<a id="s44"></a>

### Apple Schematics: Second Sight VGA Schematic

archive.org copy of the [schematic](#s26), recompressed with a lower-resolution background
(no new detail).

- **Public source:** <https://archive.org/details/Second_Sight_VGA_Schematic>.

<a id="s45"></a>

### Apple Video Docs: Second Sight VGA Manual v1

archive.org copy of the [manual](#s16) (identical file).

- **Public source:** <https://archive.org/details/Second_Sight_VGA_Manual_v1>.

<a id="s46"></a>

### Apple Video Docs: Second Sight VGA ProgLib

archive.org scan of the [Programmer's Library Documentation](#s14), July 14, 1995.

- **Public source:** <https://archive.org/details/Second_Sight_VGA_ProgLib>.

<a id="s47"></a>

### Brutal Deluxe Software: Second Sight page

Brutal Deluxe's copies of the Manual, Summary, Concepts, Firmware and Schematics PDFs and
the OTI-068 and OTI-087 databooks, and their own [Merlin 16+ library](#s33).

- **Public source:** <https://www.brutaldeluxe.fr/documentation/secondsight.html>.

<a id="s48"></a>

### jawaidbazyar2/secondsight

GitHub repository holding the [disassembly](#s27), the [API notes](#s28) and the library
files [VGALOW.ASM](#s29), [VGA.H](#s30), [VGALIB.C](#s31) and [NOTES](#s32) (pinned
commit).

- **Public source:** <https://github.com/jawaidbazyar2/secondsight/tree/780abcb754ce4ed516980925230ddbb4581107f0>.

<a id="s49"></a>

### eventcatcher/startrack: PLD Design

The startrack project's 20 ispLSI1016 designs (JEDEC fuse file plus LDF source each), used
to learn the fuse encoding; pinned commit.

- **Public source:** <https://github.com/eventcatcher/startrack/tree/42154dfddd8188a1a7317720ae5ffae54dcb77b6/sources/hardware/PLD%20Design>.

<a id="s50"></a>

### Lattice patent describing the 192 x 80 ispLSI JEDEC array layout

Lattice patent describing the 192 x 80 ispLSI JEDEC array layout

- **Copy in this repository:** [references/patents/US5635855.pdf](../references/patents/US5635855.pdf)
  (US patents are public domain).
- **Public source:** <https://patents.google.com/patent/US5635855A/en>; PDF <https://patentimages.storage.googleapis.com/33/ce/a9/d3746de2383e1e/US5635855.pdf>.

<a id="s51"></a>

### Lattice routing-pool patent

Lattice routing-pool patent (fixed source-to-input slot routing)

- **Copy in this repository:** [references/patents/US5204556.pdf](../references/patents/US5204556.pdf)
  (US patents are public domain).
- **Public source:** <https://patents.google.com/patent/US5204556A/en>; PDF <https://patentimages.storage.googleapis.com/f4/d7/c7/d49e9061cb3293/US5204556.pdf>.

<a id="s52"></a>

### Lattice patent on PLD resource allocation

Lattice patent on PLD resource allocation

- **Copy in this repository:** [references/patents/US5128871.pdf](../references/patents/US5128871.pdf)
  (US patents are public domain).
- **Public source:** <https://patents.google.com/patent/US5128871A/en>; PDF <https://patentimages.storage.googleapis.com/7c/e3/f7/9d947bccfcf7de/US5128871.pdf>.

<a id="s53"></a>

### Scanned Apple IIgs technical notes 65-79

Scanned Apple IIgs technical notes 65-79 (includes #68)

- **Public source:** <https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Computers/Apple%20IIGS/Documentation/Apple%20IIGS%20Technical%20Notes%2065-79.pdf>.

<a id="s54"></a>

### Zilog Z8S180/Z8L180 specification

Zilog Z8S180/Z8L180 specification (third-party copy)

- **Public source:** <https://pic.hallikainen.org/techref/zilog/z180/s180l1~1.pdf>.

<a id="s55"></a>

### Lattice ispLEVER Classic licensing

Lattice licensing table: ispLEVER Classic support for ispLSI needs a paid subscription

- **Public source:** <https://www.latticesemi.com/en/Support/Licensing>.

<a id="s57"></a>

### Oak VGA BIOS for the OTI-087, Paradise TBv1.01B

Oak VGA BIOS for the OTI-087, Paradise TBv1.01B (10 Mar 1993), 32 KB. Reads extended index 00 bit 1 (087 vs 083) and index 02 bits 2:1 (memory size). Download is a zip; the inner ROM oakoti087wdparadise.BIN has SHA-256 9df355978ca8de7786b6368cd6802fe2de776f4686d8ef55330c1f535ec58c4a

Its version is 1.01: Oak's own table gives BIOS versions 1.0 to 1.03 to the OTI-087B
([s112](#s112)), and its "B" matches Oak's 087B letter. It has no ext $01 test, so this is
OTI-087B code.

- **Public source:** <https://web.archive.org/web/20241110191423id_/https://vgamuseum.info/index.php/companies/item/download/1570_5b330f99f81a6a6b3b0efc7d603cf672>.

<a id="s58"></a>

### Oak VGA87 BIOS TEv1.02

Oak VGA87 BIOS TEv1.02 (30 Apr 1993), 32 KB, same index 00/02 code. Download is a zip; the inner ROM OTI087X.VBI has SHA-256 c7d4508f28465ea226bd132c7028731cb05af11d9f96b91a25cdd92654c60b27

The file name OTI087X.VBI is the download site's. This BIOS serves the 087B and later
chips, the 087X included: a helper at file offset $1FD6 reads ext $01 bits 7-4, and the
code at $2B93 and $39B5 runs extra steps only when they are 0 (an 087B). Its "E" is the
letter Oak's installers give the 087X package (WIN31E, [s79](#s79)). Oak's driver page gives
version numbers 1.0 to 1.03 to the 87B ([s112](#s112)); this BIOS's code shows it also
handles later revisions. No Oak BIOS of version 2.0 or later has been found.

- **Public source:** <https://web.archive.org/web/20241107152017id_/http://www.vgamuseum.info/index.php/home/item/download/1875_094ce2e92b88976b1c472af2ef15d881>.

<a id="s59"></a>

### Oak OTI-087 Product Overview, August 1992, 16 pages

Oak OTI-087 Product Overview, August 1992, 16 pages (straps, pins, modes; no extended-register chapter). SHA-256 93c1a266f0bd7d804ab7b08d9c21bf6c635527df67c1611d452d5eda9e6d0909

It is older than the February 1993 databook and its OTI-087X addendum, and names no
revision. Its feature list (p1) has no hardware cursor, no feature connector and no
refresh types; the February 1993 databook adds all three.

- **Public source:** <https://web.archive.org/web/20260616122232id_/https://vgamuseum.info/index.php/companies/item/download/449_8328689f263e5a3135bb9d36ef57beaa>.

<a id="s60"></a>

### Oak Technology video FAQ

Oak Technology video FAQ ("Last updated April 1996", archived 1998): BIOS 1.0x = OTI-87B,
2.0x = OTI-87X. Oak shipped separate driver sets for the two, because the 87X has "several
significant enhancements". The FAQ does not list them.

- **Public source:** <https://web.archive.org/web/19981202060820id_/http://poppy.oaktech.com/vidfaq.html>.

<a id="s61"></a>

### Programmer's Guide to the EGA, VGA, and Super VGA Cards, 3rd edition (1994), chapter 25

Programmer's Guide to the EGA, VGA, and Super VGA Cards, 3rd ed. 1994, chapter 25 (Oak): status register table (secondary)

Third party (Richard Ferraro). It covers "the 087" and names no revision; it never
mentions the OTI-087B or OTI-087X. Section 25.4: "The Product Identification Register
returns a 1 if the chip is a 087 chip." Listing 25.4 identifies an 087 by writing $0A
to ext $24 and reading it back from ext $25.

- **Public source:** <https://archive.org/details/programmersguidetotheegavgaandsupervgacardsbyrichardf.ferraro19943rdedition>.

<a id="s62"></a>

### Zilog Z8S180 product specification

Zilog Z8S180 product specification (PLCC-68 pinout used by the netlist check)

- **Public source:** <https://www.zilog.com/docs/z180/z8s180ps.pdf>.

<a id="s63"></a>

### XFree86 3.3.6 Oak driver

Period source code: `xc/programs/Xserver/hw/xfree86/vga256/drivers/oak/` in
[XFree86 3.3.6 source part 1](http://ftp.xfree86.org/pub/XFree86/3.3.6/source/X336src-1.tgz).
Archive SHA-256: `87231766bf967c0e6174e28c6bdf50e42c0f3f6c732489e455f4c405cfc43844`.

Third party: written by Jorge Delgado (copyright 1994), not by Oak. It treats every
OTI-087 as one chip and names no revision: its probe takes ext $00 = 1 as an "oti087"
(`oak_driver.c:493-494`).

`oti87_fill.c` and `oak_colexp.s` establish the offsets-0/1 color-expansion stores.
`oak_driver.c:912-935,1058-1081` saves/restores the cursor; it never draws it.
Lines 1258-1283 choose ext $22 = $1C on local bus with BitBlt, $14 on ISA, $18
without the option. The screen-copy acceleration is disabled as unfinished.

<a id="s64"></a>

### OTI-64107/64105 Spitfire Preliminary Specification

Oak, September 1994. A later Oak design, "not downwardly compatible to any other Oak
chips" ([Ferraro](#s61) 25.1.2). Page 7-27 describes its cursor block (/8 packed-pixel
pattern addressing, /4 planar addressing, enable and bit order), and pages 7-8 and 7-9 a
CRT counter test that drives the CRT counters onto pins SD15-SD0. It shows what a later
Oak chip did; it is not a source for the OTI-087X's own behavior.

[OAK.TXT](#s35) (VGADOC, lines 190-196) also describes the cursor layout and codes, but it
is not an Oak publication, and its preset and blink wording conflicts with OTI-087
pp45-46, which this reference follows.

- **Kind:** original document.
- **Public source:** bitsavers: <https://ftp.mirrorservice.org/sites/www.bitsavers.org/components/oakTechnology/OTI-64107_64105_Spitfire_Preliminary_Specification_199409.pdf>.

<a id="s66"></a>

### GAL16V8 and PEEL18CV8 data sheets

In registered mode the GAL16V8's pin 11 is /OE, with an internal pull-up; the AMI/ICT
PEEL18CV8 has an ordinary input at pin 11 and an output enable for each macrocell, and
74 product terms: eight per output, eight enables, preset and clear. These are the facts
behind the [PLD identifications](07-glue-logic.md#the-parts). Pages: [`data/netlist/SOURCES.md`](../data/netlist/SOURCES.md#package-pinouts-used).

- **Kind:** original document.

<a id="s67"></a>

### Oak packed-pixel mode tables in XFree86, svgalib and the Oak BIOS

How Oak's TEv1.02 BIOS and the third-party XFree86 and svgalib drivers
program the OTI-087's packed 256-color modes. None of them names an 087 revision; svgalib
says it supports "the OTI-087 (all variants)".

- **XFree86 3.3.2.3a**, `vga256/drivers/oak/oak_driver.c` lines 1145 and 1152 (OTI-087
  branch: attribute mode $01, ext $21 = $04) and `vga256/vga/vgaHW.c` lines 1064-1090
  (offset = width / 16, CRTC $14 = $00, $17 = $C3).
  Source archive: <https://snapshot.debian.org/archive/debian-archive/20090802T004153Z/debian/dists/slink/main/source/x11/xfree86_3.3.2.3a.orig.tar.gz>.
- **svgalib 1.4.3**, `src/oak.regs` (640 x 480, 800 x 600, 1024 x 768 x 256 and
  640 x 480 x 32K: offset x 16 = line bytes, $14 bit 6 = 0, $17 bit 6 = 1, attribute $01,
  mode select $04) and `src/oak.c`.
  Source archive: <http://archive.debian.org/debian/pool/main/s/svgalib/svgalib_1.4.3.orig.tar.gz>.
- **Oak VGA87 BIOS TEv1.02**: standard mode 13h table at file offset $1172 (ext $21 = $00);
  packed 640 x 480 and 640 x 400 tables at $1472 and $1B72. [Download](#s58)

<a id="s68"></a>

### IBM VGA XGA Technical Reference Manual (preliminary draft, 19 May 1992)

IBM's register reference for the standard VGA. Used for the standard behavior the OTI-087
copies: sequencer memory mode and chain-4 map selection (p2-54), CRTC doubleword and
count-by-4 (p2-72), word/byte mode (p2-74), and the CRT memory address mapping figure
(p2-75).

- **Public source:** bitsavers: <https://www.bitsavers.org/pdf/ibm/pc/cards/IBM_VGA_XGA_Technical_Reference_Manual_May92.pdf>.

<a id="s69"></a>

### Oak Windows 3.1 drivers for the OTI-087X (87xwin.zip, 1993)

Oak's own display drivers for the OTI-087X, "OAK-87, DISTev2.2", copyright 1993. Oak's
driver page lists this kit under OTI-087x ([s112](#s112)). `STD8_HC.DRV` (the
hardware-cursor driver) shows how Oak itself programs the pixel mask, the 64-bit latch
and the hardware cursor. Read by disassembly only.

- The 256-color drivers announce themselves as "OTI-087C". On any other chip they stop
  with "This is not a(n) OTI-087 (rev.C or later) VGA adapter." Their check
  (`STD8_SC.DRV` file offsets $8FA2-$8FD9): ext $11 must read back what was written,
  ext $00 must read 1 or 2, and bits 7-4 of ext $01 must not all be 0.
- Only this kit has the hardware-cursor drivers (`STD8_HC`, `LIN8_HC`). Every other file
  matches the OTI-087B kit ([s113](#s113)) byte for byte, except the two 256-color
  software-cursor drivers and the INF file.
- `STD8_SC.DRV` SHA-256 `544d307b45d66dcab6bdd91f242086f3ef51e672f161144d99fbdfa865686025`;
  zip SHA-256 `6db15c87142c0dcc33076f589e25e3d3210c9e00363062c0e0b31d5e2a325dfe`.

- **Public source:** Wayback copy of oaktech.com: <https://web.archive.org/web/19961112200047id_/http://www.oaktech.com:80/zipfiles/87xwin.zip>.
  `STD8_HC.DRV` `523f60c849db7f865fce075e80a890aa1f5dbc3fb243d5b0c7e950525f6d5fa9`.

<a id="s70"></a>

### GenieLamp A2, December 1995: "NEW SECONDSIGHT ROM"

Owners' messages from the GEnie Apple II round tables. One installs the new chips and
reports the EPROM label "rev 1.4-BEEF"; another writes that with the new v1.4-BEEF chips
"the Double Hi-Res display causes a freeze".

- **Kind:** another author's account.
- **Public source:** file `GL_1995/ALMP9512.TXT` in the
  GenieLamp A2 archive: <https://mirrors.apple2.org.za/ftp.apple.asimov.net/documentation/magazines/misc/GenieLamp_a2.zip>.

<a id="s71"></a>

### comp.sys.apple2 thread on the Second Sight ROM upgrade (February 1996)

Quotes Sequential's reply to an upgrade order of 24 November 1995: the upgrade needs two
chips replaced; there is no charge if the old chips are returned (a $20 deposit is held
meanwhile), and overseas owners can buy the new chips for $15.

- **Kind:** another author's account.
- **Public source:** Google Groups: <https://groups.google.com/g/comp.sys.apple2/c/jDWueKsm_Uc/m/XPD5j08aJ1QJ>.

<a id="s72"></a>

### comp.sys.apple2 thread "Need info on Second Sight card" (June 1996)

Owners describe the card on real hardware: it does not show 3200-color pictures "because
it doesn't support scan-line interrupts", it does not support Super Hi-Res fill mode,
games at 20 frames per second or slower look right, and Task Force plays well.

- **Kind:** another author's account.
- **Public source:** Google Groups: <https://groups.google.com/g/comp.sys.apple2/c/PUMT4QAprbA/m/cu6VL4a1vNMJ>.

<a id="s73"></a>

### secondsight.rgb display note (Iowa archive)

An owner's description of the card on a real IIgs: animation is choppy and skips frames,
the scrolling background of the game Rastan is blank, and double hires always locks up the card.

- **Kind:** another author's account.
- **Public source:** file `MiscInfo/Video/secondsight.rgb` in the
  Iowa Apple II archive mirror: <https://mirrors.apple2.org.za/ground.icaen.uiowa.edu/MiscInfo/Video/secondsight.rgb>.

<a id="s74"></a>

### GEnie A2 message "Second Sight software" (October 1998)

The message lists Second Sight-aware software, including SSRomFix, a
"System INIT which fixes a bug in SS ROM", and a CDA that gives the card the IIgs border
color.

- **Kind:** another author's account.
- **Public source:** a2central.com GenieLamp archive: <https://a2central.com/lamp/tlmp9810/>.

<a id="s75"></a>

### 1992 Lattice pLSI and ispLSI Data Book and Handbook

Lattice's 1992 data book. Page 4-7 (I/O cell) says the global reset clears the registers on
power-up.

- **Kind:** original document.
- **Public source:** <https://archive.org/details/bitsavers_latticeSem1992LatticepLSIandispLSIDataBookandHandb_36425546>.

<a id="s76"></a>

### Lattice pDS+ Fitter User Manual (December 1994)

Lattice's fitter manual. Page 3-22 describes the `Y1_AS_RESET` option (default on: pin
Y1/RESET is the global reset; off: it is the Y1 clock and no register can be globally reset);
page 3-21 says the RESET pin's pull-up is always on.

- **Kind:** original document.
- **Public source:** <https://ftpmirror.your.org/pub/misc/bitsavers/components/latticeSemiconductor/Lattice_pDS+_Fitter_Users_Manual_199412.pdf>.

<a id="s77"></a>

### IBM PC AT Technical Reference (6183355, March 1986)

IBM's AT reference. The system-board description of "I/O CH RDY" says a slow device should
hold the line low for no more than 2.5 microseconds.

- **Kind:** original document.
- **Public source:** <https://archive.org/details/bitsavers_ibmpcat618ferenceMar86_25829277>.

<a id="s78"></a>

### Apple IIgs Hardware Reference, 2nd edition

Apple's IIgs hardware manual: the Screen Color register ($C022), color fill mode, the ADB
keyboard reset and the expansion-slot signals. Its double hires section (pp87-88, Table
4-16) gives the 16 colors' dot patterns and says the color comes from a four-dot window
that moves one dot at a time.

- **Kind:** original document.
- **Public source:** <https://downloads.reactivemicro.com/Apple%20II%20Items/Documentation/Manuals/IIgs/IIgs%20Hardware%20Reference.pdf>.

<a id="s79"></a>

### Oak OTI-087X DOS driver kit (87xdos.zip, 1993-94)

Oak's DOS utilities and drivers for the 087X, including `MONITOR.EXE`, whose READ.ME says it
saves the chosen refresh rates to the card's EEPROM.

Every program in it is byte-for-byte the same as in the OTI-087B DOS kit ([s116](#s116))
except `INSTALL.EXE` (version 2.2 here, 1.6 there). Both installers hold Oak's revision
table: they read ext $00 and name the chip only when it reads 1 (file offset $2B8B), then
read ext $01 bits 7-4 (offsets $2BB1-$2C02) and title themselves "087B Driver Install" for
0, "087D" for 1, "087X" for 2 and "089" for 3 (title strings at $80E7-$8146). `INSTALL.EXE`
SHA-256 `609752e6c6cbd429563f22649e705f7cfedf286fce4b4cf805b27c666f9fd39c`; zip SHA-256
`298550040f81b72d5f988459ec23f88e914102f678c9c8bcda84dde5c1126dd3`.

- **Kind:** original document.
- **Public source:** <https://web.archive.org/web/1997id_/http://www.oaktech.com/zipfiles/87xdos.zip>.

<a id="s80"></a>

### Hitachi HD64180 User's Manual (October 1985)

Hitachi's manual for the HD64180, the processor the Z180 copies. Page 88, "PRT Operation
Notes" (3), gives the level of the TOUT pin after TOC1-TOC0 select the timer output, a
table that the Zilog UM0050 edition omits.

- **Kind:** original document.
- **Public source:** <https://ftp.mirrorservice.org/sites/www.bitsavers.org/components/hitachi/64180/HD64180_Users_Manual_Oct85.pdf>.

<a id="s81"></a>

### GS FlicSS 0.7 (Neon Software, Michael Searl, 1996)

An FLI/FLC animation player for the card, by GView's author. Its readme says
"320x200x256 does not work properly on the SecondSight", so it plays everything in
640 x 400 x 256 mode. Its data fork holds the old library upload routine.

- **Kind:** original document.
- **Public source:** <https://mirrors.apple2.org.za/apple2.caltech.edu/graphics/animprogs/gs.flicss.shk>.

<a id="s82"></a>

### Apple II File Type Note $C1/$0002, Super Hi-Res 3200 color screen image (September 1990)

Apple Developer Technical Support's note on the 3200-color picture
format: 200 color tables, one per scan line, and a display program that "must watch the
Mega II video counters and change the color tables in the palette for future scan lines".

- **Kind:** original document.
- **Public source:** <https://www.appleoldies.ca/graphics/shr/ft_c1.0002_3200_color.pdf>.

<a id="s83"></a>

### Double Lo-Res Graphics

A description of Apple IIe double lores. It states that the even columns,
stored in the auxiliary bank, hold their colors "rotated one bit to the right" compared
with the main-bank colors.

- **Kind:** another author's account.
- **Public source:** <https://llx.com/Neil/a2/dlowres.html>.

<a id="s84"></a>

### Elnec device page: Lattice ispLSI1016 [PLCC44]

Elnec's programmer support list for the ispLSI1016 in the 44-pin PLCC. It names the
BeeProg and BeeHive programmers that program it and the PLCC-44 ZIF adapter each needs,
for example the BeeProg2AP with the AP1 PLCC44/2 ZIF module (71-1500A) and the BeeProg4
with the DIL44/PLCC44 ZIF adapter (70-0041).

- **Kind:** original document.
- **Public source:** <https://www.elnec.com/en/device/Lattice/ispLSI1016%20%5BPLCC44%5D/>.

<a id="s85"></a>

### Lattice 1996 Data Book: pDS software (section 6) and ISP Architecture and Programming (section 8)

Section 6, pp6-7 to 6-11, describes Lattice's pDS and pDS+ design software: its LDF
design-file keywords, operators and dot extensions (p6-8), its system requirements and
parallel-port key, and the device programmers that supported the ispLSI and pLSI parts
in 1996 (p6-10).

Section 8 is Lattice's full description of programming its ISP devices,
written for anyone building their own programmer: the state machine, the instruction set (Table 4), the timing for the
ispLSI 1000 family (Table 6), the address and data register sizes (Table 8, including the
ispLSI1016E's 17,600 fuses), the mapping of JEDEC fuses to rows, and the programming
sequence (pp8-1 to 8-20). The same section states the LSB-first order for the ispGAL22V10
and ispGDS instruction registers.

Section 2 has the 1000/1000E family description (I/O cell options and output slew, pp2-11
and 2-17; output enable, p2-19) and the ispLSI and pLSI 1016E data sheet (pp2-47 to 2-58),
used for the 1016E's slew, output enable and pin functions.

- **Kind:** original document.
- **Public source:** <http://bitsavers.informatik.uni-stuttgart.de/components/latticeSemiconductor/_dataBooks/1996_Lattice_Data_Book.pdf>.

<a id="s86"></a>

### ispLSI and pLSI 1016 data sheet (1996 ISP Encyclopedia, February 1997)

Lattice's 1016 data sheet in its 1996 form: pin table, speed grades and part numbers, the
device identifier ($01), the shift-register layout (address register bits 95 to 0, data
register high-order bits 0-79 and low-order bits 80-159), and 10,000 erase-and-program
cycles for the ispLSI against 100 for the pLSI.

- **Kind:** original document.
- **Public source:** <https://docs.rs-online.com/42cc/0900766b800266b7.pdf>.

<a id="s87"></a>

### Lattice programming cable user's guides (UG48 rev 24.3, November 2011; FPGA-UG-02042-26.6, November 2023)

Lattice's guides to its download cables. The 2011 edition gives the HW-USBN-2A's 1.2-5 V
range, the flywire colors (VCC red, SDO brown, SDI orange, ispEN yellow, MODE purple, GND
black, SCLK white), the 0.01 uF capacitor on ispEN for older ISP devices, the 4.7 kOhm
pull-down on SCLK, and the rule to connect ground first to an unpowered board. The 2023
edition's feature table shows the HW-USBN-2B without 5 V support.

- **Kind:** original document.
- **Public sources:** <http://www.limpulsion.fr/upload/docs/HWUSBN2A_1.PDF> (2011);
  <https://docs.rs-online.com/c137/0900766b813a2a5f.pdf> (2023).

<a id="s88"></a>

### Lattice answer 6212: cables for 5 V devices

Lattice's support answer: "Programming devices with a 5V core requires the HW-USBN-2A USB
cable or HW-DLN-3C parallel cable"; the HW-USBN-2B programs devices with a core voltage up
to 3.3 V, and the HW-USBN-2A is obtained through Lattice's sales offices.

- **Kind:** original document.
- **Public source:** <https://www.latticesemi.com/support/answerdatabase/6/2/1/6212>.

<a id="s89"></a>

### Using Proprietary Lattice ISP Devices (Lattice, August 2001)

Lattice's application note on the five-pin programming interface of the ispLSI 1000 family:
the pins, the three-state state machine and the internal pull-up on ispEN.

- **Kind:** original document.
- **Public source:** <https://www.ic72.com/pdf_file/i/503796.pdf> (a copy; Lattice's own
  link no longer resolves).

<a id="s90"></a>

### Third-Party Programmer Support for Lattice Devices (Lattice, Rev 5.00, November 2008)

Lattice's list of approved third-party programmers. Its mature-family table marks the
"ispLSI & pLSI 1016" as supported by Advin, BPM Microsystems, Data I/O and System General.

- **Kind:** original document.
- **Public source:** <https://edge.sitecorecloud.io/latticesemi9e32-latticesemi06bb-prod9ecc-d341/media/Project/Lattice/LatticeSemi/Documents/GeneralInformation/Third-PartyProgrammerSupportforLatticeDevices.PDF?sc_lang=en>,
  linked from <https://www.latticesemi.com/en/Support/MatureAndDiscontinuedDevices/ispLSI1000>.

<a id="s91"></a>

### Xeltek: Programming Lattice devices on Xeltek programmers

Xeltek's list of Lattice devices supported on its SuperPro 6100 programmer, including
"ispLSI1016@PLCC44 [DX2044]".

- **Kind:** original document.
- **Public source:** <https://www.xeltek.com/resources/technical-articles/ic-manufacturers/programming-lattice-devices-on-xeltek-programmers/>.

<a id="s92"></a>

### XGecu T56 device support list (software V13.16, 17 March 2026)

XGecu's official list of the 40,039 devices its T56 universal programmer supports. Under
Lattice it lists only GAL16V8, GAL20V8 and GAL22V10 parts; the T48 and TL866II lists have
no ispLSI devices either.

- **Kind:** original document.
- **Public source:** <http://www.xgecu.com/MiniPro/T56_List.txt>.

<a id="s93"></a>

### ispLEVER Classic 1.6 Installation Notice (Lattice, September 2012)

Lattice's installation notice for its ispLEVER Classic design software. It lists the
ispLSI 1000 family among the supported devices and describes the bundled ispVM System
programming software and the parallel-port and USB cable drivers.

- **Kind:** original document.
- **Public source:** <https://www.latticesemi.com/api/document/download?id=47288>.

<a id="s94"></a>

### ispCODE v5.001 (Lattice, 1997), RISC OS port by Theo Markettos (2000)

Lattice's C source for programming ISP devices from a PC or an embedded system, released
for customers to use and redistribute, in a port that keeps Lattice's code unchanged. It
shows the waveforms Lattice's tools generate, for example the 1 ms wait with MODE and SDI
high after an erase pulse.

- **Kind:** original document (Lattice's code).
- **Public source:** <http://web.archive.org/web/2020id_/http://www.chiark.greenend.org.uk/~theom/riscos/acornisp.zip>,
  listed on <http://www.chiark.greenend.org.uk/~theom/riscos/othersoft.html>.

<a id="s95"></a>

### Lattice pLSI and ispLSI Data Book Supplement (September 1992)

Lattice's 1992 data book for the first pLSI and ispLSI parts. Section 2 describes the
programming mode: ispEN low puts every other pin in high impedance with internal pull-ups,
and Lattice recommends holding the RESET pin low while programming (pp2-14 to 2-24).

- **Kind:** original document.
- **Public source:** <http://bitsavers.informatik.uni-stuttgart.de/components/latticeSemiconductor/_dataBooks/1992_Lattice_pLSI_and_ispLSI_Data_Book_Supplement.pdf>.

<a id="s96"></a>

### Lattice software licensing table

Lattice's table of which device families each design tool supports and under what
license. For ispLEVER Classic, the row "ispMACH ..., ispGDX, ispLSI, ispXPGA-E" is marked
SUBSCRIPTION; no family is free in that tool.

- **Kind:** original document.
- **Public source:** <https://www.latticesemi.com/en/Support/Licensing>.

<a id="s97"></a>

### ispLSI 1016EA Data Sheet (Lattice, November 2007)

Lattice's data sheet for the ispLSI 1016EA, the successor of the 1016E. The 44-pin PLCC
pin table puts the JTAG pins TDI, TDO, TCK and TMS on pins 14, 24, 33 and 36, and the
output-driver supply VCCIO on pin 13.

- **Kind:** original document.
- **Public source:** <https://www.latticesemi.com/Support/MatureAndDiscontinuedDevices/ispLSI1000EA>
  (data sheet link on that page).

<a id="s98"></a>

### Apple IIgs Technical Note #63: Master Color Values

Apple's 12-bit RGB values (4 bits per component) for the 16 standard colors, the values
Super Hi-Res uses to match them.

- **Kind:** original document.
- **Public source:** <https://apple2.gs/technotes/tn-iigs-063/>.

<a id="s99"></a>

### 1996 Lattice ISP Synario Starter Software and ISP Encyclopedia (CD-ROM)

Lattice's free 1996 CD-ROM. Its ISP Synario Starter Fitter (pDS+ 3.0.12, August 1996)
fits designs to the plain ispLSI1016 and to the ispLSI1016E-80, -100 and -125 with no
license key. The ispLSI1016E is unsuitable as a replacement for the card's U7 ([Do not buy](lattice-versions.md#do-not-buy)).

- **Kind:** original document.
- **Public source:** <https://archive.org/details/1996-lattice-isp-synario-starter-software-and-isp-encyclopedia>.

<a id="s100"></a>

### wwerst/EE52: DRAM controller for the ispLSI1016E

A student DRAM-controller design in ABEL for the ispLSI1016E-100LJ44, with four revisions
of its fuse file and Lattice ispEXPERT 1.7 fitter report. The only public 1016E design
with its report.

- **Kind:** web page or repository.
- **Public source:** <https://github.com/wwerst/EE52>.

<a id="s101"></a>

### xpessoles PTSI designs for the ispLSI1016

Teaching designs for the ispLSI1016, with fuse files and fitter reports.

- **Kind:** web page or repository.
- **Public source:** <https://github.com/xpessoles/TP_2014_2015>.

<a id="s102"></a>

### a2fpga/a2fpga_core (A2FPGA Multicard)

The open-source core and board files of the A2FPGA Multicard, an Apple II/IIe/IIgs slot
card built on a [Tang Nano 20K](#s103) board with 720x480 HDMI output; sold by
ReActiveMicro. The A2N20v2 board files used here, at commit
`5a35b0edb0e6593b030f007da6e3156e89d133b5`:

- `boards/a2n20v2/README.md`: IIgs support through a 100-pin "a2bridge" CPLD that
  "captures and level-shifts all Apple II, //e, and IIgs signals including the M2SEL and
  M2B0 signals"; ROM 00/01 IIgs machines need slot 3.
- `boards/a2n20v2/sch/a2n20v2.pdf`: the slot pins wired to the XC9572XL CPLD, including
  RDY, /IRQ, /NMI, /INH, /DMA, /RESET, M2B0, /M2SEL, SYNC, PHASE 0, PHASE 1, Q3 and 7M,
  and its JTAG header J3.
- `hdl/bus/apple_bus.sv`: the FPGA side of the bridge. It reads the address, data, R/W,
  /M2SEL, M2B0 and the control lines each cycle, and can drive the data bus, /IRQ, /INH
  and /RESET.
- `boards/a2n20v2/impl/pnr/a2n20v2.rpt.txt`: the published build uses 8,489 of 20,736
  logic cells, 40 of 46 block RAMs and both PLLs.

- **Kind:** web page or repository.
- **Public source:** <https://github.com/a2fpga/a2fpga_core/tree/5a35b0edb0e6593b030f007da6e3156e89d133b5>;
  the card: <https://wiki.reactivemicro.com/A2FPGA>.

<a id="s103"></a>

### Sipeed Tang Nano 20K

The FPGA board the A2FPGA card carries: Gowin GW2AR-LV18QN88C8/I7 with 20,736 LUT4
cells, 15,552 flip-flops, 828 Kbit of block SRAM in 46 blocks, 41,472 bits of shadow
SRAM, 64 Mbit of 32-bit SDR SDRAM in the FPGA package, two PLLs, and an HDMI connector
clocked from a 27 MHz crystal.

- **Kind:** original document.
- **Public source:** <https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html>.

<a id="s104"></a>

### Y80e

"Z80/Z180 compatible processor softcore" in Verilog, BSD license. It supports "all IO,
MLT ... and TST instructions" and uses 2,557 logic cells on an Altera Cyclone III. Its page
lists no MMU, DMA, serial ports or timers.

- **Kind:** web page or repository.
- **Public source:** <https://opencores.org/project,y80e>.

<a id="s105"></a>

### mmu180

"A MMU (memory management unit) designed per original specifications of Zilog's Z180
family of processors", in Verilog, BSD license, status alpha. Simulated with Icarus
Verilog and fitted into a Xilinx XC95144XL CPLD.

- **Kind:** web page or repository.
- **Public source:** <https://opencores.org/projects/mmu180>.

<a id="s106"></a>

### ao486

An x86 PC system in Verilog. Its resource table, for an Altera Cyclone IV E
EP4CE115F29C7, gives its standard VGA unit as 2,534 logic cells and 260 M9K memory
blocks; the VGA has no VBE extensions.

- **Kind:** web page or repository.
- **Public source:** <https://github.com/alfikpl/ao486>.

<a id="s107"></a>

### NESTang

A NES built in FPGA logic for Sipeed's Tang boards, the Tang Nano 20K among them. Its
README lists "720p HDMI output with sound".

- **Kind:** web page or repository.
- **Public source:** <https://github.com/nand2mario/nestang>.

<a id="s108"></a>

### Second Sight owner's photos, r/apple2 (2021)

Front and back of a production card, 1500 x 2000 pixels each, posted by u/krishnadraws on
2021-08-08. The back shows the 7M rework at the slot fingers. The Lattice chip on this card
is marked "pLSI 1016-60LJ".

- **Kind:** web page or repository.
- **Public source:** <https://www.reddit.com/r/apple2/comments/p0e17o/>; the photos are
  <https://i.imgur.com/Bipd5tx.jpeg> (front) and <https://i.imgur.com/FHxIslf.jpeg> (back).

<a id="s109"></a>

### Second Sight photo, Applefritter (2026)

Front of a production card, 4288 x 2848 pixels, posted by c0op3r on 2026-04-13: the
sharpest view of the Lattice socket and the 7M wire beside it. The Lattice chip on this
card is marked "pLSI 1016-60LJ".

- **Kind:** web page or repository.
- **Public source:** <https://www.applefritter.com/files/2026/04/13/DSC_0041.JPG>, posted in
  <https://www.applefritter.com/content/has-anyone-used-sequential-systems-secondsight-apple-iie>.

<a id="s110"></a>

### Apple TIL01930: AppleColor RGB Monitor specifications

Apple Tech Info Library article for the AppleColor RGB Monitor (A2M6014): video and sync
levels, scanning frequencies for 60 Hz and 50 Hz systems, video bandwidth, the active area
and the back-panel controls.

- **Kind:** original document.
- **Public source:** <https://savagetaylor.com/TIL/TIL01930.pdf>.

<a id="s111"></a>

### Adapting Apple's RGB Color Monitor for Analogue & MiSTer (2026)

Nerdly Pleasures, May 2026: an owner drives the A2M6014 from Analogue consoles and MiSTer
at 15.7 kHz 240p and 480i, 60 Hz and 50 Hz, through a VGA-to-DA-15 adapter with composite
sync, and describes the controls' limits.

- **Kind:** web page or repository.
- **Public source:** <http://nerdlypleasures.blogspot.com/2026/05/adapting-apples-rgb-color-monitor-for.html>.

<a id="s112"></a>

### Oak Technology graphics drivers page (1997)

Oak's download page. Its table tells the chips apart by the video BIOS version that
Microsoft's MSD reports: "v 1.0 to 1.03" is the OTI-87B and "v. 2.0 and up" is the
OTI-87X. It lists separate kits for each: 87xwin.zip and 87xdos.zip for the OTI-087x,
87bwin.zip and 87bdos.zip for the OTI-087B.

- **Kind:** original document.
- **Public source:** <https://web.archive.org/web/19970616130518id_/http://www.oaktech.com/graptech.html>.

<a id="s113"></a>

### Oak Windows 3.1 drivers for the OTI-087B (87bwin.zip, 1993)

Oak's OTI-087B kit, "OAK-87, DISTbv1.6". Its 256-color drivers announce "OTI-087/043B" and
accept ext $00 = 1, 2 or 3 without reading ext $01 (`STD8_SC.DRV` file offsets
$90BD-$90E5). It has no hardware-cursor drivers. Read by disassembly only.

- **Kind:** original document.
- **Public source:** <https://web.archive.org/web/1997id_/http://www.oaktech.com/zipfiles/87bwin.zip>,
  SHA-256 `8842bb788cee569e20accf1e0c8edfc153fc6ba32e21792d61c7d49a2dbeb5df`.

<a id="s114"></a>

### Oak Windows NT 3.1 driver for the OTI-087 (87winnt.zip, 1993)

Oak's NT miniport, listed for both the OTI-087x and the OTI-087B. Its README says it
works with all of Oak's OTI-087 chips. `OAKisPresent` (`OAK.SYS` file offsets
$2D40-$2DF7) writes index $11 to port $3DE, requires bits 4-0 of $3DE to read back $11,
then reads ext $00 and records a chip type for the values 1, 2, 3 and 4.

- **Kind:** original document.
- **Public source:** <https://web.archive.org/web/1997id_/http://www.oaktech.com/zipfiles/87winnt.zip>,
  SHA-256 `a94e5e1c565b46ba405e1588b3d47f49c7c165f2530702efec6429f2914dc58b`.

<a id="s115"></a>

### EDN, 3 February 1992: "Graphics IC quintuples Windows performance"

The trade-press report of the OTI-087's launch: a $31 chip (1,000 pieces) with a host bus
interface to 40 MHz, a write cache, a read cache and "a 64 x 64-pixel hardware cursor with
2 bits/pixel"; Windows drivers planned for February 1992 and an evaluation board for March.
It names no revision.

- **Kind:** another author's account.
- **Public source:** <https://archive.org/details/edn-1992_02_03>.

<a id="s116"></a>

### Oak OTI-087B DOS driver kit (87bdos.zip, 1993-94)

Oak's DOS utilities and application drivers for the OTI-087B. Every program matches the
87X DOS kit ([s79](#s79)) byte for byte except `INSTALL.EXE` (version 1.6), which holds the
same revision table.

- **Kind:** original document.
- **Public source:** <https://web.archive.org/web/1997id_/http://www.oaktech.com/zipfiles/87bdos.zip>,
  SHA-256 `b83707fc3d6d1d7e3ebc21605d7d736f6b7af1111d544ea4901d266052fa346b`.

<a id="s117"></a>

### WHATVGA 2.00 documentation (Finn Thoegersen, 29 September 1995)

The manual of WHATVGA, a DOS program that identifies and tests SVGA chips on real cards.
Its "Adapters tested" table marks a 1 MB OTI-087 card's hardware cursor "Ok*", and its
notes say: "Oak-087. The hardware cursor only works in 256color modes." Test 5 places a
32 x 32 hardware cursor in the selected mode. It names no 087 revision. Third party.

- **Kind:** another author's account.
- **Public source:** <https://raw.githubusercontent.com/achernya/iap-6.828-website/master/readings/hardware/vgadoc/WHATVGA.DOC>,
  lines 204-209 (test 5), 393 and 516 (table), 695 (note); SHA-256
  `142e77398f013e49273781179fffaacf30c343c1d05ac02ac3779dcb72a7812d`.
- **Source code, same release:** `BITBLT.PAS` (the cursor routines: Oak presets at line 348,
  enable at 664-665, position at 783-787), `IDVGA.PAS` and `SUPERVGA.PAS` in the same folder,
  <https://github.com/achernya/iap-6.828-website/tree/master/readings/hardware/vgadoc>.

<a id="s118"></a>

### AVANCE.TXT: VGADOC register notes for Avance Logic chips

Finn Thoegersen's register notes for the Avance Logic ALG2101, ALG2201 and ALG2228, part of
the same VGADOC set as [OAK.TXT](#s35). Their hardware cursor is another 64 x 64 two-color
cursor of the period: "Note: in interlaced modes the cursor is shown double height" (line
217). Third party; not about Oak.

- **Kind:** another author's account.
- **Public source:** <https://raw.githubusercontent.com/achernya/iap-6.828-website/master/readings/hardware/vgadoc/AVANCE.TXT>,
  SHA-256 `ddd28c645be534f9adf698e4faa391a19bc6b4a2e5d17772b4b5b19e257b650a`.

<a id="s119"></a>

### IBM patent EP0422300B1, "Display system with graphics cursor" (filed 1989)

IBM's patent for the XGA sprite. For a cursor that splits its rows between the two fields
of an interlaced picture, the CRT controller sends a cursor line number "1 more than the
line number of the cursor to be displayed" in non-interlaced modes; "For an interlaced
display mode it will be 2 more". Not about Oak.

- **Kind:** original document.
- **Public source:** <https://patents.google.com/patent/EP0422300B1/en>.

<a id="s120"></a>

### IBM PS/2 Hardware Interface Technical Reference, Video Subsystem (October 1990)

IBM's timing for the standard VGA monitor signals: sync polarity per line count and the
horizontal and vertical timing of the 400- and 480-line modes (pp108-111). The reference
for how a VGA monitor frames a standard 400- or 480-line picture.

- **Kind:** original document.
- **Public source:** <http://www.mcamafia.de/pdf/ibm_hitrc10.pdf>, 2,761,797 bytes,
  SHA-256 `bc600a44a8dd03a1015e611079196cd671dfa0ad863249b6fea14dc23dab6d2a`.

<a id="s121"></a>

### VESA Display Monitor Timing Standard, version 1.0, revision 10

VESA's standard monitor timings, including 800 x 600 at 56 and 60 Hz (pp14-15), the SVGA
timings a monitor of the period expected.

- **Kind:** original document.
- **Public source:** <https://glenwing.github.io/docs/VESA-DMT-1.10.pdf>, 490,644 bytes,
  SHA-256 `f0ff1e4d821a63678534f26e2c14b435470c34f46e8d3b1194bb6019eff0d08a`.

<a id="s122"></a>

### VOGONS report: CRT Terminator RNG test on an OTI-087X card (22 August 2023)

A user (ViTi95) ran the CRT Terminator random-number program on real cards in a Pentium 100
and reported "OTI 087x (ISA 16bit) - No hardware RNG available". The program's test is the
EGA light-pen readback ([s123](#s123)), so the card's CRTC $11 did not change enough in 64
reads with CRTC $03 bit 7 = 0.

- **Kind:** another person's test of real hardware.
- **Public source:** <https://www.vogons.org/viewtopic.php?p=1187912#p1187912>.

<a id="s123"></a>

### CRT Terminator `RNG.CPP`, the light-pen readback test (commit 02d7048)

The source of the program in [s122](#s122), as published before that test. `init_rng`
clears CRTC $11 bit 7 (write protect), clears CRTC $03 bit 7 ("Unmask access to Light Pen
register"), restores CRTC $11, then reads CRTC $11 64 times with interrupts off. It reports a
usable register only when more than 16 different values come back.

- **Kind:** another author's program.
- **Public source:** <https://raw.githubusercontent.com/juj/crt_terminator/02d70480301747a7d7cde260ae8a52ad96eac969/DOS/RNG/RNG.CPP>,
  SHA-256 `78fd2303276ae458a7bf48a1f08148808e4d5751fa8aead9fa8751beb7109f3f`.

<a id="s124"></a>

### PC Underground (Abacus, 1995)

A DOS demo-programming book. Chapter 5 times palette changes to chosen lines on a standard
VGA by waiting for the vertical retrace and then counting the horizontal blanking pulses in
$3DA bit 0: "You only choice is to continuously monitor the VGA status counting the lines
as you go and then change the color at the desired line" (chapter 5, copper bars, `COPPER.ASM`).

- **Kind:** another author's account.
- **Public source:** <https://www.phatcode.net/res/225/files/pc_underground.pdf>, 5,205,631
  bytes, SHA-256 `f3c335386e301ad7347c59fdbbd3678c4f0f63f6b0895789ac0f093328cbf8e3`.

<a id="s125"></a>

### WDC W65C816S data sheet

The 65816's instruction cycle counts by addressing mode, including the extra cycle for
16-bit data, `PEI`, `PEA`, `MVN`/`MVP`, and RDY holding a read or a write cycle.

- **Kind:** original document.
- **Public source:** <https://www.westerndesigncenter.com/wdc/documentation/w65c816s.pdf>.

<a id="s126"></a>

### PEI timing on a real IIgs (Ian Brumby, 2021)

A logic-analyzer measurement on a real IIgs of Wolfenstein 3D's `PEI` screen-copy code: 39
`PEI` instructions in a row took 0.173758 ms, 4.455 us per word.

- **Kind:** another person's test of real hardware.
- **Public source:** <https://retrocomputing.stackexchange.com/questions/228/inserting-nops-to-improve-iigs-shadow-copy-performance/21745>.

<a id="s127"></a>

### "Accelerate Your TransWarp GS", AppleWorks Forum, March 1991

John Link's article on IIgs accelerators. Motherboard memory runs at 2.8, 2.6 or 1.0 MHz
"(2.8 for ROM areas, 2.6 for RAM areas, and 1.0 for screen display areas)", and "the IIgs
video memory cannot operate faster than 1 MHz"; the TransWarp GS's write-back buffers let it
run on while those writes drain (p4).

- **Kind:** another author's account.
- **Public source:** <https://mirrors.apple2.org.za/ftp.apple.asimov.net/documentation/hardware/accelerators/Accelerate%20your%20TransWarp%20GS%20Card.pdf>.

<a id="s128"></a>

### ReactiveMicro Second Sight 600-dpi production-card scans

Front and back of a fourth production card. The front shows a Z8S18016VSC CPU,
NEC D431000AGW-70L SRAM marked ES, ICT 18CV8 -15 PLDs, DV74HCT574A latches,
BI 8A330 network, Bt481AKPJ110 RAMDAC, Lattice sticker "ZORRO / BE8C / W6",
and an EPROM label "rev. 1.4BEEF". Parts differ from card to card, so these markings
describe this card only.

- **Kind:** web page or repository.
- **Public archive:** [ReactiveMicro SecondSite_VGA/Pics](https://downloads.reactivemicro.com/Apple%20II%20Items/Hardware/SecondSite_VGA/Pics/).
- **Front:** [600-dpi PNG](https://downloads.reactivemicro.com/Apple%20II%20Items/Hardware/SecondSite_VGA/Pics/SecondSight%20VGA%20-%20Front%20-%20600DPI.png), 4686 x 1902 pixels.
- **Back:** [600-dpi PNG](https://downloads.reactivemicro.com/Apple%20II%20Items/Hardware/SecondSite_VGA/Pics/SecondSight%20VGA%20-%20Back%20-%20600DPI.png), 4670 x 1964 pixels.
- **Local originals:** `second-sight-private/photos/originals/reactivemicro-600dpi/front-600dpi.png` and `back-600dpi.png`.
- **SHA256 front:** `c174b22ef86b6d05f1a485c6406369af0201c6bf7ed5d21eba161fd3aea5e0b4`.
- **SHA256 back:** `9583ee08649baa24409e74b12be9fe23407362f79b4ec089a0325b8db5bc0f18`.

The archive's file dates are not a manufacture date. R32 is fitted, but its value
cannot be read in this scan.

<a id="s129"></a>

### Zilog, Z180 Family Questions and Answers (March 1994)

Zilog application note AN971800100. Page 6-3: during sleep or bus release, the CPU does
not sample /WAIT, so a wait cannot extend the cycle.

- **Kind:** original document.
- **Public source:** <https://www.zilog.com/docs/z180/appnotes/z180qa.pdf>.

<a id="s130"></a>

### "Second Sight Features", comp.sys.apple2, 8 May 1995

Jawaid Bazyar's feature list for the card. On the blitter: "The Z180 can copy one byte
of memory in 6 20MHz clock cycles", about 3.3 MB/s, and about 5 MB/s with the VGA
controller's read/modify/write help.

- **Kind:** another author's account.
- **Public source:** Google Groups: <https://groups.google.com/g/comp.sys.apple2/c/OU04c1gWiuc>.

<a id="s131"></a>

### AMI PEEL18CV8 data sheet (February 1993)

AMI's PEEL18CV8 timing tables. Printed page 20 lists the 18CV8-5, -7, -10, -15 and -25
grades (the table is marked PREVIEW); for -15, tCO1 is 12 ns and tCO2 is 25 ns, and for
-10 they are 7 ns and 12 ns.

- **Kind:** original document.
- **Public source:** <https://datasheet.datasheetarchive.com/originals/scans/Scans-091/DSAHI00040370.pdf>.

<a id="s132"></a>

### BI Technologies 627/628 series resistor networks (January 2008)

BI's surface-mount resistor network data sheet. Page 4's marking table maps the marking
8A330 to part 628A330: 16 leads, A circuit (eight isolated resistors), code 330 (33 ohm).
Page 2 lists the resistance codes; page 5 gives 2 percent as standard and F for 1 percent.

- **Kind:** original document.
- **Public source:** <https://www.farnell.com/datasheets/1850686.pdf>.

<a id="s133"></a>

### Oak OTI-037 VGA controller data sheet

Oak's 27-page data sheet for an earlier VGA controller. CRTC $11 bit 6 selects 3 or 5
DRAM refresh cycles per horizontal line, five for slow 15.75 kHz displays (p2-12). The
DRAM timing figures show a RAS precharge between display and CPU memory cycles (p2-24).

- **Kind:** original document.
- **Public source:** <https://peel.dk/Archive/-%20PC%20cards%2C%20manuals%2C%20BIN%20files%2C%20etc/Oak%20OTI-037C/oti-037.pdf>.

## Additional component datasheets

Listed with pages in [`data/netlist/SOURCES.md`](../data/netlist/SOURCES.md): Zilog Z8S180
product specification, Brooktree Bt478, Lattice GAL16V8, TI SN74HCT574 / SN74F125 /
SN74ACT32, Toshiba 1989 MOS memory and 1992 static RAM databooks, Macronix MX27C1000,
Fairchild NM93C46.

[Reference index](../README.md) | [Method](13-method.md) | [Netlist sources](../data/netlist/SOURCES.md)
