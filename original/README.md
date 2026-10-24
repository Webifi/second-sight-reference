# Original images

The two chip images read from a Second Sight card, and the source that rebuilds each.

| File | What it is | Source that builds it | SHA-256 |
|---|---|---|---|
| [`ROM_BEEF.bin`](ROM_BEEF.bin) | The firmware EPROM (U10, a 27C1000), labeled "rev. 1.4-BEEF": firmware 1.4, byte sum $BEEF | [`firmware/v1.4/ROM_BEEF.asm`](../firmware/v1.4/ROM_BEEF.asm) with [`firmware/v1.4/src`](../firmware/v1.4/src) | `bd29e30ebf004e205609112a3c21a26eb28504115e047862fbd27f641f784d61` |
| [`isplsi1016_BE8C.bin`](isplsi1016_BE8C.bin) | The capture logic chip (U7, an ispLSI1016), labeled BE8C: its JEDEC fuse file, read with Max Loader (a text file, despite the name) | [`data/lattice/SecondSight_U7.ldf`](../data/lattice/SecondSight_U7.ldf) | `f8b2f5429a65acbe3f6c13d6aa6ae3e87e9d83c8d1e3e8bbc1d54977ee626328` |

Public copies: [ROM_BEEF.bin](../docs/sources.md#s25) and
[isplsi1016_BE8C.bin](../docs/sources.md#s24). The fuse file is also the tools' input
[`data/lattice/SecondSight_U7.jed`](../data/lattice/SecondSight_U7.jed) and the ready-built
[`Lattice_original-BE8C_ispLSI1016.jed`](../prebuilt/lattice/Lattice_original-BE8C_ispLSI1016.jed),
all three the same bytes.

## Building them from source

The firmware, after installing the assembler ([firmware/README.md](../firmware/README.md#building)):

```bash
python tools/build_rom.py firmware/v1.4/ROM_BEEF.asm
```

The fuse file ([Lattice design source](../docs/reference/lattice-source.md#building-and-changing-the-design)):

```bash
tools/lattice/pds261_build.sh data/lattice/SecondSight_U7.ldf data/lattice/SecondSight_U7.fxp build/lattice/SecondSight_U7_ispLSI1016.jed
```

```bash
python tools/lattice/jedec.py original/isplsi1016_BE8C.bin build/lattice/SecondSight_U7_ispLSI1016.jed
```

The firmware build prints "identical to ROM 1.4". The fuse comparison prints checksum
BE8C for both files and "0 fuses differ"; the built file's header differs from the read
one, so its SHA-256 does too.

## Newer versions

The firmware and Lattice versions built from changed source, which fix the
[errata](../docs/reference/errata.md):
[Firmware versions](../docs/firmware-versions.md) and
[Lattice chip versions](../docs/lattice-versions.md).
