# Input
#
# Visual test of input abstractions layered on top of raw device events:
# per-object handlers (click / hover / drag / scroll on shapes), the
# Button class (default + wrapped + stroked, with auto and explicit
# hover / pressed tints), and cursor styling (visibility + system cursor
# grid). Raw device events live in test/keyboard.rb, test/mouse.rb, and
# test/gamepad.rb.

require 'ruby2d'

W = 1400
H = 540

set title: 'Ruby 2D — Input', width: W, height: H
set close_on_esc: true

# --- Palette ----------------------------------------------------------------

BG      = [0.05, 0.06, 0.07, 1].freeze
LINE    = [0.20, 0.22, 0.24, 1].freeze
LINE_HI = [0.35, 0.38, 0.42, 1].freeze
DIM     = [0.40, 0.42, 0.44, 1].freeze
TEXT    = [0.75, 0.78, 0.80, 1].freeze
HEAD    = [0.92, 0.94, 0.96, 1].freeze
ACCENT  = [0.45, 0.95, 0.70, 1].freeze

# Demo hues for the per-object events panel — distinguishable from each
# other and from ACCENT (which is reserved for live UI signal).
WARM    = [0.95, 0.55, 0.40, 1].freeze   # click
TEAL    = [0.30, 0.80, 0.85, 1].freeze   # hover
AMBER   = [0.95, 0.85, 0.30, 1].freeze   # drag
VIOLET  = [0.70, 0.45, 0.95, 1].freeze   # scroll

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

# Text centered inside a rectangle — uses Text's actual rendered width
# and height, so variable-width labels stay pixel-aligned.
def text_in_rect(rx, ry, rw, rh, content, size: 11, color: DIM)
  t = Text.new(content, x: 0, y: 0, size: size, color: color)
  t.x = rx + (rw - t.width) / 2
  t.y = ry + (rh - t.height) / 2
  t
end

# --- Header -----------------------------------------------------------------

Text.new('INPUT TEST', x: 16, y: 12, size: 16, color: HEAD)
hairline(16, 38, W - 16, 38, color: LINE)

# --- Panel layout (3-across) -----------------------------------------------

PAD     = 16
GAP     = 8
TOP_Y   = 50
PANEL_W = (W - PAD * 2 - GAP * 2) / 3
PANEL_H = H - TOP_Y - PAD

X_PER = PAD
X_BTN = PAD + PANEL_W + GAP
X_CUR = PAD + (PANEL_W + GAP) * 2

# --- Panel: PER-OBJECT EVENTS ----------------------------------------------

frame(X_PER, TOP_Y, PANEL_W, PANEL_H)
label(X_PER + 10, TOP_Y + 8, '[ PER-OBJECT EVENTS ]')

# CLICK row — three rectangles cycling colors on click.
label(X_PER + 16, TOP_Y + 36, 'click  (cycles fill color)')
click_palette = [WARM, TEAL, AMBER, VIOLET, ACCENT]
3.times do |i|
  rx = X_PER + 22 + i * 138
  rect = Rectangle.new(x: rx, y: TOP_Y + 56, width: 124, height: 50,
                       color: click_palette[0])
  ci = 0
  rect.on(:click) do
    ci = (ci + 1) % click_palette.length
    rect.color = click_palette[ci]
  end
end

# HOVER row — three circles that highlight while the cursor is over them.
label(X_PER + 16, TOP_Y + 130, 'hover  (highlights while over)')
3.times do |i|
  cx = X_PER + 84 + i * 138
  c = Circle.new(x: cx, y: TOP_Y + 178, radius: 28, sectors: 32, color: DIM)
  c.on(:hover)     { c.color = TEAL }
  c.on(:hover_out) { c.color = DIM }
end

# DRAG row — square draggable anywhere on screen once grabbed.
label(X_PER + 16, TOP_Y + 230, 'drag  (mouse-drag the amber square)')
drag_sq = Square.new(x: X_PER + 22, y: TOP_Y + 252, size: 50, color: AMBER)
drag_sq.on(:drag) do |e|
  drag_sq.x += e.delta_x
  drag_sq.y += e.delta_y
end

# SCROLL row — rectangle reports scroll deltas while the wheel is over it.
label(X_PER + 16, TOP_Y + 320, 'scroll  (mouse wheel over the box)')
sc_x = X_PER + 22
sc_y = TOP_Y + 340
sc_w = 200
sc_h = 50
po_scroll_rect = Rectangle.new(x: sc_x, y: sc_y, width: sc_w, height: sc_h,
                               color: VIOLET)
po_scroll_label = text_in_rect(sc_x, sc_y, sc_w, sc_h,
                               'dx: +0.00  dy: +0.00', size: 11, color: BG)
po_scroll_rect.on(:mouse_scroll) do |e|
  po_scroll_label.content = format('dx: %+.2f  dy: %+.2f', e.delta_x, e.delta_y)
  po_scroll_label.x = sc_x + (sc_w - po_scroll_label.width) / 2
end

# --- Panel: BUTTONS --------------------------------------------------------

frame(X_BTN, TOP_Y, PANEL_W, PANEL_H)
label(X_BTN + 10, TOP_Y + 8, '[ BUTTONS ]')

btn_status = Text.new('—', x: X_BTN + 16, y: TOP_Y + PANEL_H - 28,
                     size: 12, color: ACCENT)

# --- Default Buttons — three variants showing the API surface.
label(X_BTN + 16, TOP_Y + 36, 'default  (color + hover/pressed tints)')

Button.new(x: X_BTN + 22, y: TOP_Y + 56, width: 130, height: 38,
           label: 'Default', color: '#2196f3') do
  btn_status.content = 'Default clicked'
end

Button.new(x: X_BTN + 162, y: TOP_Y + 56, width: 130, height: 38,
           label: 'Auto Tints', color: '#4caf50',
           hover_color: :auto, pressed_color: :auto) do
  btn_status.content = 'Auto Tints clicked'
end

Button.new(x: X_BTN + 302, y: TOP_Y + 56, width: 130, height: 38,
           label: 'Stroked', color: '#ff9800',
           stroke_color: '#e65100', stroke_width: 2,
           hover_label_color: '#fff3e0',
           pressed_color: :auto, pressed_label_color: '#ffffff') do
  btn_status.content = 'Stroked clicked'
end

# --- Wrapping custom shapes — auto-tints derived from each shape's color.
label(X_BTN + 16, TOP_Y + 116, 'wrapping shapes  (auto-tint on hover + press)')

Button.new(Circle.new(x: X_BTN + 80, y: TOP_Y + 188, radius: 36,
                      color: '#e91e63'),
           hover_color: :auto, pressed_color: :auto) do
  btn_status.content = 'Circle clicked'
end

Button.new(Triangle.new(x1: X_BTN + 220, y1: TOP_Y + 152,
                        x2: X_BTN + 270, y2: TOP_Y + 224,
                        x3: X_BTN + 170, y3: TOP_Y + 224,
                        color: TEAL),
           hover_color: :auto, pressed_color: :auto) do
  btn_status.content = 'Triangle clicked'
end

Button.new(Square.new(x: X_BTN + 320, y: TOP_Y + 156, size: 70, color: VIOLET),
           hover_color: :auto, pressed_color: :auto) do
  btn_status.content = 'Square clicked'
end

# --- Visual-less hit area — frame + label drawn separately, Button on top
# carries the click without rendering anything itself.
label(X_BTN + 16, TOP_Y + 250, 'visual-less  (no render — frame is drawn separately)')
ghost_x = X_BTN + 22
ghost_y = TOP_Y + 270
ghost_w = 200
ghost_h = 36
frame(ghost_x, ghost_y, ghost_w, ghost_h, color: LINE_HI)
text_in_rect(ghost_x, ghost_y, ghost_w, ghost_h, 'click anywhere here',
             size: 10, color: DIM)
Button.new(x: ghost_x, y: ghost_y, width: ghost_w, height: ghost_h) do
  btn_status.content = 'Visual-less clicked'
end

# --- Filtered click — :left only; :right is silently ignored.
label(X_BTN + 16, TOP_Y + 320, 'filter  (left-click only — right is ignored)')
filt_btn = Button.new(x: X_BTN + 22, y: TOP_Y + 340, width: 200, height: 36,
                      label: 'Left only', color: '#607d8b',
                      hover_color: :auto)
filt_btn.on(click: :left) { btn_status.content = 'Left-only: left clicked' }

# --- Panel: CURSOR ---------------------------------------------------------

frame(X_CUR, TOP_Y, PANEL_W, PANEL_H)
label(X_CUR + 10, TOP_Y + 8, '[ CURSOR ]')

label(X_CUR + 16, TOP_Y + 36, 'visibility  (H: hide  /  S: show)')
cursor_status = Text.new('visible', x: X_CUR + 16, y: TOP_Y + 50,
                        size: 14, color: ACCENT)

label(X_CUR + 16, TOP_Y + 88, 'system cursors  (hover any cell)')

cursors = %i[
  default     text         wait        crosshair
  progress    pointer      move        not_allowed
  nwse_resize nesw_resize  ew_resize   ns_resize
  nw_resize   n_resize     ne_resize   e_resize
  se_resize   s_resize     sw_resize   w_resize
]

short = {
  default: 'default', text: 'text', wait: 'wait', crosshair: 'cross',
  progress: 'progress', pointer: 'pointer', move: 'move',
  not_allowed: 'no entry',
  nwse_resize: 'nwse', nesw_resize: 'nesw',
  ew_resize:   'ew',   ns_resize:   'ns',
  nw_resize:   'nw',   n_resize:    'n',
  ne_resize:   'ne',   e_resize:    'e',
  se_resize:   'se',   s_resize:    's',
  sw_resize:   'sw',   w_resize:    'w'
}

CELL_W   = 104
CELL_H   = 46
CELL_GAP = 4
GRID_X   = X_CUR + 16
GRID_Y   = TOP_Y + 110

cursor_cells = cursors.each_with_index.map do |name, i|
  col = i % 4
  row = i / 4
  cx = GRID_X + col * (CELL_W + CELL_GAP)
  cy = GRID_Y + row * (CELL_H + CELL_GAP)
  Rectangle.new(x: cx + 1, y: cy + 1, width: CELL_W - 2, height: CELL_H - 2,
                color: BG)
  frame(cx, cy, CELL_W, CELL_H, color: LINE_HI)
  text_in_rect(cx, cy, CELL_W, CELL_H, short[name], size: 10, color: DIM)
  { name: name, x: cx, y: cy, w: CELL_W, h: CELL_H }
end

active_cursor = :default
cursor_name_label = Text.new('cursor: default',
                            x: X_CUR + 16, y: TOP_Y + PANEL_H - 28,
                            size: 12, color: ACCENT)

on :mouse_move do |event|
  hit = cursor_cells.find do |c|
    event.x >= c[:x] && event.x < c[:x] + c[:w] &&
      event.y >= c[:y] && event.y < c[:y] + c[:h]
  end
  new_cursor = hit ? hit[:name] : :default
  if new_cursor != active_cursor
    active_cursor = new_cursor
    set cursor: active_cursor
    cursor_name_label.content = "cursor: #{active_cursor}"
  end
end

on :key_down do |event|
  case event.key
  when :h
    set cursor: :hidden
    cursor_status.content = 'hidden'
    cursor_status.color   = DIM
  when :s
    set cursor: :visible
    cursor_status.content = 'visible'
    cursor_status.color   = ACCENT
  end
end

show
