#!/usr/bin/python3
# this is meant to run on linux (wsl in my case)
# it might work on windows though

# this needs inkscape installed as a cli-program to function
# ubuntu (works on wsl):
# sudo apt-get install inkscape

# make sure that the used fonts are installed in your os.
# ubuntu (works on wsl):
# sudo cp path/to/fonts/* /usr/local/share/fonts
# then reboot (might not be necessary)

# dependencies:
# pip install CairoSVG

# source:
# https://stackoverflow.com/questions/6589358/convert-svg-to-png-in-python

import argparse
import tempfile
import os
import sys
import subprocess
import shutil
from typing import *
from cairosvg import svg2png
from enum import Enum


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


def panic(reason: str):
    eprint(reason)
    exit(1)


class TextJustify(Enum):
    Start = 0
    Middle = 1
    End = 2


def build_text_svg(text: str, width: int, height: Optional[int], font_family: str, font_size: int, line_height: int, font_weight: int, text_align: TextJustify) -> str:
    if height == None:
        height = (text.count("\n") + 1) * line_height

    head = f'<svg width="{width}" height="{height}" viewBox="0 0 {width} {height}" xmlns="http://www.w3.org/2000/svg"\
        shape-rendering="crispEdges">'
    tail = f'</svg>'

    # # Assumes that the offset specifies the distance from the top edge to the
    # # baseline.
    # # This appears to be true for Gilroy
    # y_offset = font_size + (line_height - font_size) / 2  # can be optimized
    y_offset = line_height / 2.0

    match text_align:
        case TextJustify.Start:
            x_pos = "0"
            anchor = "start"
        case TextJustify.Middle:
            x_pos = "50%"
            anchor = "middle"
        case TextJustify.End:
            x_pos = "100%"
            anchor = "end"

    text_elements = ""
    lines = text.split("\n")
    for i, line in zip(range(len(lines)), lines):
        text_elements += f'<text x="{x_pos}" y="{line_height * i + y_offset}" font-family="{font_family}" font-size="{font_size}" font-weight="{font_weight}" fill="white" dominant-baseline="middle" text-anchor="{anchor}">'
        text_elements += line
        text_elements += "</text>"
        text_elements += "\n"

    content = f'<rect width="100%" height="100%" fill="black" />\n\
        {text_elements}'

    return "\n".join([head, content, tail])


parser = argparse.ArgumentParser(
    prog="text2bitmap-png",
    description="Converts an a textfile to a 2-color png.",
)

# parser.add_argument('-h', '--help', help="show this list")
parser.add_argument(
    'source', help="A single text file to generate a PNG from. \
        The text file should be in plaintext format, where newlines correspond \
        to newlines in the output image")
parser.add_argument(
    'width',
    type=int,
    help="The width of the output image. The text is *not* wrapped to fit inside the view box.",
)
parser.add_argument(
    "height",
    type=int,
    nargs="?",
    default=0,
    help="The height of the output image. Defaults to enough space to fit all lines",
)
parser.add_argument(
    "-f",
    "--family",
    type=str,
    default="sans-serif",
    help="The valid css font family to use. Must be installed in the os. Defaults to %(default)s",
)
parser.add_argument(
    "-s",
    "--size",
    type=int,
    default="90",
    help="The font size to use in pixels. (default: %(default)s)",
)

parser.add_argument(
    "-l",
    "--line-height",
    type=str,
    default="100%",
    help="The line height to use in pixels or percent of font-size floored to the nearest integer (ex: `-l 25` (pixels) or `-l 120%%` (percent)).",
)

parser.add_argument(
    "-w",
    "--weight",
    type=int,
    default=400,
    help="The font weight to be used. Should be given as a css weight integer, ex: 400",
)

parser.add_argument(
    "-a",
    "--align",
    type=str,
    default="start",
    choices=["start", "middle", "end"],
    help="How to align the text horizontally. Valid values are 'start', 'middle', and 'end'. (default: %(default)s)",
)

parser.add_argument(
    '-d',
    '--dest',
    default=os.getcwd(),
    help="The directory to place the generated PNGs inside, defaults to current working directory."
)

parser.add_argument(
    '-o',
    '--output-basename',
    type=str,
    default="",
    help="The base filename for the generated PNG. Defaults to the inputname with an additional png extension."
)

args = parser.parse_args()

source: str = args.source
dest: str = args.dest
if args.output_basename == "":
    out_basename: str = os.path.basename(source) + ".png"
else:
    out_basename: str = args.output_basename

font_family: str = args.family
font_size: int = args.size
font_weight: int = args.weight
line_height_str: str = args.line_height
if line_height_str.endswith("%"):
    line_height = int(float(line_height_str[:-1]) / 100.0 * float(font_size))
else:
    line_height = int(line_height_str)

align_str = args.align
match align_str:
    case "start":
        align = TextJustify.Start
    case "middle":
        align = TextJustify.Middle
    case "end":
        align = TextJustify.End

width: int = args.width
height: Optional[int] = None if args.height == 0 else args.height

if not os.path.isfile(source):
    panic(f"source file '{source}' does not exist")

if os.path.isfile(dest):
    panic(f"destination '{dest}' exists, but is not a directory")

os.makedirs(dest, exist_ok=True)
if not os.path.isdir(dest):
    panic(f"failed to create destination directory '{dest}'")

dest_path = os.path.join(dest, out_basename)

with open(source, "r") as file:
    text = file.read()
    svg = build_text_svg(text, width, height, font_family,
                         font_size, line_height, font_weight, align)

text_svg_path = os.path.join(
    tempfile.gettempdir(), "text2two-color-png.py.text-svg.svg")
path_svg_path = os.path.join(
    tempfile.gettempdir(), "text2two-color-png.py.path-svg.svg")

if os.path.isfile(text_svg_path):
    os.remove(text_svg_path)
if os.path.isfile(path_svg_path):
    os.remove(path_svg_path)
# print(f"generated svg {svg}")

with open(text_svg_path, "w") as svg_file:
    svg_file.write(svg)

print("running inkscape...")
# source: https://stackoverflow.com/a/32925617/15507414
subprocess.call(
    f"inkscape {text_svg_path} --export-text-to-path --export-plain-svg -o {path_svg_path}",
    shell=True
)

path = os.path.join(dest, out_basename)
shutil.copyfile(path_svg_path, path + '.svg')
print(f"saved '{path + '.svg'}'")

with open(path_svg_path, "rb") as file:
    svg = file.read()

    path = os.path.join(dest, out_basename)

    svg2png(bytestring=bytes(svg), write_to=path)

    print(f"saved '{path}'")


# for path in content_paths:
#     basename = os.path.basename(path)

#     if not os.path.isfile(path):
#         continue
#     if not basename.endswith('.svg'):
#         continue

#     with open(path, "rb") as file:
#         root, ext = os.path.splitext(basename)
#         basename = root + ".png"
#         path = os.path.join(dest, basename)
#         print(f"saved '{path}'")

#         content = file.read()
#         svg2png(bytestring=content, write_to=path)
