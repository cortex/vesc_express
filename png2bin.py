#!/usr/bin/python3
# this is meant to run on linux (wsl in my case)
# it might work on windows though

# It should be possible to make this code work with other file formats than PNG
# using pillow

# dependencies:
# pip install Pillow
# pip install bitstring

import argparse
import os
import sys
import math
from math import *
import itertools
from typing import *
from bitstring import BitArray
from PIL import Image

RgbTuple = Tuple[int, int, int]


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


def panic(reason: str):
    eprint(reason)
    exit(1)


def to_bit_string(number: int, bit_count: int) -> str:
    return f"{{:#0{bit_count + 2}b}}".format(number)


"""
Get a specific segment of hexadecimal digits shifted shifted to the right 
source: https://www.desmos.com/calculator/pbqpfwduxb
yes, this is very ugly ;)
"""


def get_hex_number_slice(hex_num: int, start_digit: int, end_digit: int) -> int:
    return int(floor((hex_num - floor(hex_num / 16 ** end_digit)
                      * 16 ** end_digit) / 16 ** start_digit))


def int_to_rgb(rgb_integer: int) -> RgbTuple:
    # hex_string = rgb_integer
    r = get_hex_number_slice(rgb_integer, 4, 6)
    g = get_hex_number_slice(rgb_integer, 2, 4)
    b = get_hex_number_slice(rgb_integer, 0, 2)
    return (r, g, b)


def color_dist(a: RgbTuple, b: RgbTuple) -> float:
    return math.sqrt((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2)


def get_palette_index(color: RgbTuple, palette: List[RgbTuple]) -> int:

    # source: https://stackoverflow.com/a/11825864/15507414
    distances = list(map(lambda p_color: color_dist(color, p_color), palette))

    return min(range(len(distances)), key=distances.__getitem__)


def gray_gradient_get_color(index: int, length: int) -> RgbTuple:
    value = index / length
    component = int(value * 255.0)
    return (component, component, component)


def rgb_str_to_color(rgb: str) -> RgbTuple:
    rgb = rgb.lower()
    if rgb.startswith("0x"):
        hex = rgb[2:]
        if len(hex) > 6:
            panic(
                f"given integer color '{rgb}' is too long, it must be no longer than 6.")

        for digit in hex:
            if digit not in "0123456789abcdef":
                panic(
                    f"given integer color '{rgb}' contains invalid digit '{digit}'")
        value = int(hex, 16)
        color = int_to_rgb(value)
        return color
    if rgb.startswith("#"):
        hex = rgb[1:]
        for digit in hex:
            if digit not in "0123456789abcdef":
                panic(
                    f"given hex color '{rgb}' contains invalid digit '{digit}'")

        if len(hex) != 6:
            panic(
                f"given hex color '{rgb}' has invalid amount of hex digits, must be 6")
        r = int(hex[0:2], 16)
        g = int(hex[2:4], 16)
        b = int(hex[4:6], 16)
        return (r, g, b)
    if rgb.startswith("rgb"):
        rgb_tuple = rgb[3:]

        if not rgb_tuple.startswith("(") and not rgb_tuple.endswith(")"):
            panic(
                f"given rgb color '{rgb}' is not valid. Valid example: 'rgb(0, 0, 0)'")
        rgb_tuple = rgb_tuple.removeprefix("(").removesuffix(")")

        def parse_color_component(component: str) -> int:
            component = component.strip()
            if component.isnumeric():
                return int(component)
            elif component.isdecimal():
                return int(float(component) * 255.0)
            else:
                panic(
                    f"given rgb color '{rgb}' contains invalid component '{component}'. Valid examples are '255' or '1.0'")

        components = list(map(parse_color_component, rgb_tuple.split(",")))
        if len(components) != 3:
            panic(
                f"given rgb color '{rgb}' contains an invalid number of components {len(components)}, it must contain exactly 3 components")
        return (components[0], components[1], components[2])
    else:
        panic(
            f"given color '{rgb}' follows no valid format, valid examples: {{'#ffffff', '0xffffff', 'rgb(255, 255, 255)', 'rgb(1.0, 1.0, 1.0)'}}")


def to_bin(img: Image.Image, bit_count: Literal[1, 2, 4], palette: List[RgbTuple]) -> bytes:
    width: int = img.width
    height: int = img.height

    bits = BitArray()

    bits.append(to_bit_string(width, 16))
    bits.append(to_bit_string(height, 16))
    bits.append(to_bit_string(bit_count, 8))

    has_palette = img.getpalette() != None

    for y in range(height):
        for x in range(width):
            if has_palette:
                index: int = img.getpixel((x, y))
            else:
                color: RgbTuple = img.getpixel((x, y))
                index = get_palette_index(color, palette)
            if index >= 2 ** bit_count:
                panic(
                    f"Encountered invalid color index {index} for given `bit_count` {bit_count}. This should not be possible if `to_bin` was used correctly, the `palette` argument was likely the wrong length.")

            # print(bit_str)

            bits.append(to_bit_string(index, 2))

    return bits.tobytes()


parser = argparse.ArgumentParser(
    prog="svg2png",
    description="Converts PNGs into a binary format compatible with the VESC express graphics library.",
)

# parser.add_argument('-h', '--help', help="show this list")

parser.add_argument(
    'source',
    help="a single PNG file or a the directory containing the PNGs to convert. \
        Any non-PNG files in the directory will be ignored."
)
parser.add_argument(
    'dest',
    help="The directory to place the generated BINs inside, or a filepath with the destination filename.\
        If dest ends with '.bin', it is interpreted as a complete filepath, otherwise as a directory to place the file inside of.\
        If a filename is given when operating on multiple files, the destination filename is appended to the original filename\
        (ex: given the destination 'destination/-postfix.bin', the image '/path/to/image.png' is saved as 'destination/image-postfix.bin').",
)

parser.add_argument(
    dest="color_fmt",
    metavar="color-fmt",
    choices=["indexed2", "indexed4", "indexed16"],
    help="The stored color format. See the VESC express documentation for more info about what they mean. One of {indexed2, indexed4, rgb332, rgb565, rgb888}",
)

parser.add_argument(
    '-p',
    '--palette',
    metavar="COL",
    type=str,
    nargs="*",
    help="A list of rgb colors that map the output color indices to the input image rgb colors.\
        The length must be smaller or equal to the corresponding length of color-fmt exactly (ex: length of 4 for 'indexed4').\
        If no exact match in the palette is found for any image color, the closest color in the palette is chosen instead.\
        Valid colors must follow any of these case-insensitive formats: {'#ffffff', '0xffffff', '0x0', rgb(255, 255, 255), rgb(1.0, 1.0, 1.0)} (Note that hashtags may need escaping depending on your shell, ex: '\#ffffff').\
        (The default is a list of evenly spaced gray-scale colors from black to white with the correct length for the given color-fmt, or the PNG palette if the image has one.)",
)

args = parser.parse_args()

fmt: str = args.color_fmt
if fmt == "indexed2":
    bit_count = 1
elif fmt == "indexed4":
    bit_count = 2
elif fmt == "indexed16":
    bit_count = 4
else:
    panic(
        f"invalid format '{fmt}' given, valid values are 'indexed2', 'indexed4', and 'indexed16'")

palette_strings: Union[List[str], None] = args.palette
if palette_strings == None:
    length = 2 ** bit_count
    palette = list(
        map(lambda i: gray_gradient_get_color(i, length), range(length)))
else:
    palette = list(
        map(lambda col_str: rgb_str_to_color(col_str), palette_strings))
    length = 2 ** bit_count
    if len(palette) > length:
        panic(
            f"given palette '{' '.join(palette)}' too large. The length must be no longer than {length} for given format '{fmt}'")

source: str = args.source
dest: str = args.dest

if dest.endswith(".bin"):
    (dest, dest_name) = os.path.split(dest)
else:
    dest_name = None

source_is_dir = os.path.isdir(source)
source_is_file = os.path.isfile(source)

if not source_is_dir and not source_is_file:
    panic(f"source directory or file '{source}' does not exist")

if source_is_file and not source.endswith(".png"):
    panic(f"source file '{source}' is not an PNG")

if os.path.isfile(dest):
    panic(f"destination '{dest}' exists, but is not a directory")

os.makedirs(dest, exist_ok=True)
if not os.path.isdir(dest):
    panic(f"failed to create destination directory '{dest}'")

if source_is_file:
    content_paths = [source]
else:
    content_paths: List[str] = [os.path.join(
        source, basename) for basename in os.listdir(source)]

for path in content_paths:
    basename = os.path.basename(path)

    if not os.path.isfile(path):
        continue
    if not basename.endswith('.png'):
        continue

    with open(path, "rb") as file:
        # TODO: check that image is in rgb or palette mode
        img: Image.Image = Image.open(file)
        content = to_bin(img, bit_count, palette)

    root, ext = os.path.splitext(basename)
    if dest_name != None:
        (dest_root, _) = os.path.splitext(dest_name)
        if len(content_paths) == 1:
            root = dest_root
        else:
            root += dest_root
    basename = root + ".bin"
    path = os.path.join(dest, basename)

    with open(path, "wb") as file:
        file.write(content)

    print(f"saved '{path}'")
