"""Decode Second Sight video mode records: the firmware's built-in tables and the mode files.

Every mode on the card is one 81-byte record of VGA register values, in the order the
firmware's set_video_mode writes them:

    0       misc output ($3C2)
    1       sequencer 1, clocking mode
    2       feature byte: bit 0 selects the output path (0 = VGA via port $A8,
            1 = AppleColor RGB via port $A9, pixel clock divided by 2), bits 3-1 go to the
            feature control register ($3DA), bits 7-4 go to the Bt481 Command Register A
    3-5     sequencer 2-4
    6-30    CRTC 0-$18 (25 registers)
    31-39   graphics controller 0-8
    40-60   attribute controller 0-$14
    61-80   Oak extended registers 02, 03, 04, 05, 06, 13, 14, 15, 17, 19, 20, 21, 22, 25,
            30, 31, 32, 33, 34, 35

The library's vga_mode_rec (VGA.H) is the same 81 bytes plus 30 unused bytes (111 bytes).
Some older mode files on ss.source.082395.po are bare 81-byte records. Four 939-byte files (M40,
XX, XXX, VGA/M800X600.36M) hold the 81 bytes as assembler source: `db` lines of `0XXh`
values with `;` comments.

This prints the timing each record programs.

Usage:
    python tools/mode_files.py <image.po> SECOND/MISC/VGA/M640X48032K.50M [more paths...]
    python tools/mode_files.py --firmware "sources/mirror/ROM Images/ROM_BEEF.bin"
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import prodos  # noqa: E402

# Oak extended registers held in record bytes 61-80, in the order the firmware writes them.
EXT_INDEX = [0x02, 0x03, 0x04, 0x05, 0x06, 0x13, 0x14, 0x15, 0x17, 0x19,
             0x20, 0x21, 0x22, 0x25, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35]
OTI068_MHZ = [25.175, 28.322, 65.0, 44.9, 28.322, 36.0, 40.0, 36.0,
              25.175, 28.322, 78.0, 65.0, 63.0, 72.0, 40.0, 50.0]

# Firmware mode codes, in the order of the lists in ROM_BEEF (vga_modes_table and
# applecolor_rgb_modes_table). Each list is followed by a table of 16-bit pointers.
FIRMWARE_VGA_CODES = bytes([0x01, 0x03, 0x13, 0x53, 0x61, 0xFA, 0xFB, 0xFC, 0xFD, 0xFE])
FIRMWARE_RGB_CODES = bytes([0x01, 0x03, 0x61, 0xFA, 0xFB, 0xFC, 0xFD, 0xFE])


def describe(name, d):
    """Return one line describing the timing of an 81- or 111-byte mode record."""
    if len(d) not in (81, 111):
        return f"{name}: {len(d)} bytes (not a mode record)"
    misc, clocking, feature = d[0], d[1], d[2]
    crt = d[6:31]
    ext = d[61:81]
    htotal = crt[0] + 5
    hdisp = crt[1] + 1
    dots = 8 if clocking & 1 else 9
    vtotal = (crt[6] | ((crt[7] & 1) << 8) | ((crt[7] & 0x20) << 4)) + 2
    vdisp = (crt[0x12] | ((crt[7] & 2) << 7) | ((crt[7] & 0x40) << 3)) + 1
    # CRTC 9: bit 7 shows every scan line twice; bits 4-0 are scan lines per row minus 1.
    lines_per_row = (crt[9] & 0x1F) + 1
    double_scan = " double-scan" if crt[9] & 0x80 else ""
    # set_video_mode writes ext 6 first and the misc output register ($3C2) after it.
    # Ext 6 bits 1-0 are the same storage as misc bits 3-2 (databook p35), so the misc
    # write decides CSEL1-0; CSEL3-2 stay as ext 6 set them.
    ext6 = ext[EXT_INDEX.index(0x06)]
    clock_select = (ext6 & 0x0C) | ((misc >> 2) & 0x03)
    override = "" if (ext6 & 0x03) == ((misc >> 2) & 0x03) else f" (ext06 ${ext6:02X} overridden by misc ${misc:02X})"
    mhz = OTI068_MHZ[clock_select]
    ext21 = ext[EXT_INDEX.index(0x21)]
    # Oak ext 21: bit 0 multiplies horizontal timing by 2 (hi-color), bit 1 by 3 (true color).
    multiplier = 3 if ext21 & 2 else (2 if ext21 & 1 else 1)
    # Sequencer clocking mode bit 3 halves the dot clock.
    divide = 2 if clocking & 0x08 else 1
    # Feature byte bit 0 selects port $A9 (AppleColor RGB path, VCLK divided by 2 in GAL U12).
    rgb_divide = 2 if feature & 1 else 1
    line_khz = mhz * 1000 / divide / rgb_divide / (htotal * dots * multiplier)
    frame_hz = line_khz * 1000 / vtotal
    path = "RGB ($A9, /2)" if rgb_divide == 2 else "VGA ($A8)"
    # Oak ext $14 bit 7 turns on interlace (databook pp39-40). The vertical counts are then
    # per field, and two fields make one frame with twice the lines: ROM 1.4's AppleColor
    # RGB mode $61 is 200 lines per field, 640 x 400 in all.
    if ext[EXT_INDEX.index(0x14)] & 0x80:
        vertical = (f"vtotal {vtotal} per field, visible lines {vdisp} per field, interlaced "
                    f"({2 * vdisp} lines per frame), {lines_per_row} line(s) per row{double_scan}, "
                    f"line rate {line_khz:.2f} kHz, field {frame_hz:.1f} Hz, "
                    f"frame {frame_hz / 2:.1f} Hz, ")
    else:
        vertical = (f"vtotal {vtotal}, visible lines {vdisp}, {lines_per_row} line(s) per "
                    f"row{double_scan}, line rate {line_khz:.2f} kHz, frame {frame_hz:.1f} Hz, ")
    return (f"{name}: OTI-068 code {clock_select:X} = {mhz} MHz{override}, clocking ${clocking:02X}, "
            f"Bt481 CR A ${feature & 0xF0:02X}, output path {path}, "
            f"htotal {htotal * dots} x{multiplier} clocks, visible {hdisp * dots}, "
            f"{vertical}"
            f"ext05 ${ext[EXT_INDEX.index(0x05)]:02X}, ext20 ${ext[EXT_INDEX.index(0x20)]:02X}, "
            f"ext21 ${ext21:02X}, "
            f"ext22 ${ext[EXT_INDEX.index(0x22)]:02X}")


def assembler_record(data):
    """Return the record held in a mode file written as assembler source, or None.

    The file is Apple text (high bit set, CR line ends). Every `db` line contributes its
    comma-separated `0XXh` values in order; text after `;` is a comment. The result is a
    record only when every value is hexadecimal and there are 81 or 111 of them; any other
    file (program source, notes) returns None.
    """
    text = bytes(b & 0x7F for b in data).decode("ascii", "replace").replace("\r", "\n")
    values = []
    for line in text.splitlines():
        code = line.split(";", 1)[0].strip()
        if not code.lower().startswith("db"):
            continue
        for item in code[2:].split(","):
            item = item.strip()
            if not item:
                continue
            try:
                values.append(int(item.rstrip("hH"), 16))
            except ValueError:
                return None
    if len(values) not in (81, 111):
        return None
    return bytes(values)


def firmware_tables(rom):
    """Yield (monitor, mode code, record) for each built-in mode table in the EPROM image."""
    low = rom[:0x10000]
    for monitor, codes in (("VGA", FIRMWARE_VGA_CODES), ("AppleColor RGB", FIRMWARE_RGB_CODES)):
        at = low.find(codes)
        if at < 0:
            raise ValueError(f"{monitor} mode list not found")
        pointers = at + len(codes)
        for i, code in enumerate(codes):
            address = low[pointers + 2 * i] | (low[pointers + 2 * i + 1] << 8)
            yield monitor, code, low[address:address + 81]


def main():
    if len(sys.argv) == 3 and sys.argv[1] == "--firmware":
        rom = Path(sys.argv[2]).read_bytes()
        for monitor, code, record in firmware_tables(rom):
            print(describe(f"firmware {monitor} mode ${code:02X}", record))
        return 0
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    image = prodos.read_image(sys.argv[1])
    wanted = {p.strip("/").upper() for p in sys.argv[2:]}
    for path, info in prodos.walk(image, 2):
        if info is not None and path.upper() in wanted:
            data = prodos.file_bytes(image, info[0], info[1], info[2])
            if len(data) not in (81, 111):
                data = assembler_record(data) or data
            print(describe(path, data))
    return 0


if __name__ == "__main__":
    sys.exit(main())
