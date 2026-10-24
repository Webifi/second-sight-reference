"""Dump the text layer of a PDF whose content streams use Flate or LZW compression.

Useful for the Bt481A datasheet (LZW streams) and the OCR layer of the bitsavers OTI-087
scan. It prints the strings that the page operators show, in file order, one block per
content stream. It does not lay text out; it is for searching.

Usage:
    python tools/pdf_text.py <file.pdf> <out.txt>
"""

import re
import sys
import zlib


def lzw_decode(data, early_change=1):
    """Decode a PDF LZWDecode stream (9-12 bit codes, MSB first, clear 256, end 257)."""
    out = bytearray()
    bits = 0
    nbits = 0
    code_len = 9
    table = [bytes([i]) for i in range(256)] + [None, None]
    prev = None
    pos = 0
    while True:
        while nbits < code_len and pos < len(data):
            bits = (bits << 8) | data[pos]
            pos += 1
            nbits += 8
        if nbits < code_len:
            break
        nbits -= code_len
        code = (bits >> nbits) & ((1 << code_len) - 1)
        if code == 256:
            table = table[:258]
            code_len = 9
            prev = None
            continue
        if code == 257:
            break
        if prev is None:
            entry = table[code]
            out += entry
            prev = entry
            continue
        if code < len(table):
            entry = table[code]
            table.append(prev + entry[:1])
        else:
            entry = prev + prev[:1]
            table.append(entry)
        out += entry
        prev = entry
        if len(table) + early_change >= (1 << code_len) and code_len < 12:
            code_len += 1
    return bytes(out)


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    pdf = open(sys.argv[1], "rb").read()
    blocks = []
    for match in re.finditer(rb"<<(.*?)>>\s*stream\r?\n", pdf, re.S):
        header = match.group(1)
        if b"/Image" in header:
            continue
        length = re.search(rb"/Length (\d+)(?!\s+\d+\s+R)", header)
        start = match.end()
        raw = pdf[start:start + int(length.group(1))] if length else pdf[start:pdf.find(b"endstream", start)]
        try:
            if b"LZWDecode" in header:
                body = lzw_decode(raw)
            elif b"FlateDecode" in header:
                body = zlib.decompress(raw)
            else:
                body = raw
        except Exception:
            continue
        parts = re.findall(rb"\(((?:[^()\\]|\\.)*)\)", body)
        if parts:
            text = b"".join(re.sub(rb"\\([()\\])", rb"\1", p) for p in parts)
            blocks.append(text.decode("latin1"))
    open(sys.argv[2], "w", encoding="utf-8").write("\f\n".join(blocks))
    print(f"{len(blocks)} text blocks, {sum(len(b) for b in blocks)} characters")
    return 0


if __name__ == "__main__":
    sys.exit(main())
