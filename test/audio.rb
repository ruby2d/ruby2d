# Audio
#
# Interactive test for audio playback. WAV/MP3/OGG/FLAC for both sounds
# and music with format selectors, transport controls (play, pause,
# resume, stop, fade out), loop toggle, per-source volume sliders, and
# a global mixer. The status row at the bottom reports the most recent
# action plus reported audio lengths.

require 'ruby2d'

W = 700
H = 440

set title: 'Ruby 2D — Audio', width: W, height: H
set close_on_esc: true

# --- Palette ----------------------------------------------------------------

BG      = [0.05, 0.06, 0.07, 1].freeze
LINE    = [0.20, 0.22, 0.24, 1].freeze
LINE_HI = [0.35, 0.38, 0.42, 1].freeze
DIM     = [0.40, 0.42, 0.44, 1].freeze
TEXT    = [0.75, 0.78, 0.80, 1].freeze
HEAD    = [0.92, 0.94, 0.96, 1].freeze
ACCENT  = [0.45, 0.95, 0.70, 1].freeze

# Channel hues for the volume sliders — distinguishable from each other
# and from ACCENT so the live status readout stays the only mint element.
WARM    = [0.95, 0.55, 0.40, 1].freeze   # sound
TEAL    = [0.30, 0.80, 0.85, 1].freeze   # music
AMBER   = [0.95, 0.85, 0.30, 1].freeze   # mixer

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

# Text centered inside a rect — uses Text's actual rendered width/height.
def text_in_rect(rx, ry, rw, rh, content, size: 11, color: DIM)
  t = Text.new(content, x: 0, y: 0, size: size, color: color)
  t.x = rx + (rw - t.width) / 2
  t.y = ry + (rh - t.height) / 2
  t
end

# Toggle cell: rectangle + frame + centered label that flips between an
# inactive (BG fill, DIM label) and active (ACCENT fill, BG label) state.
# Click handler receives a setter so the caller decides whether to flip
# the cell, set it active, or coordinate with siblings (radio behavior).
def toggle_cell(x, y, w, h, content, active: false, &on_click)
  fill = Rectangle.new(x: x + 1, y: y + 1, width: w - 2, height: h - 2,
                       color: active ? ACCENT : BG)
  frame(x, y, w, h, color: LINE_HI)
  txt = text_in_rect(x, y, w, h, content, size: 11,
                     color: active ? BG : DIM)
  set_active = lambda do |on|
    fill.color = on ? ACCENT : BG
    txt.color  = on ? BG : DIM
  end
  fill.on(click: :left) { on_click.call(set_active) }
  { fill: fill, text: txt, set_active: set_active }
end

# --- Header -----------------------------------------------------------------

Text.new('AUDIO TEST', x: 16, y: 12, size: 16, color: HEAD)
hairline(16, 38, W - 16, 38, color: LINE)

# --- Audio sources ---------------------------------------------------------

formats = %w[wav mp3 ogg flac]
sounds  = formats.map { |f| [f, Audio.new("#{Ruby2D.test_audio}/sound.#{f}")] }.to_h
music   = formats.map { |f| [f, Audio.new("#{Ruby2D.test_audio}/music.#{f}")] }.to_h

current_sound = 'wav'
current_music = 'wav'
active_music  = music[current_music]
loop_on       = false

# --- Status (defined early so handlers can update it) ----------------------

PAD      = 16
STATUS_Y = H - 28

status_text = Text.new('Ready', x: PAD, y: STATUS_Y, size: 13, color: ACCENT)
length_text = Text.new('', x: 0, y: STATUS_Y + 3, size: 11, color: DIM)

set_status = lambda do |msg|
  status_text.content = msg
end

fmt_length = lambda do |audio|
  len = audio.length
  len > 0 ? "#{len}s" : '?'
end

update_length = lambda do
  length_text.content = "sound: #{fmt_length.call(sounds[current_sound])}    " \
                        "music: #{fmt_length.call(music[current_music])}"
  length_text.x = W - PAD - length_text.width
end
update_length.call

# --- Panel layout -----------------------------------------------------------

PANEL_X = PAD
PANEL_W = W - PAD * 2

FORMAT_Y    = 50
FORMAT_H    = 92
TRANSPORT_Y = FORMAT_Y + FORMAT_H + 8
TRANSPORT_H = 92
MIXER_Y     = TRANSPORT_Y + TRANSPORT_H + 8
MIXER_H     = STATUS_Y - MIXER_Y - 18

# --- FORMAT -----------------------------------------------------------------

frame(PANEL_X, FORMAT_Y, PANEL_W, FORMAT_H)
label(PANEL_X + 10, FORMAT_Y + 8, '[ FORMAT ]')

FMT_CELL_W   = 60
FMT_CELL_H   = 26
FMT_CELL_GAP = 6

build_format_row = lambda do |y, current, &on_change|
  cells = {}
  total_w = FMT_CELL_W * formats.length + FMT_CELL_GAP * (formats.length - 1)
  fx0 = PANEL_X + PANEL_W - PAD - total_w
  formats.each_with_index do |f, i|
    fx = fx0 + i * (FMT_CELL_W + FMT_CELL_GAP)
    cells[f] = toggle_cell(fx, y, FMT_CELL_W, FMT_CELL_H, f.upcase,
                           active: f == current) do |_set_active|
      cells.each { |k, c| c[:set_active].call(k == f) }
      on_change.call(f)
    end
  end
  cells
end

label(PANEL_X + 16, FORMAT_Y + 36, 'sound', size: 11, color: TEXT)
build_format_row.call(FORMAT_Y + 30, current_sound) do |f|
  current_sound = f
  update_length.call
  set_status.call("sound format: #{f.upcase}")
end

label(PANEL_X + 16, FORMAT_Y + 68, 'music', size: 11, color: TEXT)
build_format_row.call(FORMAT_Y + 62, current_music) do |f|
  active_music.stop
  current_music = f
  active_music = music[current_music]
  active_music.loop = loop_on
  update_length.call
  set_status.call("music format: #{f.upcase}")
end

# --- TRANSPORT --------------------------------------------------------------

frame(PANEL_X, TRANSPORT_Y, PANEL_W, TRANSPORT_H)
label(PANEL_X + 10, TRANSPORT_Y + 8, '[ TRANSPORT ]')

TRANSPORT_BTN_H = 26
TRANSPORT_BTN_X = PANEL_X + 80

# Sound row — single Play button.
label(PANEL_X + 16, TRANSPORT_Y + 36, 'sound', size: 11, color: TEXT)
Button.new(x: TRANSPORT_BTN_X, y: TRANSPORT_Y + 30, width: 100,
           height: TRANSPORT_BTN_H,
           label: 'PLAY', label_size: 11,
           color: BG, stroke_color: LINE_HI, stroke_width: 1,
           label_color: TEXT,
           pressed_color: ACCENT, pressed_label_color: BG) do
  sounds[current_sound].play
  set_status.call("playing sound (#{current_sound.upcase})")
end

# Music row — five transport buttons + loop toggle.
label(PANEL_X + 16, TRANSPORT_Y + 68, 'music', size: 11, color: TEXT)
music_btn_y = TRANSPORT_Y + 62

music_btn_specs = [
  ['PLAY',     60, proc {
    active_music.play
    set_status.call("playing music (#{current_music.upcase})")
  }],
  ['PAUSE',    60, proc {
    active_music.pause
    set_status.call('music paused')
  }],
  ['RESUME',   60, proc {
    active_music.resume
    set_status.call('music resumed')
  }],
  ['STOP',     60, proc {
    active_music.stop
    set_status.call('music stopped')
  }],
  ['FADE OUT', 80, proc {
    active_music.stop(2000)
    set_status.call('music fading out (2s)')
  }]
]

bx = TRANSPORT_BTN_X
music_btn_specs.each do |btn_label, w, action|
  Button.new(x: bx, y: music_btn_y, width: w, height: TRANSPORT_BTN_H,
             label: btn_label, label_size: 11,
             color: BG, stroke_color: LINE_HI, stroke_width: 1,
             label_color: TEXT,
             pressed_color: ACCENT, pressed_label_color: BG, &action)
  bx += w + 6
end

# Loop toggle (radio-less — just flips its own state).
toggle_cell(bx + 8, music_btn_y, 60, TRANSPORT_BTN_H, 'LOOP') do |set_active|
  loop_on = !loop_on
  active_music.loop = loop_on
  set_active.call(loop_on)
  set_status.call("loop #{loop_on ? 'enabled' : 'disabled'}")
end

# --- MIXER ------------------------------------------------------------------

frame(PANEL_X, MIXER_Y, PANEL_W, MIXER_H)
label(PANEL_X + 10, MIXER_Y + 8, '[ MIXER ]')

SLIDER_LABEL_X = PANEL_X + 16
SLIDER_X       = PANEL_X + 80
SLIDER_VAL_W   = 40
SLIDER_W       = PANEL_W - (SLIDER_X - PANEL_X) - 16 - SLIDER_VAL_W
SLIDER_H       = 18

# A click anywhere on the bar (background or filled portion) sets the
# volume; subsequent :drag events on the originally-pressed rect keep
# tracking the cursor's absolute x.
build_slider = lambda do |y, name, color, &on_change|
  label(SLIDER_LABEL_X, y + 4, name, size: 11, color: TEXT)
  bg = Rectangle.new(x: SLIDER_X, y: y, width: SLIDER_W, height: SLIDER_H,
                     color: BG)
  fill = Rectangle.new(x: SLIDER_X, y: y, width: SLIDER_W, height: SLIDER_H,
                       color: color)
  frame(SLIDER_X, y, SLIDER_W, SLIDER_H, color: LINE_HI)
  vol_text = Text.new('1.0', x: SLIDER_X + SLIDER_W + 8, y: y + 1,
                      size: 13, color: TEXT)

  set_volume = lambda do |vol|
    fill.width = vol * SLIDER_W
    vol_text.content = vol.round(2).to_s
    on_change.call(vol)
  end

  set_from_x = lambda do |ex|
    rel = ex - SLIDER_X
    set_volume.call((rel.to_f / SLIDER_W).clamp(0.0, 1.0))
  end

  [bg, fill].each do |r|
    r.on(:mouse_down) { |e| set_from_x.call(e.x) }
    r.on(:drag)       { |e| set_from_x.call(e.x) }
  end
end

slider_top = MIXER_Y + 36
slider_gap = 18

build_slider.call(slider_top, 'sound', WARM) do |vol|
  sounds[current_sound].volume = vol
  set_status.call("sound volume: #{vol}")
end
build_slider.call(slider_top + SLIDER_H + slider_gap, 'music', TEAL) do |vol|
  active_music.volume = vol
  set_status.call("music volume: #{vol}")
end
build_slider.call(slider_top + (SLIDER_H + slider_gap) * 2, 'mixer', AMBER) do |vol|
  Audio.volume = vol
  set_status.call("mixer volume: #{vol}")
end

show
