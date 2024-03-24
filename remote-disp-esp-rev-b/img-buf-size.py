#!/usr/bin/python3

import argparse
import os
import sys
from typing import *

# Please note that this code is based on my admittedly shallow understanding of
# how image buffers work internally. So its probably not exactly correct.


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


def panic(reason: str) -> NoReturn:
    eprint(reason)
    exit(1)


def get_size_bytes(fmt: str, width: int, height: int) -> float:
    pixel_bits: int
    if fmt == "indexed2":
        pixel_bits = 1
    elif fmt == "indexed4":
        pixel_bits = 2
    elif fmt == "rgb332":
        pixel_bits = 8
    elif fmt == "rgb565":
        pixel_bits = 16
    elif fmt == "rgb888":
        pixel_bits = 24
    else:
        panic(f"Invalid color fmt '{fmt}'")

    return float(width * height * pixel_bits / 8)


parser = argparse.ArgumentParser(
    prog="img-buf-size",
    description="Calculates the expected array size in bytes of an image buffer in the VESC express extension for LispBM.\n\
        See the documentation for more information: https://github.com/vedderb/vesc_express/blob/main/main/display/README.md#image-buffers \n\
        Please note that this code is based on my admittedly shallow understanding of how image buffers work internally. So its probably not exactly correct.",
)

parser.add_argument(
    dest="color_fmt",
    metavar="color-fmt",
    choices=["indexed2", "indexed4", "rgb332", "rgb565", "rgb888", ],
    help="The stored color format. See the documentation for more info. One of {indexed2, indexed4, rgb332, rgb565, rgb888}",
)

parser.add_argument(
    'width',
    type=int,
    help="The image buffer width",
)

parser.add_argument(
    'height',
    type=int,
    help="The image buffer height",
)

parser.add_argument(
    "-b",
    "--brief",
    action="store_true",
    help="Only print the size as a number without a unit",
)

args = parser.parse_args()

fmt: str = args.color_fmt
width: int = args.width
height: int = args.height
brief: bool = args.brief

size = get_size_bytes(fmt, width, height)

size_str = str(int(size)) if size.is_integer() else f"{size:n}"

if brief:
    print(size_str)
else:
    print(f"{size_str} bytes")
