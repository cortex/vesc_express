#!/usr/bin/python3
# this is meant to run on linux (wsl in my case)
# it might work on windows though

# some dependency help: pip install bitstring


import argparse
import os
import sys
import math
import itertools
import bitstring
from bitstring import BitArray, Bits
from typing import *
import typing
from PIL import Image


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


def panic(reason: str):
    eprint(reason)
    exit(1)


T = TypeVar('T')


def split_every(iterable: Iterable[T], n) -> Iterator[List[T]]:
    """
    Slice an iterable into chunks of n elements
    :type n: int
    :type iterable: Iterable
    :rtype: Iterator
    """
    iterator = iter(iterable)
    return itertools.takewhile(bool, (list(itertools.islice(iterator, n)) for _ in itertools.repeat(None)))


def bits_chunks(bits: Bits, n: int) -> List[Bits]:
    bits_str: str = bits.bin
    str_chunks = split_every(bits_str, n)
    return list(map(lambda bits_chars: Bits(bin="".join(itertools.chain(*bits_chars))), str_chunks))


def putpixel(img: Image.Image, x: int, y: int, color: int, bits: int):
    min(max(0, color), bits - 1)
    factor = color / (2 ** bits - 1)
    color_value = int(255 * factor)

    color = (color_value, color_value, color_value)

    img.putpixel((x, y), color)


def parse_content(content: bytes) -> Image.Image:
    width = int.from_bytes(content[0:2], 'big')
    height = int.from_bytes(content[2:4], 'big')
    bit_count = int.from_bytes(content[4:5], 'big')
    if bit_count not in [1, 2, 4]:
        panic(
            f"invalid bit count: {bit_count}. only indexed2, indexed4, and indexed16 is supported")

    print(f"image {width}x{height}, bits: {bit_count}")

    img = Image.new("RGB", (width, height), 0)
    img_data = content[5:]
    pixels = width * height
    pixel_index = 0
    byte_pixel_count = 8 // bit_count
    img_bits = BitArray(bytes=img_data)

    pixels = bits_chunks(img_bits, bit_count)

    x = 0
    y = 0
    for bits in pixels:
        if x >= width:
            x = 0
            y += 1
            if y >= height:
                break
        color: int = bits.uint
        putpixel(img, x, y, color, bit_count)
        x += 1

    return img


parser = argparse.ArgumentParser(
    prog="bin2png.py",
    description="Test to convert vesc binary images to png",
)

# parser.add_argument('-h', '--help', help="show this list")
parser.add_argument(
    'source', help="A single BIN file.")

parser.add_argument(
    'dest',
    default="",
    nargs="?",
    help="The directory to place the generated PNG file into.",
)

args = parser.parse_args()

source: str = args.source
dest: str = args.dest

source_is_file = os.path.isfile(source)

if not source_is_file:
    panic(f"source file '{source}' does not exist")

dest_is_file = os.path.isfile(dest)
dest_is_directory = os.path.isdir(dest)

if dest_is_file:
    panic(f"destination '{dest}' exists but is not a directory")

if not dest_is_directory:
    dest_fixed = "./" if dest == "" else dest
    os.makedirs(dest_fixed, exist_ok=True)

path = source


with open(path, "rb") as file:
    basename = os.path.basename(path)
    root, ext = os.path.splitext(basename)

    basename = root + ".png"
    path = os.path.join(dest, basename)
    print(f"saved '{path}'")

    content = file.read()
    img = parse_content(content)
    img.save(path)
