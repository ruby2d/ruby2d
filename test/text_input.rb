# Text input
#
# Exercises :text_input, the text_input flag, and :key_repeat. Panels: the
# flag beside SDL's own state with live checks, a field fed by :text_input
# (hold BACKSPACE to repeat), and an event log. Starts on (set before show);
# TAB toggles through `set`, the ON/OFF buttons through the setter.

require 'ruby2d'

W = 900
H = 560

set title: 'Ruby 2D — Text Input', width: W, height: H
set close_on_esc: true
set text_input: true

# --- Palette ----------------------------------------------------------------

BG      = [0.05, 0.06, 0.07, 1].freeze
LINE    = [0.20, 0.22, 0.24, 1].freeze
LINE_HI = [0.35, 0.38, 0.42, 1].freeze
DIM     = [0.40, 0.42, 0.44, 1].freeze
TEXT    = [0.75, 0.78, 0.80, 1].freeze
HEAD    = [0.92, 0.94, 0.96, 1].freeze
ACCENT  = [0.45, 0.95, 0.70, 1].freeze
FAIL    = [0.95, 0.45, 0.40, 1].freeze

set background: BG

# The default font draws about 360 codepoints and leaves the rest blank, so
# typed text uses a wide system font when there is one: input method text
# shows instead of vanishing.
WIDE_FONT  = '/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
TYPED_FONT = File.exist?(WIDE_FONT) ? WIDE_FONT : Font.default

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
  Text.new('0', x: x + 30, y: y, size: 14, color: ACCENT)
end

# One flag row: indicator square, name, ON/OFF value, and where it's read from
def state_row(x, y, name, source)
  dot = Rectangle.new(x: x + 18, y: y + 2, width: 14, height: 14, color: BG)
  frame(x + 18, y + 2, 14, 14, color: LINE_HI)
  label(x + 44, y, name, size: 14, color: TEXT)
  value = Text.new('', x: x + 92, y: y, size: 14)
  label(x + 140, y + 4, source, size: 10)
  { dot: dot, value: value }
end

def paint_row(row, on)
  row[:dot].color     = on ? ACCENT : BG
  row[:value].content = on ? 'ON' : 'OFF'
  row[:value].color   = on ? ACCENT : DIM
end

def paint_check(text, pass, message)
  text.content = "#{pass ? '✓' : '×'}  #{message}"
  text.color   = pass ? ACCENT : FAIL
end

# "é" → "U+00E9", so a character the font can't draw still shows what arrived.
# A long event, such as an input method commit, lists the first few.
def code_points(text, max = 8)
  points = text.chars.first(max).map { |c| format('U+%04X', c.ord) }
  points << '…' if text.length > max
  points.join(' ')
end

def push_log(buffer, lines, str, color)
  buffer.unshift([str, color])
  buffer.pop while buffer.length > lines.length
  lines.each_with_index do |t, i|
    entry = buffer[i]
    t.content = entry ? entry[0] : ''
    t.color   = entry ? entry[1] : DIM
    t.opacity = (1.0 - (i.to_f / lines.length)).clamp(0.3, 1.0)
  end
end

# --- Header -----------------------------------------------------------------

Text.new('TEXT INPUT TEST', x: 16, y: 12, size: 16, color: HEAD)

key_count_text    = readout(W - 250, 12, 'KEY')
repeat_count_text = readout(W - 170, 12, 'REP')
text_count_text   = readout(W - 90,  12, 'TXT')

hairline(16, 38, W - 16, 38)

# --- Panel layout -----------------------------------------------------------

PAD     = 16
GAP     = 8
TOP_Y   = 50
PANEL_H = 232
STATE_W = 300

X_STATE = PAD
X_FIELD = PAD + STATE_W + GAP
FIELD_W = W - PAD - X_FIELD

LOG_Y = TOP_Y + PANEL_H + GAP
LOG_H = H - LOG_Y - PAD

# --- STATE ------------------------------------------------------------------

frame(X_STATE, TOP_Y, STATE_W, PANEL_H)
label(X_STATE + 10, TOP_Y + 8, '[ STATE ]')

flag_row = state_row(X_STATE, TOP_Y + 34, 'FLAG', 'get :text_input')
sdl_row  = state_row(X_STATE, TOP_Y + 62, 'SDL',  'SDL_TextInputActive')

# --- FIELD ------------------------------------------------------------------

frame(X_FIELD, TOP_Y, FIELD_W, PANEL_H)
label(X_FIELD + 10, TOP_Y + 8, '[ FIELD ]')

FIELD_TEXT_W = FIELD_W - 44
FIELD_TAIL   = 48   # most characters tried when trimming text to the field

field = Text.new('', x: X_FIELD + 18, y: TOP_Y + 38, size: 28, font: TYPED_FONT, color: HEAD)
caret = Rectangle.new(x: X_FIELD + 18, y: TOP_Y + 43, width: 2, height: 30, color: ACCENT)
hairline(X_FIELD + 16, TOP_Y + 84, X_FIELD + FIELD_W - 16, TOP_Y + 84, color: LINE_HI)

label(X_FIELD + 18, TOP_Y + 98, 'CHARS')
chars_text = Text.new('0', x: X_FIELD + 58, y: TOP_Y + 94, size: 14, color: ACCENT)
label(X_FIELD + 100, TOP_Y + 98, 'BYTES')
bytes_text = Text.new('0', x: X_FIELD + 140, y: TOP_Y + 94, size: 14, color: ACCENT)

label(X_FIELD + 18, TOP_Y + 126, 'LAST TEXT EVENT')
last_text   = Text.new('—', x: X_FIELD + 18, y: TOP_Y + 140, size: 22, font: TYPED_FONT, color: ACCENT)
last_points = Text.new('', x: X_FIELD + 18, y: TOP_Y + 172, size: 11, color: TEXT)

label(X_FIELD + 18, TOP_Y + PANEL_H - 22,
      'BACKSPACE deletes (hold to repeat) · RETURN clears · try Option+E then E, and an input method')

# --- EVENT LOG --------------------------------------------------------------

frame(PAD, LOG_Y, W - PAD * 2, LOG_H)
label(PAD + 10, LOG_Y + 8, '[ EVENT LOG ]')
label(W - PAD - 90, LOG_Y + 8, 'newest first', size: 9)

LOG_LINES = ((LOG_H - 28) / 16).to_i
log_lines = LOG_LINES.times.map do |i|
  Text.new('', x: PAD + 16, y: LOG_Y + 26 + i * 16, size: 12, font: TYPED_FONT)
end
log_buffer = []

# --- State + refresh helpers ------------------------------------------------

typed        = ''
key_count    = 0
repeat_count = 0
text_count   = 0
off_count    = 0     # text events that arrived while the flag was off
shown_flag   = nil   # last painted flag and SDL state, to repaint on change
shown_sdl    = nil
first_frame  = true

# Show the tail of the typed text when it's wider than the field. Every try
# re-renders the text, so trimming starts from at most FIELD_TAIL characters
# rather than one render per character of everything typed.
refresh_field = lambda do
  shown = typed
  shown = typed[typed.length - FIELD_TAIL, FIELD_TAIL] if typed.length > FIELD_TAIL
  field.content = shown == typed ? shown : "…#{shown}"
  while field.width > FIELD_TEXT_W && shown.length > 1
    shown = shown[1..]
    field.content = "…#{shown}"
  end
  caret.x = field.x + field.width + 2
  chars_text.content = typed.length.to_s
  bytes_text.content = typed.bytesize.to_s
end

# Consecutive repeats of one key share a log line with a running count, so a
# held Backspace or arrow doesn't scroll everything else away. A held letter
# alternates with its text lines, so its repeats don't collapse.
log_repeat = lambda do |key|
  top = log_buffer.first
  if top && top[2] == key
    top[3] += 1
    top[0] = "rep   #{key.inspect}   ×#{top[3]}"
    log_lines[0].content = top[0]
  else
    push_log(log_buffer, log_lines, "rep   #{key.inspect}", TEXT)
    log_buffer.first.push(key, 1)
  end
end

# Buttons go through the setter and TAB through `set`, so both paths get used
toggle = lambda do |on, via|
  if via == 'TAB'
    set text_input: on
    push_log(log_buffer, log_lines, "set   set text_input: #{on}   (TAB)", HEAD)
  else
    Window.current.text_input = on
    push_log(log_buffer, log_lines, "set   Window.current.text_input = #{on}   (#{via})", HEAD)
  end
end

label(X_STATE + 18, TOP_Y + 138, 'CHECKS')
check_show  = Text.new('', x: X_STATE + 18, y: TOP_Y + 156, size: 12)
check_match = Text.new('', x: X_STATE + 18, y: TOP_Y + 178, size: 12)
check_off   = Text.new('', x: X_STATE + 18, y: TOP_Y + 200, size: 12)
paint_check(check_off, true, 'no text while off')

Button.new(x: X_STATE + 18, y: TOP_Y + 94, width: 70, height: 28,
           label: 'ON', label_size: 12, color: BG, label_color: TEXT,
           stroke_color: LINE_HI, stroke_width: 1, hover_color: :auto,
           pressed_color: ACCENT, pressed_label_color: BG) do
  toggle.call(true, 'ON button')
end

Button.new(x: X_STATE + 96, y: TOP_Y + 94, width: 70, height: 28,
           label: 'OFF', label_size: 12, color: BG, label_color: TEXT,
           stroke_color: LINE_HI, stroke_width: 1, hover_color: :auto,
           pressed_color: ACCENT, pressed_label_color: BG) do
  toggle.call(false, 'OFF button')
end

label(X_STATE + 180, TOP_Y + 102, 'TAB toggles')

# --- Event handlers ---------------------------------------------------------

on :text_input do |event|
  text_count += 1
  text_count_text.content = text_count.to_s
  last_text.content   = event.text.inspect
  last_points.content = "#{code_points(event.text)}   (#{event.text.length} char#{'s' unless event.text.length == 1})"

  if get(:text_input)
    typed += event.text
    refresh_field.call
    push_log(log_buffer, log_lines, "text  #{event.text.inspect}   #{code_points(event.text)}", ACCENT)
  else
    off_count += 1
    paint_check(check_off, false, "#{off_count} text event#{'s' unless off_count == 1} while off")
    push_log(log_buffer, log_lines, "text  #{event.text.inspect}   arrived while OFF", FAIL)
  end
end

on :key_down do |event|
  key_count += 1
  key_count_text.content = key_count.to_s
  push_log(log_buffer, log_lines, "key   #{event.key.inspect}", TEXT)

  case event.key
  when :tab
    toggle.call(!get(:text_input), 'TAB')
  when :return, :keypad_enter
    if get(:text_input)
      typed = ''
      refresh_field.call
    end
  end
end

on :key_repeat do |event|
  repeat_count += 1
  repeat_count_text.content = repeat_count.to_s
  log_repeat.call(event.key)
end

# The press deletes one character, then the system's key repeat keeps going
on key_down: :backspace, key_repeat: :backspace do
  if get(:text_input)
    typed = typed.chop
    refresh_field.call
  end
end

# --- Per-frame update -------------------------------------------------------

update do
  flag = get(:text_input)
  sdl  = Ruby2D::Ext.window_text_input_active(Window.current)

  # The flag was set before `show`, so SDL should already be on here
  if first_frame
    first_frame = false
    paint_check(check_show, sdl, sdl ? 'set before show: on at first frame' : 'set before show: SDL off at first frame')
  end

  if flag != shown_flag || sdl != shown_sdl
    shown_flag = flag
    shown_sdl  = sdl
    paint_row(flag_row, flag)
    paint_row(sdl_row, sdl)
    paint_check(check_match, flag == sdl, flag == sdl ? 'flag and SDL agree' : 'flag and SDL disagree')
    field.color = flag ? HEAD : DIM
  end

  # The caret only blinks while the field takes text
  caret.visible = flag && (Window.frames / 30).even?
end

show
