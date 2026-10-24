# Tools

Run every command from the repository root.

| Task | Procedure | Main tool |
|---|---|---|
| Download the source documents and check their hashes | [Get sources](../docs/13-method.md#1-get-the-sources) | `fetch_sources.py` |
| Rebuild CSV copies after editing a reference page | [Export tables](#export-tables) | `export_tables.py` (`--check` to verify) |
| Check ROM/fuse dump checksums | [Check dumps](../docs/13-method.md#2-check-the-dumps) | `checksums.py` |
| Read scanned schematics/databooks | [Read documents](../docs/13-method.md#3-read-the-schematic-and-the-databooks) | `pdf_pages.py`, `pdf_text.py` |
| Regenerate prototype [netlist](../data/netlist/README.md) and audits | [Transcribe the board](../docs/13-method.md#4-transcribe-the-board) | `netlist/build_netlist.py`, `check_pinouts.py`, `audit_netlist.py` |
| Inspect firmware and the ss.source.082395.po mode files | [Read firmware](../docs/13-method.md#5-read-the-firmware) | `mode_files.py`, `prodos.py` |
| Build the Z180 firmware from source (ROM 1.4 or a changed version) | [firmware/README.md](../firmware/README.md#building) | `build_rom.py` (`--check` to verify, `--prebuilt` to write the ready-built images) |
| Build a U7 design (original, corrected or changed) with Lattice pDS 2.61 | [Building U7 with Lattice's tools](lattice/README.md) | `lattice/pds261_build.sh` |
| Check a built U7 fuse map against its source, and the v2.0 fixes, in the chip emulator | [Check a build](lattice/README.md#check-a-build) | `lattice/u7_test.py`, `lattice/chipsim.py` |

Python 3; `pdf_pages.py` also needs Pillow. Building U7 needs Lattice's pDS 2.61
([what you need](lattice/README.md#what-you-need)).

## Export tables

`export_tables.py` copies each table in `docs/reference/` that has a
`<!-- csv: data/tables/NAME.csv -->` line above it into that CSV file. Run it after
editing a reference page:

```bash
python -B tools/export_tables.py
```

List the CSV files that are out of date, without writing:

```bash
python -B tools/export_tables.py --check
```

[Reference index](../README.md) | [Reference tables](../docs/reference/README.md) | [Data](../data/README.md)
