# Gamepad
#
# Sister to test/mouse.rb and test/keyboard.rb in the same technical style.
# Verifies that a single gamepad connects/disconnects, every button fires
# button_down / button_up events with visual feedback, the analog axes
# (sticks + triggers) report raw values correctly, and rumble triggers
# on demand. Multi-pad, battery, mapping, and capability probing are
# intentionally out of scope.

require 'ruby2d'

W = 900
H = 550

set title: 'Ruby 2D — Gamepad', width: W, height: H
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

# Centered single-line text — uses Text's actual rendered width so the
# result is pixel-correct, not approximated from char count.
def text_at(cx, y, content, size: 10, color: DIM)
  t = Text.new(content, x: 0, y: y, size: size, color: color)
  t.x = cx - t.width / 2
  t
end

# Text centered inside a rectangle (cell, button).
def text_in_rect(rx, ry, rw, rh, content, size: 11, color: DIM, z: 0)
  t = Text.new(content, x: 0, y: 0, size: size, color: color, z: z)
  t.x = rx + (rw - t.width) / 2
  t.y = ry + (rh - t.height) / 2
  t
end

def readout(x, y, name)
  label(x, y + 4, name, size: 10)
  Text.new('0', x: x + 26, y: y, size: 14, color: ACCENT)
end

# Rectangular labelled cell (shoulders, dpad, system). Returns the fill +
# text so the caller can flip colors on press.
def button_cell(x, y, w, h, text)
  fill = Rectangle.new(x: x + 1, y: y + 1, width: w - 2, height: h - 2,
                       color: BG)
  frame(x, y, w, h, color: LINE_HI)
  t = text_in_rect(x, y, w, h, text, size: 11, color: DIM)
  { fill: fill, text: t }
end

# Circular labelled button (face buttons — N/S/W/E). Outline is a stroked
# ring; the inner filled circle changes color on press.
def button_circle(cx, cy, radius, text)
  Circle.new(x: cx, y: cy, radius: radius, sectors: 32,
             fill: false, stroke_width: 1, stroke_color: LINE_HI)
  fill = Circle.new(x: cx, y: cy, radius: radius - 1, sectors: 32,
                    color: BG, z: 1)
  t = Text.new(text, x: 0, y: 0, size: 11, color: DIM, z: 2)
  t.x = cx - t.width / 2
  t.y = cy - t.height / 2
  { fill: fill, text: t }
end

# Trigger widget: outline rectangle showing the 0..1 range with an inner
# fill that grows upward as the trigger is pulled. Fill is BG (invisible)
# at rest, DIM while inside the deadzone, ACCENT past it — so the
# threshold transition is visually obvious.
def trigger_widget(x, y, w, h)
  frame(x, y, w, h, color: LINE_HI)
  fill = Rectangle.new(x: x + 2, y: y + h - 1, width: w - 4, height: 1,
                       color: BG)
  { x: x, y: y, w: w, h: h, fill: fill }
end

def update_trigger(t, raw, adjusted)
  v = raw.clamp(0.0, 1.0)
  inner_h = (v * (t[:h] - 4)).round
  if inner_h <= 0
    t[:fill].height = 1
    t[:fill].y      = t[:y] + t[:h] - 1
    t[:fill].color  = BG
  else
    t[:fill].height = inner_h
    t[:fill].y      = t[:y] + t[:h] - 2 - inner_h
    t[:fill].color  = adjusted > 0 ? ACCENT : DIM
  end
end

# Stick widget: stroked outer ring shows the max-range envelope, inner
# filled dot tracks the raw stick position. Dot is DIM while inside the
# deadzone, ACCENT once either axis is past it.
def stick_widget(cx, cy, outer_r, dot_r)
  outer = Circle.new(x: cx, y: cy, radius: outer_r, sectors: 48,
                     fill: false, stroke_width: 2, stroke_color: DIM)
  dot   = Circle.new(x: cx, y: cy, radius: dot_r, sectors: 32,
                     color: DIM, z: 2)
  { outer: outer, dot: dot, cx: cx, cy: cy,
    max_offset: outer_r - dot_r - 2 }
end

def update_stick(s, raw_x, raw_y, adjusted_x, adjusted_y)
  s[:dot].x = s[:cx] + raw_x * s[:max_offset]
  s[:dot].y = s[:cy] + raw_y * s[:max_offset]
  s[:dot].color = (adjusted_x != 0 || adjusted_y != 0) ? ACCENT : DIM
end

# --- Header -----------------------------------------------------------------

Text.new('GAMEPAD TEST', x: 16, y: 12, size: 16, color: HEAD)
evt_text = readout(W - 80, 12, 'EVT')
hairline(16, 38, W - 16, 38, color: LINE)

# --- Panel layout -----------------------------------------------------------
#
# Left column stacks DEVICE on top of EVENT LOG (260px wide — log entries
# never run wider than that). Right column is one tall CONTROLLER panel
# that takes the full content height.

PAD       = 16
GAP       = 8
TOP_Y     = 50
LEFT_W    = 260
DEVICE_H  = 350
RIGHT_W   = W - PAD * 2 - GAP - LEFT_W

X_DEV = PAD
X_LOG = PAD
X_BTN = PAD + LEFT_W + GAP

Y_DEV = TOP_Y
Y_LOG = TOP_Y + DEVICE_H + GAP
LOG_H = H - PAD - Y_LOG

CONTROLLER_H = H - PAD - TOP_Y

# --- DEVICE -----------------------------------------------------------------

frame(X_DEV, Y_DEV, LEFT_W, DEVICE_H)
label(X_DEV + 10, Y_DEV + 8, '[ DEVICE ]')

status_text = Text.new('DISCONNECTED', x: X_DEV + 16, y: Y_DEV + 36,
                       size: 24, color: DIM)
label(X_DEV + 16, Y_DEV + 84, 'NAME')
name_text     = Text.new('—', x: X_DEV + 16, y: Y_DEV + 100, size: 16, color: TEXT)
label(X_DEV + 16, Y_DEV + 130, 'ID')
id_text       = Text.new('—', x: X_DEV + 16, y: Y_DEV + 146, size: 16, color: TEXT)
label(X_DEV + 16, Y_DEV + 176, 'TYPE')
type_text     = Text.new('—', x: X_DEV + 16, y: Y_DEV + 192, size: 16, color: TEXT)
label(X_DEV + 16, Y_DEV + 222, 'DEAD ZONE')
deadzone_text = Text.new('—', x: X_DEV + 16, y: Y_DEV + 238, size: 16, color: TEXT)

# Running max of |raw| per axis. Useful for choosing a deadzone — let the
# pad sit untouched and watch what values creep in. R resets the maxes.
label(X_DEV + 16, Y_DEV + 270, 'DRIFT MAX')
label(X_DEV + LEFT_W - 70, Y_DEV + 270, 'press R to reset', size: 9)

def drift_row(x, y, label_text)
  Text.new(label_text, x: x, y: y + 4, size: 10, color: DIM)
  Text.new('0.000', x: x + 22, y: y, size: 12, color: TEXT)
end

max_lx_text = drift_row(X_DEV + 16,  Y_DEV + 290, 'LX')
max_ly_text = drift_row(X_DEV + 130, Y_DEV + 290, 'LY')
max_rx_text = drift_row(X_DEV + 16,  Y_DEV + 308, 'RX')
max_ry_text = drift_row(X_DEV + 130, Y_DEV + 308, 'RY')
max_lt_text = drift_row(X_DEV + 16,  Y_DEV + 326, 'LT')
max_rt_text = drift_row(X_DEV + 130, Y_DEV + 326, 'RT')

# --- CONTROLLER -------------------------------------------------------------

frame(X_BTN, TOP_Y, RIGHT_W, CONTROLLER_H)
label(X_BTN + 10, TOP_Y + 8, '[ CONTROLLER ]')

# Two outer columns mirror the back of a real pad — left column stacks
# LT, LB, dpad, LS; right column stacks RT, RB, face cluster, RS.
# System buttons (BACK / GUIDE / START) sit centered between the
# clusters at the cluster centerline.
LCOL_X = X_BTN + 100
RCOL_X = X_BTN + RIGHT_W - 100
SYS_CX = X_BTN + RIGHT_W / 2

TRIG_LABEL_Y = TOP_Y + 30
TRIG_TOP_Y   = TOP_Y + 44
TRIG_W       = 36
TRIG_H       = 80
TRIG_VAL_Y   = TRIG_TOP_Y + TRIG_H + 6
SHOULDER_Y   = TOP_Y + 152
SHOULDER_W   = 70
SHOULDER_H   = 26
CLUSTER_CY   = TOP_Y + 240
DCELL        = 32
FACE_R       = 18
FACE_OFFSET  = 34
STICK_LABEL_Y = TOP_Y + 306
STICK_CY     = TOP_Y + 378
STICK_R      = 50
STICK_DOT_R  = 10
STICK_VAL_Y  = STICK_CY + STICK_R + 10

# --- Triggers ---
left_trigger  = trigger_widget(LCOL_X - TRIG_W / 2, TRIG_TOP_Y, TRIG_W, TRIG_H)
right_trigger = trigger_widget(RCOL_X - TRIG_W / 2, TRIG_TOP_Y, TRIG_W, TRIG_H)
text_at(LCOL_X, TRIG_LABEL_Y, 'LT')
text_at(RCOL_X, TRIG_LABEL_Y, 'RT')
left_trigger_value  = text_at(LCOL_X, TRIG_VAL_Y, '0.00', size: 11, color: TEXT)
right_trigger_value = text_at(RCOL_X, TRIG_VAL_Y, '0.00', size: 11, color: TEXT)

# --- Shoulders ---
btn_cells = {}
btn_cells[:left_shoulder]  = button_cell(LCOL_X - SHOULDER_W / 2, SHOULDER_Y,
                                         SHOULDER_W, SHOULDER_H, 'LB')
btn_cells[:right_shoulder] = button_cell(RCOL_X - SHOULDER_W / 2, SHOULDER_Y,
                                         SHOULDER_W, SHOULDER_H, 'RB')

# --- DPAD diamond (cells) ---
def diamond_cells(cx, cy, side)
  half = side / 2
  {
    top:    [cx - half,        cy - half - side],
    bottom: [cx - half,        cy + half],
    left:   [cx - half - side, cy - half],
    right:  [cx + half,        cy - half]
  }
end

dpad = diamond_cells(LCOL_X, CLUSTER_CY, DCELL)
btn_cells[:dpad_up]    = button_cell(*dpad[:top],    DCELL, DCELL, 'U')
btn_cells[:dpad_down]  = button_cell(*dpad[:bottom], DCELL, DCELL, 'D')
btn_cells[:dpad_left]  = button_cell(*dpad[:left],   DCELL, DCELL, 'L')
btn_cells[:dpad_right] = button_cell(*dpad[:right],  DCELL, DCELL, 'R')

# --- Face circles ---
btn_cells[:north] = button_circle(RCOL_X,                 CLUSTER_CY - FACE_OFFSET,
                                  FACE_R, 'N')
btn_cells[:south] = button_circle(RCOL_X,                 CLUSTER_CY + FACE_OFFSET,
                                  FACE_R, 'S')
btn_cells[:west]  = button_circle(RCOL_X - FACE_OFFSET,   CLUSTER_CY,
                                  FACE_R, 'W')
btn_cells[:east]  = button_circle(RCOL_X + FACE_OFFSET,   CLUSTER_CY,
                                  FACE_R, 'E')

# --- System (BACK / GUIDE / START) ---
SYS_W   = 56
SYS_H   = 22
SYS_GAP = 6
sys_total = SYS_W * 3 + SYS_GAP * 2
sys_x0    = SYS_CX - sys_total / 2
sys_y     = CLUSTER_CY - SYS_H / 2
btn_cells[:back]  = button_cell(sys_x0,                          sys_y,
                                SYS_W, SYS_H, 'BACK')
btn_cells[:guide] = button_cell(sys_x0 + SYS_W + SYS_GAP,        sys_y,
                                SYS_W, SYS_H, 'GUIDE')
btn_cells[:start] = button_cell(sys_x0 + (SYS_W + SYS_GAP) * 2,  sys_y,
                                SYS_W, SYS_H, 'START')

# --- Rumble (mouse-clickable) ---
# Sits in the dead space between the trigger widgets. One declarative
# Button covers frame, fill, label, hit area, and press tint. Rumble is
# a silent no-op if the pad doesn't support it.
RUMBLE_W = 80
RUMBLE_H = 26
RUMBLE_X = SYS_CX - RUMBLE_W / 2
RUMBLE_Y = TOP_Y + 68
rumble_btn = Button.new(
  x:                   RUMBLE_X,
  y:                   RUMBLE_Y,
  width:               RUMBLE_W,
  height:              RUMBLE_H,
  label:               'RUMBLE',
  label_size:          11,
  color:               BG,
  stroke_color:        LINE_HI,
  stroke_width:        1,
  label_color:         DIM,
  pressed_color:       ACCENT,
  pressed_label_color: BG
)

# --- Sticks ---
left_stick  = stick_widget(LCOL_X, STICK_CY, STICK_R, STICK_DOT_R)
right_stick = stick_widget(RCOL_X, STICK_CY, STICK_R, STICK_DOT_R)
text_at(LCOL_X, STICK_LABEL_Y, 'LS')
text_at(RCOL_X, STICK_LABEL_Y, 'RS')
left_stick_value  = text_at(LCOL_X, STICK_VAL_Y, '+0.000, +0.000', size: 11, color: TEXT)
right_stick_value = text_at(RCOL_X, STICK_VAL_Y, '+0.000, +0.000', size: 11, color: TEXT)

# --- EVENT LOG --------------------------------------------------------------

frame(X_LOG, Y_LOG, LEFT_W, LOG_H)
label(X_LOG + 10, Y_LOG + 8, '[ EVENT LOG ]')
label(X_LOG + LEFT_W - 80, Y_LOG + 8, 'newest first', size: 9)

LOG_LINES = ((LOG_H - 28) / 14).to_i
log_lines = LOG_LINES.times.map do |i|
  Text.new('', x: X_LOG + 16, y: Y_LOG + 28 + i * 14, size: 11, color: DIM)
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

# --- State + handlers -------------------------------------------------------

current_pad = nil
event_count = 0

max_drift = { left_x: 0.0, left_y: 0.0, right_x: 0.0, right_y: 0.0,
              left_trigger: 0.0, right_trigger: 0.0 }
max_text = { left_x: max_lx_text, left_y: max_ly_text,
             right_x: max_rx_text, right_y: max_ry_text,
             left_trigger: max_lt_text, right_trigger: max_rt_text }

reset_drift = lambda do
  max_drift.each_key { |k| max_drift[k] = 0.0 }
  max_text.each_value { |t| t.content = '0.000' }
end

reset_axis_widgets = lambda do
  update_trigger(left_trigger,  0.0, 0.0)
  update_trigger(right_trigger, 0.0, 0.0)
  update_stick(left_stick,  0, 0, 0, 0)
  update_stick(right_stick, 0, 0, 0, 0)
  left_trigger_value.content  = '0.00'
  right_trigger_value.content = '0.00'
  left_stick_value.content    = '+0.000, +0.000'
  right_stick_value.content   = '+0.000, +0.000'
end

on :gamepad_connect do |pad|
  next if current_pad

  current_pad = pad
  status_text.content   = 'CONNECTED'
  status_text.color     = ACCENT
  name_text.content     = pad.name
  id_text.content       = pad.id.to_s
  type_text.content     = pad.type.to_s
  deadzone_text.content = format('%.2f', pad.dead_zone)
  reset_drift.call
  event_count += 1
  evt_text.content = event_count.to_s
  push_log(log_buffer, log_lines, "connect    #{pad.name} (id=#{pad.id})")
end

on :gamepad_disconnect do |pad|
  next unless pad.equal?(current_pad)

  current_pad = nil
  status_text.content   = 'DISCONNECTED'
  status_text.color     = DIM
  name_text.content     = '—'
  id_text.content       = '—'
  type_text.content     = '—'
  deadzone_text.content = '—'
  btn_cells.each_value do |c|
    c[:fill].color = BG
    c[:text].color = DIM
  end
  reset_axis_widgets.call
  reset_drift.call
  event_count += 1
  evt_text.content = event_count.to_s
  push_log(log_buffer, log_lines, "disconnect #{pad.name}")
end

on :key_down do |event|
  reset_drift.call if event.key == :r
end

rumble_btn.on(:click) do
  pad = current_pad
  next unless pad
  pad.rumble(strength: 0.8, duration: 0.4)
  push_log(log_buffer, log_lines, 'rumble')
end

on :gamepad_button_down do |pad, button|
  next unless pad.equal?(current_pad)

  cell = btn_cells[button]
  if cell
    cell[:fill].color = ACCENT
    cell[:text].color = BG
  end
  event_count += 1
  evt_text.content = event_count.to_s
  push_log(log_buffer, log_lines, "down  #{button}")
end

on :gamepad_button_up do |pad, button|
  next unless pad.equal?(current_pad)

  cell = btn_cells[button]
  if cell
    cell[:fill].color = BG
    cell[:text].color = DIM
  end
  event_count += 1
  evt_text.content = event_count.to_s
  push_log(log_buffer, log_lines, "up    #{button}")
end

# Axes are polled rather than logged — events fire continuously while a
# stick is off-center, so a scrolling log would flood. The widgets are
# the live readout; the log stays focused on discrete button events.
update do
  pad = current_pad
  next unless pad

  track_max = lambda do |axis, raw|
    mag = raw.abs
    if mag > max_drift[axis]
      max_drift[axis] = mag
      max_text[axis].content = format('%.3f', mag)
    end
  end

  rlx = pad.axis(:left_x,  raw: true)
  rly = pad.axis(:left_y,  raw: true)
  alx = pad.axis(:left_x)
  aly = pad.axis(:left_y)
  update_stick(left_stick, rlx, rly, alx, aly)
  left_stick_value.content = format('%+.3f, %+.3f', rlx, rly)
  track_max.call(:left_x, rlx)
  track_max.call(:left_y, rly)

  rrx = pad.axis(:right_x, raw: true)
  rry = pad.axis(:right_y, raw: true)
  arx = pad.axis(:right_x)
  ary = pad.axis(:right_y)
  update_stick(right_stick, rrx, rry, arx, ary)
  right_stick_value.content = format('%+.3f, %+.3f', rrx, rry)
  track_max.call(:right_x, rrx)
  track_max.call(:right_y, rry)

  rlt = pad.axis(:left_trigger,  raw: true)
  alt = pad.axis(:left_trigger)
  update_trigger(left_trigger, rlt, alt)
  left_trigger_value.content = format('%.2f', alt)
  track_max.call(:left_trigger, rlt)

  rrt = pad.axis(:right_trigger, raw: true)
  art = pad.axis(:right_trigger)
  update_trigger(right_trigger, rrt, art)
  right_trigger_value.content = format('%.2f', art)
  track_max.call(:right_trigger, rrt)
end

show
