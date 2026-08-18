# Tileset
#
# Visual test of every Tileset feature in six panels:
#   1. DEFINE + PLACE   — name tiles by grid cell, place at world coordinates
#   2. TRANSFORMS       — same source cell defined with rotate / flip per definition
#   3. TINT             — multiplicative tint applied to every tile in a Tileset
#   4. SCENE            — composed scene built from multiple tile types
#   5. PLACEMENT API    — interactive grid: click cycles, C/G/R for clear/refill/remove
#   6. CONTROLS         — key reference

require 'ruby2d'

W = 1500
H = 970

set title: 'Ruby 2D — Tileset', width: W, height: H
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

Text.new('TILESET TEST', x: 16, y: 12, size: 16, color: HEAD)
hairline(16, 38, W - 16, 38, color: LINE)

# --- Layout -----------------------------------------------------------------

PANEL_W = 480
PANEL_H = 440
COL_X   = [15, 510, 1005].freeze
ROW_Y   = [60, 515].freeze

SHEETS_DIR  = "#{Ruby2D.test_spritesheets}".freeze
SPRITESHEET = "#{SHEETS_DIR}/spritesheet.png".freeze

# spritesheet.png is an 18×18 grid of 128×128 tiles with 1px spacing. We
# render at half scale so each tile takes 64×64 on screen.
TILE_PX     = 128
TILE_GAP    = 1
SCALE       = 0.5
TILE        = (TILE_PX * SCALE).to_i  # 64

# Helper to build a Tileset with our shared spritesheet defaults.
def new_tileset
  Tileset.new(SPRITESHEET, tile_width: TILE_PX, tile_height: TILE_PX,
              spacing: TILE_GAP, scale: SCALE)
end

# --- Panel 1: DEFINE + PLACE -----------------------------------------------

p1x, p1y = COL_X[0], ROW_Y[0]
frame(p1x, p1y, PANEL_W, PANEL_H)
panel_label(p1x + 10, p1y + 8, '[ DEFINE + PLACE ]')

terrain = new_tileset
terrain.define('grass', 7, 3)
terrain.define('snow',  17, 6)
terrain.define('water', 3, 17)
terrain.define('rock',  9, 6)

# Single placements — one of each, labeled.
section(p1x + 15, p1y + 32, "define(name, col, row) + tileset[x, y] = name")
%w[grass snow water rock].each_with_index do |name, i|
  x = p1x + 30 + i * (TILE + 28)
  terrain[x, p1y + 60] = name
  hint(x + 8, p1y + 60 + TILE + 5, name)
end

# Batch placement — 4×2 grid mixing terrain types.
section(p1x + 15, p1y + 180, "place(name, [[x, y], ...]) — many at once")
b_ox = p1x + 110
b_oy = p1y + 210
terrain.place('grass', [[b_ox + 0 * TILE, b_oy + 0 * TILE],
                        [b_ox + 1 * TILE, b_oy + 0 * TILE],
                        [b_ox + 2 * TILE, b_oy + 0 * TILE],
                        [b_ox + 3 * TILE, b_oy + 0 * TILE]])
terrain.place('rock',  [[b_ox + 0 * TILE, b_oy + 1 * TILE],
                        [b_ox + 3 * TILE, b_oy + 1 * TILE]])
terrain.place('water', [[b_ox + 1 * TILE, b_oy + 1 * TILE],
                        [b_ox + 2 * TILE, b_oy + 1 * TILE]])

# --- Panel 2: TRANSFORMS ---------------------------------------------------

p2x, p2y = COL_X[1], ROW_Y[0]
frame(p2x, p2y, PANEL_W, PANEL_H)
panel_label(p2x + 10, p2y + 8, '[ TRANSFORMS ]')

section(p2x + 15, p2y + 32, "define(rotate:, flip:) — same source cell, six variants")

xforms = new_tileset
# bridge_logs has clear directionality (horizontal logs, end-caps), so flips
# and rotations are easy to read at a glance.
SOURCE_COL = 12
SOURCE_ROW = 1
xforms.define('plain', SOURCE_COL, SOURCE_ROW)
xforms.define('rot90', SOURCE_COL, SOURCE_ROW, rotate: 90)
xforms.define('rot20', SOURCE_COL, SOURCE_ROW, rotate: 20)
xforms.define('flipH', SOURCE_COL, SOURCE_ROW, flip: :horizontal)
xforms.define('flipV', SOURCE_COL, SOURCE_ROW, flip: :vertical)
xforms.define('flipB', SOURCE_COL, SOURCE_ROW, flip: :both)

xf_ox = p2x + 50
xf_oy = p2y + 70
%w[plain rot90 rot20 flipH flipV flipB].each_with_index do |name, i|
  col = i % 3
  row = i / 3
  x = xf_ox + col * (TILE + 60)
  y = xf_oy + row * (TILE + 50)
  xforms[x, y] = name
  hint(x + 14, y + TILE + 5, name)
end

# --- Panel 3: TINT ---------------------------------------------------------

p3x, p3y = COL_X[2], ROW_Y[0]
frame(p3x, p3y, PANEL_W, PANEL_H)
panel_label(p3x + 10, p3y + 8, '[ TINT ]')

section(p3x + 15, p3y + 32, "tileset.tint = ... — multiplies every tile in this Tileset")

# Each tinted variant is its own Tileset (tint is per-tileset, not per-tile).
# Use bricks_grey as the source — gray reads tint shifts most clearly.
TINT_COL = 7
TINT_ROW = 1
tint_oy = p3y + 60
[
  ['white',   'white'],
  ['red',     'red'],
  ['lime',    'lime'],
  ['#f4a261', 'mixed']
].each_with_index do |(color, label), i|
  ts = new_tileset
  ts.tint = color
  ts.define('brick', TINT_COL, TINT_ROW)
  x = p3x + 30 + i * (TILE + 28)
  ts[x, tint_oy] = 'brick'
  hint(x + 14, tint_oy + TILE + 5, label)
end

# Tint applies across multiple placements in the same tileset.
section(p3x + 15, p3y + 180, "tint applies to every placement in the Tileset")
multi = new_tileset
multi.tint = ACCENT
multi.define('grass', 7, 3)
multi.define('rock',  9, 6)
multi.define('snow',  17, 6)

m_ox = p3x + 110
m_oy = p3y + 210
%w[grass rock snow grass rock snow].each_with_index do |n, i|
  multi[m_ox + (i % 4) * TILE, m_oy + (i / 4) * TILE] = n
end

# --- Panel 4: SCENE --------------------------------------------------------

p4x, p4y = COL_X[0], ROW_Y[1]
frame(p4x, p4y, PANEL_W, PANEL_H)
panel_label(p4x + 10, p4y + 8, '[ SCENE ]')

section(p4x + 15, p4y + 32, "compose a small scene from multiple tile types")

scene = new_tileset
scene.define('grass',   7, 3)
scene.define('bricks',  9, 1)   # bricks_brown
scene.define('door',    5, 2)   # door_closed
scene.define('bridge',  11, 1)
scene.define('bush',    13, 1)
scene.define('cactus',  14, 1)
scene.define('coin',    0, 2)   # coin_gold
scene.define('gem',     5, 3)   # gem_red
scene.define('platform', 2, 1)  # block_yellow

# Scene grid (6 cols × 5 rows).
sc_ox = p4x + 50
sc_oy = p4y + 70

# Ground row.
scene.place('grass',  [[sc_ox + 0 * TILE, sc_oy + 4 * TILE],
                       [sc_ox + 1 * TILE, sc_oy + 4 * TILE],
                       [sc_ox + 4 * TILE, sc_oy + 4 * TILE],
                       [sc_ox + 5 * TILE, sc_oy + 4 * TILE]])
# Bridge across the gap.
scene.place('bridge', [[sc_ox + 2 * TILE, sc_oy + 4 * TILE],
                       [sc_ox + 3 * TILE, sc_oy + 4 * TILE]])
# A small brick wall with a door on the left.
scene[sc_ox + 0 * TILE, sc_oy + 2 * TILE] = 'bricks'
scene[sc_ox + 0 * TILE, sc_oy + 3 * TILE] = 'bricks'
scene[sc_ox + 1 * TILE, sc_oy + 3 * TILE] = 'door'
# Floating platform on the right.
scene[sc_ox + 5 * TILE, sc_oy + 2 * TILE] = 'platform'
# Decoration.
scene[sc_ox + 4 * TILE, sc_oy + 2 * TILE] = 'bush'
scene[sc_ox + 5 * TILE, sc_oy + 3 * TILE] = 'cactus'
# Collectibles.
scene[sc_ox + 2 * TILE, sc_oy + 0 * TILE] = 'coin'
scene[sc_ox + 3 * TILE, sc_oy + 0 * TILE] = 'gem'

# --- Panel 5: PLACEMENT API (interactive) ----------------------------------

p5x, p5y = COL_X[1], ROW_Y[1]
frame(p5x, p5y, PANEL_W, PANEL_H)
panel_label(p5x + 10, p5y + 8, '[ PLACEMENT API ]')

section(p5x + 15, p5y + 32, "click a tile to cycle  ([] / []=)  ·  C clear  ·  G refill  ·  R remove")

NAMES = %w[gem_blue gem_green gem_red gem_yellow heart].freeze
GEM_CELLS = {
  'gem_blue'   => [3, 3],
  'gem_green'  => [4, 3],
  'gem_red'    => [5, 3],
  'gem_yellow' => [6, 3],
  'heart'      => [9, 3]
}.freeze

interactive = new_tileset
GEM_CELLS.each { |name, (cx, cy)| interactive.define(name, cx, cy) }

GRID_COLS = 4
GRID_ROWS = 2
INT_OX    = p5x + 110
INT_OY    = p5y + 70

def refill_grid(ts, names, ox, oy, cols, rows, tile)
  rows.times do |row|
    cols.times do |col|
      ts[ox + col * tile, oy + row * tile] = names[(row * cols + col) % names.length]
    end
  end
end

refill_grid(interactive, NAMES, INT_OX, INT_OY, GRID_COLS, GRID_ROWS, TILE)

ts_status = Text.new('click a tile…', x: p5x + 15, y: p5y + PANEL_H - 26,
                     size: 11, color: ACCENT)

# --- Panel 6: CONTROLS -----------------------------------------------------

p6x, p6y = COL_X[2], ROW_Y[1]
frame(p6x, p6y, PANEL_W, PANEL_H)
panel_label(p6x + 10, p6y + 8, '[ CONTROLS ]')

section(p6x + 15, p6y + 32, 'panel 5 keyboard')
[
  ['Click', 'cycle the tile under the cursor'],
  ['C',     'clear the interactive grid'],
  ['G',     'refill the interactive grid'],
  ['R',     'delete the top-left tile']
].each_with_index do |(key, desc), i|
  y = p6y + 60 + i * 28
  Text.new(key,  x: p6x + 25,  y: y, size: 12, color: HEAD)
  Text.new(desc, x: p6x + 110, y: y, size: 12, color: TEXT)
end

# --- Input handlers --------------------------------------------------------

on :key_down do |e|
  case e.key
  when :c
    interactive.clear
    ts_status.content = 'cleared'
  when :g
    interactive.clear
    refill_grid(interactive, NAMES, INT_OX, INT_OY, GRID_COLS, GRID_ROWS, TILE)
    ts_status.content = 'refilled'
  when :r
    interactive.delete(INT_OX, INT_OY)
    ts_status.content = 'deleted top-left'
  end
end

on :mouse_down do |event|
  next if event.x < INT_OX || event.y < INT_OY

  col = ((event.x - INT_OX) / TILE).to_i
  row = ((event.y - INT_OY) / TILE).to_i
  next if col < 0 || col >= GRID_COLS || row < 0 || row >= GRID_ROWS

  x = INT_OX + col * TILE
  y = INT_OY + row * TILE

  current = interactive[x, y]
  if current
    idx = NAMES.index(current) || 0
    next_name = NAMES[(idx + 1) % NAMES.length]
    interactive[x, y] = next_name
    ts_status.content = "(#{col},#{row}) #{current} → #{next_name}"
  else
    interactive[x, y] = NAMES.first
    ts_status.content = "(#{col},#{row}) empty → #{NAMES.first}"
  end
end

show
