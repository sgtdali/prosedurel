"""Paints the lone trees out of png_map's baked terrain tiles (baked/terrain_full), so that
map/lone_trees.gd can draw them as pictures instead (Blender renders, removable when a building
goes on top). Each visible tree of world_layout.gd's TREES (the ones world_chunk.gd drew: not
inside a mountain of its own chunk) has its crown and its shadow filled in from the ground
around them. Run once; the tiles are in git if it has to be undone.
Usage: python tools/remove_lone_trees_from_tiles.py
"""
import math
import os
import re

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TILES = os.path.join(HERE, "baked", "terrain_full")
LAYOUT = os.path.join(HERE, "map", "world_layout.gd")
CHUNK = 800.0
SCALE = 2.0
# world_chunk.gd _draw_tree: crown radius r, shadow 1.12 r at (3.5, 5)
SHADOW_OFFSET = (3.5, 5.0)
MARGIN = 1.6

VEC = r"Vector2\(([-\d.]+), ([-\d.]+)\)"


def section(text, name):
    start = text.index("const %s" % name)
    return text[start:text.index("\n]", start)]


def visible_trees():
    text = open(LAYOUT, encoding="utf-8").read()
    trees = [((float(x), float(y)), float(r)) for x, y, r in
             re.findall(r'"pos": ' + VEC + r', "size": ([\d.]+)', section(text, "TREES"))]
    mountains = [((float(a), float(b)), (float(c), float(d))) for a, b, c, d in
                 re.findall(r'"center": ' + VEC + r', "radius": ' + VEC, section(text, "MOUNTAINS"))]
    out = []
    for (x, y), r in trees:
        chunk = (math.floor(x / CHUNK), math.floor(y / CHUNK))
        hidden = False
        for (mx, my), (rx, ry) in mountains:
            if (math.floor(mx / CHUNK), math.floor(my / CHUNK)) != chunk:
                continue
            if ((x - mx) / rx) ** 2 + ((y - my) / ry) ** 2 < 1.0:
                hidden = True
        if not hidden:
            out.append(((x, y), r))
    return out


def fill(pixels, mask):
    """Fills the masked pixels from their unmasked neighbours, ring by ring, then softens them."""
    known = ~mask
    out = pixels.astype(np.float32)
    todo = mask.copy()
    h, w = mask.shape
    while todo.any():
        total = np.zeros_like(out)
        count = np.zeros((h, w), np.float32)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (-1, 1), (1, -1), (1, 1)):
            shifted_known = np.zeros((h, w), bool)
            shifted = np.zeros_like(out)
            ys = slice(max(dy, 0), h + min(dy, 0))
            yd = slice(max(-dy, 0), h + min(-dy, 0))
            xs = slice(max(dx, 0), w + min(dx, 0))
            xd = slice(max(-dx, 0), w + min(-dx, 0))
            shifted_known[yd, xd] = known[ys, xs]
            shifted[yd, xd] = out[ys, xs]
            total += shifted * shifted_known[..., None]
            count += shifted_known
        ready = todo & (count > 0)
        if not ready.any():
            break
        out[ready] = total[ready] / count[ready][:, None]
        known = known | ready
        todo = todo & ~ready
    for _ in range(6):
        blurred = out.copy()
        blurred[1:-1, 1:-1] = (out[:-2, 1:-1] + out[2:, 1:-1] + out[1:-1, :-2] + out[1:-1, 2:] + out[1:-1, 1:-1]) / 5.0
        out[mask] = blurred[mask]
    return out


def main():
    trees = visible_trees()
    by_tile = {}
    for tree in trees:
        (x, y), r = tree
        reach = r * 1.12 + 6.0 + MARGIN
        for tx in {math.floor((x - reach) / CHUNK), math.floor((x + reach) / CHUNK)}:
            for ty in {math.floor((y - reach) / CHUNK), math.floor((y + reach) / CHUNK)}:
                by_tile.setdefault((tx, ty), []).append(tree)
    painted = 0
    for (tx, ty), tile_trees in sorted(by_tile.items()):
        path = os.path.join(TILES, "tile_%d_%d.png" % (tx, ty))
        if not os.path.exists(path):
            continue
        image = Image.open(path).convert("RGB")
        pixels = np.asarray(image).copy()
        h, w, _ = pixels.shape
        for (x, y), r in tile_trees:
            lx, ly = (x - tx * CHUNK) * SCALE, (y - ty * CHUNK) * SCALE
            sx, sy = lx + SHADOW_OFFSET[0] * SCALE, ly + SHADOW_OFFSET[1] * SCALE
            crown = (r + MARGIN) * SCALE
            shade = (r * 1.12 + MARGIN) * SCALE
            x0 = int(max(0, min(lx - crown, sx - shade) - 6))
            x1 = int(min(w, max(lx + crown, sx + shade) + 7))
            y0 = int(max(0, min(ly - crown, sy - shade) - 6))
            y1 = int(min(h, max(ly + crown, sy + shade) + 7))
            if x0 >= x1 or y0 >= y1:
                continue
            yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32) + 0.5
            mask = ((xx - lx) ** 2 + (yy - ly) ** 2 <= crown ** 2) | ((xx - sx) ** 2 + (yy - sy) ** 2 <= shade ** 2)
            if not mask.any() or mask.all():
                continue
            window = pixels[y0:y1, x0:x1]
            window[:] = np.clip(fill(window, mask), 0, 255).astype(np.uint8)
            painted += 1
        Image.fromarray(pixels).save(path)
    print("trees", len(trees), "painted", painted, "tiles", len(by_tile))


main()
