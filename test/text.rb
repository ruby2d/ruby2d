# Text
#
# Comprehensive visual test for Text (TTF), BitmapText, and Fonts. Four
# panels in a 2×2 grid:
#   1. TEXT — SIZES       — "Hello, Ruby 2D!" stacked at 11–64pt
#   2. FONTS              — same string rendered in available system fonts
#   3. TEXT — MODIFIERS   — colors, opacity, rotation, dynamic content
#   4. BITMAP TEXT        — scales, colors, opacity, ASCII coverage, dynamic

require 'ruby2d'

W = 1500
H = 890

set title: 'Ruby 2D — Text', width: W, height: H
set close_on_esc: true

# --- Palette ----------------------------------------------------------------

BG      = [0.05, 0.06, 0.07, 1].freeze
LINE    = [0.20, 0.22, 0.24, 1].freeze
LINE_HI = [0.35, 0.38, 0.42, 1].freeze
DIM     = [0.40, 0.42, 0.44, 1].freeze
TEXT    = [0.75, 0.78, 0.80, 1].freeze
HEAD    = [0.92, 0.94, 0.96, 1].freeze
ACCENT  = [0.45, 0.95, 0.70, 1].freeze

# Demo hues for the color rows.
WARM    = [0.95, 0.55, 0.40, 1].freeze
TEAL    = [0.30, 0.80, 0.85, 1].freeze
AMBER   = [0.95, 0.85, 0.30, 1].freeze
VIOLET  = [0.70, 0.45, 0.95, 1].freeze
AZURE   = [0.40, 0.65, 0.95, 1].freeze

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

def panel_label(x, y, text)
  Text.new(text, x: x, y: y, size: 10, color: DIM)
end

def section(x, y, text)
  Text.new(text, x: x + 10, y: y, size: 10, color: DIM)
end

# --- Header -----------------------------------------------------------------

Text.new('TEXT TEST', x: 16, y: 12, size: 16, color: HEAD)
hairline(16, 38, W - 16, 38, color: LINE)

# --- Layout -----------------------------------------------------------------

PANEL_W = 727
PANEL_H = 400
COL_X   = [15, 757].freeze
ROW_Y   = [60, 475].freeze

SAMPLE = 'The quick brown fox jumps over the lazy dog'

# --- Panel 1: TEXT — SIZES -------------------------------------------------

p1x, p1y = COL_X[0], ROW_Y[0]
frame(p1x, p1y, PANEL_W, PANEL_H)
panel_label(p1x + 10, p1y + 8, '[ TEXT — SIZES ]')

sizes = [64, 48, 36, 24, 18, 14, 11]
y = p1y + 28
sizes.each do |sz|
  Text.new("Hello, Ruby 2D!  (#{sz}pt)",
           x: p1x + 20, y: y, size: sz, color: HEAD)
  y += sz + 4
end

# --- Panel 2: FONTS --------------------------------------------------------

p2x, p2y = COL_X[1], ROW_Y[0]
frame(p2x, p2y, PANEL_W, PANEL_H)
panel_label(p2x + 10, p2y + 8, '[ FONTS ]')

# Default Outfit + bundled roboto_mono + up to 6 available system fonts.
# Filter out missing files.
font_entries = [
  ['default (Outfit)',      Font.default],
  ['roboto_mono (bundled)', "#{Ruby2D.assets}/resources/fonts/roboto_mono/roboto_mono.ttf"]
]
candidates = Font.all.first(20)
candidates.each do |name|
  break if font_entries.length >= 8

  path = Font.path(name)
  next unless path && File.exist?(path)

  font_entries << [name, path]
end

y = p2y + 28
font_entries.each do |name, path|
  Text.new(name, x: p2x + 20, y: y, size: 11, color: DIM)
  y += 14
  Text.new(SAMPLE, x: p2x + 20, y: y, size: 18, font: path, color: HEAD)
  y += 28
end

# --- Panel 3: TEXT — MODIFIERS ---------------------------------------------

p3x, p3y = COL_X[0], ROW_Y[1]
frame(p3x, p3y, PANEL_W, PANEL_H)
panel_label(p3x + 10, p3y + 8, '[ TEXT — MODIFIERS ]')

# COLOR row
section(p3x, p3y + 26, 'color')
[WARM, TEAL, AMBER, VIOLET, AZURE].each_with_index do |c, i|
  Text.new('Hello', x: p3x + 20 + i * 130, y: p3y + 44, size: 28, color: c)
end

# OPACITY row
section(p3x, p3y + 92, 'opacity (0.25 / 0.5 / 0.75 / 1.0)')
[0.25, 0.5, 0.75, 1.0].each_with_index do |a, i|
  Text.new('Hello', x: p3x + 20 + i * 160, y: p3y + 110, size: 28,
           color: TEAL, opacity: a)
end

# ROTATION row — pivots at the rendered text's origin.
section(p3x, p3y + 162, 'rotation (0deg / 45deg / 90deg / 135deg)')
[0, 45, 90, 135].each_with_index do |angle, i|
  Text.new('Hello', x: p3x + 80 + i * 160, y: p3y + 210, size: 28,
           color: AMBER, rotate: angle)
end

# DYNAMIC counter — content + size update every frame.
section(p3x, p3y + 296, 'dynamic content (size cycles, content updates)')
dyn_text = Text.new('frames: 0', x: p3x + 20, y: p3y + 316,
                    size: 28, color: ACCENT)

# --- Panel 4: BITMAP TEXT --------------------------------------------------

p4x, p4y = COL_X[1], ROW_Y[1]
frame(p4x, p4y, PANEL_W, PANEL_H)
panel_label(p4x + 10, p4y + 8, '[ BITMAP TEXT ]')

# SCALES row
section(p4x, p4y + 26, 'scale')
[1, 2, 3, 5].each_with_index do |s, i|
  x = p4x + 20 + i * 175
  Text.new("#{s}x", x: x, y: p4y + 44, size: 10, color: DIM)
  BitmapText.new('Aa', x: x, y: p4y + 58, scale: s, color: HEAD)
end

# COLORS row
section(p4x, p4y + 116, 'color')
[WARM, TEAL, AMBER, VIOLET, AZURE].each_with_index do |c, i|
  BitmapText.new('Hi!', x: p4x + 20 + i * 130, y: p4y + 134, scale: 3, color: c)
end

# OPACITY row
section(p4x, p4y + 178, 'opacity (0.25 / 0.5 / 0.75 / 1.0)')
[0.25, 0.5, 0.75, 1.0].each_with_index do |a, i|
  BitmapText.new('Hi!', x: p4x + 20 + i * 160, y: p4y + 196, scale: 3,
                 color: TEAL, opacity: a)
end

# ASCII coverage — verifies the bitmap font has all printable glyphs.
section(p4x, p4y + 240, 'printable ASCII')
ascii_lines = [
  ' !"#$%&\'()*+,-./0123456789:;<=>?@',
  'ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`',
  'abcdefghijklmnopqrstuvwxyz{|}~'
]
ascii_lines.each_with_index do |line, i|
  BitmapText.new(line, x: p4x + 20, y: p4y + 258 + i * 22, scale: 2, color: TEXT)
end

# DYNAMIC counter
dyn_bt = BitmapText.new('frames: 0', x: p4x + 20, y: p4y + PANEL_H - 28,
                        scale: 2, color: ACCENT)

# --- Update loop -----------------------------------------------------------

update do
  frame = Window.frames
  dyn_text.content = "frames: #{frame}"
  dyn_text.size = 22 + ((Math.sin(frame * 0.05) + 1) * 14).to_i  # 22..50
  dyn_bt.content = "frames: #{frame}"
  dyn_bt.rotate = Math.sin(frame * 0.05) * 15  # gently rock to show BitmapText rotation
end

show
