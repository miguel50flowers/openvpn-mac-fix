#!/usr/bin/env python3
"""Generate app icon PNGs, .icns file, and DMG background for VPN Fix.

Uses skia-python for professional vector rendering with gradients, glows,
anti-aliasing, and effects that PIL cannot achieve.

Usage:
    python3 tests/generate_assets.py --style 1              # Full generation
    python3 tests/generate_assets.py --style 2 --preview    # Preview only
    python3 tests/generate_assets.py --style 3 --preview    # Preview only
"""

import argparse
import math
import os
import subprocess
import tempfile

import numpy as np
import skia
from PIL import Image, ImageDraw, ImageFont

# Paths
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APPICONSET = os.path.join(ROOT, "app", "VPNFix", "Resources", "Assets.xcassets", "AppIcon.appiconset")
RESOURCES = os.path.join(ROOT, "app", "VPNFix", "Resources")
DMG_ASSETS = os.path.join(ROOT, "dmg-assets")
TESTS_DIR = os.path.dirname(os.path.abspath(__file__))

# Icon sizes: (base_size, scale, pixel_size, filename)
ICON_SIZES = [
    (16, 1, 16, "icon_16x16.png"),
    (16, 2, 32, "icon_16x16@2x.png"),
    (32, 1, 32, "icon_32x32.png"),
    (32, 2, 64, "icon_32x32@2x.png"),
    (128, 1, 128, "icon_128x128.png"),
    (128, 2, 256, "icon_128x128@2x.png"),
    (256, 1, 256, "icon_256x256.png"),
    (256, 2, 512, "icon_256x256@2x.png"),
    (512, 1, 512, "icon_512x512.png"),
    (512, 2, 1024, "icon_512x512@2x.png"),
]


# ---------------------------------------------------------------------------
# Shared utilities
# ---------------------------------------------------------------------------

def superellipse_mask(size, n=5):
    """Create a macOS-style rounded superellipse mask."""
    img = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(img)
    cx, cy = size / 2, size / 2
    r = size / 2 * 0.93  # slight inset from edge
    points = []
    for angle_deg in range(360):
        t = math.radians(angle_deg)
        cos_t = math.cos(t)
        sin_t = math.sin(t)
        x = math.copysign(abs(cos_t) ** (2.0 / n), cos_t) * r + cx
        y = math.copysign(abs(sin_t) ** (2.0 / n), sin_t) * r + cy
        points.append((x, y))
    draw.polygon(points, fill=255)
    return img


def skia_surface_to_pil(surface):
    """Skia surface -> PIL RGBA."""
    image = surface.makeImageSnapshot()
    array = image.toarray()
    return Image.fromarray(array, 'RGBA')


def create_skia_surface(size):
    """Create a transparent Skia surface and return (surface, canvas)."""
    surface = skia.Surface(size, size)
    surface.getCanvas().clear(skia.Color(0, 0, 0, 0))
    return surface, surface.getCanvas()


def make_glow_paint(color, sigma):
    """Create a paint with blur mask filter for glow effects."""
    paint = skia.Paint(Color=color, AntiAlias=True)
    paint.setMaskFilter(skia.MaskFilter.MakeBlur(skia.kNormal_BlurStyle, sigma))
    return paint


def hex_to_skia(hex_str, alpha=255):
    """Convert hex color string to skia.Color."""
    h = hex_str.lstrip('#')
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    return skia.Color(r, g, b, alpha)


def draw_noise_texture(canvas, size, opacity=0.04):
    """Draw subtle noise texture using NumPy random data."""
    rng = np.random.default_rng(42)
    noise = rng.integers(0, 256, (size, size), dtype=np.uint8)
    alpha_val = int(255 * opacity)
    rgba = np.zeros((size, size, 4), dtype=np.uint8)
    rgba[:, :, 0] = noise
    rgba[:, :, 1] = noise
    rgba[:, :, 2] = noise
    rgba[:, :, 3] = alpha_val

    noise_img = skia.Image.fromarray(rgba, colorType=skia.kRGBA_8888_ColorType)
    paint = skia.Paint(AntiAlias=True)
    paint.setBlendMode(skia.BlendMode.kOverlay)
    canvas.drawImage(noise_img, 0, 0, skia.SamplingOptions(), paint)


def make_shield_path(cx, cy, w, h):
    """Create a smooth shield path using cubic bezier curves."""
    path = skia.Path()
    # Top center
    path.moveTo(cx, cy - h * 0.5)
    # Top center -> top right (curve outward)
    path.cubicTo(cx + w * 0.15, cy - h * 0.5,
                 cx + w * 0.5, cy - h * 0.42,
                 cx + w * 0.5, cy - h * 0.3)
    # Right side down
    path.cubicTo(cx + w * 0.5, cy + h * 0.05,
                 cx + w * 0.4, cy + h * 0.25,
                 cx, cy + h * 0.5)
    # Bottom -> left side up
    path.cubicTo(cx - w * 0.4, cy + h * 0.25,
                 cx - w * 0.5, cy + h * 0.05,
                 cx - w * 0.5, cy - h * 0.3)
    # Left side -> top center
    path.cubicTo(cx - w * 0.5, cy - h * 0.42,
                 cx - w * 0.15, cy - h * 0.5,
                 cx, cy - h * 0.5)
    path.close()
    return path


# ---------------------------------------------------------------------------
# Style 1: "Shield Guardian" — Shield + Restored WiFi
# ---------------------------------------------------------------------------

def generate_style1(size=1024):
    """Shield Guardian: frosted glass shield with WiFi arcs and repair spark."""
    surface, canvas = create_skia_surface(size)
    s = size  # shorthand

    # Layer 1: Vertical gradient background
    bg_paint = skia.Paint(AntiAlias=True)
    bg_paint.setShader(skia.GradientShader.MakeLinear(
        points=[(s / 2, 0), (s / 2, s)],
        colors=[hex_to_skia('#0A1628'), hex_to_skia('#123A6B'), hex_to_skia('#1E88E5')],
        positions=[0.0, 0.5, 1.0],
    ))
    canvas.drawRect(skia.Rect.MakeWH(s, s), bg_paint)

    # Layer 2: Radial glow center (Screen blend)
    glow_paint = skia.Paint(AntiAlias=True)
    glow_paint.setBlendMode(skia.BlendMode.kScreen)
    glow_paint.setShader(skia.GradientShader.MakeRadial(
        center=(s / 2, s * 0.45),
        radius=s * 0.45,
        colors=[hex_to_skia('#1565C0', 102), hex_to_skia('#1565C0', 0)],
        positions=[0.0, 1.0],
    ))
    canvas.drawRect(skia.Rect.MakeWH(s, s), glow_paint)

    # Layer 3: Noise texture
    draw_noise_texture(canvas, s, opacity=0.04)

    # Layer 4: Shield
    cx, cy = s / 2, s * 0.48
    shield_w = s * 0.35
    shield_h = s * 0.42
    shield = make_shield_path(cx, cy, shield_w, shield_h)

    # Shadow
    shadow_paint = skia.Paint(AntiAlias=True, Color=skia.Color(0, 0, 0, 77))
    shadow_paint.setMaskFilter(skia.MaskFilter.MakeBlur(skia.kNormal_BlurStyle, 15))
    canvas.save()
    canvas.translate(0, 8)
    canvas.drawPath(shield, shadow_paint)
    canvas.restore()

    # Glass fill (white 18%)
    glass_paint = skia.Paint(AntiAlias=True, Color=skia.Color(255, 255, 255, 46))
    canvas.drawPath(shield, glass_paint)

    # Glass border
    border_paint = skia.Paint(AntiAlias=True, Color=hex_to_skia('#B3D4FC', 153))
    border_paint.setStyle(skia.Paint.kStroke_Style)
    border_paint.setStrokeWidth(s * 0.004)
    border_paint.setMaskFilter(skia.MaskFilter.MakeBlur(skia.kNormal_BlurStyle, 2))
    canvas.drawPath(shield, border_paint)

    # Layer 5: WiFi arcs inside shield
    wifi_cx = cx
    wifi_cy = cy + s * 0.02
    arc_radii = [s * 0.08, s * 0.14, s * 0.20]
    arc_colors = [
        hex_to_skia('#E3F2FD', 230),
        hex_to_skia('#E3F2FD', 190),
        hex_to_skia('#E3F2FD', 150),
    ]

    for i, (radius, color) in enumerate(zip(arc_radii, arc_colors)):
        arc_paint = skia.Paint(AntiAlias=True, Color=color)
        arc_paint.setStyle(skia.Paint.kStroke_Style)
        arc_paint.setStrokeWidth(s * 0.012)
        arc_paint.setStrokeCap(skia.Paint.kRound_Cap)

        rect = skia.Rect.MakeLTRB(
            wifi_cx - radius, wifi_cy - radius,
            wifi_cx + radius, wifi_cy + radius
        )

        if i == 2:  # Outer arc is "broken" with dash
            arc_paint.setColor(hex_to_skia('#FF8A65', 180))
            arc_paint.setPathEffect(skia.DashPathEffect.Make([s * 0.04, s * 0.035], 0))
            canvas.drawArc(rect, -140, 100, False, arc_paint)
        else:
            canvas.drawArc(rect, -140, 100, False, arc_paint)

    # WiFi dot at bottom center
    dot_paint = skia.Paint(AntiAlias=True, Color=hex_to_skia('#E3F2FD', 240))
    canvas.drawCircle(wifi_cx, wifi_cy + s * 0.01, s * 0.015, dot_paint)

    # Layer 6: Repair spark in the gap of broken arc
    spark_cx = wifi_cx + arc_radii[2] * math.cos(math.radians(-40)) * 0.85
    spark_cy = wifi_cy + arc_radii[2] * math.sin(math.radians(-40)) * 0.85
    spark_size = s * 0.04

    spark_path = skia.Path()
    spark_path.moveTo(spark_cx - spark_size * 0.3, spark_cy - spark_size * 0.8)
    spark_path.lineTo(spark_cx + spark_size * 0.1, spark_cy - spark_size * 0.1)
    spark_path.lineTo(spark_cx + spark_size * 0.4, spark_cy - spark_size * 0.15)
    spark_path.lineTo(spark_cx + spark_size * 0.1, spark_cy + spark_size * 0.6)
    spark_path.lineTo(spark_cx - spark_size * 0.05, spark_cy + spark_size * 0.05)
    spark_path.lineTo(spark_cx - spark_size * 0.35, spark_cy + spark_size * 0.1)
    spark_path.close()

    # Spark glow
    canvas.drawPath(spark_path, make_glow_paint(hex_to_skia('#FFAB00', 120), 8))
    # Spark fill
    spark_fill = skia.Paint(AntiAlias=True, Color=hex_to_skia('#FFD54F'))
    canvas.drawPath(spark_path, spark_fill)

    # Layer 7: Badge (green circle with checkmark, bottom-right)
    badge_cx = cx + s * 0.18
    badge_cy = cy + shield_h * 0.35
    badge_r = s * 0.065

    # Badge shadow
    canvas.drawCircle(badge_cx, badge_cy + 3, badge_r,
                      make_glow_paint(skia.Color(0, 0, 0, 80), 6))
    # Badge glow
    canvas.drawCircle(badge_cx, badge_cy, badge_r * 1.3,
                      make_glow_paint(hex_to_skia('#4CAF50', 60), 10))
    # Badge fill
    badge_paint = skia.Paint(AntiAlias=True, Color=hex_to_skia('#66BB6A'))
    canvas.drawCircle(badge_cx, badge_cy, badge_r, badge_paint)

    # Checkmark in badge
    check_path = skia.Path()
    cs = badge_r * 0.45
    check_path.moveTo(badge_cx - cs * 1.0, badge_cy + cs * 0.1)
    check_path.lineTo(badge_cx - cs * 0.2, badge_cy + cs * 0.8)
    check_path.lineTo(badge_cx + cs * 1.1, badge_cy - cs * 0.7)

    check_paint = skia.Paint(AntiAlias=True, Color=skia.Color(255, 255, 255, 240))
    check_paint.setStyle(skia.Paint.kStroke_Style)
    check_paint.setStrokeWidth(s * 0.012)
    check_paint.setStrokeCap(skia.Paint.kRound_Cap)
    check_paint.setStrokeJoin(skia.Paint.kRound_Join)
    canvas.drawPath(check_path, check_paint)

    # Convert to PIL and apply superellipse mask
    pil_img = skia_surface_to_pil(surface)
    mask = superellipse_mask(s)
    result = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    result.paste(pil_img, mask=mask)
    return result


# ---------------------------------------------------------------------------
# Style 2: "Power Cycle" — Circular Arrow + Lightning Bolt
# ---------------------------------------------------------------------------

def generate_style2(size=1024):
    """Power Cycle: circular refresh arrow with globe and lightning bolt."""
    surface, canvas = create_skia_surface(size)
    s = size

    # Layer 1: Diagonal gradient background (blue to purple)
    bg_paint = skia.Paint(AntiAlias=True)
    bg_paint.setShader(skia.GradientShader.MakeLinear(
        points=[(0, 0), (s, s)],
        colors=[hex_to_skia('#0D47A1'), hex_to_skia('#1A237E'), hex_to_skia('#6A1B9A')],
        positions=[0.0, 0.5, 1.0],
    ))
    canvas.drawRect(skia.Rect.MakeWH(s, s), bg_paint)

    # Layer 2: Radial burst center (Screen blend)
    burst_paint = skia.Paint(AntiAlias=True)
    burst_paint.setBlendMode(skia.BlendMode.kScreen)
    burst_paint.setShader(skia.GradientShader.MakeRadial(
        center=(s / 2, s / 2),
        radius=s * 0.45,
        colors=[hex_to_skia('#42A5F5', 77), hex_to_skia('#42A5F5', 0)],
        positions=[0.0, 1.0],
    ))
    canvas.drawRect(skia.Rect.MakeWH(s, s), burst_paint)

    cx, cy = s / 2, s / 2

    # Layer 3: Globe mesh (meridians + parallels)
    globe_r = s * 0.2
    globe_paint = skia.Paint(AntiAlias=True, Color=hex_to_skia('#CE93D8', 128))
    globe_paint.setStyle(skia.Paint.kStroke_Style)
    globe_paint.setStrokeWidth(s * 0.005)

    # Circle outline
    canvas.drawCircle(cx, cy, globe_r, globe_paint)

    # Meridians (2 ellipses)
    for rx_factor in [0.35, 0.7]:
        rect = skia.Rect.MakeLTRB(
            cx - globe_r * rx_factor, cy - globe_r,
            cx + globe_r * rx_factor, cy + globe_r
        )
        canvas.drawOval(rect, globe_paint)

    # Parallels (equator + 2 latitudes)
    for lat_y_offset in [0, -0.45, 0.45]:
        ry_factor = 0.25 if lat_y_offset != 0 else 0.3
        y_off = globe_r * lat_y_offset
        rect = skia.Rect.MakeLTRB(
            cx - globe_r, cy + y_off - globe_r * ry_factor,
            cx + globe_r, cy + y_off + globe_r * ry_factor
        )
        canvas.drawArc(rect, 0, 180, False, globe_paint)
        canvas.drawArc(rect, 180, 180, False, globe_paint)

    # Layer 4: Circular arrow (refresh ↻)
    arrow_r_outer = s * 0.34
    arrow_r_inner = s * 0.27
    arrow_thickness = arrow_r_outer - arrow_r_inner

    # Arrow arc path (about 300 degrees, gap at top-right for lightning)
    arrow_start_angle = 50  # degrees
    arrow_sweep = 290

    # Build arrow body as thick arc
    arrow_path = skia.Path()
    outer_rect = skia.Rect.MakeLTRB(cx - arrow_r_outer, cy - arrow_r_outer,
                                     cx + arrow_r_outer, cy + arrow_r_outer)
    inner_rect = skia.Rect.MakeLTRB(cx - arrow_r_inner, cy - arrow_r_inner,
                                     cx + arrow_r_inner, cy + arrow_r_inner)

    # Outer arc
    arrow_path.arcTo(outer_rect, arrow_start_angle, arrow_sweep, True)

    # Connect to inner arc end
    end_angle_rad = math.radians(arrow_start_angle + arrow_sweep)
    inner_end_x = cx + arrow_r_inner * math.cos(end_angle_rad)
    inner_end_y = cy + arrow_r_inner * math.sin(end_angle_rad)
    arrow_path.lineTo(inner_end_x, inner_end_y)

    # Inner arc (reverse direction)
    inner_path = skia.Path()
    inner_path.arcTo(inner_rect, arrow_start_angle + arrow_sweep, -arrow_sweep, True)
    arrow_path.addPath(inner_path)
    arrow_path.close()

    # Arrow gradient fill
    arrow_paint = skia.Paint(AntiAlias=True)
    arrow_paint.setShader(skia.GradientShader.MakeLinear(
        points=[(cx - arrow_r_outer, cy), (cx + arrow_r_outer, cy)],
        colors=[hex_to_skia('#BBDEFB'), skia.Color(255, 255, 255, 245)],
        positions=[0.0, 1.0],
    ))
    canvas.drawPath(arrow_path, arrow_paint)

    # Metallic sheen (SoftLight)
    sheen_paint = skia.Paint(AntiAlias=True, Color=skia.Color(255, 255, 255, 77))
    sheen_paint.setBlendMode(skia.BlendMode.kSoftLight)
    canvas.drawPath(arrow_path, sheen_paint)

    # Arrowhead (triangle at the start of the arc)
    ah_angle = math.radians(arrow_start_angle)
    ah_cx = cx + (arrow_r_outer + arrow_r_inner) / 2 * math.cos(ah_angle)
    ah_cy = cy + (arrow_r_outer + arrow_r_inner) / 2 * math.sin(ah_angle)
    ah_size = arrow_thickness * 1.2

    # Rotated triangle
    ah_path = skia.Path()
    perp = ah_angle - math.pi / 2
    tip_x = ah_cx + ah_size * 0.8 * math.cos(ah_angle - 0.3)
    tip_y = ah_cy + ah_size * 0.8 * math.sin(ah_angle - 0.3)
    base1_x = ah_cx + ah_size * 0.5 * math.cos(perp)
    base1_y = ah_cy + ah_size * 0.5 * math.sin(perp)
    base2_x = ah_cx - ah_size * 0.5 * math.cos(perp)
    base2_y = ah_cy - ah_size * 0.5 * math.sin(perp)

    ah_path.moveTo(tip_x, tip_y)
    ah_path.lineTo(base1_x, base1_y)
    ah_path.lineTo(base2_x, base2_y)
    ah_path.close()

    ah_paint = skia.Paint(AntiAlias=True, Color=skia.Color(255, 255, 255, 240))
    canvas.drawPath(ah_path, ah_paint)

    # Layer 5: Glow trail near arrowhead
    glow_arc_paint = skia.Paint(AntiAlias=True, Color=hex_to_skia('#64B5F6', 64))
    glow_arc_paint.setStyle(skia.Paint.kStroke_Style)
    glow_arc_paint.setStrokeWidth(arrow_thickness * 1.8)
    glow_arc_paint.setMaskFilter(skia.MaskFilter.MakeBlur(skia.kNormal_BlurStyle, 8))
    glow_rect = skia.Rect.MakeLTRB(cx - (arrow_r_outer + arrow_r_inner) / 2,
                                     cy - (arrow_r_outer + arrow_r_inner) / 2,
                                     cx + (arrow_r_outer + arrow_r_inner) / 2,
                                     cy + (arrow_r_outer + arrow_r_inner) / 2)
    canvas.drawArc(glow_rect, arrow_start_angle - 20, 80, False, glow_arc_paint)

    # Layer 6: Lightning bolt in the gap
    gap_angle = math.radians(arrow_start_angle - 10)
    bolt_cx = cx + arrow_r_outer * 0.85 * math.cos(gap_angle)
    bolt_cy = cy + arrow_r_outer * 0.85 * math.sin(gap_angle)
    bs = s * 0.06  # bolt scale

    bolt_path = skia.Path()
    bolt_path.moveTo(bolt_cx - bs * 0.2, bolt_cy - bs * 1.2)
    bolt_path.lineTo(bolt_cx + bs * 0.5, bolt_cy - bs * 1.0)
    bolt_path.lineTo(bolt_cx + bs * 0.1, bolt_cy - bs * 0.1)
    bolt_path.lineTo(bolt_cx + bs * 0.6, bolt_cy - bs * 0.2)
    bolt_path.lineTo(bolt_cx - bs * 0.1, bolt_cy + bs * 1.2)
    bolt_path.lineTo(bolt_cx + bs * 0.05, bolt_cy + bs * 0.2)
    bolt_path.lineTo(bolt_cx - bs * 0.4, bolt_cy + bs * 0.3)
    bolt_path.close()

    # Bolt glow
    canvas.drawPath(bolt_path, make_glow_paint(hex_to_skia('#FFC400', 100), 10))

    # Bolt fill with gradient
    bolt_paint = skia.Paint(AntiAlias=True)
    bolt_paint.setShader(skia.GradientShader.MakeLinear(
        points=[(bolt_cx, bolt_cy - bs * 1.2), (bolt_cx, bolt_cy + bs * 1.2)],
        colors=[hex_to_skia('#FFD740'), hex_to_skia('#FFAB00')],
        positions=[0.0, 1.0],
    ))
    canvas.drawPath(bolt_path, bolt_paint)

    # Convert and mask
    pil_img = skia_surface_to_pil(surface)
    mask = superellipse_mask(s)
    result = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    result.paste(pil_img, mask=mask)
    return result


# ---------------------------------------------------------------------------
# Style 3: "Connection Bridge" — Nodes + Neon Bridge
# ---------------------------------------------------------------------------

def generate_style3(size=1024):
    """Connection Bridge: two luminous nodes connected by neon cyan bridge."""
    surface, canvas = create_skia_surface(size)
    s = size

    # Layer 1: Dark vertical gradient
    bg_paint = skia.Paint(AntiAlias=True)
    bg_paint.setShader(skia.GradientShader.MakeLinear(
        points=[(s / 2, 0), (s / 2, s)],
        colors=[hex_to_skia('#1A1A2E'), hex_to_skia('#16213E')],
        positions=[0.0, 1.0],
    ))
    canvas.drawRect(skia.Rect.MakeWH(s, s), bg_paint)

    cx, cy = s / 2, s / 2

    # Layer 2: Grid pattern with radial fade
    grid_spacing = s * 0.06
    grid_paint = skia.Paint(AntiAlias=True, Color=hex_to_skia('#2A3A5C', 31))
    grid_paint.setStyle(skia.Paint.kStroke_Style)
    grid_paint.setStrokeWidth(1)

    # Draw grid lines
    x = 0.0
    while x <= s:
        canvas.drawLine(x, 0, x, s, grid_paint)
        x += grid_spacing
    y = 0.0
    while y <= s:
        canvas.drawLine(0, y, s, y, grid_paint)
        y += grid_spacing

    # Radial fade mask for grid (darken edges)
    fade_paint = skia.Paint(AntiAlias=True)
    fade_paint.setBlendMode(skia.BlendMode.kDstIn)
    fade_paint.setShader(skia.GradientShader.MakeRadial(
        center=(cx, cy),
        radius=s * 0.5,
        colors=[skia.Color(255, 255, 255, 255), skia.Color(255, 255, 255, 0)],
        positions=[0.3, 1.0],
    ))
    canvas.drawRect(skia.Rect.MakeWH(s, s), fade_paint)

    # Re-draw background underneath (since DstIn affected it)
    canvas.save()
    bg2_paint = skia.Paint(AntiAlias=True)
    bg2_paint.setShader(skia.GradientShader.MakeLinear(
        points=[(s / 2, 0), (s / 2, s)],
        colors=[hex_to_skia('#1A1A2E'), hex_to_skia('#16213E')],
        positions=[0.0, 1.0],
    ))
    bg2_paint.setBlendMode(skia.BlendMode.kDstOver)
    canvas.drawRect(skia.Rect.MakeWH(s, s), bg2_paint)
    canvas.restore()

    # Layer 3: Star field
    rng = np.random.default_rng(123)
    num_stars = 50
    star_x = rng.uniform(s * 0.05, s * 0.95, num_stars)
    star_y = rng.uniform(s * 0.05, s * 0.95, num_stars)
    star_alpha = rng.integers(25, 77, num_stars)
    star_radius = rng.uniform(1.0, 2.5, num_stars)

    for i in range(num_stars):
        sp = skia.Paint(AntiAlias=True, Color=skia.Color(255, 255, 255, int(star_alpha[i])))
        canvas.drawCircle(float(star_x[i]), float(star_y[i]), float(star_radius[i]), sp)

    # Node positions
    node_left_cx = s * 0.25
    node_right_cx = s * 0.75
    node_cy = cy

    # Layer 6: Bridge beam between nodes (draw BEFORE nodes so nodes overlap)
    beam_h = s * 0.035
    beam_y_top = node_cy - beam_h / 2
    beam_y_bot = node_cy + beam_h / 2
    beam_rect = skia.Rect.MakeLTRB(node_left_cx, beam_y_top, node_right_cx, beam_y_bot)

    # Beam glow
    beam_glow = skia.Paint(AntiAlias=True, Color=hex_to_skia('#00E5FF', 38))
    beam_glow.setMaskFilter(skia.MaskFilter.MakeBlur(skia.kNormal_BlurStyle, 12))
    glow_rect = skia.Rect.MakeLTRB(node_left_cx - 5, beam_y_top - s * 0.02,
                                     node_right_cx + 5, beam_y_bot + s * 0.02)
    canvas.drawRect(glow_rect, beam_glow)

    # Beam fill with gradient
    beam_paint = skia.Paint(AntiAlias=True)
    beam_paint.setShader(skia.GradientShader.MakeLinear(
        points=[(node_left_cx, node_cy), (node_right_cx, node_cy)],
        colors=[hex_to_skia('#42A5F5', 200), hex_to_skia('#00E5FF', 230), hex_to_skia('#7E57C2', 200)],
        positions=[0.0, 0.5, 1.0],
    ))
    canvas.drawRoundRect(beam_rect, beam_h / 2, beam_h / 2, beam_paint)

    # White pulse at center
    pulse_paint = skia.Paint(AntiAlias=True)
    pulse_paint.setShader(skia.GradientShader.MakeRadial(
        center=(cx, node_cy),
        radius=s * 0.06,
        colors=[skia.Color(255, 255, 255, 100), skia.Color(255, 255, 255, 0)],
        positions=[0.0, 1.0],
    ))
    canvas.drawRect(beam_rect, pulse_paint)

    # Layer 4: Left node (blue)
    node_r = s * 0.07

    def draw_node(n_cx, n_cy, color_hex, glow_hex):
        color = hex_to_skia(color_hex)
        # Ripple rings (3 concentric, decreasing opacity)
        for ring_i in range(3):
            ring_r = node_r * (1.6 + ring_i * 0.6)
            ring_alpha = max(10, 50 - ring_i * 18)
            ring_paint = skia.Paint(AntiAlias=True, Color=hex_to_skia(color_hex, ring_alpha))
            ring_paint.setStyle(skia.Paint.kStroke_Style)
            ring_paint.setStrokeWidth(s * 0.004)
            canvas.drawCircle(n_cx, n_cy, ring_r, ring_paint)

        # Outer glow
        canvas.drawCircle(n_cx, n_cy, node_r * 1.5,
                          make_glow_paint(hex_to_skia(glow_hex, 60), 15))

        # Node body
        node_paint = skia.Paint(AntiAlias=True, Color=color)
        canvas.drawCircle(n_cx, n_cy, node_r, node_paint)

        # Bright spot (radial highlight)
        spot_paint = skia.Paint(AntiAlias=True)
        spot_paint.setShader(skia.GradientShader.MakeRadial(
            center=(n_cx - node_r * 0.25, n_cy - node_r * 0.25),
            radius=node_r * 0.7,
            colors=[skia.Color(255, 255, 255, 140), skia.Color(255, 255, 255, 0)],
            positions=[0.0, 1.0],
        ))
        canvas.drawCircle(n_cx, n_cy, node_r, spot_paint)

    draw_node(node_left_cx, node_cy, '#42A5F5', '#42A5F5')

    # Layer 5: Right node (purple)
    draw_node(node_right_cx, node_cy, '#7E57C2', '#7E57C2')

    # Layer 7: Small VPN shield at center of bridge
    shield_cx = cx
    shield_cy = node_cy
    sh_w = s * 0.06
    sh_h = s * 0.075
    shield = make_shield_path(shield_cx, shield_cy, sh_w, sh_h)

    # Shield glow
    canvas.drawPath(shield, make_glow_paint(hex_to_skia('#26C6DA', 50), 8))

    # Shield fill
    shield_fill = skia.Paint(AntiAlias=True, Color=hex_to_skia('#26C6DA', 179))
    canvas.drawPath(shield, shield_fill)

    # Shield edge highlight
    edge_paint = skia.Paint(AntiAlias=True, Color=skia.Color(255, 255, 255, 77))
    edge_paint.setStyle(skia.Paint.kStroke_Style)
    edge_paint.setStrokeWidth(s * 0.003)
    canvas.drawPath(shield, edge_paint)

    # Lock keyhole in shield
    kh_r = sh_w * 0.18
    kh_paint = skia.Paint(AntiAlias=True, Color=skia.Color(255, 255, 255, 200))
    canvas.drawCircle(shield_cx, shield_cy - sh_h * 0.08, kh_r, kh_paint)
    lock_rect_path = skia.Path()
    lock_rect_path.addRect(skia.Rect.MakeLTRB(
        shield_cx - kh_r * 0.6, shield_cy - sh_h * 0.02,
        shield_cx + kh_r * 0.6, shield_cy + sh_h * 0.15
    ))
    canvas.drawPath(lock_rect_path, kh_paint)

    # Convert and mask
    pil_img = skia_surface_to_pil(surface)
    mask = superellipse_mask(s)
    result = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    result.paste(pil_img, mask=mask)
    return result


# ---------------------------------------------------------------------------
# Asset generation (unchanged logic)
# ---------------------------------------------------------------------------

def generate_icon_pngs(master):
    """Resize master icon to all required sizes and save."""
    os.makedirs(APPICONSET, exist_ok=True)
    for _, _, pixel_size, filename in ICON_SIZES:
        resized = master.resize((pixel_size, pixel_size), Image.Resampling.LANCZOS)
        path = os.path.join(APPICONSET, filename)
        resized.save(path, "PNG")
        print(f"  Created {filename} ({pixel_size}x{pixel_size})")


def generate_icns(master):
    """Create .icns file using iconutil."""
    with tempfile.TemporaryDirectory() as tmpdir:
        iconset_dir = os.path.join(tmpdir, "AppIcon.iconset")
        os.makedirs(iconset_dir)

        # iconutil expects these exact filenames
        iconutil_sizes = [
            (16, "icon_16x16.png"),
            (32, "icon_16x16@2x.png"),
            (32, "icon_32x32.png"),
            (64, "icon_32x32@2x.png"),
            (128, "icon_128x128.png"),
            (256, "icon_128x128@2x.png"),
            (256, "icon_256x256.png"),
            (512, "icon_256x256@2x.png"),
            (512, "icon_512x512.png"),
            (1024, "icon_512x512@2x.png"),
        ]

        for pixel_size, filename in iconutil_sizes:
            resized = master.resize((pixel_size, pixel_size), Image.Resampling.LANCZOS)
            resized.save(os.path.join(iconset_dir, filename), "PNG")

        icns_path = os.path.join(RESOURCES, "AppIcon.icns")
        result = subprocess.run(
            ["iconutil", "--convert", "icns", "--output", icns_path, iconset_dir],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            print(f"  WARNING: iconutil failed: {result.stderr}")
            return False
        print(f"  Created AppIcon.icns")
        return True


def generate_dmg_background():
    """Generate a 600x400 DMG background image."""
    width, height = 600, 400

    surface, canvas = create_skia_surface(width)
    # Recreate as non-square
    surface = skia.Surface(width, height)
    canvas = surface.getCanvas()
    canvas.clear(skia.Color(0, 0, 0, 0))

    # Light gradient background
    bg_paint = skia.Paint(AntiAlias=True)
    bg_paint.setShader(skia.GradientShader.MakeLinear(
        points=[(width / 2, 0), (width / 2, height)],
        colors=[skia.Color(240, 245, 250, 255), skia.Color(210, 225, 245, 255)],
        positions=[0.0, 1.0],
    ))
    canvas.drawRect(skia.Rect.MakeWH(width, height), bg_paint)

    # Title
    title_font = skia.Font(skia.Typeface('Helvetica'), 36)
    title_paint = skia.Paint(AntiAlias=True, Color=skia.Color(26, 115, 232, 255))
    title = "VPN Fix"
    tw = title_font.measureText(title)
    canvas.drawString(title, (width - tw) / 2, 65, title_font, title_paint)

    # Subtitle
    sub_font = skia.Font(skia.Typeface('Helvetica'), 16)
    sub_paint = skia.Paint(AntiAlias=True, Color=skia.Color(100, 100, 100, 255))
    subtitle = "Drag to Applications to install"
    sw = sub_font.measureText(subtitle)
    canvas.drawString(subtitle, (width - sw) / 2, 100, sub_font, sub_paint)

    # Arrow
    arrow_y = 200
    arrow_x1 = 220
    arrow_x2 = 380
    arrow_paint = skia.Paint(AntiAlias=True, Color=skia.Color(26, 115, 232, 255))
    arrow_paint.setStyle(skia.Paint.kStroke_Style)
    arrow_paint.setStrokeWidth(3)
    canvas.drawLine(arrow_x1, arrow_y, arrow_x2, arrow_y, arrow_paint)

    # Arrowhead
    ah_path = skia.Path()
    ah_path.moveTo(arrow_x2 - 10, arrow_y - 10)
    ah_path.lineTo(arrow_x2 + 5, arrow_y)
    ah_path.lineTo(arrow_x2 - 10, arrow_y + 10)
    ah_path.close()
    ah_paint = skia.Paint(AntiAlias=True, Color=skia.Color(26, 115, 232, 255))
    canvas.drawPath(ah_path, ah_paint)

    # Convert and save
    pil_img = skia_surface_to_pil(surface)
    # Crop to exact size (surface might differ)
    pil_img = pil_img.crop((0, 0, width, height))
    rgb_img = Image.new("RGB", (width, height), (255, 255, 255))
    rgb_img.paste(pil_img, mask=pil_img.split()[3])

    os.makedirs(DMG_ASSETS, exist_ok=True)
    path = os.path.join(DMG_ASSETS, "background.png")
    rgb_img.save(path, "PNG")
    print(f"  Created dmg-assets/background.png (600x400)")


# ---------------------------------------------------------------------------
# Main / CLI
# ---------------------------------------------------------------------------

STYLE_GENERATORS = {
    1: generate_style1,
    2: generate_style2,
    3: generate_style3,
}


def main():
    parser = argparse.ArgumentParser(description="Generate VPN Fix app icon assets")
    parser.add_argument('--style', type=int, choices=[1, 2, 3], default=1,
                        help='Icon style: 1=Shield Guardian, 2=Power Cycle, 3=Connection Bridge')
    parser.add_argument('--preview', action='store_true',
                        help='Generate only a 512x512 preview image in tests/')
    args = parser.parse_args()

    generator = STYLE_GENERATORS[args.style]

    if args.preview:
        print(f"Generating preview for style {args.style}...")
        master = generator(1024)
        preview = master.resize((512, 512), Image.Resampling.LANCZOS)
        preview_path = os.path.join(TESTS_DIR, f"preview_style{args.style}.png")
        preview.save(preview_path, "PNG")
        print(f"  Saved {preview_path}")
        return

    print(f"Generating VPN Fix assets (style {args.style})...")

    print(f"\n[1/4] Drawing master icon (1024x1024) — style {args.style}...")
    master = generator(1024)

    print("\n[2/4] Generating icon PNGs...")
    generate_icon_pngs(master)

    print("\n[3/4] Generating AppIcon.icns...")
    generate_icns(master)

    print("\n[4/4] Generating DMG background...")
    generate_dmg_background()

    print("\nDone! All assets generated.")


if __name__ == "__main__":
    main()
