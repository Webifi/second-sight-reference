# Pre-built files

Ready-to-program files. Which goes with which, what each fixes, and programming:
[Firmware versions](../docs/firmware-versions.md), [U7 logic versions](../docs/lattice-versions.md).
The images read from Sequential's card are in [`original/`](../original/README.md).

> [!WARNING]
> **Preliminary research, provided as is with no warranty. It may contain errors.**

| File | What it is |
|---|---|
| [`firmware/SecondSight_firmware_v1.5-B5CB.bin`](firmware/SecondSight_firmware_v1.5-B5CB.bin) | Firmware 1.5, for a card with the original U7 |
| [`firmware/SecondSight_firmware_v2.0-1C46.bin`](firmware/SecondSight_firmware_v2.0-1C46.bin) | Firmware 2.0, for a card with U7 v2.0 |
| [`lattice/U7_v2.0-BBB1_ispLSI1016.jed`](lattice/U7_v2.0-BBB1_ispLSI1016.jed) | U7 v2.0 for an ispLSI1016, built by Lattice pDS 2.61 |
| [`lattice/U7_original-BE8C_ispLSI1016.jed`](lattice/U7_original-BE8C_ispLSI1016.jed) | The original U7, for an ispLSI1016: the dump of Sequential's chip, which pDS 2.61 rebuilds fuse for fuse |

A fresh firmware build matches these images byte for byte:

```bash
python tools/build_rom.py --check
```

A fresh U7 build has the same fuses and a header with a new date; `tools/lattice/jedec.py`
compares the fuses. Building: [firmware](../firmware/README.md#building),
[U7](../tools/lattice/README.md).
