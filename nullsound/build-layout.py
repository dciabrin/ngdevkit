# Copyright (c) 2026 Damien Ciabrini
# This file is part of ngdevkit
#
# ngdevkit is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# ngdevkit is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with ngdevkit.  If not, see <http://www.gnu.org/licenses/>.

"""Build a graphical representation of nullsound's memory layout
"""

import argparse
import gzip
from collections.abc import Iterator
from colorsys import *
from dataclasses import dataclass

# Various constants
Z80_RAM = 2048
Z80_RAM_START_ADDR = 0xF800

# Layout dimensions
COLUMN_WIDTH = 350
COLUMN_CELLS = 256
CELL_HEIGHT = 20
CELL_WIDTH = 45
SYMBOL_MARGIN = 10
SYMBOL_OFFSET = 60
X_PADDING = 40
Y_PADDING_TOP = 300
Y_PADDING_BOTTOM = 100

# Color theme
COL_FM1 = "#6699ff"
COL_FM2 = "#88bbff"
COL_FM3 = "#aaddff"
COL_FM4 = "#ccffff"
COL_FM2_EXT_OP1 = "#c878c8"
COL_FM2_EXT_OP2 = "#b060b0"
COL_FM2_EXT_OP3 = "#984898"
COL_FM2_EXT_OP4 = "#803080"
COL_SSGA = "#33ff33"
COL_SSGB = "#22dd22"
COL_SSGC = "#00bb00"
COL_ADPCMA6 = "#aa9900"
COL_ADPCMA5 = "#bbaa11"
COL_ADPCMA4 = "#ccbb22"
COL_ADPCMA3 = "#ddcc33"
COL_ADPCMA2 = "#eedd44"
COL_ADPCMA1 = "#ffee55"
COL_ADPCMB = "#ffaa55"
COL_NSS = "#999999"
COL_OTHER = "#dddddd"
COL_UNUSED = "#ff0000"
COL_NONE = "none"


@dataclass
class symdesc:
    """Symbol allocated in RAM at offset `offset` (`size` bytes)"""

    symbol: str = ""
    offset: int = 0
    size: int = 0


def data_symbol_from_linkmap(filename) -> Iterator[tuple[str, str]]:
    """Parse a Asxxxx map file, return symbols from the DATA segment"""
    in_data_segment = False
    with open(filename, "r") as f:
        for line in f:
            if line.startswith("DATA"):
                in_data_segment = True
                continue
            if in_data_segment and line.startswith("     0000F"):
                address, symbol, _ = line.split()
                yield address, symbol


def layout_from_linkmap(filename) -> dict[int, symdesc]:
    """Build a view of all user symbols allocated in Z80 RAM"""
    res: dict[int, symdesc] = {}
    prev = None
    for address, sym in data_symbol_from_linkmap(filename):
        off = int(address, 16) - Z80_RAM_START_ADDR
        cur = symdesc(sym, off, 1)

        # do not add _end symbol, it is just for alignment purpose
        if cur.symbol.endswith("_end"):
            continue

        # from here we know the size of the previous symbol
        if prev:
            prev.size = off - prev.offset

        # do not add _align symbol, this is unused memory
        if cur.symbol.endswith("_align"):
            prev = None
            continue
        res[off] = cur
        prev = cur
    return res


def symbol_color(symbol: str) -> str:
    """Return a hex rgb color for the given symbol"""
    if "state_fm2" in symbol:
        return COL_FM2
    elif "state_fm3" in symbol:
        return COL_FM3
    elif "state_fm4" in symbol:
        return COL_FM4
    elif "state_fm" in symbol or "pan_ams" in symbol:
        return COL_FM1
    elif "state_op1" in symbol:
        return COL_FM2_EXT_OP1
    elif "state_op2" in symbol:
        return COL_FM2_EXT_OP2
    elif "state_op3" in symbol:
        return COL_FM2_EXT_OP3
    elif "state_op4" in symbol:
        return COL_FM2_EXT_OP4
    elif "_fifo" in symbol or "_ym2610" in symbol:
        return COL_OTHER
    elif "_timer" in symbol:
        return COL_NSS
    elif "state_volume" in symbol:
        return COL_OTHER
    elif "ym2610_" in symbol:
        return COL_FM1
    elif "_ch_" in symbol:
        return COL_NSS
    elif "_nss_" in symbol or "_stream" in symbol:
        return COL_NSS  # "#cccccc"
    elif "_ssg_channel" in symbol or "state_mirrored" in symbol:
        return COL_SSGA
    elif "_ssg_c" in symbol:
        return COL_SSGC
    elif "_ssg_b" in symbol:
        return COL_SSGB
    elif "_ssg_" in symbol:
        return COL_SSGA
    elif "state_b" in symbol or "adpcm_b_vol" in symbol:
        return COL_ADPCMB
    elif "state_adpcm" in symbol:
        return COL_ADPCMA1
    elif "state_a6" in symbol:
        return COL_ADPCMA6
    elif "state_a5" in symbol:
        return COL_ADPCMA5
    elif "state_a4" in symbol:
        return COL_ADPCMA4
    elif "state_a3" in symbol:
        return COL_ADPCMA3
    elif "state_a2" in symbol:
        return COL_ADPCMA2
    elif "state_a" in symbol:
        return COL_ADPCMA1
    else:
        return COL_NONE


def memory_layout_elements(symbols: dict[int, symdesc]) -> tuple[list[str], int]:
    """SVG representation of the Z80 memory layout, along with unused RAM"""
    # output svg elements
    elements = []
    # unused RAM
    unused_bytes = 0
    # last symbol's occupied space in RAM
    space_in_ram = 0

    for i in list(range(Z80_RAM)):
        xoff = X_PADDING + (i // COLUMN_CELLS) * COLUMN_WIDTH
        yoff = Y_PADDING_TOP
        name_length = 0
        descriptor = symbols.get(i, False)
        if descriptor:
            name_length = len(descriptor.symbol)
            space_in_ram = descriptor.size

        cell_x = xoff + 20
        cell_y = yoff + ((i % COLUMN_CELLS) * CELL_HEIGHT)

        if descriptor:
            fillcolor = symbol_color(descriptor.symbol)
        elif not descriptor and space_in_ram == 0:
            unused_bytes += 1
            fillcolor = COL_UNUSED
        elif not descriptor and space_in_ram != 0:
            pass
        else:
            fillcolor = COL_NONE

        # cell frame
        elements.append(
            f'  <rect x="{cell_x}" y="{cell_y}" width="{CELL_WIDTH}" height="{CELL_HEIGHT}"'
            f' fill="{fillcolor}" />'
        )
        # cell memory address
        elements.append(
            f'  <text x="{cell_x + SYMBOL_MARGIN}" y="{cell_y + (CELL_HEIGHT / 2)}"'
            f' fill="#333333" >{"%04X" % (Z80_RAM_START_ADDR + i)}</text>'
        )

        if descriptor:
            # symbol at memory address
            elements.append(
                f'  <text x="{cell_x + SYMBOL_OFFSET}" y="{cell_y + (CELL_HEIGHT / 2)}"'
                f' fill="#333333" >{descriptor.symbol}</text>'
            )
        elif space_in_ram > 0:
            # previous symbol occupies this memory address
            # draw it with a specific frame
            slen = name_length * 6 - 10
            vx = cell_x + 5 + SYMBOL_OFFSET
            vy = cell_y + (CELL_HEIGHT / 2) - 10
            vy2 = vy + 20
            if space_in_ram == 1:
                vy2 -= 10
            elements.append(f'<line x1="{vx}" y1="{vy}" x2="{vx}" y2="{vy2}" />')
            elements.append(
                f'<line x1="{vx + slen}" y1="{vy}" x2="{vx + slen}" y2="{vy2}" />'
            )
            # last byte used by this symbol, finish the frame
            if space_in_ram == 1:
                elements.append(
                    f'<line x1="{vx}" y1="{vy2}" x2="{vx + slen}" y2="{vy2}" />'
                )

        space_in_ram = max(0, space_in_ram - 1)

    return elements, unused_bytes


def legend_elements(unused_bytes: int, y: int):
    """SVG legend with color codes, and RAM consumption"""

    def legend_item(color, name, x, y):
        return (
            f'  <rect x="{x}" y="{y}" width="{20}" height="{20}"'
            + f' fill="{color}" stroke="black" stroke-width="1" />',
            f'  <text x="{x + 30}" y="{y + 10}"'
            + ' font-family="sans-serif" font-size="20" fill="#333333"'
            + f' dominant-baseline="middle">{name}</text>',
        )

    res: list[str] = []
    res.extend(legend_item(COL_FM1, "FM state", 200, y))
    res.extend(legend_item(COL_FM2_EXT_OP1, "FM2 ext state", 500, y))
    res.extend(legend_item(COL_SSGA, "SSG state", 800, y))
    res.extend(legend_item(COL_ADPCMA1, "ADPCM-A state", 1100, y))
    res.extend(legend_item(COL_ADPCMB, "ADPCM-B state", 1400, y))
    res.extend(legend_item(COL_NSS, "NSS state", 1700, y))
    res.extend(legend_item(COL_OTHER, "Others", 2000, y))
    res.extend(legend_item(COL_UNUSED, "UNUSED", 2300, y))
    used = Z80_RAM - unused_bytes
    res.append(
        f'  <text x="{1000}" y="{y + 100}"'
        f' font-family="sans-serif" font-size="50" fill="#333333"'
        f' dominant-baseline="middle">{used} bytes used ({int(100 * used / Z80_RAM)}% of RAM)</text>'
    )
    return res


def open_output(outfile):
    """Generic output stream based on arguments
    """
    if outfile.endswith('svgz'):
        return gzip.open(outfile, mode='wt')
    else:
        return open(outfile, mode='w')


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='Generate a SVG layout of nullsound RAM occupation')
    parser.add_argument(metavar='FILE', dest='file',
                        help='ASxxxx linkmap to process')
    parser.add_argument('-o', '--output',
                        dest='output',
                        metavar='OUTFILE', type=str,
                        required = True,
                        help='SVG layout (either .svg or .svgz)')
    arguments = parser.parse_args()

    symbols = layout_from_linkmap(arguments.file)

    svg_mem, unused_ram = memory_layout_elements(symbols)
    svg_legend = legend_elements(unused_ram, 50)
    svg_elements = svg_mem + svg_legend

    page_width = (X_PADDING) + (Z80_RAM // COLUMN_CELLS) * COLUMN_WIDTH
    page_height = (Y_PADDING_TOP + Y_PADDING_BOTTOM) + COLUMN_CELLS * CELL_HEIGHT

    with open_output(arguments.output) as ostream:
        ostream.write(
            f'<svg xmlns="http://www.w3.org/2000/svg"'
            f' viewBox="0 0 {page_width} {page_height}"'
            f' width="{page_width}" height="{page_height}">'
        )
        ostream.write("""
<style>
  text {
     font-family: monospace;
     dominant-baseline: middle;
  }
  rect {
     stroke: black;
     stroke-width: 1;
  }
  line {
     stroke: #999999;
     stroke-width: 1;
  }
</style>
""")
        ostream.write(
            f'<rect x="0" y="0"'
            f' width="{page_width}" height="{page_height}"'
            ' fill="#ffffff" />\n'
        )
        ostream.write(f"{chr(10).join(svg_elements)}\n")
        ostream.write("</svg>")
