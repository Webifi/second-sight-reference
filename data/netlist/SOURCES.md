# Sources for the pin-level transcription

The documents behind the `source` values in `pinout_checks.csv`. Page numbers are PDF
pages, counted from 1, with the printed page where it differs.

## Board evidence

- The schematic, the board photos and the [cable pinout document](../../docs/sources.md#s13) come from the Apple II
  Documentation Project mirror: [Sources](../../docs/sources.md).
- The schematic is the 1994 prototype. Production differences are in
  [02 Board](../../docs/02-board.md).

## Package pinouts used

| Evidence identifier | Publisher and download | Pages used |
|---|---|---|
| sources/Z8S180.pdf | Zilog, [Z8S180 product specification](../../docs/sources.md#s62): <https://www.zilog.com/docs/z180/z8s180ps.pdf> | 4, PLCC-68 diagram |
| sources/OTI-087-sharp.pdf | Oak Technology, OTI-087 February 1993 databook: <http://bitsavers.informatik.uni-stuttgart.de/components/oakTechnology/OTI-087_Feb1993.pdf> | 22-28 signal descriptions; 31 (printed 26), ISA 160-pin diagram |
| sources/OTI-087.pdf | Oak Technology, second scan: <https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Interface%20Cards/Video/Sequential%20Systems%20Second%20Sight/Datasheets/OTI-087.pdf> | supplemental |
| sources/Bt478.pdf | Brooktree, Bt471/Bt476/Bt478 datasheet: <https://www.ardent-tool.com/datasheets/Brooktree_Bt471_476_478.pdf> | 10 (printed 4-30), PLCC-44 |
| sources/Bt481.pdf | Brooktree, Bt481A ([L481A_C](../../docs/sources.md#s36)): <http://www.pldworld.com/_hdl/1/erc.msstate.edu/www/~reese/EE4993/data_sheets/btl481a_c.pdf> | 7-9, PLCC-44 figure on 9 |
| ../analysis/datasheet.pdf | Lattice, [ispLSI1016 datasheet](../../docs/sources.md#s37): <https://ftcelectronics.jp/datasheets-18/ISPLSI-1016-60LT44I.pdf> | 15 (printed 14), PLCC-44 |
| sources/GAL16V8.pdf | Lattice, GAL16V8 datasheet: <https://ece-classes.usc.edu/ee459/library/datasheets/16v8.pdf> | 1, 20-pin pin configurations |
| sources/74HCT574.pdf | Texas Instruments, SN74HCT574: <https://www.ti.com/lit/ds/symlink/sn74hct574.pdf> | 3, package diagram |
| sources/74F125.pdf | Texas Instruments, SN74F125: <https://www.ti.com/lit/ds/symlink/sn74f125.pdf> | 1-2 |
| sources/74ACT32.pdf | Texas Instruments, SN74ACT32: <https://www.ti.com/lit/ds/symlink/sn74act32.pdf> | 3 |
| sources/Toshiba_MOS_1989.pdf | Toshiba, 1989 MOS Memory databook: <https://ftpmirror.your.org/pub/misc/bitsavers/components/toshiba/_dataBook/1989_Toshiba_MOS_Memory.pdf> | 114 (printed A-87), TC514256 ZIP |
| sources/Toshiba_SRAM_1992.pdf | Toshiba, 1992 Static RAM databook: <https://ftpmirror.your.org/pub/misc/bitsavers/components/toshiba/_dataBook/1992_Toshiba_Static_RAM.pdf> | 160 (printed B-35), TC551001 |
| (web only) | Macronix, MX27C1000 datasheet: <https://www.syntax.com.tw/upload/pdf/IC-27C1000-12.pdf> | 1, 27C1000 pin map |
| sources/OTI-068.pdf | Oak Technology, OTI-068 April 1993: <https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Interface%20Cards/Video/Sequential%20Systems%20Second%20Sight/Datasheets/OTI-068.pdf> | 5, 20-pin diagram |
| sources/NM93C46.pdf | Fairchild, NM93C46 Rev. E: <https://www.rcscomponents.kiev.ua/datasheets/nm93c46.pdf> | 2, 8-pin package |

## Known problems in the source documents

- [Bt481A datasheet](../../docs/sources.md#s36) L481A_C: Table 1 (PDF page 8) puts COMP on pin 1, but the pinout
  figure (PDF page 9) puts COMP on pin 29 and SENSE* on pin 1. The figure is used.
- TI SN74HCT574 revision H, PDF page 3: the pin-function table uses transceiver-style A/B
  names that disagree with its own D/Q package diagram. The diagram is used.
- The cable document says "19 Pin IDC", while the drawn J1 is a 16-pin BERG header and
  the production headers look like 2 x 8. The physical pin counts are used.

PLD equations: [PLD functions](../../docs/07-glue-logic.md); Bt481 "PROTO 2"
differences are [Bt481 sample](../../docs/reference/bt481-modes.md).

[Netlist guide](README.md) | [Main sources](../../docs/sources.md) | [Reference index](../../README.md)
