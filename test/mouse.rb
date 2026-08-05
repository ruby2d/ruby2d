# Mouse
#
# An alternative test-style direction: near-black background, faint grid,
# hairline panel borders, mint-green accent for live values, warm orange for
# active state. Exercises mouse_down, mouse_up, mouse_held, mouse_move, and
# mouse_scroll with compact numeric readouts and a scrolling event log.

require 'ruby2d'

W = 900
H = 500

set title: 'Ruby 2D — Mouse', width: W, height: H
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

def readout(x, y, name)
  label(x, y + 4, name, size: 10)
  Text.new('0', x: x + 26, y: y, size: 14, color: ACCENT)
end

# Horizontally-centered text. Uses Text's actual rendered width so
# variable-width glyphs (e.g. L vs M vs R) stay pixel-aligned without
# per-character fudge offsets.
def text_at(cx, y, content, size: 10, color: DIM)
  t = Text.new(content, x: 0, y: y, size: size, color: color)
  t.x = cx - t.width / 2
  t
end

# --- Header -----------------------------------------------------------------

Text.new('MOUSE TEST', x: 16, y: 12, size: 16, color: HEAD)

pos_x_text = readout(W - 240, 12, 'X')
pos_y_text = readout(W - 160, 12, 'Y')
evt_text   = readout(W - 80,  12, 'EVT')

hairline(16, 38, W - 16, 38, color: LINE)

# --- Panel layout -----------------------------------------------------------

PAD     = 16
GAP     = 8
TOP_Y   = 50
PANEL_H = 240
PANEL_W = (W - PAD * 2 - GAP * 2) / 3

X_BTN = PAD
X_MOT = PAD + PANEL_W + GAP
X_SCR = PAD + (PANEL_W + GAP) * 2

LOG_Y = TOP_Y + PANEL_H + GAP
LOG_H = H - LOG_Y - PAD

# --- BUTTONS ----------------------------------------------------------------

frame(X_BTN, TOP_Y, PANEL_W, PANEL_H)
label(X_BTN + 10, TOP_Y + 8, '[ BUTTONS ]')

buttons = %i[left middle right]
btn_w   = 70
btn_gap = 10
btn_y   = TOP_Y + 36
total_w = btn_w * 3 + btn_gap * 2
btn_x0  = X_BTN + (PANEL_W - total_w) / 2

btn_state = {}
buttons.each_with_index do |name, i|
  bx = btn_x0 + i * (btn_w + btn_gap)
  fill = Rectangle.new(x: bx + 1, y: btn_y + 1, width: btn_w - 2, height: 78,
                       color: BG)
  frame(bx, btn_y, btn_w, 80, color: LINE_HI)
  letter = text_at(bx + btn_w / 2, btn_y + 22, name.to_s[0].upcase,
                   size: 26, color: DIM)
  tag    = Text.new('', x: bx + 8, y: btn_y + 62, size: 9, color: DIM)
  btn_state[name] = { fill: fill, letter: letter, tag: tag }
end

label(X_BTN + 10, TOP_Y + 134, 'LAST')
last_btn = Text.new('—', x: X_BTN + 10, y: TOP_Y + 148, size: 13, color: TEXT)
label(X_BTN + 10, TOP_Y + 184, 'HELD')
held_text = Text.new('—', x: X_BTN + 10, y: TOP_Y + 198, size: 13, color: TEXT)

held_set = []

# Latch the lit fill/letter for LATCH_S seconds so a tap stays visible even when
# DOWN and UP arrive in the same frame — without it, a fast click toggles the
# visual state inside one tick and never presents. Releases on an `elapsed`
# deadline (monotonic engine seconds), not a wall clock: the web build's 32-bit
# `mrb_int` can't hold milliseconds-since-epoch. Tag content tracks release
# immediately; only the color flash is held.
LATCH_S = 0.08
pending_reset = {}

on :mouse_down do |event|
  s = btn_state[event.button]
  if s
    s[:fill].color   = ACCENT
    s[:letter].color = BG
    s[:tag].content  = 'DOWN'
    s[:tag].color    = ACCENT
    pending_reset.delete(event.button)
  end
  last_btn.content = "#{event.button}  @  #{event.x}, #{event.y}"
end

on :mouse_up do |event|
  s = btn_state[event.button]
  if s
    s[:tag].content = ''
    s[:tag].color   = DIM
    pending_reset[event.button] = elapsed + LATCH_S
  end
  if held_set.delete(event.button)
    held_text.content = held_set.empty? ? '—' : held_set.join(' + ')
  end
end

on :mouse_held do |event|
  next unless btn_state.key?(event.button)

  btn_state[event.button][:tag].content = 'HELD'
  unless held_set.include?(event.button)
    held_set << event.button
    held_text.content = held_set.join(' + ')
  end
end

update do
  pending_reset.delete_if do |btn, deadline|
    next false if elapsed < deadline

    s = btn_state[btn]
    s[:fill].color   = BG
    s[:letter].color = DIM
    true
  end
end

# --- MOTION -----------------------------------------------------------------

frame(X_MOT, TOP_Y, PANEL_W, PANEL_H)
label(X_MOT + 10, TOP_Y + 8, '[ MOTION ]')

label(X_MOT + 16, TOP_Y + 36, 'DX')
dx_val = Text.new('+0', x: X_MOT + 40, y: TOP_Y + 30, size: 18, color: ACCENT)
label(X_MOT + 130, TOP_Y + 36, 'DY')
dy_val = Text.new('+0', x: X_MOT + 154, y: TOP_Y + 30, size: 18, color: ACCENT)

trail_x = X_MOT + 16
trail_y = TOP_Y + 78
trail_w = PANEL_W - 32
trail_h = PANEL_H - 90
frame(trail_x, trail_y, trail_w, trail_h, color: LINE)
label(trail_x + 4, trail_y + trail_h - 12,
      'trail / move inside this box', size: 9)

TRAIL_LEN = 80
trail_dots = TRAIL_LEN.times.map do
  Circle.new(x: -10, y: -10, radius: 1.8, sectors: 10, color: ACCENT)
end
trail_idx = 0

# --- SCROLL -----------------------------------------------------------------

frame(X_SCR, TOP_Y, PANEL_W, PANEL_H)
label(X_SCR + 10, TOP_Y + 8, '[ SCROLL ]')

label(X_SCR + 16, TOP_Y + 36, 'DX')
sdx_val = Text.new('+0.00', x: X_SCR + 40, y: TOP_Y + 30, size: 16, color: ACCENT)
label(X_SCR + 130, TOP_Y + 36, 'DY')
sdy_val = Text.new('+0.00', x: X_SCR + 154, y: TOP_Y + 30, size: 16, color: ACCENT)
label(X_SCR + 16, TOP_Y + 64, 'DIR')
sdir_val = Text.new('—', x: X_SCR + 50, y: TOP_Y + 60, size: 13, color: TEXT)

# Square moves with each scroll event, clamped to the area bounds.
scroll_area_x = X_SCR + 16
scroll_area_y = TOP_Y + 92
scroll_area_w = PANEL_W - 32
scroll_area_h = PANEL_H - 108
frame(scroll_area_x, scroll_area_y, scroll_area_w, scroll_area_h, color: LINE)

SCROLL_SQ    = 18
SCROLL_SCALE = 12
scroll_sq = Square.new(
  x: scroll_area_x + (scroll_area_w - SCROLL_SQ) / 2,
  y: scroll_area_y + (scroll_area_h - SCROLL_SQ) / 2,
  size: SCROLL_SQ, color: ACCENT
)

on :mouse_scroll do |event|
  sdx_val.content  = format('%+.2f', event.delta_x)
  sdy_val.content  = format('%+.2f', event.delta_y)
  sdir_val.content = event.direction.to_s
  scroll_sq.x = (scroll_sq.x + event.delta_x * SCROLL_SCALE)
                .clamp(scroll_area_x, scroll_area_x + scroll_area_w - SCROLL_SQ)
  scroll_sq.y = (scroll_sq.y + event.delta_y * SCROLL_SCALE)
                .clamp(scroll_area_y, scroll_area_y + scroll_area_h - SCROLL_SQ)
end

# --- EVENT LOG --------------------------------------------------------------

frame(PAD, LOG_Y, W - PAD * 2, LOG_H)
label(PAD + 10, LOG_Y + 8, '[ EVENT LOG ]')
label(W - PAD - 90, LOG_Y + 8, 'newest first', size: 9)

LOG_LINES = ((LOG_H - 28) / 14).to_i
log_lines = LOG_LINES.times.map do |i|
  Text.new('', x: PAD + 16, y: LOG_Y + 28 + i * 14, size: 11, color: DIM)
end
log_buffer = []

# Fade older lines so the most recent stays bright.
def push_log(buffer, lines, str)
  buffer.unshift(str)
  buffer.pop while buffer.length > lines.length
  lines.each_with_index do |t, i|
    t.content = buffer[i] || ''
    fade = (1.0 - (i.to_f / lines.length)).clamp(0.25, 1.0)
    t.color = [0.85 * fade + 0.10, 0.88 * fade + 0.10,
               0.90 * fade + 0.10, 1]
  end
end

# --- Mouse move drives header readouts and the trail ----------------------

on :mouse_move do |event|
  pos_x_text.content = event.x.to_s
  pos_y_text.content = event.y.to_s
  dx_val.content     = format('%+d', event.delta_x.to_i)
  dy_val.content     = format('%+d', event.delta_y.to_i)

  if event.x >= trail_x && event.x <= trail_x + trail_w &&
     event.y >= trail_y && event.y <= trail_y + trail_h
    d = trail_dots[trail_idx]
    d.x = event.x
    d.y = event.y
    trail_idx = (trail_idx + 1) % TRAIL_LEN
  end
end

# --- Universal tap: counter + log feed -------------------------------------

event_count = 0

on :mouse do |event|
  event_count += 1
  evt_text.content = event_count.to_s

  msg = case event.type
        when :down
          "down    btn=#{event.button.to_s.ljust(6)} " \
            "x=#{event.x.to_s.rjust(4)}  y=#{event.y.to_s.rjust(4)}"
        when :up
          "up      btn=#{event.button.to_s.ljust(6)} " \
            "x=#{event.x.to_s.rjust(4)}  y=#{event.y.to_s.rjust(4)}"
        when :scroll
          "scroll  dx=#{format('%+.2f', event.delta_x)} " \
            " dy=#{format('%+.2f', event.delta_y)}  dir=#{event.direction}"
        end
  push_log(log_buffer, log_lines, msg) if msg
end

show
