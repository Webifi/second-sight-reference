# Firmware versions

[Reference index](../README.md) | [U7 logic versions](lattice-versions.md) | [08 Firmware](08-firmware.md) | [Errata](reference/errata.md)

The Z180's program, in EPROM U10.

> [!WARNING]
> **Preliminary research, provided as is with no warranty. It may contain errors.**

| Version | For a card with | What it is | Image and SHA-256 |
|---|---|---|---|
| **1.4-BEEF** | any U7 | Sequential's last release, the 1995 "v1.1" update: the EPROM labeled "rev. 1.4-BEEF", the only revision that survives ([others](08-firmware.md#other-rom-revisions)) | [`original/ROM_BEEF.bin`](../original/ROM_BEEF.bin) `bd29e30ebf004e205609112a3c21a26eb28504115e047862fbd27f641f784d61` |
| **1.5-B5CB** | the original U7 ([BE8C](lattice-versions.md)) | ROM 1.4 with every erratum firmware can fix (E1-E11, E13, E16, E17, E26, E27 and E29, and E19 and E25 in part), and uploads across 512 KB split on the card | [`SecondSight_firmware_v1.5-B5CB.bin`](../prebuilt/firmware/SecondSight_firmware_v1.5-B5CB.bin) `45d6fb82f92b5e9ca2c5d9e03b1f9d0b8faaf0a73f7c2d52c9a3743ab06aa562` |
| **2.0-1C46** | [U7 v2.0](lattice-versions.md) | Version 1.5 plus E15, the IIgs border color, which only U7 v2.0 makes possible | [`SecondSight_firmware_v2.0-1C46.bin`](../prebuilt/firmware/SecondSight_firmware_v2.0-1C46.bin) `675f38252930c0cfef3e5d20de5358df07f433386066150d7e0dd74014be7337` |

Each version is named by its number and its image's 16-bit byte sum, as Sequential
labeled its EPROM. GetStatus reports the number as Sequential's
[firmware documentation](sources.md#s15) defines the byte: $14, $15 and $20. Sequential's
library and the programs checked test only the "GSVGA" signature; GView asks for "roms
v1.1 or greater", which both new versions meet.

## Which firmware goes with which U7

| U7 | Firmware | Result |
|---|---|---|
| Original (BE8C) | 1.5 | Every firmware fix |
| Original (BE8C) | 2.0 | The same as 1.5: the original U7 never reports a $C034 write, so 2.0's border code never acts |
| v2.0 | 2.0 | Every fix: the firmware fixes, the IIgs border color, and U7 v2.0's own fixes (E14, E28) |
| v2.0 | 1.4 or 1.5 | U7 v2.0's own fixes (E14, E28), but no border color |

## What each version fixes

| Erratum | 1.4 | 1.5 | 2.0 |
|---|---|---|---|
| [E1](reference/errata.md#e1-mode-13-shows-a-broken-picture) Mode $13 shows a broken picture | fault | fixed | fixed |
| [E2](reference/errata.md#e2-double-hires-hangs) Double hires hangs the card | fault | fixed | fixed |
| [E3](reference/errata.md#e3-super-hi-res-lines-102-127-use-the-wrong-palette) Super Hi-Res lines 102-127 use the next line's palette | fault | fixed | fixed |
| [E4](reference/errata.md#e4-uploaddata-cannot-load-z180-code-as-documented) UploadData flag 0 never reaches Z180 memory | fault | fixed | fixed |
| [E5](reference/errata.md#e5-runcode-never-reports-completion) RunCode never reports completion | fault | fixed | fixed |
| [E6](reference/errata.md#e6-mixed-hires-text-ignores-the-c022-colors) Mixed-hires text ignores the $C022 colors | fault | fixed | fixed |
| [E7](reference/errata.md#e7-double-lores-is-not-implemented) Double lores shows as single lores | fault | fixed | fixed |
| [E8](reference/errata.md#e8-scrollscreen-past-512-kb-overwrites-card-memory) ScrollScreen and ClearScreen past 512 KB overwrite card memory | fault | fixed | fixed |
| [E9](reference/errata.md#e9-scrollscreen-toward-a-higher-address-copies-the-wrong-bytes) ScrollScreen toward a higher address copies the wrong bytes | fault | fixed | fixed |
| [E10](reference/errata.md#e10-settextfont-is-missing) SetTextFont is missing | fault | fixed | fixed |
| [E11](reference/errata.md#e11-super-hi-res-color-fill-mode-is-ignored) Super Hi-Res color fill mode is ignored | fault | fixed | fixed |
| [E13](reference/errata.md#e13-fast-animation-is-choppy) Fast animation is choppy | 92 ms a full Super Hi-Res screen | about 68 ms | about 68 ms |
| [E15](reference/errata.md#e15-the-iigs-border-color-does-not-show) The IIgs border color does not show | fault | fault | fixed with U7 v2.0 |
| [E16](reference/errata.md#e16-library-mode-files-run-at-the-wrong-clock) Library mode files run at the wrong clock | fault | fixed | fixed |
| [E17](reference/errata.md#e17-the-true-color-mode-file-shows-palette-colors) The true-color mode file shows palette colors | fault | fixed | fixed |
| [E19](reference/errata.md#e19-uploads-of-whole-64-kb-blocks-hang-older-programs) Uploads of whole 64 KB blocks hang older programs | fault | partly fixed | partly fixed |
| [E25](reference/errata.md#e25-very-large-pictures-may-hang-the-card) Very large pictures may hang the card | fault | partly fixed | partly fixed |
| [E26](reference/errata.md#e26-flashing-text-ignores-the-c022-colors) Flashing text ignores the $C022 colors | fault | fixed | fixed |
| [E27](reference/errata.md#e27-four-language-characters-sit-one-row-low-in-the-8x16-font) Four language characters sit one row low | fault | fixed | fixed |
| [E29](reference/errata.md#e29-apple-display-switches-reset-a-native-vga-mode) Apple display switches reset a native VGA mode | fault | fixed | fixed |

1.5 and 2.0 also split an UploadData phase that crosses video $80000, which Sequential's
documentation forbids programs to send
([UploadData across 512 KB](firmware-fixes.md#uploaddata-across-512-kb)).

[Firmware fixes](firmware-fixes.md) describes each change. E12 has no firmware fix
([errata](reference/errata.md#e12-palettes-rewritten-during-each-frame-show-wrong-colors)).

## Putting a version on a card

Program the image into a 27C1000 (128 KB) EPROM and fit it in socket U10 in place of the
original, the same way round (the notch to the notch). Any device programmer that lists
the 27C1000 does this. Nothing in the firmware checks its own checksum. To go back, refit
the original EPROM, or program [`ROM_BEEF.bin`](../original/ROM_BEEF.bin) into a 27C1000.

## Building a version yourself

Each version is built from assembly source in [`firmware/`](../firmware/README.md):

| Version | Source |
|---|---|
| 1.4-BEEF | [`firmware/ROM_BEEF.asm`](../firmware/ROM_BEEF.asm) with [`firmware/src`](../firmware/src); builds the dump byte for byte, and marks each known fault `BUG (En)` |
| 1.5 | [`firmware/for_original_u7`](../firmware/for_original_u7/SecondSight_for_original_u7.asm); each fix marked `CHANGE (En)` |
| 2.0 | [`firmware/for_corrected_u7`](../firmware/for_corrected_u7/SecondSight_for_corrected_u7.asm); the 1.5 source plus E15 |

Installing the assembler, building, and checking a build against these images:
[firmware/README.md](../firmware/README.md). How the firmware works: [08 Firmware](08-firmware.md).

---

[Reference index](../README.md) | [U7 logic versions](lattice-versions.md)
