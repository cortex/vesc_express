#!/usr/bin/python3

import argparse
import os
import sys
import math
import itertools
import bitstring
import time
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


def to_bit_string(number: int, bit_count: int) -> str:
    return f"{{:#0{bit_count + 2}b}}".format(number)


def lerp(a: T, b: T, t: float) -> float:
    return a * (1 - t) + b * t


def color_lerp(a: Tuple[int, int, int], b: Tuple[int, int, int], t: float) -> Tuple[int, int, int]:
    return (
        int(lerp(a[0], b[0], t)),
        int(lerp(a[1], b[1], t)),
        int(lerp(a[2], b[2], t)),
    )


def color_alpha_composite(fg: Tuple[int, int, int, float], bg: Tuple[int, int, int]) -> Tuple[int, int, int]:
    return color_lerp(bg, fg[0:3], fg[3])


def putpixel_alpha(img: Image.Image, x: int, y: int, color: Tuple[int, int, int, float]):
    if x < 0 or x >= img.width\
            or y < 0 or y >= img.height:
        print(f"tried to draw pixel ({x}, {y}) outside image")
        return

    old_color = img.getpixel((x, y))
    img.putpixel((x, y), color_alpha_composite(color, old_color))


def img_rect(img: Image.Image, x: int, y: int, w: int, h: int, color: Tuple[int, int, int, float]):
    for x0 in range(x, x + w):
        putpixel_alpha(img, x0, y, color)
        putpixel_alpha(img, x0, y + h - 1, color)
    for y0 in range(y + 1, y + h - 1):
        putpixel_alpha(img, x, y0, color)
        putpixel_alpha(img, x + w - 1, y0, color)


def img_putc(img: Image.Image, x: int, y: int, font_data: bytes, ch: int):
    w = font_data[0]
    h = font_data[1]
    char_num = font_data[2]
    print(f"printed '{chr(ch)}' at x: {x}, y: {y}, {w}x{h}")

    bytes_per_char = (w * h) // 8

    if (w * h) % 8 != 0:
        bytes_per_char += 1

    if char_num == 10:
        ch -= ord('0')
    else:
        ch -= ord(' ')

    if ch >= char_num:
        return

    first = True

    for i in range(w * h):
        byte = font_data[4 + bytes_per_char * ch + (i // 8)]
        bit_pos = i % 8
        bit = byte & (1 << bit_pos)
        if bit:
            x0 = i % w
            y0 = i // w
            if first:
                # print(f"first {x0}, {y0}")
                first = False
            try:
                img.putpixel((x + x0, y + y0), (255, 255, 255))
            except IndexError:
                # print(f"tried to draw to pixel {x + x0}, {y + y0}")
                pass


def parse_content(content: bytes) -> Image.Image:
    w = content[0]
    h = content[1]
    char_num = content[2]

    img = Image.new("RGB", (w * char_num, h), 0)

    start_char = ord("0" if char_num == 10 else " ")

    for i in range(char_num):
        x = w * i
        img_putc(img, x, 0, content, start_char + i)
        img_rect(img, x, 0, w, h, (255, 0, 0, 0.5))

    return img


def handle_single_char(font_data: bytes, char: int) -> Image.Image:
    w = font_data[0]
    h = font_data[1]
    char_num = font_data[2]

    img = Image.new("RGB", (w, h), 0)

    img_putc(img, 0, 0, font_data, char)
    img_rect(img, 0, 0, w, h, (255, 0, 0, 0.5))

    return img


def cycle_chars(font_data, path):
    char_num = font_data[2]
    start_char = ord("0" if char_num == 10 else " ")

    for i in range(char_num):
        img = handle_single_char(font_data, start_char + i)
        img.save(path)

        time.sleep(2.0)


parser = argparse.ArgumentParser(
    prog="font-test.py",
    description="Test to convert vesc binary fonts to an image",
)


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
    # img = parse_content(content)
    # img.save(path)
    cycle_chars(content, path)
