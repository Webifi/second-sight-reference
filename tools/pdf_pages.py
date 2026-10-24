"""Extract the page images from the scanned PDFs (schematic, databooks, manual).

The scans are bitmaps wrapped in PDF. This script pulls each page image out and saves it
as PNG, so you can zoom into part numbers and net labels at the scan's full resolution.
It handles the three encodings these files use:

- CCITT G4 (the schematic and the mirror's OTI-087 / OTI-068 databooks): wrapped in a
  one-strip TIFF in memory and decoded by Pillow.
- JPEG 2000 (the manual).
- JPEG (the bitsavers OTI-087 scan, the photos page of the manual).

Usage:
    python tools/pdf_pages.py <file.pdf> <out_dir> [--rotate DEG] [--scale F]

The schematic sheets are drawn in landscape; use --rotate -90 to turn them upright.
Requires Pillow (pip install pillow).
"""

import io
import re
import struct
import sys
from pathlib import Path

from PIL import Image, ImageFile

ImageFile.LOAD_TRUNCATED_IMAGES = True


def tiff_g4(data, width, height, black_is_1):
    """Wrap a raw CCITT G4 stream in a minimal little-endian TIFF so Pillow can decode it."""
    photometric = 1 if black_is_1 else 0
    entries = [
        (256, 4, 1, width),
        (257, 4, 1, height),
        (258, 3, 1, 1),
        (259, 3, 1, 4),
        (262, 3, 1, photometric),
        (273, 4, 1, 0),
        (277, 3, 1, 1),
        (278, 4, 1, height),
        (279, 4, 1, len(data)),
    ]
    ifd_offset = 8
    data_offset = ifd_offset + 2 + len(entries) * 12 + 4
    out = bytearray(b"II*\x00" + struct.pack("<I", ifd_offset))
    out += struct.pack("<H", len(entries))
    for tag, kind, count, value in entries:
        if tag == 273:
            value = data_offset
        if kind == 3:
            out += struct.pack("<HHIHH", tag, kind, count, value, 0)
        else:
            out += struct.pack("<HHII", tag, kind, count, value)
    out += struct.pack("<I", 0)
    return bytes(out) + data


def stream_bytes(pdf, header_start, header_end):
    """Return the raw stream that follows an object header."""
    header = pdf[header_start:header_end]
    start = pdf.find(b"stream", header_end) + len(b"stream")
    if pdf[start:start + 2] == b"\r\n":
        start += 2
    elif pdf[start:start + 1] == b"\n":
        start += 1
    length = re.search(rb"/Length (\d+)(?!\s+\d+\s+R)", header)
    if length:
        return pdf[start:start + int(length.group(1))]
    return pdf[start:pdf.find(b"endstream", start)].rstrip(b"\r\n")


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    src, out_dir = Path(sys.argv[1]), Path(sys.argv[2])
    rotate = float(sys.argv[sys.argv.index("--rotate") + 1]) if "--rotate" in sys.argv else 0
    scale = float(sys.argv[sys.argv.index("--scale") + 1]) if "--scale" in sys.argv else 1.0
    out_dir.mkdir(parents=True, exist_ok=True)
    pdf = src.read_bytes()
    count = 0
    for match in re.finditer(rb"/Subtype\s*/Image", pdf):
        header_start = pdf.rfind(b"<<", 0, match.start())
        header_end = pdf.find(b"stream", match.start())
        header = pdf[header_start:header_end]
        width = int(re.search(rb"/Width (\d+)", header).group(1))
        height = int(re.search(rb"/Height (\d+)", header).group(1))
        if width < 400 or height < 400:
            continue  # skip small mask fragments and logos
        data = stream_bytes(pdf, header_start, header_end)
        if b"CCITTFaxDecode" in header:
            black_is_1 = b"/BlackIs1 true" in header
            image = Image.open(io.BytesIO(tiff_g4(data, width, height, black_is_1)))
        elif b"JPXDecode" in header or b"DCTDecode" in header:
            image = Image.open(io.BytesIO(data))
        else:
            continue
        image.load()
        image = image.convert("L")
        if rotate:
            image = image.rotate(rotate, expand=True)
        if scale != 1.0:
            image = image.resize((int(image.width * scale), int(image.height * scale)), Image.LANCZOS)
        count += 1
        image.save(out_dir / f"page{count:02d}.png")
    print(f"{count} page images written to {out_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
