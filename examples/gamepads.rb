# Gamepads
# Connect one or more controllers, claim a color, then drop into the field.
#
# Left/right moves your cursor along the color row; south locks your color
# in. Each color can be held by only one player — if the one you're hovering
# is already taken the lock is refused, and east frees it again. Once every
# joined player is locked in, any pad presses START to launch (a single
# player is enough). In the field the left stick or dpad moves your square,
# and any face button gives it a pop and rumbles the pad. Press `r` to
# return to the color picker.

require 'ruby2d'

# === Tunables ===

WIDTH       = 720    # window width in pixels
HEIGHT      = 480    # window height in pixels
MAX_PLAYERS = 4      # most players (and color slots) at once
COLOR_W     = 80     # color swatch size (px)
COLOR_GAP   = 16     # gap between color swatches
COLOR_Y     = 140    # color row top y-coord
RING_PAD    = 6      # hover-ring border thickness around a swatch (px)
MARKER_BASE = 250    # first (top) marker row y-coord
MARKER_ROW  = 32     # vertical spacing per stacked marker row
SQ_SIZE     = 60     # play-screen square size (px)
SPEED       = 280.0  # max movement speed in play (px/sec)
POP_SCALE   = 1.4    # square size multiplier at the peak of a pop
POP_S       = 0.18   # how long a button pop lasts (seconds)
RUMBLE_STR  = 0.6    # rumble strength on a button pop (0.0..1.0)
RUMBLE_S    = 0.2    # rumble duration on a button pop (seconds)

TEXT_FAINT  = '#6b7280'  # dim label on an empty slot
TEXT_NORMAL = '#cbd5e1'  # secondary text (hints, markers)
TEXT_BRIGHT = '#f5f5f4'  # primary text / a hovering marker
TEXT_WARN   = '#f87171'  # a blocked pick (color already taken)

COLORS = [
  '#06d6a0',  # teal
  '#ff8c42',  # orange
  '#3b82f6',  # blue
  '#a78bfa',  # purple
  '#fbbf24',  # yellow
  '#22c55e'   # green
].freeze

FACE_BUTTONS = %i[south east west north].freeze

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ Gamepads',
    width: WIDTH, height: HEIGHT, background: '#1b1b2f'
set close_on_esc: true

# === Layout helpers ===

colors_total_w = COLORS.size * COLOR_W + (COLORS.size - 1) * COLOR_GAP
colors_x0 = (WIDTH - colors_total_w) / 2
color_x = ->(i) { colors_x0 + i * (COLOR_W + COLOR_GAP) }

# === Mutable state ===

# slots[i] is the Gamepad in slot i (nil if open). players[pad] holds the
# per-player UI state — color index and ready flag. Each pad drives its
# own cursor independently.
slots = Array.new(MAX_PLAYERS, nil)
players = {}
state = :select   # :select or :playing
arrivals = 0      # bumped on each pick; stamps arrival order within a column

# Play-field state, per slot: the square's center and the end time of its
# current pop animation (0.0 = not popping).
centers = Array.new(MAX_PLAYERS)
pops = Array.new(MAX_PLAYERS, 0.0)

# === Persistent renderables ===

title = Text.new('Pick your color', x: 30, y: 40, size: 28, color: TEXT_BRIGHT)
hint  = Text.new('', x: 0, y: HEIGHT - 44, size: 16, color: TEXT_NORMAL)

# Highlight rings — drawn BEFORE the color swatches so the swatch sits on
# top, leaving a visible border peeking out. Shown only when a non-ready
# player is hovering that color.
rings = COLORS.each_with_index.map do |_, i|
  Rectangle.new(
    x: color_x.call(i) - RING_PAD, y: COLOR_Y - RING_PAD,
    width: COLOR_W + RING_PAD * 2, height: COLOR_W + RING_PAD * 2,
    color: TEXT_BRIGHT, visible: false
  )
end

# The color row — fixed Squares, always visible during :select.
color_squares = COLORS.each_with_index.map do |hex, i|
  Square.new(x: color_x.call(i), y: COLOR_Y, size: COLOR_W, color: hex)
end

# Per-player cursor — a Text label that positions itself under the color the
# player is hovering, stacking below anyone who picked the same color (see
# `update_all_markers`). Hidden until the slot is filled.
markers = MAX_PLAYERS.times.map do
  Text.new('', x: 0, y: MARKER_BASE, size: 16, color: TEXT_NORMAL, visible: false)
end

play_squares = MAX_PLAYERS.times.map do
  Square.new(x: 0, y: 0, size: SQ_SIZE, color: '#000000', visible: false)
end

# === Logic helpers ===

# True if some other player has already locked the given color index.
locked_by_other = lambda do |pad, color_idx|
  players.any? { |other, p| !other.equal?(pad) && p[:ready] && p[:sel] == color_idx }
end

# Show a ring around any color a non-ready player is currently hovering.
update_rings = lambda do
  COLORS.size.times do |i|
    rings[i].visible = players.any? { |_, p| !p[:ready] && p[:sel] == i }
  end
end

# Lay out every marker. Within a color, players stack in the order they
# arrived on it — first there takes the top row, later arrivals append below
# — so a marker only moves when its own player changes color (its number may
# then sit out of order in the column). Repaints the whole board, since one
# move can shift a column.
update_all_markers = lambda do
  MAX_PLAYERS.times { |i| markers[i].hide if slots[i].nil? }

  rows = Hash.new(0)   # color index => next free stack row
  filled = (0...MAX_PLAYERS).select { |i| slots[i] }
  filled.sort_by { |i| players[slots[i]][:seq] }.each do |i|
    m = markers[i]
    p = players[slots[i]]
    sel = p[:sel]

    if p[:ready]
      m.color = COLORS[sel]
      m.content = "P#{i + 1}  ✓"
    elsif locked_by_other.call(slots[i], sel)
      m.color = TEXT_WARN
      m.content = "P#{i + 1}  ×"
    else
      m.color = TEXT_BRIGHT
      m.content = "P#{i + 1}  ↑"
    end

    # Center under the chosen color (width is known after the content
    # assignment); drop to the next free row in that color's stack.
    row = rows[sel]
    rows[sel] += 1
    m.x = color_x.call(sel) + (COLOR_W - m.width) / 2
    m.y = MARKER_BASE + row * MARKER_ROW
    m.show
  end
end

refresh_hint = lambda do
  hint.content = case state
                 when :select
                   joined = players.size
                   ready  = players.values.count { |p| p[:ready] }
                   if joined.zero?
                     'Connect a controller to join'
                   elsif ready < joined
                     "#{ready}/#{joined} locked in  ·  DPAD move  ·  SOUTH lock  ·  EAST undo"
                   else
                     'All locked in  ·  press START to launch'
                   end
                 when :playing
                   'STICK / DPAD move  ·  FACE BUTTON pop  ·  R pick again'
                 end
  # Re-center under the color row now that the content's width is known.
  hint.x = (WIDTH - hint.width) / 2
end

show_select = lambda do
  title.show
  color_squares.each(&:show)
  update_rings.call
  update_all_markers.call
  play_squares.each(&:hide)
end

show_play = lambda do
  title.hide
  color_squares.each(&:hide)
  rings.each(&:hide)
  markers.each(&:hide)

  visible_count = slots.compact.size
  step = WIDTH / (visible_count + 1)
  shown = 0
  slots.each_with_index do |pad, i|
    next if pad.nil?
    shown += 1
    centers[i] = [step * shown, HEIGHT / 2]
    pops[i] = 0.0
    sq = play_squares[i]
    sq.color = COLORS[players[pad][:sel]]
    sq.size = SQ_SIZE
    sq.x = centers[i][0] - SQ_SIZE / 2
    sq.y = centers[i][1] - SQ_SIZE / 2
    sq.show
  end
end

reset = lambda do
  players.each_value { |p| p[:ready] = false }   # return to the picker unlocked
  state = :select
  show_select.call
  refresh_hint.call
end

reset.call

# === Input handlers ===

on :gamepad_connect do |pad|
  next unless state == :select
  i = slots.index(nil) or next
  slots[i] = pad
  players[pad] = { sel: i % COLORS.size, ready: false, seq: (arrivals += 1) }
  update_all_markers.call
  update_rings.call
  refresh_hint.call
end

on :gamepad_disconnect do |pad|
  i = slots.index(pad) or next
  slots[i] = nil
  players.delete(pad)
  case state
  when :select
    # A leaver frees its color and shifts everyone stacked below it up a row,
    # so repaint the whole board.
    update_all_markers.call
    update_rings.call
  when :playing
    play_squares[i].hide
  end
  refresh_hint.call
end

on :gamepad_button_down do |pad, button|
  case state
  when :select
    player = players[pad] or next

    case button
    when :dpad_left
      next if player[:ready]
      player[:sel] = (player[:sel] - 1) % COLORS.size
      player[:seq] = (arrivals += 1)   # re-arrive: append to the new column
      update_all_markers.call
      update_rings.call
    when :dpad_right
      next if player[:ready]
      player[:sel] = (player[:sel] + 1) % COLORS.size
      player[:seq] = (arrivals += 1)   # re-arrive: append to the new column
      update_all_markers.call
      update_rings.call
    when :south
      next if player[:ready]
      next if locked_by_other.call(pad, player[:sel])   # lock refused
      player[:ready] = true
      update_all_markers.call    # other hoverers of this color now show ×
      update_rings.call          # this color's ring drops if no non-ready hoverer remains
      refresh_hint.call
    when :east
      next unless player[:ready]
      player[:ready] = false
      update_all_markers.call    # color is free again — others previously × may unblock
      update_rings.call
      refresh_hint.call
    when :start
      next if players.empty?
      next unless players.values.all? { |p| p[:ready] }
      state = :playing
      show_play.call
      refresh_hint.call
    end

  when :playing
    # Any face button pops the mover's square and rumbles the pad — a quick
    # taste of pairing a visual reaction with haptic feedback.
    next unless FACE_BUTTONS.include?(button)
    i = slots.index(pad) or next
    pops[i] = elapsed + POP_S
    pad.rumble(strength: RUMBLE_STR, duration: RUMBLE_S)
  end
end

on key_down: :r do
  reset.call
end

# === Update ===

update do |dt|
  next unless state == :playing
  now = elapsed
  slots.each_with_index do |pad, i|
    next if pad.nil?

    # Stick or dpad — whichever is pressed harder per axis. Lets pads
    # without sticks (or with drift) still steer.
    sx, sy = pad.axis(:left_x), pad.axis(:left_y)
    dx = (pad.held?(:dpad_right) ? 1.0 : 0.0) - (pad.held?(:dpad_left) ? 1.0 : 0.0)
    dy = (pad.held?(:dpad_down)  ? 1.0 : 0.0) - (pad.held?(:dpad_up)   ? 1.0 : 0.0)
    vx = sx.abs > dx.abs ? sx : dx
    vy = sy.abs > dy.abs ? sy : dy

    cx, cy = centers[i]
    cx = (cx + vx * SPEED * dt).clamp(SQ_SIZE / 2, WIDTH  - SQ_SIZE / 2)
    cy = (cy + vy * SPEED * dt).clamp(SQ_SIZE / 2, HEIGHT - SQ_SIZE / 2)
    centers[i] = [cx, cy]

    # A button press pops the square; the size eases from POP_SCALE back to 1
    # over POP_S. Center-anchored so the square grows in place.
    size = SQ_SIZE
    if now < pops[i]
      k = (pops[i] - now) / POP_S          # 1 → 0 across the pop's life
      size = SQ_SIZE * (1 + (POP_SCALE - 1) * k)
    end

    sq = play_squares[i]
    sq.size = size
    sq.x = cx - size / 2
    sq.y = cy - size / 2
  end
end

show
