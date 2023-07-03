# Remote Software

The repository houses LispBM code that runs on the remote.

## How to run this code

The main code is found in `main/main_ui.lisp`. This is the file that you upload
with VESC tool. You can move the entire `main/` directory around, just make sure
that you have all the files under the `main/` folder present, with the original
relative paths to `main_ui.lisp` so that it can find them.

## Assets

All original and processed assets can be found under `sources/`.
In addition to that, there are also a couple python scripts to help automate the
asset creation process. They should all contain documentation for how to run them.
Most of them can either operate on single files or entire directories.

The workflow for icons is that I start with the `sources/icons/svg-original`
directory, which I copy into `svg-prepared`, where I sanitize them, make sure
that they're grayscale, and pixel perfect.
I then convert them to PNGs with `svg2png.py` placed inside the `sources/icons/png/`
directory.
These are then finally converted into binaries using `png2bin.py` and placed
inside the `sources/icons/bin` directory.

I then finally copy the binary icon, texts, or font files that I'm going to use
inside their respective directories in the `main/` directory.

### `png2bin.py`

This script generates binaries that are compatible with the vesc_express
graphics library from a single PNG or a directory containing multiple PNGs.
This binary format is what's actually used in the lisp code.

This is convenient to avoid having to manually convert each one through VESC tool.

example:

```bash
./png2bin.py sources/icons/png/ sources/icons/bin/ indexed2 -p 0x0 0xffffff
```

### `bin2png.py`

This converts lisp compatible binaries into PNGs. It isn't really used.
Essentially the inverse of `png2bin.py`.

### `json-text2png.py`

This generates PNGs of text snippets with a given font.
The format for the text snippets are given as JSON files. The format is
documented in the source code.
Some example files can be found under `sources/texts/json/`.

example:

```bash
./json-text2png.py sources/texts/json/ sources/texts/png
```

### `svg2png.py`

This generates PNGs from SVG images, which is the first step in the process of
converting icons into lisp compatible binaries.

example:

```bash
./svg2png.py sources/icons/svg-prepared/ sources/icons/png
```

### `img-buf-size.py`

Small utility that tells you the rough memory footprint an image buffer of the
given size and format would have. Don't know if it's exact though, as I haven't
checked the source code. I don't really use it that much.

example:

```bash
./img-buf-size.py indexed4 25 25
```

### `text2two-color-png.py`

This was mostly a test that turned into the `json-text2png.py`. It generates
PNGs from text snippets configured from the command line instead of through JSON
files.
