#!/usr/bin/env python3
"""Renders Media/Arrow/arrow3d.tga: the 3D navigation arrow sprite sheet.

A faceted arrowhead (raised spine, sloped wings, side walls) seen from a
camera tilted 50 degrees down, lit from the upper left, in 64 rotation
steps. Frame k (row-major in an 8x8 grid of 128x128 frames) shows the arrow
turned k * 360/64 degrees counterclockwise (seen from above): frame 0 points
straight ahead (up on screen), frame 16 points left. UI/Arrow.lua picks the
frame with SetTexCoord and tints it with SetVertexColor, so the arrow is
rendered light grey.

Pure numpy + Pillow, no 3D library. Run: python3 tools/render_arrow.py
"""
import os
import struct
import sys

import numpy as np
from PIL import Image, ImageFilter

FRAMES_PER_ROW = 8
FRAMES = FRAMES_PER_ROW * FRAMES_PER_ROW
FRAME = 128          # final frame size, px
SUPER = 4            # supersampling
SIZE = FRAME * SUPER

PITCH = np.radians(50)   # camera looks down this much
DISTANCE = 6.0
FOCAL = 6.0

# Arrowhead outline (top view, pointing +Y), counterclockwise, with the
# height of the top surface at each point: low tip and wings, high notch so
# the spine runs up from the tip.
TIP, LEFT, NOTCH, RIGHT = 0, 1, 2, 3
OUTLINE = np.array([
    (0.00, 1.00),    # tip
    (-0.72, -0.62),  # left wing
    (0.00, -0.28),   # notch
    (0.72, -0.62),   # right wing
])
TOP_Z = np.array([0.10, 0.07, 0.26, 0.07])
CENTER = np.array([0.0, 0.10])  # rotation center (keeps the arrow centered)

BASE = np.array([0.86, 0.86, 0.86])
WALL = np.array([0.62, 0.62, 0.62])
OUTLINE_COLOR = np.array([0.07, 0.07, 0.07])
LIGHT = np.array([-0.45, -0.35, 0.82])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def mesh(angle):
    """Triangles (n, 3, 3) and their colors for the arrow turned by angle."""
    c, s = np.cos(angle), np.sin(angle)
    rot = np.array([[c, -s], [s, c]])
    xy = (OUTLINE - CENTER) @ rot.T
    top = np.column_stack([xy, TOP_Z])
    bottom = np.column_stack([xy, np.zeros(4)])
    triangles, kinds = [], []
    # Top: two facets meeting at the spine (tip -> notch).
    triangles += [(top[TIP], top[LEFT], top[NOTCH]), (top[TIP], top[NOTCH], top[RIGHT])]
    kinds += ["top", "top"]
    # Walls along each outline edge.
    for i in range(4):
        j = (i + 1) % 4
        triangles += [(bottom[i], bottom[j], top[j]), (bottom[i], top[j], top[i])]
        kinds += ["wall", "wall"]
    # Bottom (hidden, closes the mesh for the depth test).
    triangles += [(bottom[TIP], bottom[NOTCH], bottom[LEFT]), (bottom[TIP], bottom[RIGHT], bottom[NOTCH])]
    kinds += ["bottom", "bottom"]
    return np.array(triangles), kinds


def camera():
    target = np.array([0.0, 0.0, 0.08])
    position = target + DISTANCE * np.array([0.0, -np.cos(PITCH), np.sin(PITCH)])
    forward = target - position
    forward /= np.linalg.norm(forward)
    right = np.array([1.0, 0.0, 0.0])
    up = np.cross(right, forward)
    return position, forward, right, up


CAM_POS, CAM_FWD, CAM_RIGHT, CAM_UP = camera()


def project(points, scale):
    rel = points - CAM_POS
    depth = rel @ CAM_FWD
    x = (rel @ CAM_RIGHT) / depth * FOCAL
    y = (rel @ CAM_UP) / depth * FOCAL
    return np.column_stack([SIZE / 2 + x * scale, SIZE / 2 - y * scale]), depth


def shade(triangle, kind):
    a, b, c = triangle
    normal = np.cross(b - a, c - a)
    normal /= np.linalg.norm(normal)
    center = triangle.mean(axis=0)
    view = CAM_POS - center
    view /= np.linalg.norm(view)
    if normal @ view < 0 and kind != "bottom":
        normal = -normal  # winding-independent: facets face the camera side
    diffuse = max(0.0, normal @ LIGHT)
    half = LIGHT + view
    half /= np.linalg.norm(half)
    specular = max(0.0, normal @ half) ** 40
    base = BASE if kind == "top" else WALL
    color = base * (0.32 + 0.78 * diffuse) + 0.45 * specular
    return np.clip(color, 0, 1)


def rasterize(angle, scale):
    color = np.zeros((SIZE, SIZE, 3))
    depth_buffer = np.full((SIZE, SIZE), np.inf)
    triangles, kinds = mesh(angle)
    ys, xs = np.mgrid[0:SIZE, 0:SIZE] + 0.5
    for triangle, kind in zip(triangles, kinds):
        if kind == "bottom":
            continue
        screen, depth = project(triangle, scale)
        (x0, y0), (x1, y1), (x2, y2) = screen
        area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)
        if abs(area) < 1e-9:
            continue
        left, right = int(max(0, np.floor(screen[:, 0].min()))), int(min(SIZE, np.ceil(screen[:, 0].max())))
        top, bottom = int(max(0, np.floor(screen[:, 1].min()))), int(min(SIZE, np.ceil(screen[:, 1].max())))
        if left >= right or top >= bottom:
            continue
        px, py = xs[top:bottom, left:right], ys[top:bottom, left:right]
        w0 = ((x1 - px) * (y2 - py) - (x2 - px) * (y1 - py)) / area
        w1 = ((x2 - px) * (y0 - py) - (x0 - px) * (y2 - py)) / area
        w2 = 1 - w0 - w1
        inside = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
        z = w0 * depth[0] + w1 * depth[1] + w2 * depth[2]
        zbuf = depth_buffer[top:bottom, left:right]
        visible = inside & (z < zbuf)
        zbuf[visible] = z[visible]
        color[top:bottom, left:right][visible] = shade(triangle, kind)
    mask = np.isfinite(depth_buffer)
    return color, mask


def frame_image(angle, scale):
    color, mask = rasterize(angle, scale)
    mask_img = Image.fromarray((mask * 255).astype(np.uint8))
    # Dark outline (~1 px at the final size) for contrast on bright ground.
    outline = np.asarray(mask_img.filter(ImageFilter.MaxFilter(7))) > 0
    # Soft drop shadow, down and to the right.
    shift = 3 * SUPER
    shadow_img = Image.fromarray((outline * 255).astype(np.uint8)).transform(
        (SIZE, SIZE), Image.AFFINE, (1, 0, -shift, 0, 1, -shift))
    shadow = np.asarray(shadow_img.filter(ImageFilter.GaussianBlur(3 * SUPER))) / 255.0 * 0.55

    rgb = np.zeros((SIZE, SIZE, 3))
    alpha = shadow.copy()
    rgb[outline] = OUTLINE_COLOR
    alpha[outline] = 1.0
    rgb[mask] = color[mask]

    # Box-filter down to the final size on premultiplied color.
    premultiplied = rgb * alpha[..., None]
    def down(a):
        shape = (FRAME, SUPER, FRAME, SUPER) + a.shape[2:]
        return a.reshape(shape).mean(axis=(1, 3))
    alpha_small = down(alpha)
    rgb_small = down(premultiplied) / np.maximum(alpha_small[..., None], 1e-6)
    return np.dstack([np.clip(rgb_small, 0, 1), alpha_small])


def fit_scale():
    """Largest scale that keeps every rotation inside its frame (8% margin)."""
    extent = 0.0
    for k in range(FRAMES):
        triangles, _ = mesh(2 * np.pi * k / FRAMES)
        screen, _ = project(triangles.reshape(-1, 3), 1.0)
        extent = max(extent, np.abs(screen - SIZE / 2).max())
    return (SIZE / 2) * 0.84 / extent


def write_tga(path, rgba):
    """32-bit uncompressed TGA, bottom-left origin, like the theme textures."""
    height, width, _ = rgba.shape
    data = (np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8)
    bgra = data[::-1, :, [2, 1, 0, 3]]
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, width, height, 32, 8)
    with open(path, "wb") as f:
        f.write(header)
        f.write(bgra.tobytes())


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join(root, "Media", "Arrow", "arrow3d.tga")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    scale = fit_scale()
    sheet = np.zeros((FRAME * FRAMES_PER_ROW, FRAME * FRAMES_PER_ROW, 4))
    for k in range(FRAMES):
        row, col = divmod(k, FRAMES_PER_ROW)
        sheet[row * FRAME:(row + 1) * FRAME, col * FRAME:(col + 1) * FRAME] = frame_image(2 * np.pi * k / FRAMES, scale)
    write_tga(out, sheet)
    if len(sys.argv) > 1:  # optional preview PNG on a grey background
        preview = Image.new("RGBA", (sheet.shape[1], sheet.shape[0]), (60, 70, 60, 255))
        preview.alpha_composite(Image.fromarray((sheet * 255).astype(np.uint8), "RGBA"))
        preview.save(sys.argv[1])
    print("wrote", out)


if __name__ == "__main__":
    main()
