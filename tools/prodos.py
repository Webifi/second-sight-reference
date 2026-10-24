"""List and extract files from the ProDOS-order disk images (.po) in the sources.

The disk image ss.source.082395.po holds the IIgs library source
(VGALOW.ASM, VGALIB.C, VGA.H), the video mode files, SecondView and the ZMAC Z80
assembler. This reads the ProDOS directory tree and file blocks directly.

Usage:
    python tools/prodos.py ls  <image.po>
    python tools/prodos.py cat <image.po> <PATH/IN/IMAGE> [--raw] > out

`cat` converts Apple text (high bit set, CR line ends) to plain text unless --raw is given,
in which case the bytes are written unchanged (use --raw for binary mode files).
"""

import sys


def read_image(path):
    return open(path, "rb").read()


def block(image, number):
    return image[number * 512:(number + 1) * 512]


def entries(image, key_block):
    """Yield (storage_type, name, key_pointer, eof, file_type) for one directory."""
    current = key_block
    first = True
    while current:
        data = block(image, current)
        next_block = data[2] | (data[3] << 8)
        for i in range(13):
            entry = data[4 + i * 39:4 + (i + 1) * 39]
            if first and i == 0:
                continue  # directory header
            storage = entry[0] >> 4
            name_len = entry[0] & 15
            if storage == 0 or name_len == 0:
                continue
            name = entry[1:1 + name_len].decode("ascii")
            key = entry[0x11] | (entry[0x12] << 8)
            eof = entry[0x15] | (entry[0x16] << 8) | (entry[0x17] << 16)
            yield storage, name, key, eof, entry[0x10]
        first = False
        current = next_block


def index_block(image, number):
    data = block(image, number)
    return [data[i] | (data[256 + i] << 8) for i in range(256)]


def file_bytes(image, storage, key, eof):
    """Return a file's data fork. Storage 1-3 are seedling, sapling and tree files.

    Storage 5 is a GS/OS extended (forked) file: its key block holds a mini directory
    entry for the data fork at offset 0 (storage, key block, blocks used, 3-byte EOF) and
    one for the resource fork at offset 256. Only the data fork is returned.
    """
    if storage == 5:
        mini = block(image, key)
        data_storage = mini[0] & 0x0F
        data_key = mini[1] | (mini[2] << 8)
        data_eof = mini[5] | (mini[6] << 8) | (mini[7] << 16)
        return file_bytes(image, data_storage, data_key, data_eof)
    if storage == 1:  # seedling
        blocks = [key]
    elif storage == 2:  # sapling
        blocks = index_block(image, key)
    elif storage == 3:  # tree
        blocks = []
        for master in index_block(image, key):
            blocks += index_block(image, master) if master else [0] * 256
    else:
        raise ValueError(f"unsupported ProDOS storage type {storage}")
    return b"".join(block(image, b) if b else bytes(512) for b in blocks)[:eof]


def walk(image, key, prefix=""):
    for storage, name, ptr, eof, ftype in entries(image, key):
        path = prefix + name
        if storage == 0xD:
            yield path + "/", None
            yield from walk(image, ptr, path + "/")
        else:
            yield path, (storage, ptr, eof, ftype)


def main():
    if len(sys.argv) < 3 or sys.argv[1] not in ("ls", "cat"):
        print(__doc__)
        return 1
    image = read_image(sys.argv[2])
    if sys.argv[1] == "ls":
        for path, info in walk(image, 2):
            if info is None:
                print(path)
            elif info[0] == 5:
                size = len(file_bytes(image, info[0], info[1], info[2]))
                print(f"{path:48s} type=${info[3]:02X} size={size} (data fork; also has a resource fork)")
            else:
                print(f"{path:48s} type=${info[3]:02X} size={info[2]}")
        return 0
    want = sys.argv[3].strip("/").upper()
    for path, info in walk(image, 2):
        if info is not None and path.upper() == want:
            data = file_bytes(image, info[0], info[1], info[2])
            if "--raw" in sys.argv:
                sys.stdout.buffer.write(data)
            else:
                text = bytes(c & 0x7F for c in data).replace(b"\r", b"\n")
                sys.stdout.buffer.write(text)
            return 0
    print("not found: " + sys.argv[3], file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
