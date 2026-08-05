# Image
#
# Visual test of every Image variation and modifier in three panels:
#   1. FORMATS + MODIFIERS — PNG / JPG / BMP / SVG decoders, tint, opacity
#   2. VECTOR SCALING      — bee.svg at increasing sizes plus modifiers on a vector source
#   3. ROTATION            — slow live rotation around three pivot points (default / center / external)

require 'ruby2d'

W = 1500
H = 540

set title: 'Ruby 2D — Image', width: W, height: H
set close_on_esc: true

# --- Palette ----------------------------------------------------------------

BG      = [0.05, 0.06, 0.07, 1].freeze
LINE    = [0.20, 0.22, 0.24, 1].freeze
LINE_HI = [0.35, 0.38, 0.42, 1].freeze
DIM     = [0.40, 0.42, 0.44, 1].freeze
TEXT    = [0.75, 0.78, 0.80, 1].freeze
HEAD    = [0.92, 0.94, 0.96, 1].freeze
ACCENT  = [0.45, 0.95, 0.70, 1].freeze

set background: BG

# --- Helpers ----------------------------------------------------------------

def hairline(x1, y1, x2, y2, color: LINE)
  Line.new(x1: x1, y1: y1, x2: x2, y2: y2, stroke_width: 1, color: color)
end

def frame(x, y, w, h, color: LINE)
  hairline(x,     y,     x + w, y,     color: color)
  hairline(x + w, y,     x + w, y + h, color: color)
  hairline(x,     y + h, x + w, y + h, color: color)
  hairline(x,     y,     x,     y + h, color: color)
end

def hint(x, y, text)
  Text.new(text, x: x, y: y, size: 10, color: DIM)
end

def section(x, y, text)
  Text.new(text, x: x, y: y, size: 11, color: TEXT)
end

def panel_label(x, y, text)
  Text.new(text, x: x, y: y, size: 10, color: DIM)
end

# --- Header -----------------------------------------------------------------

Text.new('IMAGE TEST', x: 16, y: 12, size: 16, color: HEAD)
hairline(16, 38, W - 16, 38, color: LINE)

# --- Layout -----------------------------------------------------------------

PANEL_W = 480
PANEL_H = 440
COL_X   = [15, 510, 1005].freeze
ROW_Y   = 60

IMG_DIR = "#{Ruby2D.test_images}".freeze
BEE     = "#{IMG_DIR}/bee.svg".freeze

# --- Panel 1: FORMATS + MODIFIERS ------------------------------------------

p1x, p1y = COL_X[0], ROW_Y
frame(p1x, p1y, PANEL_W, PANEL_H)
panel_label(p1x + 10, p1y + 8, '[ FORMATS + MODIFIERS ]')

# Formats row — proves png, jpg, bmp, and svg decoders all work.
section(p1x + 15, p1y + 32, 'formats')
[
  ['PNG', 'image.png'],
  ['JPG', 'image.jpg'],
  ['BMP', 'image.bmp'],
  ['SVG', 'bee.svg']
].each_with_index do |(name, file), i|
  x = p1x + 20 + i * 110
  Image.new("#{IMG_DIR}/#{file}", x: x, y: p1y + 50, width: 60, height: 60)
  hint(x, p1y + 115, name)
end

# Tint row — multiplies texture colors. Three pure channels then a mix.
section(p1x + 15, p1y + 162, 'tint')
[
  ['red',     'pure R'],
  ['lime',    'pure G'],
  ['blue',    'pure B'],
  ['#f4a261', 'mixed']
].each_with_index do |(color, name), i|
  x = p1x + 20 + i * 110
  Image.new("#{IMG_DIR}/colors.png", x: x, y: p1y + 180, width: 50, height: 50, tint: color)
  hint(x, p1y + 235, name)
end

# Opacity row.
section(p1x + 15, p1y + 282, 'opacity')
[0.25, 0.5, 0.75, 1.0].each_with_index do |a, i|
  x = p1x + 20 + i * 110
  Image.new("#{IMG_DIR}/colors.png", x: x, y: p1y + 300, width: 50, height: 50, opacity: a)
  hint(x, p1y + 355, a.to_s)
end

# --- Panel 2: VECTOR SCALING ------------------------------------------------

p2x, p2y = COL_X[1], ROW_Y
frame(p2x, p2y, PANEL_W, PANEL_H)
panel_label(p2x + 10, p2y + 8, '[ VECTOR SCALING ]')

# Scale row — same SVG at increasing sizes, baselines aligned so growth is visible.
section(p2x + 15, p2y + 32, 'scale — bee.svg at 24 / 48 / 96 / 160')

SCALE_BASELINE = p2y + 50 + 160  # bottom edge of the largest thumb
scale_xs = [p2x + 20, p2x + 74, p2x + 152, p2x + 278]
[24, 48, 96, 160].each_with_index do |size, i|
  Image.new(BEE, x: scale_xs[i], y: SCALE_BASELINE - size, width: size, height: size)
  hint(scale_xs[i], SCALE_BASELINE + 5, "#{size}px")
end

# Modifiers on a vector source — parity with raster modifiers above.
section(p2x + 15, p2y + 252, 'modifiers on vector — plain / tint / opacity / rotation')

mod_y = p2y + 270
[
  [{},                                  'plain'],
  [{ tint: 'aqua' },                    'tint'],
  [{ opacity: 0.4 },                    'opacity'],
  [{ rotate: 30 },                      'rotate']
].each_with_index do |(opts, name), i|
  x = p2x + 30 + i * 108
  Image.new(BEE, x: x, y: mod_y, width: 60, height: 60, **opts)
  hint(x, mod_y + 70, name)
end

# --- Panel 3: ROTATION ------------------------------------------------------

p3x, p3y = COL_X[2], ROW_Y
frame(p3x, p3y, PANEL_W, PANEL_H)
panel_label(p3x + 10, p3y + 8, '[ ROTATION ]')

section(p3x + 15, p3y + 32, 'slow rotation · pivot point varies (accent dot marks rx, ry)')

# Three cells across the panel — each shows the same image rotating around a
# different pivot. Image and pivot dot share the same logical center per cell.
ROT_SIZE   = 50
ROT_CELL_W = PANEL_W / 3
ROT_CY     = p3y + 200      # vertical center of each rotation cell

# Per-cell horizontal centers
rot_cx0 = p3x + ROT_CELL_W / 2
rot_cx1 = p3x + ROT_CELL_W + ROT_CELL_W / 2
rot_cx2 = p3x + ROT_CELL_W * 2 + ROT_CELL_W / 2

# Cell 0 — default pivot. rx/ry are unset, so they default to the image's
# center — the bee spins in place.
img_default = Image.new(BEE,
                        x: rot_cx0 - ROT_SIZE / 2, y: ROT_CY - ROT_SIZE / 2,
                        width: ROT_SIZE, height: ROT_SIZE)
Circle.new(x: rot_cx0, y: ROT_CY, radius: 3, sectors: 16, color: ACCENT, z: 10)

# Cell 1 — top-left corner pivot. rx/ry pinned to the image's (x, y), so
# the bee swings in a wide arc around its corner.
img_corner = Image.new(BEE,
                       x: rot_cx1, y: ROT_CY,
                       width: ROT_SIZE, height: ROT_SIZE,
                       rx: rot_cx1, ry: ROT_CY)
Circle.new(x: rot_cx1, y: ROT_CY, radius: 3, sectors: 16, color: ACCENT, z: 10)

# Cell 2 — external pivot. rx/ry sit outside the image, so the image orbits
# the pivot while rotating with it.
ORBIT_DX = 20
ORBIT_DY = -20
img_orbit = Image.new(BEE,
                      x: rot_cx2 + ORBIT_DX, y: ROT_CY + ORBIT_DY,
                      width: ROT_SIZE, height: ROT_SIZE,
                      rx: rot_cx2, ry: ROT_CY)
Circle.new(x: rot_cx2, y: ROT_CY, radius: 3, sectors: 16, color: ACCENT, z: 10)

# Captions
ROT_LABEL_Y = p3y + 320
hint(rot_cx0 - 44, ROT_LABEL_Y, 'default (center)')
hint(rot_cx1 - 50, ROT_LABEL_Y, 'top-left (corner)')
hint(rot_cx2 - 48, ROT_LABEL_Y, 'external (orbit)')

# --- Update -----------------------------------------------------------------

ROT_DEG_PER_SEC = 60  # ~6s per revolution; same wall-clock speed at any refresh rate

angle = 0.0

update do |dt|
  angle += ROT_DEG_PER_SEC * dt
  img_default.rotate = angle
  img_corner.rotate  = angle
  img_orbit.rotate   = angle
end

show
