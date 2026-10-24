"""Reproduce the manually transcribed prototype netlist; see NETLIST.md."""

import csv
import json
from collections import defaultdict
from pathlib import Path

# Outputs live in data/netlist/ at the repository root.
ROOT = Path(__file__).resolve().parents[2] / "data" / "netlist"
rows = []
parts = {}


def part(
    sheet, ref, value, count, package, production="Not individually verified", note=""
):
    assert ref not in parts
    parts[ref] = dict(
        sheet=sheet,
        refdes=ref,
        value_or_part=value,
        package=package,
        prototype_part=value,
        production_part=production,
        notes=note,
        count=count,
    )


def pin(ref, number, name, net, confidence="high", note=""):
    assert not any(r["refdes"] == ref and r["pin_number"] == str(number) for r in rows)
    if net == "NC":
        net = f"NC_{ref}_{number}"
        if not note:
            note = "Open pin stub in schematic."
    if net == "?":
        net = f"UNRESOLVED_{ref}_{number}"
        confidence = "low"
        note = "Not shown or not legible; connection not established. " + note
    rows.append(
        dict(
            sheet=parts[ref]["sheet"],
            refdes=ref,
            part=parts[ref]["value_or_part"],
            pin_number=str(number),
            pin_name=name,
            net=net,
            confidence=confidence,
            note=note.strip(),
        )
    )


def sequence(ref, numbers, names, nets, **kwargs):
    assert len(numbers) == len(names) == len(nets)
    for number, name, net in zip(numbers, names, nets):
        pin(ref, number, name, net, **kwargs)


def hidden_power(ref, vcc, gnd):
    for number in vcc:
        pin(
            ref,
            number,
            "",
            "VCC",
            "medium",
            "Power pin hidden in symbol; name/number from datasheet, rail inferred.",
        )
    for number in gnd:
        pin(
            ref,
            number,
            "",
            "GND",
            "medium",
            "Ground pin hidden in symbol; name/number from datasheet, rail inferred.",
        )


def passive(
    sheet,
    ref,
    value,
    a,
    b,
    package="Not specified",
    production="Not individually verified",
):
    part(sheet, ref, value, 2, package, production)
    pin(
        ref,
        1,
        "",
        a,
        "medium",
        "Pad numbers not printed; transcription convention: first endpoint.",
    )
    pin(
        ref,
        2,
        "",
        b,
        "medium",
        "Pad numbers not printed; transcription convention: second endpoint.",
    )


# Sheet 1: Apple II edge and bus latches.
part(1, "U1", "APPLE I/O", 50, "50-contact card edge", "Apple II card edge")
pin("U1", 1, "-IOSEL", "NC")
sequence(
    "U1",
    list(range(2, 18)),
    [f"A{i}" for i in range(16)],
    [f"AA{i}" for i in range(16)],
)
for number, name, net in [
    (18, "R/-W", "ARW"),
    (19, "-SYNC", "NC"),
    (20, "-IOSTR", "NC"),
    (21, "-RDY", "ARDY"),
    (22, "-DMA", "DMA"),
    (23, "INTIN", "N_U1_23"),
    (24, "DMAOUT", "DMAINOUT"),
    (25, "VCC", "VCC"),
    (26, "GND", "GND"),
    (27, "DMAIN", "DMAINOUT"),
    (28, "INTOUT", "N_U1_23"),
    (29, "-NMI", "NC"),
    (30, "IRQ", "AIRQ"),
    (31, "-RESET", "ARES"),
    (32, "-INH", "NC"),
    (33, "-12V", "-12V"),
    (34, "-5V", "NC"),
    (35, "M2B0", "M2B0"),
    (36, "7M", "7M"),
    (37, "Q3", "NC"),
    (38, "PHASE1", "NC"),
    (39, "-M2SEL", "M2SEL"),
    (40, "PHASE0", "PHASE0"),
    (41, "-DEVSEL", "NC"),
    (50, "12V", "+12V"),
]:
    pin("U1", number, name, net)
sequence(
    "U1",
    list(range(42, 50)),
    [f"D{i}" for i in range(7, -1, -1)],
    [f"AD{i}" for i in range(7, -1, -1)],
)

for ref, source, dest, start, oe, clk in [
    ("U2", "AD", "HD", 7, "BEN", "ADIN"),
    ("U3", "HD", "AD", 7, "ADOUT", "BCLK"),
    ("U5", "AA", "HA", 7, "BACK", "CATCH"),
    ("U6", "AA", "HA", 15, "BACK", "CATCH"),
]:
    part(1, ref, "SN74HCT574DW", 20, "SOIC-20 (DW)")
    pin(ref, 1, "OC", oe)
    pin(ref, 11, "CLK", clk)
    sequence(
        ref,
        list(range(2, 10)),
        [f"{i}D" for i in range(1, 9)],
        [f"{source}{i}" for i in range(start, start - 8, -1)],
    )
    sequence(
        ref,
        list(range(19, 11, -1)),
        [f"{i}Q" for i in range(1, 9)],
        [f"{dest}{i}" for i in range(start, start - 8, -1)],
    )
    hidden_power(ref, [20], [10])

part(
    1,
    "U7",
    "PLSI1016",
    44,
    "PLCC-44",
    "ispLSI1016-90LJ",
    "Production Y2/pin 33 wire; see NETLIST.md.",
)
for number, name, net in [
    (1, "GND", "GND"),
    (2, "IN3", "AD6"),
    (11, "Y0", "CLK"),
    (12, "VCC", "VCC"),
    (13, "ISPEN", "NC"),
    (14, "IN0", "M2B0"),
    (23, "GND", "GND"),
    (24, "IN1", "AX"),
    (25, "IO8", "M2SEL"),
    (26, "IO9", "ADOUT"),
    (27, "IO10", "CATCH"),
    (28, "IO11", "ADIN"),
    (29, "IO12", "HA0"),
    (30, "IO13", "HD3"),
    (31, "IO14", "HA1"),
    (32, "IO15", "HD1"),
    (33, "Y2", "NC"),
    (34, "VCC", "VCC"),
    (35, "Y1/RESET", "RESET"),
    (36, "IN2", "AD4"),
    (37, "IO16", "CPU"),
    (38, "IO17", "INT1"),
    (39, "IO18", "CATCH_BANK"),
    (40, "IO19", "HD0"),
    (41, "IO20", "HA2"),
    (42, "IO21", "ARW"),
    (43, "IO22", "RDY0"),
    (44, "IO23", "HD2"),
]:
    pin(
        "U7",
        number,
        name,
        net,
        "medium" if number == 2 else "high",
        (
            "Blurred label; AD6 reading agrees with supplied C068 bit-6 analysis; continuity unverified."
            if number == 2
            else ""
        ),
    )
sequence(
    "U7",
    list(range(3, 11)),
    [f"IO{i}" for i in range(24, 32)],
    [f"AA{i}" for i in range(8)],
)
sequence(
    "U7",
    list(range(15, 23)),
    [f"IO{i}" for i in range(8)],
    [f"AA{i}" for i in range(8, 16)],
)

part(
    "1;4",
    "U8",
    "74125",
    14,
    "SOIC-14 (photo)",
    "74F125",
    "Gate C not drawn; do not assume its inputs are grounded.",
)
for n, name, net in [
    (1, "", "RDY0"),
    (2, "", "GND"),
    (3, "", "ARDY"),
    (4, "", "AIRQ0"),
    (5, "", "GND"),
    (6, "", "AIRQ"),
]:
    pin("U8", n, name, net)
for n in [8, 9, 10]:
    pin("U8", n, "", "?", note="Unused gate C omitted from drawing.")
hidden_power("U8", [14], [7])

# Sheet 2: CPU, program/data memory and PAL glue.
part(
    2,
    "U18",
    "Z180PLCC",
    68,
    "PLCC-68",
    "Z8S18020VSC",
    "Production external 36 MHz oscillator replaces crystal network.",
)
addr_pins = [
    14,
    15,
    16,
    17,
    19,
    20,
    21,
    22,
    23,
    24,
    25,
    26,
    27,
    28,
    29,
    30,
    31,
    32,
    33,
    35,
]
sequence("U18", addr_pins, [f"A{i}" for i in range(20)], [f"HA{i}" for i in range(20)])
sequence(
    "U18",
    [37, 38, 39, 40, 41, 42, 43, 44],
    [f"D{i}" for i in range(8)],
    [f"HD{i}" for i in range(8)],
)
for n, name, net in [
    (3, "XTAL", "N_U18_3"),
    (4, "EXTAL", "EXTAL"),
    (5, "WAIT", "WAIT"),
    (6, "RESET", "RES"),
    (7, "BUSREQ", "BREQ"),
    (8, "BUSACK", "BACK"),
    (9, "NMI", "NMI"),
    (10, "INT0", "-INT0"),
    (11, "INT1", "INT1"),
    (12, "INT2", "INT2"),
    (13, "ST", "NC"),
    (45, "RTS0", "RTS0"),
    (67, "RD", "HRD"),
    (66, "WR", "HWR"),
    (54, "TEND0", "NC"),
    (58, "DREQ1", "INT1"),
    (59, "TEND1", "NC"),
    (60, "HALT", "NC"),
    (61, "RFSH", "RFSH"),
    (62, "IOE", "-IOE"),
    (63, "ME", "-ME"),
    (68, "PHI", "N_U18_68"),
    (65, "LIR", "NC"),
    (50, "DREQ0", "GND"),
]:
    pin("U18", n, name, net)
hidden_power("U18", [34], [1, 2, 18, 36])
for n in [46, 47, 48, 49, 51, 52, 53, 55, 56, 57, 64]:
    pin(
        "U18",
        n,
        "",
        "?",
        note="Serial/test function absent from schematic symbol; board termination unknown.",
    )
passive(2, "R1", "22ohm", "HCLK", "N_U18_68")
passive(2, "R15", "10K", "VCC", "NMI")
passive(2, "R16", "10K", "VCC", "RES")
passive(2, "X1", "20MHz", "N_U18_3", "EXTAL", "Crystal, 2 pins", "Unfitted")
passive(2, "C1", "22pF", "EXTAL", "GND", production="Unfitted")
passive(2, "C2", "22pF", "N_U18_3", "GND", production="Unfitted")

for ref, value, addr16, addr15, addr14 in [
    ("U10", "27C1000", 24, 3, 29),
    ("U11", "431000", 2, 31, 3),
]:
    part(
        2,
        ref,
        value,
        32,
        "DIP-32" if ref == "U10" else "SOP-32",
        "EPROM label obscures type" if ref == "U10" else "TC551001FL-10",
    )
    sequence(
        ref,
        [12, 11, 10, 9, 8, 7, 6, 5, 27, 26, 23, 25, 4, 28, addr14, addr15, addr16],
        [f"A{i}" for i in range(17)],
        [f"HA{i}" for i in range(17)],
    )
    sequence(
        ref,
        [13, 14, 15, 17, 18, 19, 20, 21],
        [f"IO{i}" for i in range(8)],
        [f"HD{i}" for i in range(8)],
    )
    hidden_power(ref, [] if ref == "U10" else [32], [16])
pin("U10", 22, "CE", "GND")
pin("U10", 2, "OE", "ROM")
pin("U10", 31, "PGM", "+5V")
pin(
    "U10",
    32,
    "",
    "VCC",
    note="Designer note explicitly says missing TANGO p32 VCC was forced into original netlist.",
)
pin(
    "U10",
    1,
    "",
    "?",
    note="VPP not drawn; datasheet identifies pin 1; termination unverified.",
)
pin("U10", 30, "", "NC", "medium", "Datasheet NC; pin omitted from symbol.")
pin("U11", 22, "CE1", "RAM")
pin("U11", 24, "OE", "MRD")
pin("U11", 29, "WE", "MWR")
pin("U11", 30, "CE2", "+5V")
pin("U11", 1, "", "NC", "medium", "TC551001 datasheet NC; pin omitted from symbol.")


def gal(sheet, ref, nets):
    part(
        sheet,
        ref,
        "GAL16V8A",
        20,
        "PLCC-20 (photo)",
        "GAL16V8A or AMI 18CV8; refdes mapping unverified",
    )
    names = {1: "I0/CK", 11: "I9"}
    names.update({n: f"I{n-1}" for n in range(2, 10)})
    names.update({n: f"F{n-12}" for n in range(12, 20)})
    for n, net in nets.items():
        pin(ref, n, names[n], net)
    hidden_power(ref, [20], [10])


gal(
    2,
    "U4",
    {
        1: "HA0",
        2: "HA1",
        3: "HA2",
        4: "HA3",
        5: "HA4",
        6: "HA5",
        7: "HA6",
        8: "HA7",
        9: "HRD",
        11: "HWR",
        12: "BCLK",
        13: "-IOE",
        14: "BACK",
        15: "AX",
        16: "BEN",
        17: "DIVOE",
        18: "VGAIO_SEL",
        19: "AIRQ0",
    },
)
gal(
    2,
    "U15",
    {
        1: "HCLK",
        2: "BACK",
        3: "IOCHRDY",
        4: "VGAIO_SEL",
        5: "HA19",
        6: "HA18",
        7: "HA17",
        8: "HA16",
        9: "RTS0",
        11: "-ME",
        12: "NC",
        13: "ROM",
        14: "RAM",
        15: "WAIT",
        16: "RS2",
        17: "NC",
        18: "RS1",
        19: "VGAIO",
    },
)
gal(
    2,
    "U17",
    {
        1: "HCLK",
        2: "CATCH",
        3: "CATCH_BANK",
        4: "BACK",
        5: "ARES",
        6: "NC",
        7: "NC",
        8: "NC",
        9: "NC",
        11: "NC",
        12: "RESN",
        13: "NC",
        14: "NC",
        15: "HA19",
        16: "BREQ",
        17: "INT_RES",
        18: "HWR",
        19: "RES",
    },
)
part(2, "U29", "7432", 14, "SOIC-14 (photo)", "74ACT32")
for n, net in {
    1: "-ME",
    2: "HRD",
    3: "MRD",
    4: "-ME",
    5: "HWR",
    6: "MWR",
    9: "-IOE",
    10: "HRD",
    8: "IORD",
    12: "-IOE",
    13: "HWR",
    11: "IOWR",
}.items():
    pin("U29", n, "", net)
hidden_power("U29", [14], [7])

# Sheet 3: two groups of DRAM address loads and reset straps.
for index in range(8):
    ref = f"U{20 + index}"
    first = [0, 8, 16, 20, 4, 12, 24, 28][index]
    suffix = "" if index < 4 else "A"
    part(
        3,
        ref,
        "44256Z",
        20,
        "ZIP-20 positions; position 10 key/NC",
        "256K x 4 ZIP DRAM (exact markings to verify)",
    )
    sequence(
        ref,
        [11, 12, 13, 14, 16, 17, 18, 19, 20],
        [f"A{i}" for i in range(9)],
        [f"MA{i}{suffix}" for i in range(9)],
    )
    sequence(
        ref,
        [6, 7, 3, 4],
        [f"IO{i}" for i in range(4)],
        [f"MD{i}" for i in range(first, first + 4)],
    )
    pin(ref, 1, "OE", "GND")
    pin(ref, 2, "CAS", "CASA")
    pin(ref, 8, "WE", ["WEA", "WEA", "WEC", "WEC", "WEB", "WEB", "WED", "WED"][index])
    pin(ref, 9, "RAS", "RASL")
    pin(ref, 10, "", "NC", "medium", "ZIP key/NC position; not a signal pin in symbol.")
    hidden_power(ref, [15], [5])
for ref, nets in [
    ("R39", ["VCC", "MD1", "MD2", "MD4", "NC", "NC"]),
    ("R21", ["GND", "MD11", "MD15", "MD10", "MD5", "MD3"]),
]:
    part(3, ref, "10K", 6, "6-pin bussed resistor network")
    for n, net in enumerate(nets, 1):
        pin(ref, n, "", net)
passive(3, "R27", "10K", "VCC", "MD8")
passive(3, "R26", "10K", "MD9", "GND")

# Sheet 4: Oak controller. Names below retain the symbol's bus spelling.
part(
    4,
    "U28",
    "OAK087",
    160,
    "QFP-160",
    "OTI087X",
    "SA19=HA19; SA20=VGAIO in drawing; production continuity unverified.",
)
sequence(
    "U28",
    list(range(2, 10)),
    [f"MD{i}" for i in range(24, 32)],
    [f"MD{i}" for i in range(24, 32)],
)
sequence(
    "U28",
    list(range(160, 144, -1)),
    [f"MD{i}" for i in range(23, 7, -1)],
    [f"MD{i}" for i in range(23, 7, -1)],
)
sequence(
    "U28",
    [143, 142, 140, 139, 138, 137, 136, 135],
    [f"MD{i}" for i in range(7, -1, -1)],
    [f"MD{i}" for i in range(7, -1, -1)],
)
sequence(
    "U28",
    list(range(50, 61)) + list(range(62, 71)),
    [f"SA{i}" for i in range(20)],
    [f"HA{i}" for i in range(20)],
)
sequence(
    "U28",
    [75, 76, 77, 81, 82, 83, 84, 85],
    [f"SD{i}" for i in range(8)],
    [f"HD{i}" for i in range(8)],
)
sequence(
    "U28",
    [25, 26, 27, 28, 30, 31, 32, 33],
    [f"P{i}" for i in range(8)],
    [f"P{i}" for i in range(8)],
)
for n, name, net in [
    (1, "VSS00", "GND"),
    (10, "BD0/-ATOEL", "NC"),
    (11, "BD1/DIR", "NC"),
    (12, "BD2/-SDLOE", "NC"),
    (13, "BD3/-SDHOE", "NC"),
    (14, "BD4/CPUA0", "NC"),
    (15, "BD5/CPUA1", "NC"),
    (16, "BD6/-CPUBHE", "NC"),
    (17, "BD7/CPURESET", "NC"),
    (18, "CSEL3", "CSEL3"),
    (19, "SSA(19)/GA20", "?"),
    (20, "SSA(18)/SRDY1", "?"),
    (21, "VDD0", "VCC"),
    (22, "VSS0", "GND"),
    (23, "SSA(17)/-LBSEL", "NC"),
    (24, "SWSENSE", "SWSENSE"),
    (29, "VSS01", "GND"),
    (34, "VSYNC", "VSYNCI"),
    (35, "HSYNC", "HSYNCI"),
    (36, "-BLANK", "-BLANK"),
    (37, "PCLK", "PCLKX"),
    (38, "SD8", "NC"),
    (39, "SD9", "NC"),
    (40, "SD10", "NC"),
    (41, "VSS02", "GND"),
    (42, "SD11", "NC"),
    (43, "SD12", "NC"),
    (44, "SD13", "NC"),
    (45, "SD14", "NC"),
    (46, "SD15", "NC"),
    (47, "-EEPCS/-ATDEN", "EECS"),
    (48, "-DACRD", "-DACRD"),
    (49, "-DACWR", "-DACWR"),
    (61, "VDD1", "VCC"),
    (71, "SA20", "VGAIO"),
    (72, "SA21", "GND"),
    (73, "SA22", "GND"),
    (74, "SA23", "GND"),
    (78, "-M16/SRDY", "NC"),
    (79, "IOCHRDY", "IOCHRDY"),
    (80, "VSS03", "GND"),
    (86, "AEN", "GND"),
    (87, "-RFSH", "RFSH"),
    (88, "-MRD", "MRD"),
    (89, "-MWR", "MWR"),
    (90, "CINT", "-INT0"),
    (91, "-IO16", "NC"),
    (92, "HLDA", "VCC"),
    (93, "ALE/-ADS", "ALE"),
    (94, "VDD2", "VCC"),
    (95, "-ROMEN/PROCLK", "NC"),
    (96, "VSS1", "GND"),
    (97, "RSET", "RESET"),
    (98, "ENVGA/-WR", "VCC"),
    (99, "-ZEROWS/-DC", "-ZEROWS"),
    (100, "-BHE", "VCC"),
    (101, "-IOR", "IORD"),
    (102, "-IOW", "IOWR"),
    (103, "CSEL2", "CSEL2"),
    (104, "CSEL1", "CSEL1"),
    (105, "CSEL0", "CSEL0"),
    (106, "VCLK", "VCLK"),
    (107, "MCLK", "MCLK"),
    (108, "MA23(1)", "MA1A"),
    (109, "MA23(2)", "MA2A"),
    (110, "MA23(3)", "MA3A"),
    (111, "MA23(4)", "MA4A"),
    (112, "MA23(5)", "MA5A"),
    (113, "MA23(6)", "MA6A"),
    (114, "MA23(7)", "MA7A"),
    (115, "MA23(8)", "MA8A"),
    (116, "-WEC", "N_U28_116"),
    (117, "-WED", "N_U28_117"),
    (118, "-WEA", "N_U28_118"),
    (119, "-WEB", "N_U28_119"),
    (120, "-RASL", "N_U28_120"),
    (121, "VSS04", "GND"),
    (122, "MA23(0)", "MA0A"),
    (123, "-CASA", "N_U28_123"),
    (124, "MA01(0)", "MA0"),
    (125, "-RASH/MA(9)", "NC"),
    (126, "MA01(1)", "MA1"),
    (127, "MA01(2)", "MA2"),
    (128, "MA01(3)", "MA3"),
    (129, "MA01(4)", "MA4"),
    (130, "VSS05", "GND"),
    (131, "MA01(5)", "MA5"),
    (132, "MA01(6)", "MA6"),
    (133, "MA01(7)", "MA7"),
    (134, "MA01(8)", "MA8"),
    (141, "VDD3", "VCC"),
    (144, "VSS06", "GND"),
]:
    pin("U28", n, name, net)

part(4, "R2", "22ohm", 16, "16-pin isolated resistor network")
for a, b, net, target in [
    (1, 16, "NC", "NC"),
    (2, 15, "NC", "NC"),
    (3, 14, "N_U28_123", "CASA"),
    (4, 13, "N_U28_120", "RASL"),
    (5, 12, "N_U28_119", "WEB"),
    (6, 11, "N_U28_118", "WEA"),
    (7, 10, "N_U28_117", "WED"),
    (8, 9, "N_U28_116", "WEC"),
]:
    pin("R2", a, "", net)
    pin("R2", b, "", target)
passive(4, "R4", "22ohm", "PCLK", "PCLKX")
passive(4, "R7", "22ohm", "N_U30_12", "MCLK")
passive(4, "R17", "22ohm", "VCLK", "VCLK1")
passive(4, "R38", "10ohm", "EXTAL", "MCLK", production="Unfitted")
passive(4, "R14", "10K", "VCC", "-ZEROWS")
passive(4, "R32", "10K", "VCC", "IOCHRDY")
passive(4, "R6", "10K", "VCC", "N_U30_9")
passive(4, "R19", "10K", "VCC", "N_U30_11")
passive(4, "JP2", "SHUNT", "N_U30_9", "GND", "2-pad jumper")
passive(4, "JP1", "SHUNT", "N_U30_11", "GND", "2-pad jumper")
gal(
    4,
    "U12",
    {
        1: "VCLK0",
        2: "DIVOE",
        3: "NC",
        4: "NC",
        5: "NC",
        6: "NC",
        7: "HSYNC",
        8: "VSYNC",
        9: "NC",
        11: "NC",
        12: "NC",
        13: "NC",
        14: "NC",
        15: "NC",
        16: "VCLK1",
        17: "NC",
        18: "XSYNC",
        19: "NC",
    },
)
for n, net in [(11, "VCLK1"), (12, "VCLK0"), (13, "DIVOE")]:
    pin("U8", n, "", net)
part(
    4,
    "U16",
    "NM93C46",
    8,
    "SOIC-8 (photo)",
    "ST part marked 93C466 9518 (photo): most probably ST93C46, temperature grade 6",
    "Marking read from the production front photo; never accessed by the firmware.",
)
for n, name, net in [
    (1, "CS", "EECS"),
    (2, "SK", "CSEL2"),
    (3, "DI", "CSEL1"),
    (4, "DO", "CSEL0"),
]:
    pin("U16", n, name, net)
hidden_power("U16", [8], [5])
for n in [6, 7]:
    pin(
        "U16",
        n,
        "",
        "NC",
        "medium",
        note="NM93C46 normal pinout NC; omitted from symbol. Not a statement about the production part's pins 6-7.",
    )
part(4, "U30", "OTI068", 20, "SOIC-20 (photo)", "OTI068")
for n, name, net in [
    (1, "XTAL1", "N_U30_1"),
    (2, "XTAL2", "N_U30_2"),
    (3, "AVSS", "GND"),
    (4, "FS0", "CSEL0"),
    (5, "FS1", "CSEL1"),
    (6, "STROBE", "NC"),
    (7, "FS2", "CSEL2"),
    (8, "FS3", "CSEL3"),
    (9, "MS0", "N_U30_9"),
    (10, "DVSS", "GND"),
    (11, "MS1", "N_U30_11"),
    (12, "MCLK", "N_U30_12"),
    (13, "DVDD", "VCC"),
    (14, "VSS", "GND"),
    (15, "AVDD", "VCC"),
    (16, "VSS", "GND"),
    (17, "VSS", "GND"),
    (18, "NC", "NC"),
    (19, "VCLK", "VCLK0"),
    (20, "DVDD", "VCC"),
]:
    pin("U30", n, name, net)
passive(4, "X2", "14.318MHz", "N_U30_1", "N_U30_2", "Crystal, 2 pins")
passive(4, "C3", "22pF", "N_U30_1", "GND")
passive(4, "C4", "22pF", "N_U30_2", "GND")
passive(
    4, "C8", "22uF", "VCC", "GND", "Polarized capacitor; pin 1 positive by convention"
)
passive(4, "C21", ".1uF", "VCC", "GND")

# Sheet 5: RAMDAC and analog output.
part(
    5,
    "U31",
    "BT478-JOZ",
    44,
    "PLCC-44",
    "Bt481AKPJ PROTO2",
    "RS2 production grounding reported by coordinator; see NETLIST.md.",
)
sequence(
    "U31", list(range(8, 16)), [f"D{i}" for i in range(8)], [f"HD{i}" for i in range(8)]
)
sequence(
    "U31", list(range(32, 40)), [f"P{i}" for i in range(8)], [f"P{i}" for i in range(8)]
)
for n, name, net in [
    (1, "", "NC"),
    (2, "8/6", "VAA"),
    (5, "SYNC", "VAA"),
    (6, "RD", "-DACRD"),
    (7, "BLANK", "-BLANK"),
    (16, "WR", "-DACWR"),
    (17, "RS0", "HA0"),
    (18, "RS1", "HA1"),
    (19, "RS2", "HA2"),
    (23, "SETUP", "N_U31_23"),
    (25, "IOR", "RED"),
    (26, "IOG", "GRN"),
    (27, "IOB", "BLU"),
    (28, "IREF", "RSET"),
    (29, "COMP", "N_U31_29"),
    (30, "OPA", "N_U31_29"),
    (31, "VREF", "N_U31_31"),
    (40, "CLOCK", "PCLK"),
    (41, "OL0", "GND"),
    (42, "OL1", "GND"),
    (43, "OL2", "GND"),
    (44, "OL3", "GND"),
]:
    pin("U31", n, name, net)
for n in [4, 21, 22]:
    pin(
        "U31",
        n,
        "",
        "VAA",
        "medium",
        "Hidden analog supply; datasheet pin assignment; rail inferred.",
    )
for n in [3, 24]:
    pin(
        "U31",
        n,
        "",
        "GND",
        "medium",
        "Hidden analog ground; datasheet pin assignment; rail inferred.",
    )
pin(
    "U31",
    20,
    "",
    "VAA",
    note="Explicit drawing note: please tie pin 20 to VAA (not shown). Bt478 VAA; Bt481 TRUECOL*.",
)
passive(5, "L6", "ferrite", "+5V", "VAA")
passive(5, "R31", "1K", "VAA", "N_U31_31")
passive(
    5, "D1", "1.2V Zener", "N_U31_31", "GND", "Zener diode; pin 1 cathode by convention"
)
passive(5, "R20", "147ohm metal", "RSET", "GND")
passive(5, "R3", "[Value]", "+5V", "N_U31_23")
passive(5, "JP3", "SHUNT", "N_U31_23", "GND", "2-pad jumper")
passive(5, "C30", ".1uF", "VAA", "N_U31_31")
passive(5, "C29", ".1uF", "VAA", "N_U31_29")
passive(5, "C31", ".1uF", "VAA", "GND")
passive(
    5,
    "C33",
    "10uF TANT",
    "VAA",
    "GND",
    "Polarized tantalum; pin 1 positive by convention",
)
passive(5, "R12", "22ohm", "VSYNCI", "VSYNC")
passive(5, "R13", "22ohm", "HSYNCI", "HSYNC")
passive(5, "C11", "22pF", "VSYNC", "GND")
passive(5, "C12", "22pF", "HSYNC", "GND")
for r, c, net in [("R9", "C5", "RED"), ("R10", "C6", "GRN"), ("R11", "C7", "BLU")]:
    passive(5, r, "75ohm metal", net, "GND")
    passive(5, c, "22pF", net, "GND")
part(5, "J1", "BERG16", 16, "2x8 header", "VGA IDC header")
for n, net in {
    1: "BLU",
    2: "NC",
    3: "GRN",
    4: "GND",
    5: "RED",
    6: "NC",
    7: "NC",
    8: "NC",
    9: "GND",
    10: "HSYNC",
    11: "GND",
    12: "VSYNC",
    13: "GND",
    14: "NC",
    15: "GND",
    16: "NC",
}.items():
    pin("J1", n, "", net)
for n in list(range(13, 21)) + list(range(22, 29)):
    passive(5, f"C{n}", ".1uF", "VCC", "GND")
passive(5, "C34", ".1uF", "+12V", "GND")
passive(5, "C32", ".1uF", "-12V", "GND")

# Record unresolved details in the source transcription.
pin_notes = {
    ("U2", 1): (
        "medium",
        "Blurred net label read BEN; matches U4.16, subject to original CAD/continuity confirmation.",
    ),
    ("U7", 35): ("medium", "Net reads RESET; do not silently alias to RESN on U17.12."),
    ("U17", 12): (
        "medium",
        "Net appears RESN. Relation to RESET is not established by this scan.",
    ),
    ("U17", 15): (
        "medium",
        "Blurred label read HA19; supplied handover also marks HA19 uncertain.",
    ),
    ("U28", 19): (
        "low",
        "Net label illegible (looks ECLK/BCLK); connected labeled stub, not a no-connect. Datasheet AT-mode function EPCLK.",
    ),
    ("U28", 20): (
        "low",
        "Net label illegible (looks EPCL); connected labeled stub, not a no-connect. Datasheet AT-mode function EPDATA.",
    ),
    ("U28", 71): (
        "medium",
        "Label read VGAIO, matching U15.19. Rotated crop distinguishes SA20 from neighboring SA19=HA19.",
    ),
    ("U31", 1): (
        "medium",
        "Bt478 datasheet NC; omitted from schematic symbol. Bt481 changes this pin to SENSE*.",
    ),
}
for row in rows:
    key = (row["refdes"], int(row["pin_number"]))
    if key in pin_notes:
        row["confidence"], row["note"] = pin_notes[key]
for ref in ["U2", "U3", "U5", "U6"]:
    parts[ref]["production_part"] = "PC74HCT574T (Philips)"
parts["R2"]["production_part"] = "Dale SOMC1603 330G resistor array (photo)"
parts["R2"][
    "notes"
] = "SOMC 16-pin isolated network, 330 = 33 ohms, G = 2 percent, versus 22 ohms on the schematic; not measured."
parts["R32"]["production_part"] = "SMD resistor marked 202 (photo)"
parts["R32"][
    "notes"
] = "202 = 2.0K, versus 10K on the schematic; not measured."
parts["JP1"]["production_part"] = "Axial resistor fitted in jumper position (photo)"
parts["JP1"][
    "notes"
] = "Value and electrical endpoints not measured; do not model as a closed zero-ohm shunt."


def write_csv(name, data, fields):
    with (ROOT / name).open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(data)


def export():
    # Assertions validate enumeration, not electrical accuracy of the source.
    for ref, data in parts.items():
        numbers = {int(r["pin_number"]) for r in rows if r["refdes"] == ref}
        assert numbers == set(range(1, data["count"] + 1)), (
            ref,
            numbers ^ set(range(1, data["count"] + 1)),
        )
    ordered = sorted(
        rows, key=lambda r: (str(r["sheet"]), r["refdes"], int(r["pin_number"]))
    )
    write_csv(
        "netlist.csv",
        ordered,
        [
            "sheet",
            "refdes",
            "part",
            "pin_number",
            "pin_name",
            "net",
            "confidence",
            "note",
        ],
    )
    nets = defaultdict(list)
    for row in ordered:
        nets[row["net"]].append(f"{row['refdes']}.{row['pin_number']}")
    inverse = [
        dict(net=net, pin_count=len(pins), pins=";".join(pins))
        for net, pins in sorted(nets.items())
    ]
    assert sum(r["pin_count"] for r in inverse) == len(rows)
    write_csv("nets.csv", inverse, ["net", "pin_count", "pins"])
    write_csv(
        "bom.csv",
        parts.values(),
        [
            "refdes",
            "value_or_part",
            "package",
            "prototype_part",
            "production_part",
            "notes",
        ],
    )
    report = dict(
        parts=len(parts),
        pins=len(rows),
        nets=len(nets),
        confidence={
            c: sum(r["confidence"] == c for r in rows)
            for c in ["high", "medium", "low"]
        },
        unresolved=[
            f"{r['refdes']}.{r['pin_number']}"
            for r in rows
            if r["net"].startswith("UNRESOLVED_")
        ],
    )
    (ROOT / "validation.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    export()
