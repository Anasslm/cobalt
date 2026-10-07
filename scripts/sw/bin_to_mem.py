#!/usr/bin/env python3

import sys
from pathlib import Path


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input.bin> <output.mem>")
        sys.exit(1)

    input_file = Path(sys.argv[1])
    output_file = Path(sys.argv[2])

    data = input_file.read_bytes()

    # Pad to 64-bit boundary
    if len(data) % 8:
        data += b"\x00" * (8 - len(data) % 8)

    with output_file.open("w") as f:
        for i in range(0, len(data), 8):
            word = int.from_bytes(
                data[i:i + 8],
                byteorder="little"
            )
            f.write(f"{word:016x}\n")


if __name__ == "__main__":
    main()