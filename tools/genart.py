#!/usr/bin/env python3
"""
FIDATI. (C64) - pixel art generator.

Converts small ASCII grids into VIC-II character / sprite bit patterns
and prints ca65-ready ".byte" lines. This is a build-time helper only;
its output is pasted into src/fidati.s so the final game has no runtime
dependency on Python.

Char (multicolor, 4x8 "double pixels" per 8x8 cell):
    .  = 00  (background colour $D021)
    1  = 01  (shared multicolor 1, $D022)
    2  = 10  (individual colour, from Color RAM low bits)
    3  = 11  (shared multicolor 2, $D023)

Char (hires, 8x8 single pixels):
    . = 0 (background $D021)
    1 = 1 (individual colour, from Color RAM)

Sprite (multicolor, 12x21 "double pixels"):
    . = 00 (transparent)
    1 = 01 (shared multicolor 1, $D025)
    2 = 10 (individual sprite colour, $D027+n)
    3 = 11 (shared multicolor 2, $D026)
"""

def mc_char(rows, label):
    assert len(rows) == 8, label
    out = []
    for row in rows:
        row = row.replace(" ", "")
        assert len(row) == 4, (label, row)
        b = 0
        for ch in row:
            v = 0 if ch == "." else int(ch)
            b = (b << 2) | v
        out.append(b)
    return out

def hi_char(rows, label):
    assert len(rows) == 8, label
    out = []
    for row in rows:
        row = row.replace(" ", "")
        assert len(row) == 8, (label, row)
        b = 0
        for ch in row:
            b = (b << 1) | (1 if ch == "1" else 0)
        out.append(b)
    return out

def mc_sprite(rows, label):
    assert len(rows) == 21, (label, len(rows))
    out = []
    for row in rows:
        row = row.replace(" ", "")
        assert len(row) == 12, (label, row, len(row))
        bits = 0
        for ch in row:
            v = 0 if ch == "." else int(ch)
            bits = (bits << 2) | v
        # 24 bits -> 3 bytes
        out.append((bits >> 16) & 0xFF)
        out.append((bits >> 8) & 0xFF)
        out.append(bits & 0xFF)
    out.append(0)  # 64th pad byte
    return out

def fmt(bytelist, perline=8):
    lines = []
    for i in range(0, len(bytelist), perline):
        chunk = bytelist[i:i+perline]
        lines.append("    .byte " + ",".join("$%02X" % b for b in chunk))
    return "\n".join(lines)

# ---------------------------------------------------------------
# TILE quarter chars (solid / fake floor - identical look, colour
# RAM alone never distinguishes them since the whole point is you
# can't tell until it crumbles).
#   1 = base blue fill, 3 = bright top/edge highlight, . = dark cutout
TILE_TL = mc_char([
 "3333",
 "3333",
 "1111",
 "1.11",
 "1111",
 "1111",
 "1111",
 "1111",
], "TILE_TL")

TILE_TR = mc_char([
 "3333",
 "3333",
 "1111",
 "1111",
 "1111",
 "1.11",
 "1111",
 "1111",
], "TILE_TR")

TILE_BL = mc_char([
 "1111",
 "1111",
 "1.11",
 "1111",
 "1111",
 "1111",
 "1111",
 "1111",
], "TILE_BL")

TILE_BR = mc_char([
 "1111",
 "1111",
 "1111",
 "1111",
 "1.11",
 "1111",
 "1111",
 "1111",
], "TILE_BR")

# ---------------------------------------------------------------
# SPIKE (hires, sits in the bottom half of the tile cell)
SPIKE_BLANK = hi_char([
 "........",
 "........",
 "........",
 "........",
 "........",
 "........",
 "........",
 "........",
], "SPIKE_BLANK")

SPIKE_BL = hi_char([
 "........",
 "...1....",
 "..111...",
 "..111...",
 ".11111..",
 ".11111..",
 "111111..",
 "111111..",
], "SPIKE_BL")

SPIKE_BR = hi_char([
 "........",
 "....1...",
 "...111..",
 "...111..",
 "..11111.",
 "..11111.",
 "..111111",
 "..111111",
], "SPIKE_BR")

# ---------------------------------------------------------------
# FLAG (hires). pole = own colour, pennant animates over 2 frames.
FLAG_BL = hi_char([
 "1.......",
 "1.......",
 "1.......",
 "1.......",
 "1.......",
 "1.......",
 "1.......",
 "1.......",
], "FLAG_BL")

FLAG_TL_A = hi_char([
 "1.......",
 "1111....",
 "1111111.",
 "11111111",
 "1111111.",
 "1111....",
 "1.......",
 "1.......",
], "FLAG_TL_A")

FLAG_TR_A = hi_char([
 "........",
 "........",
 "........",
 "........",
 "........",
 "........",
 "........",
 "........",
], "FLAG_TR_A")

FLAG_TL_B = hi_char([
 "1.......",
 "1111....",
 "1111111.",
 "1111111.",
 "1111111.",
 "1111....",
 "1.......",
 "1.......",
], "FLAG_TL_B")

FLAG_TR_B = hi_char([
 "........",
 "........",
 "........",
 "........",
 "........",
 "........",
 "........",
 "........",
], "FLAG_TR_B")

# ---------------------------------------------------------------
# PLAYER sprite, multicolor 12x21 (double-wide -> 24x21 on screen)
# 1 = outline/eye (shared MC1), 2 = body (individual, per-sprite),
# 3 = cap (shared MC2)
PLAYER_R0 = mc_sprite([
 "....33......",
 "...333......",
 "..33333.....",
 "..11111.....",
 ".222222.....",
 ".222222.....",
 ".2222122....",
 ".222222.....",
 ".222222.....",
 "..22222.....",
 "..2.2.2.....",
 "..2...2.....",
 "............",
 "............",
 "............",
 "............",
 "............",
 "............",
 "............",
 "............",
 "............",
], "PLAYER_R0")

PLAYER_R1 = mc_sprite([
 "....33......",
 "...333......",
 "..33333.....",
 "..11111.....",
 ".222222.....",
 ".222222.....",
 ".2222122....",
 ".222222.....",
 ".222222.....",
 "..22222.....",
 "..22.2......",
 ".2...2......",
 "............",
 "............",
 "............",
 "............",
 "............",
 "............",
 "............",
 "............",
 "............",
], "PLAYER_R1")

PLAYER_JUMP_R = mc_sprite([
 "....33......",
 "...333......",
 "..33333.....",
 "..11111.....",
 ".222222.....",
 ".222222.....",
 ".2222122....",
 ".222222.....",
 ".222222.....",
 ".22..22.....",
 ".2....22....",
 "............",
 "............",
 "............",
 "............",
 "............",
 "............",
 "............",
 "............",
 "............",
 "............",
], "PLAYER_JUMP_R")

def mirror12(row):
    return row[::-1]

def mirror_sprite_rows(rows):
    return [mirror12(r) for r in rows]

PLAYER_R0_ROWS = [
 "....33......",
 "...333......",
 "..33333.....",
 "..11111.....",
 ".222222.....",
 ".222222.....",
 ".2222122....",
 ".222222.....",
 ".222222.....",
 "..22222.....",
 "..2.2.2.....",
 "..2...2.....",
 "............",
 "............",
 "............",
 "............",
 "............",
 "............",
 "............",
 "............",
 "............",
]
PLAYER_R1_ROWS = [
 "....33......",
 "...333......",
 "..33333.....",
 "..11111.....",
 ".222222.....",
 ".222222.....",
 ".2222122....",
 ".222222.....",
 ".222222.....",
 "..22222.....",
 "..22.2......",
 ".2...2......",
 "............",
 "............",
 "............",
 "............",
 "............",
 "............",
 "............",
 "............",
 "............",
]
PLAYER_JUMP_ROWS = [
 "....33......",
 "...333......",
 "..33333.....",
 "..11111.....",
 ".222222.....",
 ".222222.....",
 ".2222122....",
 ".222222.....",
 ".222222.....",
 ".22..22.....",
 ".2....22....",
 "............",
 "............",
 "............",
 "............",
 "............",
 "............",
 "............",
 "............",
 "............",
 "............",
]

PLAYER_L0 = mc_sprite(mirror_sprite_rows(PLAYER_R0_ROWS), "PLAYER_L0")
PLAYER_L1 = mc_sprite(mirror_sprite_rows(PLAYER_R1_ROWS), "PLAYER_L1")
PLAYER_JUMP_L = mc_sprite(mirror_sprite_rows(PLAYER_JUMP_ROWS), "PLAYER_JUMP_L")

if __name__ == "__main__":
    print("; ---- AUTO-GENERATED by tools/genart.py, do not hand-edit ----")
    print(";; tile quarters")
    for name, data in [("glyph_tile_tl", TILE_TL), ("glyph_tile_tr", TILE_TR),
                        ("glyph_tile_bl", TILE_BL), ("glyph_tile_br", TILE_BR)]:
        print(name+":")
        print(fmt(data))
    print(";; spikes")
    for name, data in [("glyph_spike_blank", SPIKE_BLANK), ("glyph_spike_bl", SPIKE_BL),
                        ("glyph_spike_br", SPIKE_BR)]:
        print(name+":")
        print(fmt(data))
    print(";; flag")
    for name, data in [("glyph_flag_bl", FLAG_BL),
                        ("glyph_flag_tl_a", FLAG_TL_A), ("glyph_flag_tr_a", FLAG_TR_A),
                        ("glyph_flag_tl_b", FLAG_TL_B), ("glyph_flag_tr_b", FLAG_TR_B)]:
        print(name+":")
        print(fmt(data))
    print(";; player sprite frames (64 bytes each)")
    for name, data in [("spr_player_r0", PLAYER_R0), ("spr_player_r1", PLAYER_R1),
                        ("spr_player_jr", PLAYER_JUMP_R), ("spr_player_l0", PLAYER_L0),
                        ("spr_player_l1", PLAYER_L1), ("spr_player_jl", PLAYER_JUMP_L)]:
        print(name+":")
        print(fmt(data))
