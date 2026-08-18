# Shapes
#
# Every shape × three variants of the universal modifiers, laid out in the
# technical style of test/mouse.rb and friends. Six panels in a 3×2 grid:
#   1. FILL+STROKE    — fill / stroke / fill+stroke             (blue)
#   2. OPACITY        — 1.0 / 0.5 / 0.25                       (warm)
#   3. ROTATION       — 0° / 45° / 90°                         (violet)
#   4. Z-INDEX        — left-click brings front, right-click sends back
#   5. CONTAINS?      — hover highlights the shape under the cursor (amber)
#   6. GRADIENTS+DASH — per-vertex pure-RGB arrays + dashed-line variants
#
# V toggles visibility on every matrix shape. ACCENT (mint) is reserved for
# UI signal — hover highlight in CONTAINS?, click-to-front feedback — while
# each shape panel uses one regular hue. Z-INDEX and GRADIENTS get small
# local palettes since distinguishability is the feature being tested.

require 'ruby2d'

W = 1500
H = 550

set title: 'Ruby 2D — Shapes', width: W, height: H
set close_on_esc: true

# --- Palette ----------------------------------------------------------------

BG      = [0.05, 0.06, 0.07, 1].freeze
LINE    = [0.20, 0.22, 0.24, 1].freeze
LINE_HI = [0.35, 0.38, 0.42, 1].freeze
DIM     = [0.40, 0.42, 0.44, 1].freeze
TEXT    = [0.75, 0.78, 0.80, 1].freeze
HEAD    = [0.92, 0.94, 0.96, 1].freeze
ACCENT  = [0.45, 0.95, 0.70, 1].freeze

# Per-panel demo hues. ACCENT is reserved for UI signal (hover highlight,
# click feedback) so each shape panel takes a distinct regular color.
BLUE    = [0.40, 0.70, 1.00, 1].freeze   # FILL+STROKE
WARM    = [0.95, 0.55, 0.40, 1].freeze   # OPACITY
VIOLET  = [0.70, 0.45, 0.95, 1].freeze   # ROTATION
AMBER   = [0.95, 0.85, 0.30, 1].freeze   # CONTAINS? default

# Z-INDEX palette — soft RGB so the three shapes read as distinct colors
# without competing visually with the other panels' demo hues.
SOFT_RED   = [0.95, 0.50, 0.50, 1].freeze
SOFT_GREEN = [0.50, 0.85, 0.55, 1].freeze
SOFT_BLUE  = [0.50, 0.65, 0.95, 1].freeze

# GRADIENTS palette — RGB primaries first so every shape starts red→green
# →blue at its first three vertices, then yellow and magenta extend the
# palette for shapes that need 4 or 5 stops. Each shape type uses the same
# starting colors, just truncated/extended to fit its vertex count.
PURE = [
  [1.0, 0.0, 0.0, 1],   # red
  [0.0, 1.0, 0.0, 1],   # green
  [0.0, 0.0, 1.0, 1],   # blue
  [1.0, 1.0, 0.0, 1],   # yellow
  [1.0, 0.0, 1.0, 1]    # magenta
].freeze

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

def label(x, y, text, size: 10, color: DIM)
  Text.new(text, x: x, y: y, size: size, color: color)
end

# --- Shape rendering -------------------------------------------------------

SHAPES      = %i[triangle square rectangle quad line circle ellipse polygon polyline].freeze
SHAPE_NAMES = %w[Tri Sq Rect Quad Line Circ Elps Poly Pline].freeze

# Renders one of each SHAPE variant inside an [x..x+s, y..y+s] cell.
# Shapes that don't take fill/stroke_color (Line, Polyline) silently drop
# those kwargs.
def render_shape_at(type, x, y, s, **opts)
  case type
  when :triangle
    Triangle.new(x1: x + s / 2, y1: y, x2: x + s, y2: y + s,
                 x3: x, y3: y + s, **opts)
  when :square
    Square.new(x: x, y: y, size: s, **opts)
  when :rectangle
    Rectangle.new(x: x, y: y + s / 4, width: s, height: s / 2, **opts)
  when :quad
    Quad.new(x1: x + 4, y1: y, x2: x + s - 2, y2: y + 4,
             x3: x + s, y3: y + s - 2, x4: x + 2, y4: y + s, **opts)
  when :line
    line_opts = opts.reject { |k, _| %i[fill stroke_color].include?(k) }
    line_opts[:stroke_width] ||= 2
    Line.new(x1: x, y1: y + s, x2: x + s, y2: y, **line_opts)
  when :circle
    Circle.new(x: x + s / 2, y: y + s / 2, radius: s / 2, sectors: 24, **opts)
  when :ellipse
    Ellipse.new(x: x + s / 2, y: y + s / 2,
                xradius: s / 2, yradius: s / 3, **opts)
  when :polygon
    Polygon.new(points: [
      [x + s / 2,     y],         [x + s,         y + s * 2 / 5],
      [x + s * 4 / 5, y + s],     [x + s / 5,     y + s],
      [x,             y + s * 2 / 5]
    ], **opts)
  when :polyline
    line_opts = opts.reject { |k, _| %i[fill stroke_color].include?(k) }
    line_opts[:stroke_width] ||= 2
    Polyline.new(points: [
      [x,             y + s / 2], [x + s / 4,     y],
      [x + s / 2,     y + s / 2], [x + s * 3 / 4, y],
      [x + s,         y + s / 2]
    ], **line_opts)
  end
end

# --- Header -----------------------------------------------------------------

Text.new('SHAPES TEST', x: 16, y: 12, size: 16, color: HEAD)
hairline(16, 38, W - 16, 38, color: LINE)

# --- Panel layout (3×2 grid) -----------------------------------------------

PAD     = 16
GAP     = 8
TOP_Y   = 50
PANEL_W = (W - PAD * 2 - GAP * 2) / 3
# Asymmetric heights: matrix panels (top) only need room for 3 rows of
# cells, so keep them short. Z-INDEX / CONTAINS? / GRADIENTS panels
# (bottom) hold larger content and need the breathing room.
PANEL_H     = 210
BOT_PANEL_H = 250

X1 = PAD
X2 = PAD + PANEL_W + GAP
X3 = PAD + (PANEL_W + GAP) * 2
Y1 = TOP_Y
Y2 = TOP_Y + PANEL_H + GAP

# Matrix cell sizing inside the matrix panels.
CELL     = 40
COL_GAP  = 8
ROW_GAP  = 8
ROW_LBL_W = 40

# --- Matrix panel helper ---------------------------------------------------

def matrix_panel(panel_x, panel_y, label_text, rows)
  frame(panel_x, panel_y, PANEL_W, PANEL_H)
  label(panel_x + 10, panel_y + 8, "[ #{label_text} ]")

  cell_x0 = panel_x + 10 + ROW_LBL_W

  SHAPE_NAMES.each_with_index do |name, i|
    Text.new(name, x: cell_x0 + i * (CELL + COL_GAP),
             y: panel_y + 30, size: 9, color: DIM)
  end

  shapes = []
  rows.each_with_index do |(row_label_text, row_opts), i|
    row_y = panel_y + 50 + i * (CELL + ROW_GAP)
    label(panel_x + 12, row_y + 8, row_label_text, size: 9)
    SHAPES.each_with_index do |type, j|
      cx = cell_x0 + j * (CELL + COL_GAP)
      shapes << render_shape_at(type, cx, row_y, CELL, **row_opts)
    end
  end

  shapes
end

# Tracked separately so the V key can hide them as a group.
matrix_shapes = []

# --- Panel 1: FILL + STROKE ------------------------------------------------

matrix_shapes += matrix_panel(X1, Y1, 'FILL + STROKE', [
  ['fill',     { color: BLUE }],
  ['stroke',   { color: BLUE, fill: false, stroke_width: 2,
                 stroke_color: BLUE }],
  ['fill+str', { color: BLUE, stroke_width: 5, stroke_color: HEAD }]
])

# --- Panel 2: OPACITY ------------------------------------------------------

matrix_shapes += matrix_panel(X2, Y1, 'OPACITY', [
  ['1.0',  { color: WARM, opacity: 1.0 }],
  ['0.5',  { color: WARM, opacity: 0.5 }],
  ['0.25', { color: WARM, opacity: 0.25 }]
])

# --- Panel 3: ROTATION -----------------------------------------------------

matrix_shapes += matrix_panel(X3, Y1, 'ROTATION', [
  ['0°',  { color: VIOLET, rotate: 0 }],
  ['45°', { color: VIOLET, rotate: 45 }],
  ['90°', { color: VIOLET, rotate: 90 }]
])

# --- Panel 4: Z-INDEX (interactive) ---------------------------------------

frame(X1, Y2, PANEL_W, BOT_PANEL_H)
label(X1 + 10, Y2 + 8, '[ Z-INDEX ]')
label(X1 + PANEL_W - 130, Y2 + 8, 'L-click front · R-click back', size: 9)

# Three shapes — square, circle, triangle — each occupying its own region
# but reaching into a common center so every depth permutation (3! = 6
# orderings) is reachable by clicking. Soft RGB makes each shape instantly
# identifiable.
ZA = 0.75
zcx = X1 + 242
zcy = Y2 + 135

def with_alpha(c, a)
  [c[0], c[1], c[2], a].freeze
end

z_raw_shapes = [
  Square.new(x: zcx - 110, y: zcy - 80, size: 130,
             color: with_alpha(SOFT_RED, ZA),
             stroke_width: 2, stroke_color: SOFT_RED),
  Circle.new(x: zcx + 35, y: zcy - 25, radius: 70, sectors: 32,
             color: with_alpha(SOFT_GREEN, ZA),
             stroke_width: 2, stroke_color: SOFT_GREEN),
  Triangle.new(x1: zcx,       y1: zcy - 10,
               x2: zcx + 110, y2: zcy + 100,
               x3: zcx - 110, y3: zcy + 100,
               color: with_alpha(SOFT_BLUE, ZA),
               stroke_width: 2, stroke_color: SOFT_BLUE)
]

z_entries = z_raw_shapes.each_with_index.map do |shape, i|
  z = i + 1
  shape.z = z
  lx = shape.respond_to?(:x) ? shape.x.to_i + 6 : zcx - 8
  ly = shape.respond_to?(:y) ? shape.y.to_i + 6 : zcy - 80
  text = Text.new("z:#{z}", x: lx, y: ly, z: z, size: 9, color: HEAD)
  { shape: shape, label: text, z: z }
end
next_z = z_entries.length

# Visual-less Button as the panel hit area. Clicks outside the panel
# never reach this handler.
z_panel = Button.new(x: X1, y: Y2, width: PANEL_W, height: BOT_PANEL_H)

z_panel.on(:mouse_down) do |event|
  hit = z_entries
        .select { |e| e[:shape].contains?(event.x, event.y) }
        .max_by { |e| e[:z] }
  next unless hit

  case event.button
  when :left
    next_z += 1
    new_z = next_z
  when :right
    new_z = z_entries.map { |e| e[:z] }.min - 1
  else
    next
  end

  hit[:z] = new_z
  hit[:shape].z = new_z
  hit[:label].z = new_z
  hit[:label].content = "z:#{new_z}"
end

# --- Panel 5: CONTAINS? (interactive) -------------------------------------

frame(X2, Y2, PANEL_W, BOT_PANEL_H)
label(X2 + 10, Y2 + 8, '[ CONTAINS? ]')

# Live readout sits in the header instead of the panel bottom — leaves the
# whole vertical for shapes.
contains_readout = Text.new('hover any shape', x: X2 + 110, y: Y2 + 9,
                            size: 9, color: DIM)

# 3×3 grid of one of each shape so hit-testing is exercised on every type.
# DIM by default, AMBER under the cursor — neutral resting state, panel hue
# on hit so the contains? region is unmistakable.
csx = X2 + 20
cx0 = csx + 74
cx1 = csx + 222
cx2 = csx + 370
ry0 = Y2 + 32
ry1 = ry0 + 65
ry2 = ry0 + 130

contains_shapes = []
# Row 1: Square, Rectangle, Triangle
contains_shapes << Square.new(x: cx0 - 28, y: ry0 + 5, size: 56, color: DIM)
contains_shapes << Rectangle.new(x: cx1 - 50, y: ry0 + 12,
                                 width: 100, height: 42, color: DIM)
contains_shapes << Triangle.new(x1: cx2,      y1: ry0 + 5,
                                x2: cx2 + 38, y2: ry0 + 60,
                                x3: cx2 - 38, y3: ry0 + 60, color: DIM)
# Row 2: Quad, Circle, Ellipse
contains_shapes << Quad.new(x1: cx0 - 38, y1: ry1 + 10,
                            x2: cx0 + 36, y2: ry1 + 5,
                            x3: cx0 + 42, y3: ry1 + 55,
                            x4: cx0 - 30, y4: ry1 + 50, color: DIM)
contains_shapes << Circle.new(x: cx1, y: ry1 + 30, radius: 28, color: DIM)
contains_shapes << Ellipse.new(x: cx2, y: ry1 + 30,
                               xradius: 50, yradius: 26, color: DIM)
# Row 3: Line, Polygon, Polyline
contains_shapes << Line.new(x1: cx0 - 38, y1: ry2 + 55,
                            x2: cx0 + 38, y2: ry2 + 5,
                            stroke_width: 12, color: DIM)
contains_shapes << Polygon.new(points: [
  [cx1 - 28, ry2 + 5],  [cx1 + 28, ry2 + 5],
  [cx1 + 42, ry2 + 30], [cx1 + 14, ry2 + 55],
  [cx1 - 38, ry2 + 30]
], color: DIM)
contains_shapes << Polyline.new(points: [
  [cx2 - 60, ry2 + 55], [cx2 - 30, ry2 + 5],
  [cx2,      ry2 + 45], [cx2 + 30, ry2 + 5],
  [cx2 + 60, ry2 + 55]
], stroke_width: 8, color: DIM)

update do
  mx = get(:mouse_x)
  my = get(:mouse_y)
  hits = []
  contains_shapes.each do |s|
    inside = s.contains?(mx, my)
    hits << s.class.name.split('::').last if inside
    s.color = inside ? AMBER : DIM
  end
  contains_readout.content = hits.empty? ? 'hover any shape' : "hits: #{hits.join(', ')}"
end

# --- Panel 6: GRADIENTS + DASH --------------------------------------------

frame(X3, Y2, PANEL_W, BOT_PANEL_H)
label(X3 + 10, Y2 + 8, '[ GRADIENTS + DASH ]')

# --- per-vertex fill (shapes that take a color array)
label(X3 + 12, Y2 + 36, 'fill')
fy = Y2 + 50
Triangle.new(x1: X3 + 110, y1: fy, x2: X3 + 165, y2: fy + 50,
             x3: X3 + 55, y3: fy + 50, color: PURE[0..2])
Quad.new(x1: X3 + 200, y1: fy, x2: X3 + 285, y2: fy,
         x3: X3 + 295, y3: fy + 50, x4: X3 + 190, y4: fy + 50,
         color: PURE[0..3])
Polygon.new(points: [
  [X3 + 360, fy + 5], [X3 + 425, fy], [X3 + 450, fy + 28],
  [X3 + 405, fy + 50], [X3 + 340, fy + 38]
], color: PURE[0..4])

# --- per-vertex stroke (outlined shapes with color arrays as stroke)
label(X3 + 12, Y2 + 115, 'stroke')
sy = Y2 + 130
Rectangle.new(x: X3 + 55, y: sy, width: 110, height: 50,
              fill: false, stroke_width: 3, stroke_color: PURE[0..3])
Triangle.new(x1: X3 + 245, y1: sy, x2: X3 + 300, y2: sy + 50,
             x3: X3 + 190, y3: sy + 50,
             fill: false, stroke_width: 3, stroke_color: PURE[0..2])
Polyline.new(points: [
  [X3 + 325, sy + 45], [X3 + 355, sy + 5], [X3 + 390, sy + 35],
  [X3 + 425, sy + 5],  [X3 + 455, sy + 45]
], stroke_width: 3, color: PURE[0..4])

# --- dashed lines (2-stop gradient so dashes show the gradient runs the
# full length, not just the visible segments)
label(X3 + 12, Y2 + 198, 'dash')
dy = Y2 + 213
Line.new(x1: X3 + 55, y1: dy,      x2: X3 + 460, y2: dy,
         dash: 8,  gap: 4, stroke_width: 1, color: PURE[0..1])
Line.new(x1: X3 + 55, y1: dy + 9,  x2: X3 + 460, y2: dy + 9,
         dash: 16, gap: 8, stroke_width: 2, color: PURE[0..1])
Line.new(x1: X3 + 55, y1: dy + 20, x2: X3 + 460, y2: dy + 20,
         dash: 4,  gap: 2, stroke_width: 3, color: PURE[0..1])

# --- Footer + V-toggle ----------------------------------------------------

label(16, H - 22, 'V toggles shape visibility', size: 12)

visible = true
on :key_down do |event|
  next unless event.key == :v

  visible = !visible
  matrix_shapes.each { |s| s.visible = visible }
end

show
