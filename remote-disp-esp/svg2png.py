#!/usr/bin/python3
# this is meant to run on linux (wsl in my case)
# it might work on windows though

# source:
# https://stackoverflow.com/questions/6589358/convert-svg-to-png-in-python

import argparse
import os
import sys
from typing import *
from cairosvg import svg2png


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


def panic(reason: str):
    eprint(reason)
    exit(1)


parser = argparse.ArgumentParser(
    prog="svg2png",
    description="Converts an entire directory of SVGs into PNGs and moves them into another specified directory.",
)

# parser.add_argument('-h', '--help', help="show this list")
parser.add_argument(
    'source', help="a single SVG file or a the directory containing the SVGs to convert. \
        Any non-SVG files in the directory will be ignored.")
parser.add_argument(
    'dest', help="the directory to place the generated PNGs inside")

args = parser.parse_args()

source: str = args.source
dest: str = args.dest

source_is_dir = os.path.isdir(source)
source_is_file = os.path.isfile(source)

if not source_is_dir and not source_is_file:
    panic(f"source directory or file '{source}' does not exist")

if source_is_file and not source.endswith(".svg"):
    panic(f"source file '{source}' is not an SVG")

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
    if not basename.endswith('.svg'):
        continue

    with open(path, "rb") as file:
        root, ext = os.path.splitext(basename)
        basename = root + ".png"
        path = os.path.join(dest, basename)
        print(f"saved '{path}'")

        content = file.read()
        svg2png(bytestring=content, write_to=path)
