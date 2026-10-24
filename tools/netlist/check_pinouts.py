"""Independent datasheet pin enumerations and a per-pin comparison ledger.

Numbers below were read from the cited package diagrams. Signal aliases are
explicitly reported; this does not verify copper connectivity or PLD functions.
"""

import re
from build_netlist import ROOT, parts, rows, write_csv

maps = {}
sources = {}


def register(refs, mapping, source, pages):
    for ref in refs:
        assert set(mapping) == set(range(1, parts[ref]["count"] + 1)), ref
        maps[ref] = mapping
        sources[ref] = (source, pages)


def indexed(mapping, pins, prefix, start=0):
    for i, n in enumerate(pins, start):
        mapping[n] = f"{prefix}{i}"


def normalized(name):
    return re.sub(r"[^A-Z0-9]", "", name.upper())


latch = {1: "OE", 10: "GND", 11: "CLK", 20: "VCC"}
for i in range(1, 9):
    latch[i + 1] = f"{i}D"
    latch[20 - i] = f"{i}Q"
register(["U2", "U3", "U5", "U6"], latch, "sources/74HCT574.pdf", 3)

buffer = {
    1: "1OE",
    2: "1A",
    3: "1Y",
    4: "2OE",
    5: "2A",
    6: "2Y",
    7: "GND",
    8: "3Y",
    9: "3A",
    10: "3OE",
    11: "4Y",
    12: "4A",
    13: "4OE",
    14: "VCC",
}
register(["U8"], buffer, "sources/74F125.pdf", "1-2")
or_gate = {
    1: "1A",
    2: "1B",
    3: "1Y",
    4: "2A",
    5: "2B",
    6: "2Y",
    7: "GND",
    8: "3Y",
    9: "3A",
    10: "3B",
    11: "4Y",
    12: "4A",
    13: "4B",
    14: "VCC",
}
register(["U29"], or_gate, "sources/74ACT32.pdf", 3)

gal = {1: "I/CLK", 10: "GND", 11: "I/OE", 20: "VCC"}
gal.update({n: "I" for n in range(2, 10)})
gal.update({n: "I/O/Q" for n in range(12, 20)})
register(["U4", "U12", "U15", "U17"], gal, "sources/GAL16V8.pdf", 1)

isp = {
    1: "GND",
    2: "IN3",
    11: "Y0",
    12: "VCC",
    13: "ispEN",
    14: "SDI/IN0",
    23: "GND",
    24: "SDO/IN1",
    33: "Y2/SCLK",
    34: "VCC",
    35: "Y1/RESET",
    36: "IN2/MODE",
}
indexed(isp, range(3, 11), "IO", 24)
indexed(isp, range(15, 23), "IO")
indexed(isp, range(25, 33), "IO", 8)
indexed(isp, range(37, 45), "IO", 16)
register(["U7"], isp, "../analysis/datasheet.pdf", 15)

cpu = {
    1: "VSS",
    2: "VSS",
    3: "XTAL",
    4: "EXTAL",
    5: "WAIT",
    6: "RESET",
    7: "BUSREQ",
    8: "BUSACK",
    9: "NMI",
    10: "INT0",
    11: "INT1",
    12: "INT2",
    13: "ST",
    18: "VSS",
    34: "VDD",
    36: "VSS",
    45: "RTS0",
    46: "CTS0",
    47: "DCD0",
    48: "TXA0",
    49: "RXA0",
    50: "CKA0/DREQ0",
    51: "TXA1",
    52: "TEST",
    53: "RXA1",
    54: "CKA1/TEND0",
    55: "TXS",
    56: "RXS/CTS1",
    57: "CKS",
    58: "DREQ1",
    59: "TEND1",
    60: "HALT",
    61: "RFSH",
    62: "IORQ",
    63: "MREQ",
    64: "E",
    65: "M1",
    66: "WR",
    67: "RD",
    68: "PHI",
}
indexed(
    cpu,
    [14, 15, 16, 17, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 35],
    "A",
)
cpu[33] = "A18/TOUT"
indexed(cpu, range(37, 45), "D")
register(["U18"], cpu, "sources/Z8S180.pdf", 4)

eprom = {1: "VPP", 2: "OE", 16: "GND", 22: "CE", 30: "NC", 31: "PGM", 32: "VCC"}
indexed(eprom, [12, 11, 10, 9, 8, 7, 6, 5, 27, 26, 23, 25, 4, 28, 29, 3, 24], "A")
indexed(eprom, [13, 14, 15, 17, 18, 19, 20, 21], "Q")
register(["U10"], eprom, "https://www.syntax.com.tw/upload/pdf/IC-27C1000-12.pdf", 1)

sram = {1: "NC", 16: "GND", 22: "CE1", 24: "OE", 29: "R/W", 30: "CE2", 32: "VDD"}
indexed(sram, [12, 11, 10, 9, 8, 7, 6, 5, 27, 26, 23, 25, 4, 28, 3, 31, 2], "A")
indexed(sram, [13, 14, 15, 17, 18, 19, 20, 21], "IO", 1)
register(["U11"], sram, "sources/Toshiba_SRAM_1992.pdf", 160)

dram = {
    1: "OE",
    2: "CAS",
    3: "IO3",
    4: "IO4",
    5: "VSS",
    6: "IO1",
    7: "IO2",
    8: "WRITE",
    9: "RAS",
    10: "NC/key",
    15: "VCC",
}
indexed(dram, [11, 12, 13, 14, 16, 17, 18, 19, 20], "A")
register([f"U{i}" for i in range(20, 28)], dram, "sources/Toshiba_MOS_1989.pdf", 114)

eeprom = {1: "CS", 2: "SK", 3: "DI", 4: "DO", 5: "GND", 6: "NC", 7: "NC", 8: "VCC"}
register(["U16"], eeprom, "sources/NM93C46.pdf", 2)

clock = {
    1: "XTAL1",
    2: "XTAL2",
    3: "VSS",
    4: "FS0",
    5: "FS1",
    6: "NC",
    7: "FS2",
    8: "FS3",
    9: "MS0",
    10: "VSS",
    11: "MS1",
    12: "MCLK",
    13: "DVDD",
    14: "VSS",
    15: "AVDD",
    16: "VSS",
    17: "VSS",
    18: "NC",
    19: "VCLK",
    20: "DVDD",
}
register(["U30"], clock, "sources/OTI-068.pdf", 5)

dac = {
    1: "NC",
    2: "8/6",
    3: "GND",
    4: "VAA",
    5: "SYNC",
    6: "RD",
    7: "BLANK",
    16: "WR",
    17: "RS0",
    18: "RS1",
    19: "RS2",
    20: "VAA",
    21: "VAA",
    22: "VAA",
    23: "SETUP",
    24: "GND",
    25: "IOR",
    26: "IOG",
    27: "IOB",
    28: "IREF",
    29: "COMP",
    30: "OPA",
    31: "VREF",
    40: "CLOCK",
}
indexed(dac, range(8, 16), "D")
indexed(dac, range(32, 40), "P")
indexed(dac, range(41, 45), "OL")
register(["U31"], dac, "sources/Bt478.pdf", 10)

oak = {
    1: "VSSO0",
    18: "CSEL3",
    19: "EPCLK/GA20",
    20: "EPDATA/SRDYI",
    21: "VDD0",
    22: "VSSI0",
    23: "MXPCLK/LBSEL",
    24: "SWSENSE",
    29: "VSSO1",
    34: "VSYNC",
    35: "HSYNC",
    36: "BLANK",
    37: "PCLK",
    41: "VSSO2",
    47: "EEPCS/ATOEH",
    48: "DACRD",
    49: "DACWR",
    61: "VDD1",
    78: "M16/SRDY",
    79: "IOCHRDY",
    80: "VSSO3",
    86: "AEN",
    87: "RFSH",
    88: "MRD",
    89: "MWR",
    90: "CINT",
    91: "IO16",
    92: "MASTER/HLDA",
    93: "ALE/ADS",
    94: "VDD2",
    95: "ROMENL/PROCLK",
    96: "VSSI1",
    97: "RSET",
    98: "ENVGA/WR",
    99: "ZEROWS/DC",
    100: "BHE",
    101: "IOR",
    102: "IOW",
    103: "CSEL2/EEPSK",
    104: "CSEL1/EEPWD",
    105: "CSEL0/EEPRD",
    106: "VCLK",
    107: "MCLK",
    116: "WEC/CAS2",
    117: "WED/CAS3",
    118: "WEA/CAS0",
    119: "WEB/CAS1",
    120: "RASL",
    121: "VSSO4",
    122: "MA23(0)",
    123: "CASA/WE",
    124: "MA01(0)/CASB",
    125: "RASH/MA9",
    130: "VSSO5",
    141: "VDD3",
    144: "VSSO6",
}
indexed(oak, range(2, 10), "MD", 24)
indexed(oak, range(153, 161), "MD", 16)
indexed(oak, range(145, 153), "MD", 8)
indexed(oak, [135, 136, 137, 138, 139, 140, 142, 143], "MD")
indexed(oak, range(10, 18), "BD")
indexed(oak, [25, 26, 27, 28, 30, 31, 32, 33], "P")
indexed(oak, [38, 39, 40, 42, 43, 44, 45, 46], "SD", 8)
indexed(oak, list(range(50, 61)) + list(range(62, 68)), "SA")
indexed(oak, range(68, 75), "LA", 17)
indexed(oak, [75, 76, 77, 81, 82, 83, 84, 85], "SD")
for i, p in enumerate([126, 127, 128, 129, 131, 132, 133, 134], 1):
    oak[p] = f"MA01({i})"
for i, p in enumerate(range(108, 116), 1):
    oak[p] = f"MA23({i})"
register(["U28"], oak, "sources/OTI-087-sharp.pdf", "22-28;31")


def compare(row):
    ref = row["refdes"]
    n = int(row["pin_number"])
    observed = row["pin_name"]
    expected = maps[ref][n]
    note = ""
    if not observed:
        status = (
            "omitted_symbol"
            if row["net"].startswith("UNRESOLVED_")
            or expected in {"VCC", "VDD", "VSS", "GND", "VAA", "NC", "NC/key"}
            else "unnamed_symbol"
        )
        note = "Datasheet supplies function; schematic does not print this pin name."
    elif normalized(observed) == normalized(expected):
        status = "match"
    elif ref == "U30" and n == 6:
        status = "disagreement"
        note = "Schematic STROBE versus April 1993 databook NC. Pin is open in drawing."
    elif ref == "U18" and n == 65:
        status = "legacy_name"
        note = "Z180 symbol LIR versus Z8S180 M1; pin open in drawing."
    elif ref == "U28" and n in {19, 20, 23, 47}:
        status = "symbol_label_difference"
        note = "Symbol contains additional/differently spelled alternate-function text absent from the checked AT/local-bus pin descriptions; retain the original and consult the datasheet function."
    else:
        status = "alias_or_notation"
        note = "Different symbol terminology; see NETLIST.md. Number and corresponding function were compared."
        if ref == "U11" and observed.startswith("IO"):
            note = "Schematic IO0..IO7 versus Toshiba IO1..IO8, same ordered physical pins."
        if ref in {f"U{i}" for i in range(20, 28)} and observed.startswith("IO"):
            note = "Schematic IO0..IO3 versus Toshiba IO1..IO4, same physical pins."
        if ref == "U28" and 68 <= n <= 74:
            note = "Symbol SA17..SA23; ISA pin diagram LA17..LA23 (unlatched high address inputs)."
    return dict(
        refdes=ref,
        pin_number=n,
        schematic_pin_name=observed,
        datasheet_pin_name=expected,
        status=status,
        source=sources[ref][0],
        pdf_page=sources[ref][1],
        note=note,
    )


checks = [compare(row) for row in rows if row["refdes"] in maps]
assert len(checks) == sum(parts[ref]["count"] for ref in maps)
assert {
    r["refdes"] for r in rows if r["refdes"].startswith("U") and r["refdes"] != "U1"
} == set(maps)
write_csv(
    "pinout_checks.csv",
    checks,
    [
        "refdes",
        "pin_number",
        "schematic_pin_name",
        "datasheet_pin_name",
        "status",
        "source",
        "pdf_page",
        "note",
    ],
)

# Production RAMDAC comparison uses the pinout figure, correcting a typographical
# error in L481A_C Table 1: COMP is pin 29, not pin 1; pin 1 is SENSE*.
production_dac = dac.copy()
production_dac[1] = "SENSE*"
production_dac[20] = "TRUECOL*"
write_csv(
    "bt478_bt481_pin_changes.csv",
    [
        dict(
            pin_number=n,
            bt478=dac[n],
            bt481=production_dac[n],
            changed=dac[n] != production_dac[n],
            source="sources/Bt481.pdf",
            pdf_page=9,
        )
        for n in range(1, 45)
    ],
    ["pin_number", "bt478", "bt481", "changed", "source", "pdf_page"],
)
print(f"Checked {len(checks)} pins across {len(maps)} schematic ICs.")
print("Reported differences:")
for check in checks:
    if check["status"] in {"disagreement", "legacy_name", "symbol_label_difference"}:
        print(check)
