# Window
#
# Visual test of window-level behavior — coverage that isn't already in
# test/viewport.rb or test/pixel_scale.rb. Two panels plus a controls
# footer:
#   1. WINDOW STATE     — live readout (size, viewport, display, fps, frames)
#   2. RENDER METHODS   — .new (top) vs .render (bottom) — should match exactly

require 'ruby2d'

W = 1245
H = 580

set title: 'Ruby 2D — Window', width: W, height: H
set close_on_esc: true
set resizable: true

# --- Palette ----------------------------------------------------------------

BG      = [0.05, 0.06, 0.07, 1].freeze
LINE    = [0.20, 0.22, 0.24, 1].freeze
LINE_HI = [0.35, 0.38, 0.42, 1].freeze
DIM     = [0.40, 0.42, 0.44, 1].freeze
TEXT    = [0.75, 0.78, 0.80, 1].freeze
HEAD    = [0.92, 0.94, 0.96, 1].freeze
ACCENT  = [0.45, 0.95, 0.70, 1].freeze

# Single demo hue for the "Hi!" text in panel 2.
AMBER   = [0.95, 0.85, 0.30, 1].freeze

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
  Text.new(text, x: x, y: y, size: 11, color: TEXT)
end

def hint(x, y, text)
  Text.new(text, x: x, y: y, size: 10, color: DIM)
end

# --- Header -----------------------------------------------------------------

Text.new('WINDOW TEST', x: 16, y: 12, size: 16, color: HEAD)
hairline(16, 38, W - 16, 38, color: LINE)

# --- Layout -----------------------------------------------------------------

PANEL_W  = 600
PANEL_H  = 410
COL_X    = [15, 630].freeze
PANEL_Y  = 60
FOOTER_Y = 485
FOOTER_H = 80
FOOTER_W = W - 30

# --- Panel 1: WINDOW STATE -------------------------------------------------

p1x = COL_X[0]
frame(p1x, PANEL_Y, PANEL_W, PANEL_H)
panel_label(p1x + 10, PANEL_Y + 8, '[ WINDOW STATE ]')

state_lines = [
  ['TITLE',            -> { get(:title) }],
  ['WIDTH X HEIGHT',   -> { "#{get(:width)} x #{get(:height)}" }],
  ['VIEWPORT',         -> { "#{get(:viewport_width)} x #{get(:viewport_height)}" }],
  ['DISPLAY LOGICAL',  -> { "#{Window.display_width} x #{Window.display_height}" }],
  ['DISPLAY PHYSICAL', -> { "#{Window.display_pixel_width} x #{Window.display_pixel_height}" }],
  ['HIGHDPI',          -> { get(:highdpi).to_s }],
  ['PIXEL SCALE',      -> { get(:pixel_scale).to_s }],
  ['RENDER MODE',      -> { get(:render_mode).to_s }],
  ['VIEWPORT MODE',    -> { get(:viewport_mode).to_s }],
  ['FPS',              -> { Window.fps.round(1).to_s }],
  ['FRAMES',           -> { Window.frames.to_s }],
  ['MOUSE',            -> { "#{Window.mouse_x}, #{Window.mouse_y}" }]
]

# 2 columns × 6 rows. Each pair: small uppercase label (size 10, DIM) above
# its value (size 16, TEXT), 46px between pair tops — matching the DEVICE
# panel in test/gamepad.rb.
LCOL_X = p1x + 16
RCOL_X = p1x + PANEL_W / 2 + 16

state_texts = state_lines.map.with_index do |(name, _), i|
  col_x = i < 6 ? LCOL_X : RCOL_X
  row   = i % 6
  y     = PANEL_Y + 36 + row * 46
  Text.new(name, x: col_x, y: y,      size: 10, color: DIM)
  Text.new('—',  x: col_x, y: y + 16, size: 16, color: TEXT)
end

# --- Panel 2: RENDER METHODS -----------------------------------------------

p2x = COL_X[1]
frame(p2x, PANEL_Y, PANEL_W, PANEL_H)
panel_label(p2x + 10, PANEL_Y + 8, '[ RENDER METHODS ]')

section(p2x + 25, PANEL_Y + 32, '.new  (top row)')
section(p2x + 25, PANEL_Y + 200, '.render  (bottom row, drawn each frame in render block)')
hint(p2x + 25, PANEL_Y + PANEL_H - 24, 'Both rows should match exactly.')

grad4 = [
  [1.0, 0.2, 0.2, 1.0],
  [0.2, 1.0, 0.2, 1.0],
  [0.2, 0.2, 1.0, 1.0],
  [1.0, 1.0, 0.2, 1.0]
]
grad3 = grad4[0..2]
magenta = [0.9, 0.1, 0.7, 1.0]

# Top row: object-based.
top_y = PANEL_Y + 60
Square.new(x: p2x + 30, y: top_y, size: 70, color: grad4)
Rectangle.new(x: p2x + 120, y: top_y, width: 90, height: 70, color: grad4, rotate: 20)
Triangle.new(x1: p2x + 270, y1: top_y, x2: p2x + 340, y2: top_y + 70,
             x3: p2x + 230, y3: top_y + 70, color: grad3)
Circle.new(x: p2x + 390, y: top_y + 35, radius: 35, color: magenta)
Quad.new(x1: p2x + 460, y1: top_y, x2: p2x + 560, y2: top_y + 5,
         x3: p2x + 555, y3: top_y + 70, x4: p2x + 465, y4: top_y + 65, color: grad4)

Image.new("#{Ruby2D.test_images}/image.png", x: p2x + 30, y: PANEL_Y + 140, width: 60, height: 60)
Text.new('Hi!', x: p2x + 110, y: PANEL_Y + 140, size: 28, color: AMBER)

# Bottom row: render-based (in a render block).
img_render = Image.new("#{Ruby2D.test_images}/image.png", add: false)
txt_render = Text.new('Hi!', size: 28, add: false)

bot_y = PANEL_Y + 228
render do
  Square.render(x: p2x + 30, y: bot_y, size: 70, color: grad4)
  Rectangle.render(x: p2x + 120, y: bot_y, width: 90, height: 70, color: grad4, rotate: 20)
  Triangle.render(x1: p2x + 270, y1: bot_y, x2: p2x + 340, y2: bot_y + 70,
                  x3: p2x + 230, y3: bot_y + 70, color: grad3)
  Circle.render(x: p2x + 390, y: bot_y + 35, radius: 35, color: magenta)
  Quad.render(x1: p2x + 460, y1: bot_y, x2: p2x + 560, y2: bot_y + 5,
              x3: p2x + 555, y3: bot_y + 70, x4: p2x + 465, y4: bot_y + 65, color: grad4)

  img_render.render(x: p2x + 30, y: bot_y + 80, width: 60, height: 60)
  txt_render.render(x: p2x + 110, y: bot_y + 80, color: AMBER)
end

# --- Footer strip: CONTROLS ------------------------------------------------

frame(15, FOOTER_Y, FOOTER_W, FOOTER_H)
panel_label(25, FOOTER_Y + 8, '[ CONTROLS ]')

controls = [
  ['F',     'toggle show_fps'],
  ['D',     'toggle diagnostics'],
  ['M',     'toggle render_mode (continuous / on_demand)'],
  ['Space', 'request_render (effective with on_demand)'],
  ['ESC',   'quit']
]

# Two rows of three columns spanning the footer width.
CONTROL_COL_W = FOOTER_W / 3
controls.each_with_index do |(key, desc), i|
  col = i % 3
  row = i / 3
  x = 30 + col * CONTROL_COL_W
  y = FOOTER_Y + 28 + row * 24
  Text.new(key,  x: x,      y: y, size: 12, color: HEAD)
  Text.new(desc, x: x + 80, y: y, size: 12, color: TEXT)
end

# --- Interaction -----------------------------------------------------------

on :key_down do |event|
  case event.key
  when :f
    set show_fps: !get(:show_fps)
  when :d
    set diagnostics: !get(:diagnostics)
  when :m
    new_mode = get(:render_mode) == :continuous ? :on_demand : :continuous
    set render_mode: new_mode
  when :space
    request_render
  end
end

# --- Update loop: refresh state readout ------------------------------------

update do
  state_lines.each_with_index do |(_, value_proc), i|
    state_texts[i].content = value_proc.call.to_s
  end
end

show
