"""
This tool was generated for fun and has very limited testing.
YMMV
Attempts to report symbols and functions that are not called upon in a LBM project.
Provide a root directory to *.lisp
Use output report to make decisions about your programming.
"""

import os
import re
from collections import defaultdict

def strip_comments(content):
    """Strip comments from Lisp code."""
    lines = content.splitlines()
    stripped_lines = [re.split(r';', line, 1)[0] for line in lines]
    return "\n".join(stripped_lines)

def find_lisp_files(directory):
    """Recursively find all .lisp files in the directory and its subdirectories."""
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith('.lisp'):
                yield os.path.join(root, file)

def parse_definitions(filepath):
    """Parse the Lisp file for (def ... and (defun ... symbols, ignoring comments."""
    with open(filepath, 'r') as file:
        content = strip_comments(file.read())
    pattern = re.compile(r'\((def|defun)\s+([^\s\(\)]+)')
    matches = pattern.finditer(content)
    return [(match.group(2), filepath, content[:match.start()].count('\n') + 1) for match in matches]

def count_symbol_occurrences(symbols, directory):
    """Count occurrences of each symbol in all .lisp files within the directory."""
    symbol_counts = defaultdict(int)
    for filepath in find_lisp_files(directory):
        with open(filepath, 'r') as file:
            content = strip_comments(file.read())
            for symbol in symbols:
                symbol_counts[symbol] += len(re.findall(r'\b' + re.escape(symbol) + r'\b', content))
    return symbol_counts

def main(directory):
    definitions = defaultdict(list)

    for lisp_file in find_lisp_files(directory):
        for symbol, filepath, line in parse_definitions(lisp_file):
            definitions[symbol].append((filepath, line))

    redefined_symbols = {sym: locs for sym, locs in definitions.items() if len(locs) > 1}

    symbol_counts = count_symbol_occurrences(definitions.keys(), directory)
    unused_symbols = [symbol for symbol, count in symbol_counts.items() if count < 2]

    # Report redefined symbols
    print("Redefined Symbols:")
    for symbol, locs in redefined_symbols.items():
        print(f"{symbol} is defined at:")
        for loc in locs:
            print(f"  {loc[0]}:{loc[1]}")

    # Report unused symbols
    if unused_symbols:
        print("\nUnused Symbols:")
        for symbol in unused_symbols:
            print(symbol)
    else:
        print("\nNo unused symbols found or all symbols are used.")

    # Calculate and print counts
    unused_count = len(unused_symbols)
    redefined_count = len(redefined_symbols)

    print(f"\nTotal Unused Symbols: {unused_count}")
    print(f"Total Redefined Symbols: {redefined_count}")

if __name__ == "__main__":
    directory = input("Enter the directory to scan: ")
    main(directory)
