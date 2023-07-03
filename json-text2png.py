#!/home/rasmus/pypy3.10-v7.3.12-linux64/bin/pypy3.10
# yes that path is super specific to my system. But because python for god knows
# what reason can't seem to make installing it on linux properly not be a total
# nightmare, this is the best you're going to get. >:(

# this is meant to run on linux (wsl in my case)
# it might work on windows though

# this needs inkscape installed as a cli-program to function
# ubuntu (works on wsl):
# sudo apt-get install inkscape

# make sure that the used fonts are installed in your os.
# ubuntu (works on wsl):
# sudo cp path/to/fonts/* /usr/local/share/fonts
# then reboot (might not be necessary)

# this is a modified version of text2two-color-png.py that uses a new json
# system that can handle multiple json files at once.

# dependencies:
# pip install CairoSVG
# sudo apt-get install inkscape

"""
Text json format
The text files should consist of json in the following format:
```json
{
    "text": "<text>",
    "width": <width>,
    "font-family": "<font-family>",
    "font-size": <font-size>,
    "line-height": "<line-height>",
    "font-weight": <font-weight>,
    "align": "<align>"
}
```
where
- <text> [str]: text lines separated by newlines
- <width> [int]: output image width in pixels
- <font-family> [str]: css font family name
- <font-size> [int]: font size in pixels as int
- <line-height> [str]: line height in pixels without unit **or** percentage of
  font-size, with percentage unit, eg: "line-height": "72" or "line-height":
  "120%"
- <font-weight> [int] (optional): css font weight number as int
- <align> [str]: how to horizontally justify the text (valid values: "start",
  "middle", "end")
"""

import argparse
import tempfile
import os
import sys
import subprocess
import shutil
import json
from collections.abc import Mapping
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
    # y_offset = font_size + (liqne_height - font_size) / 2  # can be optimized
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


def handle_text_json_file(file_path: str, dest_directory: str):
    def access_helper(key: str, dictionary: dict) -> str:
        if key not in dictionary:
            panic(
                f"json of file '{file_path}' didn't contain required key '{key}'")
        return str(dictionary[key])

    def optional_access_helper(key: str, dictionary: dict, default: str) -> str:
        if key not in dictionary:
            return default
        return str(dictionary[key])

    with open(file_path, "r") as file:
        data: dict = json.load(file)
        if not isinstance(data, Mapping):
            print(data)
            panic(f"json content of file '{file_path}' isn't an object")
        text = access_helper("text", data)
        width = int(access_helper("width", data))
        font_family = access_helper("font-family", data)
        font_size = int(access_helper("font-size", data))
        line_height_str = access_helper("line-height", data)
        font_weight = int(optional_access_helper("font-weight", data, "400"))
        align_str = access_helper("align", data)
        match align_str:
            case "start":
                align = TextJustify.Start
            case "middle":
                align = TextJustify.Middle
            case "end":
                align = TextJustify.End
            case _:
                panic(
                    f"file '{file_path}': json key 'align' did not contain valid value: '{align_str}'. Valid values are 'start', 'middle', or 'end'.")

        if line_height_str.endswith("%"):
            line_height = int(
                float(line_height_str[:-1]) / 100.0 * float(font_size))
        else:
            line_height = int(line_height_str)

        svg = build_text_svg(text, width, None, font_family,
                             font_size, line_height, font_weight, align)

        text_svg_path = os.path.join(
            tempfile.gettempdir(), "json-text2png.py.text-svg.svg")
        path_svg_path = os.path.join(
            tempfile.gettempdir(), "json-text2png.py.path-svg.svg")

        if os.path.isfile(text_svg_path):
            os.remove(text_svg_path)

        if os.path.isfile(path_svg_path):
            os.remove(path_svg_path)

        with open(text_svg_path, "w") as svg_file:
            svg_file.write(svg)

        print(f"{file_path}: running inkscape...")
        # source: https://stackoverflow.com/a/32925617/15507414
        subprocess.call(
            f"inkscape {text_svg_path} --export-text-to-path --export-plain-svg {path_svg_path}",
            shell=True
        )

        if not os.path.isfile(path_svg_path):
            panic("inkscape failed :(")

        with open(path_svg_path, "rb") as file:
            svg = file.read()

            root, ext = os.path.splitext(os.path.basename(file_path))

            path = os.path.join(dest_directory, root + ".png")

            svg2png(bytestring=svg, write_to=path)

            print(f"saved '{path}'")


parser = argparse.ArgumentParser(
    prog="json-text2png",
    description="Converts json textfiles to a 2-color png (see the source code for the json format).",
)

# parser.add_argument('-h', '--help', help="show this list")
parser.add_argument(
    'source', help="A single JSON text file or a the directory containing the JSON files to convert. \
        Any non-JSON files in the directory will be ignored.")
parser.add_argument(
    'dest',
    nargs="?",
    default=os.getcwd(),
    help="the directory to place the generated PNGs inside, defaults to cwd",
)

args = parser.parse_args()

source: str = args.source
dest: str = args.dest

source_is_dir = os.path.isdir(source)
source_is_file = os.path.isfile(source)

if not source_is_dir and not source_is_file:
    panic(f"source directory or file '{source}' does not exist")

if source_is_file and not source.endswith(".json"):
    panic(f"source file '{source}' is not a JSON document")

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
    if not basename.endswith('.json'):
        continue

    handle_text_json_file(path, dest)
