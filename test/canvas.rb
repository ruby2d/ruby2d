# Canvas
#
# Comprehensive visual test of the Canvas drawing API. Six panels in a
# 3×2 grid:
#   1. FILLED PRIMITIVES   — fill_triangle/rect/square/quad/circle/ellipse/polygon
#   2. STROKED PRIMITIVES  — stroke_* variants + draw_line (solid / dashed / gradient)
#   3. GRADIENTS           — per-vertex fill + stroke gradients
#   4. BLENDING            — alpha gradient, RGB Venn, accumulation, per-vertex alpha
#   5. JOINS + CONCAVE     — polylines at varied widths, concave polygon fill
#   6. IMAGES + TEXT       — draw_image (native + scaled), draw_text (sized + tinted)

require 'ruby2d'

W = 1500
H = 970

set title: 'Ruby 2D — Canvas', width: W, height: H
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

def label(x, y, text, size: 10, color: DIM)
  Text.new(text, x: x, y: y, size: size, color: color)
end

def hint(x, y, text)
  Text.new(text, x: x, y: y, size: 10, color: DIM)
end

# --- Header -----------------------------------------------------------------

Text.new('CANVAS TEST', x: 16, y: 12, size: 16, color: HEAD)
hairline(16, 38, W - 16, 38, color: LINE)

# --- Layout -----------------------------------------------------------------

PANEL_W = 480
PANEL_H = 440
COL_X   = [15, 510, 1005].freeze
ROW_Y   = [60, 515].freeze

# --- Panel 1: FILLED PRIMITIVES --------------------------------------------

p1x, p1y = COL_X[0], ROW_Y[0]
frame(p1x, p1y, PANEL_W, PANEL_H)
label(p1x + 10, p1y + 8, '[ FILLED PRIMITIVES ]')

c1 = Canvas.new(x: p1x + 10, y: p1y + 30, width: 460, height: 400, fill: [1.0, 1.0, 1.0, 0.0])

c1.fill_triangle(x1: 60, y1: 30, x2: 110, y2: 110, x3: 10, y3: 110, color: 'yellow')
c1.fill_rectangle(x: 130, y: 30, width: 90, height: 80, color: 'blue')
c1.fill_square(x: 240, y: 30, size: 80, color: 'green')
c1.fill_quad(x1: 340, y1: 30, x2: 440, y2: 30, x3: 420, y3: 110, x4: 350, y4: 110,
             color: 'red')

c1.fill_circle(x: 50, y: 180, radius: 40, color: 'orange')
c1.fill_ellipse(x: 180, y: 180, xradius: 70, yradius: 35, color: 'purple')
c1.fill_polygon(
  points: [[300, 140], [380, 150], [400, 220], [340, 240], [290, 200]],
  color: 'teal'
)

%w[triangle rectangle square quad].each_with_index do |name, i|
  hint(p1x + 30 + i * 110, p1y + 150, name)
end
%w[circle ellipse polygon].each_with_index do |name, i|
  hint(p1x + 30 + i * 140, p1y + 270, name)
end

# --- Panel 2: STROKED PRIMITIVES -------------------------------------------

p2x, p2y = COL_X[1], ROW_Y[0]
frame(p2x, p2y, PANEL_W, PANEL_H)
label(p2x + 10, p2y + 8, '[ STROKED PRIMITIVES ]')

c2 = Canvas.new(x: p2x + 10, y: p2y + 30, width: 460, height: 400, fill: [1.0, 1.0, 1.0, 0.0])

c2.stroke_triangle(x1: 60, y1: 30, x2: 110, y2: 110, x3: 10, y3: 110,
                   stroke_width: 3, color: 'green')
c2.stroke_rectangle(x: 130, y: 30, width: 90, height: 80, stroke_width: 3, color: 'blue')
c2.stroke_square(x: 240, y: 30, size: 80, stroke_width: 3, color: 'fuchsia')
c2.stroke_quad(x1: 340, y1: 30, x2: 440, y2: 30, x3: 420, y3: 110, x4: 350, y4: 110,
               stroke_width: 3, color: 'red')

c2.stroke_circle(x: 50, y: 180, radius: 40, stroke_width: 3, color: 'orange')
c2.stroke_ellipse(x: 180, y: 180, xradius: 60, yradius: 35, stroke_width: 3, color: 'lime')

# draw_line variants — solid, dashed thin, dashed thick
c2.draw_line(x1: 280, y1: 160, x2: 440, y2: 160, stroke_width: 3, color: 'white')
c2.draw_line(x1: 280, y1: 185, x2: 440, y2: 185, stroke_width: 3,
             dash: 15, gap: 8, color: [0.0, 1.0, 1.0, 1.0])
c2.draw_line(x1: 280, y1: 215, x2: 440, y2: 215, stroke_width: 6,
             dash: 10, gap: 5, color: 'lime')

# draw_polyline open + closed
c2.draw_polyline(points: [[20, 280], [80, 340], [140, 280], [200, 340], [260, 280]],
                 stroke_width: 3, color: 'yellow')
c2.draw_polyline(points: [[300, 280], [380, 290], [400, 350], [340, 380], [290, 340]],
                 stroke_width: 3, color: 'white', closed: true)

hint(p2x + 25, p2y + 150, 'tri/rect/sq/quad')
hint(p2x + 25, p2y + 260, 'circ/ellipse')
hint(p2x + 290, p2y + 260, 'line / dashed')
hint(p2x + 25, p2y + 420, 'polyline (open)')
hint(p2x + 295, p2y + 420, 'polyline (closed)')

# --- Panel 3: GRADIENTS ----------------------------------------------------

p3x, p3y = COL_X[2], ROW_Y[0]
frame(p3x, p3y, PANEL_W, PANEL_H)
label(p3x + 10, p3y + 8, '[ GRADIENTS ]')

c3 = Canvas.new(x: p3x + 10, y: p3y + 30, width: 460, height: 400, fill: [1.0, 1.0, 1.0, 0.0])

# Per-vertex fills
c3.fill_triangle(x1: 60, y1: 30, x2: 110, y2: 110, x3: 10, y3: 110,
                 color: [[1.0, 0.0, 0.0, 1.0], [0.0, 1.0, 0.0, 1.0], [0.0, 0.0, 1.0, 1.0]])
c3.fill_rectangle(x: 130, y: 30, width: 90, height: 80,
                  color: [[1.0, 1.0, 1.0, 1.0], [1.0, 0.0, 0.0, 1.0], [0.0, 0.0, 0.0, 1.0], [0.0, 0.0, 1.0, 1.0]])
c3.fill_quad(x1: 240, y1: 30, x2: 340, y2: 30, x3: 320, y3: 110, x4: 250, y4: 110,
             color: [[1.0, 0.0, 0.0, 1.0], [1.0, 1.0, 0.0, 1.0], [0.0, 1.0, 0.0, 1.0], [0.0, 0.0, 1.0, 1.0]])
c3.fill_polygon(
  points: [[370, 30], [440, 50], [430, 100], [380, 110], [355, 70]],
  color: [[1.0, 0.0, 0.0, 1.0], [1.0, 1.0, 0.0, 1.0], [0.0, 1.0, 0.0, 1.0], [0.0, 1.0, 1.0, 1.0], [0.0, 0.0, 1.0, 1.0]]
)

hint(p3x + 25, p3y + 150, 'fill: per-vertex colors')

# Per-vertex stroke gradients
c3.stroke_triangle(x1: 60, y1: 200, x2: 110, y2: 280, x3: 10, y3: 280,
                   stroke_width: 6, color: %w[red yellow aqua])
c3.stroke_rectangle(x: 140, y: 200, width: 110, height: 80, stroke_width: 6,
                    color: %w[red yellow lime aqua])
c3.draw_polyline(points: [[280, 280], [320, 200], [360, 280], [400, 200], [440, 280]],
                 stroke_width: 6, color: %w[red yellow lime aqua fuchsia])

hint(p3x + 25, p3y + 320, 'stroke: per-vertex colors (perimeter interpolation)')

# Gradient lines (solid + dashed)
c3.draw_line(x1: 30, y1: 350, x2: 230, y2: 350, stroke_width: 6, color: %w[red yellow])
c3.draw_line(x1: 250, y1: 350, x2: 440, y2: 350, stroke_width: 6,
             dash: 12, gap: 6, color: %w[red aqua])

hint(p3x + 25, p3y + 395, 'line gradient (solid + dashed)')

# --- Panel 4: BLENDING -----------------------------------------------------

p4x, p4y = COL_X[0], ROW_Y[1]
frame(p4x, p4y, PANEL_W, PANEL_H)
label(p4x + 10, p4y + 8, '[ BLENDING ]')

# Two-tone background under the canvas to verify alpha compositing against scene.
Rectangle.new(x: p4x + 10,  y: p4y + 30, width: 230, height: 400, color: [0.6, 0.1, 0.1, 1])
Rectangle.new(x: p4x + 240, y: p4y + 30, width: 230, height: 400, color: [0.1, 0.1, 0.6, 1])

c4 = Canvas.new(x: p4x + 10, y: p4y + 30, width: 460, height: 400, fill: [1.0, 1.0, 1.0, 0.2])

# Alpha gradient (10 circles 0.1..1.0)
10.times do |i|
  c4.fill_circle(x: 30 + i * 42, y: 40, radius: 18, color: [0.0, 1.0, 0.0, (i + 1) / 10.0])
end

# RGB Venn — overlapping translucent circles
c4.fill_circle(x: 130, y: 150, radius: 50, color: [1.0, 0.0, 0.0, 0.5])
c4.fill_circle(x: 200, y: 150, radius: 50, color: [0.0, 1.0, 0.0, 0.5])
c4.fill_circle(x: 165, y: 210, radius: 50, color: [0.0, 0.0, 1.0, 0.5])

# Alpha accumulation (5 stacked rects)
5.times do |i|
  c4.fill_rectangle(x: 290 + i * 12, y: 130 + i * 12, width: 90, height: 90,
                    color: [1.0, 1.0, 0.0, 0.2])
end

# Per-vertex alpha (gradient transparency within one shape)
c4.fill_triangle(x1: 60, y1: 280, x2: 240, y2: 280, x3: 150, y3: 370,
                 color: [[1.0, 0.0, 0.0, 1.0], [0.0, 1.0, 0.0, 0.0], [0.0, 0.0, 1.0, 1.0]])

# Fill + stroke at different alpha levels
c4.fill_rectangle(x: 290, y: 280, width: 130, height: 90, color: [1.0, 1.0, 1.0, 0.3])
c4.stroke_rectangle(x: 290, y: 280, width: 130, height: 90, stroke_width: 5,
                    color: [1.0, 0.0, 0.0, 0.9])

# --- Panel 5: JOINS + CONCAVE ----------------------------------------------

p5x, p5y = COL_X[1], ROW_Y[1]
frame(p5x, p5y, PANEL_W, PANEL_H)
label(p5x + 10, p5y + 8, '[ JOINS + CONCAVE ]')

c5 = Canvas.new(x: p5x + 10, y: p5y + 30, width: 460, height: 400, fill: [1.0, 1.0, 1.0, 0.0])

# Same zigzag polyline at two stroke widths to inspect joins.
zigzag = [[20, 80], [100, 30], [180, 90], [260, 30], [340, 90], [420, 30]]
c5.draw_polyline(points: zigzag, stroke_width: 30, color: [1.0, 1.0, 1.0, 0.6])
c5.draw_polyline(points: zigzag, stroke_width: 1,  color: 'red')

# Closed polygon outline as polyline
diamond = [[80, 160], [180, 200], [80, 240], [-20, 200]].map { |x, y| [x + 80, y] }
c5.draw_polyline(points: diamond, stroke_width: 18, color: [0.2, 0.7, 1.0, 0.7],
                 closed: true)
c5.draw_polyline(points: diamond, stroke_width: 1, color: 'white', closed: true)

# Concave polygon (arrow) with per-vertex colors — verifies triangulation.
arrow = [
  [300, 160], [370, 160], [370, 140], [440, 200],
  [370, 260], [370, 240], [300, 240]
]
c5.fill_polygon(
  points: arrow,
  color: %w[red yellow lime aqua blue fuchsia white]
)
c5.draw_polyline(points: arrow, stroke_width: 1, color: 'white', closed: true)

# Concave star with per-vertex colors
star = []
10.times do |i|
  angle = i * Math::PI / 5 - Math::PI / 2
  r = i.even? ? 70 : 28
  star << [200 + r * Math.cos(angle), 320 + r * Math.sin(angle)]
end
c5.fill_polygon(points: star,
                color: %w[red yellow lime aqua blue fuchsia red yellow lime aqua])

hint(p5x + 20, p5y + 130, 'polyline joins (thick + thin centerline)')
hint(p5x + 20, p5y + 270, 'closed thick polyline')
hint(p5x + 320, p5y + 295, 'concave fill (arrow)')
hint(p5x + 130, p5y + 410, 'concave fill (star)')

# --- Panel 6: IMAGES + TEXT ------------------------------------------------

p6x, p6y = COL_X[2], ROW_Y[1]
frame(p6x, p6y, PANEL_W, PANEL_H)
label(p6x + 10, p6y + 8, '[ IMAGES + TEXT ]')

c6 = Canvas.new(x: p6x + 10, y: p6y + 30, width: 460, height: 400, fill: [1.0, 1.0, 1.0, 0.0])

# Images on canvas — native + scaled
img = Image.new("#{Ruby2D.test_images}/image.png", add: false)
c6.draw_image(img, x: 20, y: 30)                            # native size
c6.draw_image(img, x: 140, y: 30, width: 60, height: 60)    # scaled smaller
c6.draw_image(img, x: 220, y: 30, width: 120, height: 120)  # scaled larger

hint(p6x + 30,  p6y + 190, 'native')
hint(p6x + 150, p6y + 190, 'scaled 60')
hint(p6x + 230, p6y + 190, 'scaled 120')

# Text on canvas — default + tinted + sized
txt = Text.new('Hello Canvas!', size: 22, add: false)
c6.draw_text(txt, x: 20, y: 200)
c6.draw_text(txt, x: 20, y: 240, color: 'red')
c6.draw_text(txt, x: 20, y: 280, color: 'aqua')

big = Text.new('BIG', size: 56, add: false)
c6.draw_text(big, x: 20, y: 320, color: 'yellow')

small = Text.new('small', size: 14, add: false)
c6.draw_text(small, x: 130, y: 360, color: 'lime')

hint(p6x + 30, p6y + 215, 'draw_text — default / red / aqua / sized')

show
