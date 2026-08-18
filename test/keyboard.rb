# Keyboard
#
# Sister to test/mouse.rb in the same technical style. Exercises key_down,
# key_held, and key_up. Three panels: event indicators (with the most-recent
# key), a grid of currently-held keys, and modifier-family indicators.

require 'ruby2d'

W = 900
H = 500

set title: 'Ruby 2D — Keyboard', width: W, height: H
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

# Text centered inside a rectangle (cell). Uses Text's actual rendered
# width/height, so variable-width labels stay pixel-aligned without
# per-label fudge offsets.
def text_in_rect(rx, ry, rw, rh, content, size: 11, color: DIM)
  t = Text.new(content, x: 0, y: 0, size: size, color: color)
  t.x = rx + (rw - t.width) / 2
  t.y = ry + (rh - t.height) / 2
  t
end

# --- Header -----------------------------------------------------------------

Text.new('KEYBOARD TEST', x: 16, y: 12, size: 16, color: HEAD)

held_count_text = readout(W - 160, 12, 'HLD')
evt_text        = readout(W - 80,  12, 'EVT')

hairline(16, 38, W - 16, 38, color: LINE)

# --- Panel layout -----------------------------------------------------------

PAD     = 16
GAP     = 8
TOP_Y   = 50
PANEL_H = 240
PANEL_W = (W - PAD * 2 - GAP * 2) / 3

X_EVT = PAD
X_HLD = PAD + PANEL_W + GAP
X_MOD = PAD + (PANEL_W + GAP) * 2

LOG_Y = TOP_Y + PANEL_H + GAP
LOG_H = H - LOG_Y - PAD

# --- EVENTS -----------------------------------------------------------------

frame(X_EVT, TOP_Y, PANEL_W, PANEL_H)
label(X_EVT + 10, TOP_Y + 8, '[ EVENTS ]')

event_names = %w[DOWN HELD UP]
cell_w      = 70
cell_h      = 62
cell_gap    = 12
cell_y      = TOP_Y + 36
total_w     = cell_w * 3 + cell_gap * 2
cell_x0     = X_EVT + (PANEL_W - total_w) / 2

evt_state = {}
event_names.each_with_index do |name, i|
  cx = cell_x0 + i * (cell_w + cell_gap)
  fill = Rectangle.new(x: cx + 1, y: cell_y + 1, width: cell_w - 2,
                       height: cell_h - 2, color: BG)
  frame(cx, cell_y, cell_w, cell_h, color: LINE_HI)
  text = text_in_rect(cx, cell_y, cell_w, cell_h, name, size: 16, color: DIM)
  evt_state[name.downcase.to_sym] = { fill: fill, text: text }
end

label(X_EVT + 16, TOP_Y + 122, 'LAST KEY')
last_key = Text.new('—', x: X_EVT + 16, y: TOP_Y + 142, size: 26, color: ACCENT)

# --- HELD -------------------------------------------------------------------

frame(X_HLD, TOP_Y, PANEL_W, PANEL_H)
label(X_HLD + 10, TOP_Y + 8, '[ HELD ]')

HELD_GRID_COLS = 3
HELD_GRID_ROWS = 6
HELD_SLOT_COUNT = HELD_GRID_COLS * HELD_GRID_ROWS
held_slot_w = (PANEL_W - 32) / HELD_GRID_COLS
held_slot_h = 28

held_slots = HELD_SLOT_COUNT.times.map do |i|
  col = i % HELD_GRID_COLS
  row = i / HELD_GRID_COLS
  Text.new('', x: X_HLD + 16 + col * held_slot_w,
           y: TOP_Y + 40 + row * held_slot_h, size: 13, color: ACCENT)
end

# --- MODIFIERS --------------------------------------------------------------

frame(X_MOD, TOP_Y, PANEL_W, PANEL_H)
label(X_MOD + 10, TOP_Y + 8, '[ MODIFIERS ]')

modifiers = %w[shift ctrl alt gui]
mod_state = {}
modifiers.each_with_index do |mod, i|
  cy = TOP_Y + 50 + i * 38
  dot = Rectangle.new(x: X_MOD + 18, y: cy, width: 14, height: 14, color: BG)
  frame(X_MOD + 18, cy, 14, 14, color: LINE_HI)
  text = Text.new(mod.upcase, x: X_MOD + 44, y: cy - 2, size: 14, color: DIM)
  mod_state[mod] = { dot: dot, text: text }
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

# --- State + refresh helpers -----------------------------------------------

held_keys   = []
event_count = 0
down_flash  = 0
up_flash    = 0
FLASH_LEN   = 8

def refresh_held(keys, slots, count_text)
  slots.each_with_index do |s, i|
    s.content = i < keys.length ? keys[i] : ''
  end
  count_text.content = keys.length.to_s
end

def refresh_modifiers(keys, mod_state)
  mod_state.each do |name, state|
    active = keys.any? { |k| k.to_s.include?(name) }
    state[:dot].color  = active ? ACCENT : BG
    state[:text].color = active ? HEAD  : DIM
  end
end

# --- Event handlers --------------------------------------------------------

on :key_down do |event|
  held_keys << event.key unless held_keys.include?(event.key)
  refresh_held(held_keys, held_slots, held_count_text)
  refresh_modifiers(held_keys, mod_state)

  evt_state[:down][:fill].color = ACCENT
  evt_state[:down][:text].color = BG
  down_flash = FLASH_LEN

  last_key.content = event.key.to_s
  push_log(log_buffer, log_lines, "down  #{event.key}")
end

on :key_held do |_event|
  evt_state[:held][:fill].color = ACCENT
  evt_state[:held][:text].color = BG
end

on :key_up do |event|
  held_keys.delete(event.key)
  refresh_held(held_keys, held_slots, held_count_text)
  refresh_modifiers(held_keys, mod_state)

  if held_keys.empty?
    evt_state[:held][:fill].color = BG
    evt_state[:held][:text].color = DIM
  end

  evt_state[:up][:fill].color = ACCENT
  evt_state[:up][:text].color = BG
  up_flash = FLASH_LEN

  push_log(log_buffer, log_lines, "up    #{event.key}")
end

on :key do |_event|
  event_count += 1
  evt_text.content = event_count.to_s
end

# --- Frame timers for the brief down/up flashes ----------------------------

update do
  if down_flash > 0
    down_flash -= 1
    if down_flash.zero?
      evt_state[:down][:fill].color = BG
      evt_state[:down][:text].color = DIM
    end
  end
  if up_flash > 0
    up_flash -= 1
    if up_flash.zero?
      evt_state[:up][:fill].color = BG
      evt_state[:up][:text].color = DIM
    end
  end
end

show
