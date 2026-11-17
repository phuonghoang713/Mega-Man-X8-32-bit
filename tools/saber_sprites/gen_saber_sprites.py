#!/usr/bin/env python3
"""Procedural pixel-art sheet for Zeno, the saber knight (original design).

Navy armor with silver plates, a swept-back helmet fin, a cyan visor, an amber
chest core, a long teal scarf and an orange energy blade.

Writes an Aseprite-style export (sheet PNG + JSON with frame tags) that
src/Actors/Player/Zeno/ZenoSprites.gd loads (default: src/Actors/Player/zeno_sprites/).

    python3 tools/saber_sprites/gen_saber_sprites.py [out_dir]

Each pose is a small skeleton (hip, lean, leg/arm angles, saber angle, scarf
flow). Angles are in degrees: 0 points straight down, +90 points forward
(right, the way the character faces), 180 points up.
"""
import json
import math
import os
import sys

from PIL import Image, ImageDraw

CELL = 96          # cell size (px)
COLS = 10
FOOT_Y = 66        # ground line inside a cell
CX = 46            # body center x inside a cell (a little left: slashes go right)
S = 0.8            # body scale: 0.8 makes Zeno about as tall as X (~34 px)
R = 0.85           # limb thickness scale (kept thicker so parts stay readable)
N = CELL * CELL
FULL = (1 << N) - 1
COL0 = sum(1 << (y * CELL) for y in range(CELL))
COLL = COL0 << (CELL - 1)


def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


RAMPS = {  # dark, base, light
    "navy": ("#1a2247", "#2c3d78", "#4a64ae"),
    "silver": ("#687089", "#a7b1c6", "#e8edf6"),
    "suit": ("#1d1d26", "#33333f", "#4e4e5e"),
    "scarf": ("#0d6566", "#18a09c", "#62e2d2"),
    "amber": ("#b0520e", "#f08a1c", "#ffd56a"),
    "skin": ("#a3634a", "#d89a74", "#f3c7a2"),
    "visor": ("#0d6a98", "#19a2da", "#93f2ff"),
    "glove": ("#24242c", "#3b3b47", "#5b5b6b"),
    "grip": ("#3a3f4f", "#6b7388", "#a7b1c6"),
}
OUTLINE = hexc("#0a0b17")
BLADE = [hexc("#d2430b"), hexc("#ff8a1a"), hexc("#ffcf45"), hexc("#fffbe2")]  # edge..core


def ramp(name, dim=1.0):
    cols = [hexc(c) for c in RAMPS[name]]
    if dim != 1.0:
        cols = [(int(c[0] * dim), int(c[1] * dim), int(c[2] * dim), 255) for c in cols]
    return cols


def dirv(a, length=1.0):
    r = math.radians(a)
    return (math.sin(r) * length, math.cos(r) * length)


def add(p, v, k=1.0):
    return (p[0] + v[0] * k, p[1] + v[1] * k)


def seg_dist(px, py, p0, p1):
    ax, ay = p0
    dx, dy = p1[0] - ax, p1[1] - ay
    l2 = dx * dx + dy * dy or 1e-9
    t = min(1.0, max(0.0, ((px - ax) * dx + (py - ay) * dy) / l2))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


class Canvas:
    """96x96 canvas; masks are int bitsets (bit y*CELL+x)."""

    def __init__(self):
        self.px = [None] * N

    # ---- masks
    def where(self, pred, box=None):
        x0, y0, x1, y1 = box or (0, 0, CELL, CELL)
        x0, y0 = max(0, int(x0)), max(0, int(y0))
        x1, y1 = min(CELL, int(x1) + 1), min(CELL, int(y1) + 1)
        m = 0
        for y in range(y0, y1):
            for x in range(x0, x1):
                if pred(x + 0.5, y + 0.5):
                    m |= 1 << (y * CELL + x)
        return m

    def capsule(self, p0, p1, r):
        box = (min(p0[0], p1[0]) - r - 1, min(p0[1], p1[1]) - r - 1,
               max(p0[0], p1[0]) + r + 1, max(p0[1], p1[1]) + r + 1)
        return self.where(lambda x, y: seg_dist(x, y, p0, p1) <= r, box)

    def disc(self, c, r):
        return self.capsule(c, c, r)

    def poly(self, pts):
        im = Image.new("L", (CELL, CELL), 0)
        ImageDraw.Draw(im).polygon([(x, y) for x, y in pts], fill=1)
        m = 0
        for i, v in enumerate(im.getdata()):
            if v:
                m |= 1 << i
        return m

    @staticmethod
    def shift(m, dy, dx):
        """out[y][x] = m[y-dy][x-dx]"""
        if dy > 0:
            m = (m << (dy * CELL)) & FULL
        elif dy < 0:
            m >>= -dy * CELL
        if dx > 0:
            m = ((m << dx) & FULL) & ~COL0
        elif dx < 0:
            m = (m >> -dx) & ~COLL
        return m

    def put(self, mask, cols, outline=True, shade=True):
        """Paint a part: 1px outline around it, then a top-left lit fill."""
        if not mask:
            return
        sh = self.shift
        if outline:
            grown = mask | sh(mask, 1, 0) | sh(mask, -1, 0) | sh(mask, 0, 1) | sh(mask, 0, -1)
            self.flat(grown & ~mask, OUTLINE)
        dark, base, light = cols
        self.flat(mask, base)
        if shade:
            d = mask & (~sh(mask, -1, 0) | ~sh(mask, 0, -1))
            lt = mask & (~sh(mask, 1, 0) | ~sh(mask, 0, 1)) & ~d
            self.flat(d, dark)
            self.flat(lt, light)

    def flat(self, mask, col):
        px = self.px
        while mask:
            low = mask & -mask
            px[low.bit_length() - 1] = col
            mask ^= low

    def image(self):
        return Image.frombytes("RGBA", (CELL, CELL),
                               bytes(c for p in self.px for c in (p or (0, 0, 0, 0))))


# --------------------------------------------------------------------------- skeleton

THIGH, SHIN = 7.5 * S, 7.5 * S
UPPER, FORE = 5.0 * S, 5.5 * S
TORSO = 10.0      # in torso units (local() scales by S)
BLADE_LEN = 21.0 * S


def base_pose(**kw):
    p = dict(
        hip=(0.0, 0.0), ground=True, lean=4.0, head_tilt=0.0, breath=0,
        fl=(8, -4), bl=(-7, -12), foot_f=90, foot_b=90,
        fa=(12, 40), ba=(-12, 18),
        scarf=(-25, 8, 0.0), saber=None, trail=None, sheathed=True,
        effect=None, flash=0.0, dim_back=0.72,
    )
    p.update(kw)
    return p


def leg_points(hip, thigh, shin, foot):
    knee = add(hip, dirv(thigh, THIGH))
    ankle = add(knee, dirv(shin, SHIN))
    toe = add(ankle, dirv(foot, 4.0 * S))
    return knee, ankle, toe


def solve(p):
    """Turn a pose into joint positions in cell pixels."""
    hip = (CX + p["hip"][0], 40.0 + p["hip"][1])
    legs = {k: leg_points(hip, p[k][0], p[k][1], p["foot_" + k[0]]) for k in ("fl", "bl")}
    if p["ground"]:
        low = max(max(a[1], t[1]) for _, a, t in legs.values()) + 2.0 * R
        dy = FOOT_Y - low
        hip = (hip[0], hip[1] + dy)
        legs = {k: leg_points(hip, p[k][0], p[k][1], p["foot_" + k[0]]) for k in ("fl", "bl")}
    lean = math.radians(p["lean"])
    up = (math.sin(lean), -math.cos(lean))
    fwd = (math.cos(lean), math.sin(lean))
    body = (hip[0], hip[1] + p["breath"])
    neck = add(body, up, TORSO * S)
    shoulder = add(add(body, up, (TORSO - 2.0) * S), fwd, -0.5)
    tilt = math.radians(p["lean"] + p["head_tilt"])
    head = add(neck, (math.sin(tilt), -math.cos(tilt)), 5.0 * S)
    arms = {}
    for k in ("fa", "ba"):
        elbow = add(shoulder, dirv(p[k][0], UPPER))
        wrist = add(elbow, dirv(p[k][1], FORE))
        arms[k] = (elbow, wrist)
    return dict(hip=hip, body=body, up=up, fwd=fwd, neck=neck, shoulder=shoulder,
                head=head, legs=legs, arms=arms)


def local(j, u, v):
    """Point in the torso frame: u forward, v up from the waist."""
    u, v = u * S, v * S
    return (j["body"][0] + j["fwd"][0] * u + j["up"][0] * v,
            j["body"][1] + j["fwd"][1] * u + j["up"][1] * v)


# --------------------------------------------------------------------------- parts

def draw_scarf(cv, j, p, dim=1.0):
    base_angle, amp, phase = p["scarf"]
    start = local(j, -1.6, TORSO - 1.0)
    pts = [start]
    a = base_angle
    n = 8
    for i in range(n):
        a = base_angle + amp * math.sin(phase + i * 0.95) * (0.3 + i / n)
        pts.append(add(pts[-1], dirv(a, 2.6 * S)))
    mask = 0
    for i in range(n):
        r = (1.9 - 0.9 * i / n) * R
        mask |= cv.capsule(pts[i], pts[i + 1], r)
    # second, shorter tail split off halfway
    q = pts[4]
    a2 = base_angle - 22 + amp * 0.6 * math.sin(phase + 1.7)
    for i in range(3):
        q2 = add(q, dirv(a2 + 8 * i, 2.4 * S))
        mask |= cv.capsule(q, q2, (1.3 - 0.25 * i) * R)
        q = q2
    cv.put(mask, ramp("scarf", dim))


def draw_leg(cv, j, key, dim):
    hip = j["hip"]
    knee, ankle, toe = j["legs"][key]
    cv.put(cv.capsule(hip, knee, 1.9 * R), ramp("suit", dim))
    shin = cv.capsule(knee, ankle, 2.1 * R) | cv.capsule(ankle, toe, 1.9 * R) | cv.disc(ankle, 2.3 * R)
    cv.put(shin, ramp("navy", dim))
    cv.put(cv.disc(knee, 1.7 * R), ramp("silver", dim))
    # silver toe cap and amber heel light
    cv.put(cv.disc(toe, 1.5 * R), ramp("silver", dim), outline=False)
    heel = add(ankle, dirv(ramp_angle(ankle, toe) + 180, 1.6 * R))
    cv.flat(cv.disc(heel, 0.8), ramp("amber", dim)[1])


def ramp_angle(a, b):
    return math.degrees(math.atan2(b[0] - a[0], b[1] - a[1]))


def draw_arm(cv, j, key, dim, pad=True):
    sh = j["shoulder"]
    elbow, wrist = j["arms"][key]
    cv.put(cv.capsule(sh, elbow, 1.4 * R), ramp("suit", dim))
    cv.put(cv.capsule(elbow, wrist, 1.9 * R), ramp("navy", dim))
    cuff = add(elbow, (wrist[0] - elbow[0], wrist[1] - elbow[1]), 0.35)
    cv.put(cv.disc(cuff, 1.2), ramp("silver", dim), outline=False)
    hand = add(wrist, dirv(ramp_angle(elbow, wrist), 1.0))
    cv.put(cv.disc(hand, 1.6 * R), ramp("glove", dim))
    if pad:
        cv.put(cv.disc(add(sh, (0, -0.5)), 2.7 * R), ramp("silver", dim))
    return hand


def draw_torso(cv, j, p):
    body = [(-2.6, -1.0), (2.6, -1.0), (3.4, 3.5), (4.2, 7.5), (2.6, 10.6),
            (-2.8, 10.6), (-4.0, 7.0), (-3.2, 3.0)]
    pelvis = cv.capsule(local(j, 0, -1.0), local(j, 0.4, -2.5), 3.0 * S)
    cv.put(pelvis, ramp("suit"))
    cv.put(cv.poly([local(j, u, v) for u, v in body]), ramp("navy"))
    belt = [(-3.2, -1.6), (3.0, -1.6), (3.3, 0.8), (-3.4, 0.8)]
    cv.put(cv.poly([local(j, u, v) for u, v in belt]), ramp("silver"))
    collar = [(-2.6, 8.8), (2.8, 8.8), (2.2, 11.4), (-2.2, 11.4)]
    cv.put(cv.poly([local(j, u, v) for u, v in collar]), ramp("silver"))
    core = local(j, 2.4, 5.6)
    cv.put(cv.disc(core, 1.4 * R), ramp("amber"), outline=False)
    cv.flat(cv.disc(add(core, (-0.5, -0.5)), 0.5), ramp("amber")[2])


def draw_neck_scarf(cv, j):
    m = cv.capsule(local(j, -1.8, TORSO - 0.6), local(j, 1.8, TORSO - 0.2), 1.7 * R)
    cv.put(m, ramp("scarf"))


def draw_head(cv, j):
    hx, hy = j["head"]

    def h(dx, dy):
        return (hx + dx * S, hy + dy * S)

    helmet = cv.disc((hx, hy), 5.1 * S)
    fin = cv.poly([h(1.0, -4.3), h(-3.5, -8.8), h(-9.5, -8.6), h(-7.0, -7.2), h(-3.0, -3.4)])
    cv.put(helmet | fin, ramp("navy"))
    cv.put(fin & ~helmet, ramp("silver"), outline=False)
    box = (hx - 6, hy - 6, hx + 6, hy + 6)
    face = helmet & cv.where(lambda x, y: x > hx + 0.6 and hy - 0.2 < y < hy + 3.4 * S, box)
    cv.put(face, ramp("skin"), outline=False)
    visor = helmet & cv.where(lambda x, y: x > hx - 0.8 and hy - 2.4 * S < y < hy - 0.2, box)
    cv.put(visor, ramp("visor"), outline=False)
    cv.flat(visor & cv.where(lambda x, y: y < hy - 1.2 and x > hx + 2.0, box), ramp("visor")[2])
    chin = helmet & cv.where(lambda x, y: y > hy + 3.4 * S, box)
    cv.put(chin, ramp("silver"), outline=False)
    ear = h(-1.6, 0.8)
    cv.put(cv.disc(ear, 1.5), ramp("silver"))
    cv.flat(cv.disc(ear, 0.6), ramp("amber")[1])


def draw_sheath(cv, j, dim):
    a = local(j, -3.6, 1.5)
    b = local(j, -6.5, -2.5)
    cv.put(cv.capsule(a, b, 1.1 * R), ramp("grip", dim))
    cv.flat(cv.disc(a, 0.7), ramp("amber")[1])


def draw_saber(cv, hand, angle):
    d = dirv(angle)
    hilt0 = add(hand, d, -1.6)
    hilt1 = add(hand, d, 1.8)
    cv.put(cv.capsule(hilt0, hilt1, 1.0), ramp("grip"))
    b0 = add(hand, d, 2.6)
    b1 = add(hand, d, 2.6 + BLADE_LEN)
    for r, col in zip((1.7, 1.2, 0.8, 0.4), BLADE):
        cv.flat(cv.capsule(b0, b1, r), col)


def draw_trail(cv, center, a0, a1, r_out, width, reverse=False):
    """Crescent slash arc swept from angle a0 (tail) to a1 (leading edge)."""
    cx, cy = CX + (center[0] - CX) * S, FOOT_Y - (FOOT_Y - center[1]) * S
    r_out, width = r_out * S, width * S
    lo, hi = min(a0, a1), max(a0, a1)
    span = hi - lo
    px = cv.px
    for y in range(CELL):
        for x in range(CELL):
            fx, fy = x + 0.5 - cx, y + 0.5 - cy
            rad = math.hypot(fx, fy)
            if rad > r_out:
                continue
            rel = (math.degrees(math.atan2(fx, fy)) - lo) % 360
            if rel > span:
                continue
            t = rel / span
            if a1 < a0:
                t = 1 - t
            thick = 1.0 + width * t ** 1.4
            if rad < r_out - thick:
                continue
            depth = (r_out - rad) / thick
            if depth < 0.22:
                col = BLADE[3] if t > 0.7 else BLADE[2]
            elif depth < 0.55:
                col = BLADE[1]
            else:
                col = BLADE[0] if t > 0.35 else BLADE[1]
            px[y * CELL + x] = col


def render(p):
    cv = Canvas()
    j = solve(p)
    dim = p["dim_back"]
    if p.get("trail_behind"):
        draw_trail(cv, *p["trail_behind"])
    draw_scarf(cv, j, p)
    hand_b = draw_arm(cv, j, "ba", dim)
    if p.get("saber_back") is not None:
        draw_saber(cv, hand_b, p["saber_back"])
    draw_leg(cv, j, "bl", dim)
    if p["sheathed"] and p["saber"] is None:
        draw_sheath(cv, j, 1.0)
    draw_torso(cv, j, p)
    draw_leg(cv, j, "fl", 1.0)
    draw_neck_scarf(cv, j)
    draw_head(cv, j)
    if p["trail"]:
        draw_trail(cv, *p["trail"])
    hand_f = draw_arm(cv, j, "fa", 1.0)
    if p["saber"] is not None:
        draw_saber(cv, hand_f, p["saber"])
        draw_arm_over_hilt(cv, j)
    if p["flash"] > 0:
        k = p["flash"]
        cv.px = [None if c is None else tuple(int(v + (255 - v) * k) for v in c[:3]) + (255,)
                 for c in cv.px]
    if p["effect"]:
        p["effect"](cv, j)
    return cv.image()


def draw_arm_over_hilt(cv, j):
    """Glove drawn again so the fist wraps the hilt."""
    elbow, wrist = j["arms"]["fa"]
    hand = add(wrist, dirv(ramp_angle(elbow, wrist), 1.0))
    cv.put(cv.disc(hand, 1.5), ramp("glove"), outline=False)


# --------------------------------------------------------------------------- effects

def fx_beam(cv, j):
    cv.px = [None] * N
    x = CX
    cv.flat(cv.where(lambda px, py: abs(px - x) < 3.6 and py < FOOT_Y - 1), OUTLINE)
    glow = cv.where(lambda px, py: abs(px - x) < 2.6 and py < FOOT_Y - 2)
    cv.flat(glow, BLADE[1])
    cv.flat(cv.where(lambda px, py: abs(px - x) < 1.2 and py < FOOT_Y - 4), BLADE[3])
    cv.flat(cv.disc((x, FOOT_Y - 4), 3.2) & ~glow, BLADE[2])


def fx_land_splash(cv, j):
    cv.px = [None] * N
    x = CX
    for w, h, col in ((13, 2.6, BLADE[0]), (10, 1.8, BLADE[1]), (6, 1.0, BLADE[3])):
        cv.flat(cv.where(lambda px, py: ((px - x) / w) ** 2 + ((py - (FOOT_Y - 1.5)) / h) ** 2 <= 1), col)
    cv.flat(cv.where(lambda px, py: abs(px - x) < 2.0 and FOOT_Y - 30 < py < FOOT_Y - 1
                     and int(py) % 3 != 0), BLADE[2])
    cv.flat(cv.where(lambda px, py: abs(px - x) < 0.8 and FOOT_Y - 30 < py < FOOT_Y - 1), BLADE[3])


def fx_scanlines(gap):
    def f(cv, j):
        cv.px = [None if c is None or (i // CELL) % gap else (255, 236, 190, 255)
                 for i, c in enumerate(cv.px)]
    return f


def fx_sparks(cv, j):
    hx, hy = j["head"]
    for (dx, dy) in ((-7, -6), (6, -8), (8, 2), (-9, 3)):
        c = (hx + dx, hy + dy)
        m = cv.capsule(add(c, (-1.5, 0)), add(c, (1.5, 0)), 0.5) | cv.capsule(add(c, (0, -1.5)), add(c, (0, 1.5)), 0.5)
        cv.flat(m, BLADE[3])


def fx_dash_dust(cv, j):
    x = j["legs"]["bl"][2][0] - 5
    for k, r in enumerate((2.6, 1.9, 1.3)):
        c = (x - k * 5, FOOT_Y - 2 - k * 0.5)
        cv.put(cv.disc(c, r), ramp("silver", 0.95), outline=True)


def fx_air_jets(cv, j):
    hip = j["hip"]
    for k in range(3):
        y = hip[1] - 2 + k * 3
        m = cv.where(lambda px, py: y - 0.6 < py < y + 0.6 and hip[0] - 18 + k * 2 < px < hip[0] - 8 - k)
        cv.flat(m, BLADE[2] if k != 1 else BLADE[3])


def combine(*fs):
    def f(cv, j):
        for g in fs:
            g(cv, j)
    return f


# --------------------------------------------------------------------------- animations

def run_pose(i):
    ph = i / 8 * 2 * math.pi
    s, c = math.sin(ph), math.cos(ph)

    def leg(sig, cc):
        thigh = 6 + 34 * sig
        shin = thigh - (12 + 62 * max(0.0, cc))
        foot = max(45, min(100, shin + 95))
        return (thigh, shin), foot

    fl, ff = leg(s, c)
    bl, fb = leg(-s, -c)
    return base_pose(lean=16, head_tilt=-6, fl=fl, bl=bl, foot_f=ff, foot_b=fb,
                     fa=(-40 * s + 10, -40 * s + 75), ba=(40 * s + 10, 40 * s + 75),
                     scarf=(-100, 14, ph * 2))


IDLE_AIR_HIP = None


def air(dx=0.0, dy=0.0):
    return (dx, IDLE_AIR_HIP + dy)


def build_animations():
    global IDLE_AIR_HIP
    stand = base_pose()
    IDLE_AIR_HIP = solve(stand)["hip"][1] - 40.0
    anims = []

    # Row 1: idle (4) + teleport (4)
    idle = []
    for i, (b, ph) in enumerate(((0, 0.0), (0, 0.8), (1, 1.6), (1, 2.4))):
        idle.append(base_pose(breath=b, scarf=(-58, 9, ph),
                              fa=(12 - b * 2, 40 - b * 4), ba=(-12, 18 - b * 3)))
    anims.append(("idle", idle, [220, 160, 220, 160]))
    anims.append(("beam", [base_pose(effect=fx_beam)], [60]))
    anims.append(("beam_in", [
        base_pose(effect=fx_land_splash),
        base_pose(effect=fx_scanlines(2)),
        base_pose(flash=0.55, scarf=(-58, 9, 0.4)),
    ], [60, 60, 80]))

    # Row 2: run (8)
    anims.append(("walk", [run_pose(i) for i in range(8)], [70] * 8))

    # Row 3: jump (2), fall (1), recover (1), slide (1), walljump (2), dash (2), airdash (1)
    anims.append(("jump", [
        base_pose(lean=14, fl=(48, -18), bl=(22, -40), fa=(-30, 20), ba=(-45, 0),
                  scarf=(-35, 6, 0.5)),
        base_pose(ground=False, hip=air(0, -2), lean=6, fl=(55, -5), bl=(-4, -14),
                  foot_b=60, fa=(140, 165), ba=(-30, 10), scarf=(-15, 10, 1.0)),
    ], [60, 120]))
    anims.append(("fall", [
        base_pose(ground=False, hip=air(0, -2), lean=2, fl=(30, 8), bl=(-14, -30),
                  foot_b=65, fa=(110, 135), ba=(-70, -40), scarf=(-155, 18, 2.0)),
    ], [120]))
    anims.append(("recover", [
        base_pose(lean=20, head_tilt=-8, fl=(68, -8), bl=(30, -62), foot_b=40,
                  fa=(30, 70), ba=(-30, 10), scarf=(-60, 10, 1.4)),
    ], [80]))
    # wall slide: back to the wall (wall on the left), one hand dragging on it
    anims.append(("slide", [
        base_pose(ground=False, hip=air(2, -2), lean=-6, head_tilt=6,
                  fl=(40, -10), bl=(-10, -6), foot_b=70,
                  fa=(40, 70), ba=(-120, -150), scarf=(-170, 12, 0.3), effect=fx_sparks_wall),
    ], [100]))
    anims.append(("walljump", [
        base_pose(ground=False, hip=air(2, -3), lean=-10, fl=(70, 20), bl=(-30, -50),
                  foot_b=40, fa=(80, 120), ba=(-80, -60), scarf=(-140, 10, 0.8)),
        base_pose(ground=False, hip=air(0, -4), lean=10, fl=(55, -10), bl=(10, -25),
                  fa=(150, 170), ba=(-40, -10), scarf=(-60, 14, 1.8)),
    ], [60, 100]))
    anims.append(("dash", [
        base_pose(lean=30, head_tilt=-10, fl=(70, 30), bl=(-50, -70), foot_b=30, foot_f=95,
                  fa=(-40, 30), ba=(-60, -20), scarf=(-105, 6, 0.4)),
        base_pose(lean=34, head_tilt=-10, fl=(72, 40), bl=(-62, -78), foot_b=25, foot_f=95,
                  fa=(-50, 20), ba=(-70, -30), scarf=(-98, 12, 2.0), effect=fx_dash_dust),
    ], [50, 80]))
    anims.append(("airdash", [
        base_pose(ground=False, hip=air(0, 2), lean=34, head_tilt=-10, fl=(75, 20),
                  bl=(-45, -70), foot_b=30, fa=(-50, 20), ba=(-70, -30),
                  scarf=(-96, 10, 1.2), effect=fx_air_jets),
    ], [80]))

    # Row 4: three-hit ground combo (3 frames each)
    anims.append(("saber_1", [
        base_pose(lean=-4, fl=(20, -2), bl=(-14, -20), fa=(-95, -130), ba=(-20, 10),
                  saber=-150, scarf=(-50, 8, 0.2)),
        base_pose(lean=14, fl=(30, -8), bl=(-20, -26), fa=(70, 95), ba=(-30, 0),
                  saber=110, scarf=(-80, 10, 1.0),
                  trail=((CX + 2, 38), -165, 115, 26, 7)),
        base_pose(lean=12, fl=(30, -8), bl=(-20, -26), fa=(40, 50), ba=(-30, 0),
                  saber=55, scarf=(-70, 10, 2.0),
                  trail=((CX + 2, 38), 150, 60, 25, 4)),
    ], [80, 90, 110]))
    anims.append(("saber_2", [
        base_pose(lean=10, fl=(26, -6), bl=(-18, -24), fa=(45, 30), ba=(-30, 0),
                  saber=30, scarf=(-70, 8, 0.3)),
        base_pose(lean=6, fl=(28, -6), bl=(-20, -26), fa=(130, 150), ba=(-40, -10),
                  saber=170, scarf=(-90, 10, 1.2),
                  trail=((CX + 2, 40), 40, 175, 25, 7)),
        base_pose(lean=4, fl=(28, -6), bl=(-20, -26), fa=(155, 175), ba=(-40, -10),
                  saber=-170, scarf=(-80, 10, 2.2),
                  trail=((CX + 2, 40), 110, 190, 24, 4)),
    ], [80, 90, 110]))
    anims.append(("saber_3", [
        base_pose(lean=-6, fl=(18, 0), bl=(-16, -22), fa=(-170, -175), ba=(-150, -165),
                  saber=-178, scarf=(-30, 8, 0.4)),
        base_pose(lean=26, head_tilt=-8, fl=(50, -10), bl=(-36, -52), foot_b=45,
                  fa=(80, 100), ba=(-50, -20), saber=100, scarf=(-100, 12, 1.4),
                  trail=((CX + 4, 40), -178, 105, 33, 10)),
        base_pose(lean=30, head_tilt=-8, fl=(56, -10), bl=(-36, -52), foot_b=45,
                  fa=(25, 40), ba=(-50, -20), saber=30, scarf=(-95, 12, 2.6),
                  trail=((CX + 4, 40), 160, 30, 31, 6)),
    ], [110, 130, 160]))

    # Row 5: air spin (4), dash slash (3), hurt (2) + defeat (1)
    spin = []
    for k, (sab, lean) in enumerate(((180, 0), (90, 10), (0, 0), (-90, -10))):
        tr = ((CX + 1, 33 + IDLE_AIR_HIP), sab - 160, sab - 10, 22, 6)
        spin.append(base_pose(ground=False, hip=air(0, -3), lean=lean,
                              fl=(60, 0), bl=(30, -40), foot_b=50,
                              fa=(sab, sab + 10), ba=(-40, -10), saber=sab + 5,
                              scarf=(-150 + 30 * k, 12, k * 1.5), trail=tr))
    anims.append(("saber_air", spin, [70, 75, 75, 75]))
    anims.append(("saber_dash", [
        base_pose(lean=30, head_tilt=-10, fl=(70, 30), bl=(-50, -70), foot_b=30, foot_f=95,
                  fa=(-60, -100), ba=(-60, -20), saber=-120, scarf=(-105, 6, 0.4)),
        base_pose(lean=32, head_tilt=-10, fl=(72, 40), bl=(-60, -76), foot_b=25, foot_f=95,
                  fa=(85, 92), ba=(-70, -30), saber=92, scarf=(-98, 12, 1.6),
                  trail=((CX + 6, 46), -130, 95, 30, 8), effect=fx_dash_dust),
        base_pose(lean=28, head_tilt=-6, fl=(66, 30), bl=(-50, -70), foot_b=30, foot_f=95,
                  fa=(60, 70), ba=(-70, -30), saber=65, scarf=(-96, 12, 2.6),
                  trail=((CX + 6, 46), 140, 65, 29, 5)),
    ], [90, 100, 110]))
    anims.append(("damage", [
        base_pose(lean=-18, head_tilt=-14, fl=(30, 10), bl=(-10, -20), fa=(150, 120),
                  ba=(-120, -150), scarf=(20, 14, 0.2), flash=0.6),
        base_pose(lean=-14, head_tilt=-10, fl=(28, 4), bl=(-12, -24), fa=(120, 100),
                  ba=(-100, -130), scarf=(10, 14, 1.4)),
    ], [80, 140]))
    anims.append(("defeat", [
        base_pose(lean=40, head_tilt=30, fl=(80, -10), bl=(70, -85), foot_b=10, foot_f=90,
                  fa=(10, 5), ba=(-5, 0), scarf=(-20, 4, 0.0), sheathed=False),
    ], [400]))
    return anims


def fx_sparks_wall(cv, j):
    # sparks where the back hand drags on the wall
    elbow, wrist = j["arms"]["ba"]
    x, y = wrist[0] - 1, wrist[1] + 3
    for k, (dx, dy) in enumerate(((0, 0), (-1, 4), (1, 7))):
        c = (x + dx, y + dy)
        cv.flat(cv.disc(c, 0.9 - k * 0.15), BLADE[3] if k == 0 else BLADE[2])


# Rows of the sheet, as in the brief (tag names the game plays).
ROWS = [
    ["idle", "beam", "beam_in"],
    ["walk"],
    ["jump", "fall", "recover", "slide", "walljump", "dash", "airdash"],
    ["saber_1", "saber_2", "saber_3"],
    ["saber_air", "saber_dash", "damage", "defeat"],
]


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        here, "..", "..", "src", "Actors", "Player", "zeno_sprites")
    os.makedirs(out_dir, exist_ok=True)
    anims = {name: (poses, durs) for name, poses, durs in build_animations()}
    sheet = Image.new("RGBA", (CELL * COLS, CELL * len(ROWS)), (0, 0, 0, 0))
    frames, tags = [], []
    index = 0
    for row, names in enumerate(ROWS):
        col = 0
        for name in names:
            poses, durs = anims[name]
            start = index
            for k, (pose, dur) in enumerate(zip(poses, durs)):
                img = render(pose)
                x, y = col * CELL, row * CELL
                sheet.paste(img, (x, y))
                frames.append({
                    "filename": "%s %d" % (name, k),
                    "frame": {"x": x, "y": y, "w": CELL, "h": CELL},
                    "rotated": False, "trimmed": False,
                    "spriteSourceSize": {"x": 0, "y": 0, "w": CELL, "h": CELL},
                    "sourceSize": {"w": CELL, "h": CELL},
                    "duration": dur,
                })
                col += 1
                index += 1
            tags.append({"name": name, "from": start, "to": index - 1, "direction": "forward"})
    sheet.save(os.path.join(out_dir, "zeno.png"))
    data = {
        "frames": frames,
        "meta": {
            "app": "tools/saber_sprites/gen_saber_sprites.py",
            "image": "zeno.png", "format": "RGBA8888",
            "size": {"w": sheet.width, "h": sheet.height}, "scale": "1",
            "frameTags": tags,
        },
    }
    with open(os.path.join(out_dir, "zeno.json"), "w") as f:
        json.dump(data, f, indent=1)
    print("wrote %d frames, %d tags -> %s" % (len(frames), len(tags), out_dir))


if __name__ == "__main__":
    main()
