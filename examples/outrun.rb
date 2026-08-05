# Out Run
# A pseudo-3D arcade racer, classic Sega-style — a rollercoaster of big hills and near-constant curves.
#
# Up throttles, down brakes, left/right steer. Stay on the asphalt —
# the grass will bog you down. Press `r` to restart. The course is laid
# out as discrete pieces (straights, curves, hills) joined end to end,
# each easing its bend in and out so the road flows without kinks.

require 'ruby2d'

# === Tunables ===

WIDTH = 900                # window width in pixels
HEIGHT = 540               # window height in pixels
ROAD_WIDTH = 2000          # half-width of the road in world units
SEGMENT_LENGTH = 200       # depth of each road slice (world units)
RUMBLE_LENGTH = 3          # segments per rumble color block
LANES = 3                  # lanes between the rumble strips
DRAW_DISTANCE = 220        # segments rendered ahead of the camera
FIELD_OF_VIEW = 100        # vertical FOV in degrees
CAMERA_HEIGHT = 1000       # camera height above the road (world units)
MAX_SPEED = 12000.0        # top speed (world units/sec)
ACCEL = MAX_SPEED / 4.5    # throttle acceleration (units/sec²)
BRAKING = -MAX_SPEED       # brake deceleration (units/sec²)
DECEL = -MAX_SPEED / 5.5   # passive coast deceleration (units/sec²)
OFF_ROAD_DECEL = -MAX_SPEED       # extra deceleration on grass (units/sec²)
OFF_ROAD_LIMIT = MAX_SPEED * 0.25 # speed cap with both wheels on grass
CENTRIFUGAL = 0.28         # outward pull on curves at top speed (1/sec)
STEER_RATE = 1.8           # max road-widths/sec lateral movement at full speed

# Road-piece vocabulary. A piece is `len` slices long in each of its three
# phases (ease in, hold, ease out); curve is the bend, hill the rise/fall.
SEG_SHORT = 25             # slices per phase in a short piece
SEG_MEDIUM = 50            # slices per phase in a medium piece
SEG_LONG = 100             # slices per phase in a long piece
CURVE_EASY = 2.0           # gentle bend
CURVE_MED = 4.0            # sweeping bend
CURVE_HARD = 6.0           # tight bend
HILL_LOW = 2500            # low crest (world y units)
HILL_MED = 5000            # medium crest
HILL_HIGH = 8000           # tall crest — you crest it blind

# Sunset Outrun palette
SKY_TOP = '#1e1148'
SKY_HORIZON = '#ed7d3a'
SUN = '#fde68a'
SUN_GLOW = '#f97316'
ROAD_LIGHT = '#6b6b6b'
ROAD_DARK = '#5a5a5a'
GRASS_LIGHT = '#1a8c50'
GRASS_DARK = '#137d44'
RUMBLE_LIGHT = '#fafafa'
RUMBLE_DARK = '#dc2626'
LANE_COLOR = '#fafafa'

# Car palette
CAR_RED = '#e11d2a'        # bodywork
CAR_RED_LO = '#8f1418'     # shaded lower body / bumper
CAR_GLASS = '#0b1220'      # rear window
CAR_TIRE = '#0a0a0d'       # tires
TAIL_ON = '#ff3b3b'        # taillights
TAIL_BRAKE = '#ffd0d0'     # taillights under braking (hot)

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ Out Run',
    width: WIDTH, height: HEIGHT, background: SKY_TOP
set close_on_esc: true

# === Helpers ===

CAMERA_DEPTH = 1.0 / Math.tan((FIELD_OF_VIEW / 2.0) * Math::PI / 180.0)
PLAYER_Z = CAMERA_HEIGHT * CAMERA_DEPTH

def lerp(a, b, t)
  a + (b - a) * t
end

# Quadratic ease from a to b (slow start), and a cosine ease-in-out (slow
# at both ends). Used to ramp a piece's curve and elevation smoothly.
def ease_in(a, b, t)
  a + (b - a) * t * t
end

def ease_in_out(a, b, t)
  a + (b - a) * (0.5 - Math.cos(t * Math::PI) / 2.0)
end

# Pinhole projection: turn a world point (x, y, z) into screen coords plus the
# road's projected half-width at that depth. Returns [sx, sy, sw, scale, rel_z].
def project(world_x, world_y, world_z, cam_x, cam_y, cam_z)
  rel_z = world_z - cam_z
  rel_z = 0.0001 if rel_z < 0.0001
  scale = CAMERA_DEPTH / rel_z
  sx = WIDTH * 0.5 + scale * (world_x - cam_x) * WIDTH * 0.5
  sy = HEIGHT * 0.5 - scale * (world_y - cam_y) * HEIGHT * 0.5
  sw = scale * ROAD_WIDTH * WIDTH * 0.5
  [sx, sy, sw, scale, rel_z]
end

# The player's car, drawn rear-on from a few stacked rectangles — enough to
# read as a car without stealing the show from the road. The body leans by
# `lean` into a turn while the tires stay planted; the taillights flare
# near-white while `braking`.
def draw_car(cx, base_y, lean, braking)
  bw = 124                   # body width
  bh = 34                    # body height
  cw = 80                    # cabin width
  ch = 26                    # cabin height
  tw = 24                    # tire width
  th = 18                    # tire height showing below the body
  body_top = base_y - th - bh
  cabin_top = body_top - ch
  lc = cx + lean             # body leans; tires and shadow stay planted

  # Ground shadow.
  Rectangle.render(x: cx - bw / 2 - 6, y: base_y - 5, width: bw + 12, height: 9,
                   color: [0, 0, 0, 0.30])

  # Rear tires at the corners.
  Rectangle.render(x: cx - bw / 2 - 2, y: base_y - th - 4, width: tw, height: th + 8, color: CAR_TIRE)
  Rectangle.render(x: cx + bw / 2 - tw + 2, y: base_y - th - 4, width: tw, height: th + 8, color: CAR_TIRE)

  # Cabin with a dark rear window.
  Rectangle.render(x: lc - cw / 2, y: cabin_top, width: cw, height: ch, color: CAR_RED)
  Rectangle.render(x: lc - cw / 2 + 9, y: cabin_top + 6, width: cw - 18, height: ch - 11, color: CAR_GLASS)

  # Body with a darker bumper band.
  Rectangle.render(x: lc - bw / 2, y: body_top, width: bw, height: bh, color: CAR_RED)
  Rectangle.render(x: lc - bw / 2, y: body_top + bh - 9, width: bw, height: 9, color: CAR_RED_LO)

  # Taillights (flare white under braking).
  lamp = braking ? TAIL_BRAKE : TAIL_ON
  Rectangle.render(x: lc - bw / 2 + 10, y: body_top + bh - 22, width: 26, height: 11, color: lamp)
  Rectangle.render(x: lc + bw / 2 - 36, y: body_top + bh - 22, width: 26, height: 11, color: lamp)
end

# === Track ===
#
# The course is assembled from discrete pieces — straights, curves and hills —
# rather than one endless wave, so the drive has a rhythm: open straights to
# wind out the throttle, then a sweeper or a crest, then room to settle before
# the next feature. `add_road` eases each piece's curve in and out and its
# elevation from the current height to the next, so pieces join without kinks.

segments = []

# Append one road slice; `color` alternates every RUMBLE_LENGTH slices to paint
# the rumble strips and grass stripes.
add_segment = lambda do |curve, y|
  segments << { curve: curve, y: y,
                color: (segments.length / RUMBLE_LENGTH).even? ? :light : :dark }
end

# Lay a piece `len` slices long in each phase: ease the curve up from straight,
# hold it, then ease back to straight, while the elevation eases from the
# current height by `hill` world units across the whole piece.
add_road = lambda do |len, curve, hill|
  start_y = segments.empty? ? 0.0 : segments.last[:y]
  end_y = start_y + hill
  total = 3.0 * len
  (0...len).each { |n| add_segment.call(ease_in(0, curve, n / len.to_f), ease_in_out(start_y, end_y, n / total)) }
  (0...len).each { |n| add_segment.call(curve, ease_in_out(start_y, end_y, (len + n) / total)) }
  (0...len).each { |n| add_segment.call(ease_in_out(curve, 0, n / len.to_f), ease_in_out(start_y, end_y, (2 * len + n) / total)) }
end

# The lap, piece by piece: [slices, curve, hill]. Features come thick and
# fast with only brief straights to punctuate. Each climb is paired with an
# equal descent of the same length, so the hill deltas cancel and the loop
# closes flat; both ends are straight so there's no seam.
TRACK = [
  [SEG_SHORT,  0,           0],          # brief straight off the line
  [SEG_MEDIUM, CURVE_MED,   HILL_HIGH],  # right-hander up a big hill
  [SEG_MEDIUM, -CURVE_MED, -HILL_HIGH],  # left-hander back down
  [SEG_SHORT,  CURVE_HARD,  HILL_MED],   # tight right, climbing
  [SEG_SHORT,  -CURVE_HARD, -HILL_MED],  # tight left, descending
  [SEG_MEDIUM, 0,           HILL_HIGH],  # straight up a blind crest
  [SEG_MEDIUM, CURVE_EASY, -HILL_HIGH],  # over the top, ease right, drop
  [SEG_MEDIUM, -CURVE_MED,  HILL_MED],   # left sweeper up
  [SEG_MEDIUM, CURVE_MED,  -HILL_MED],   # right sweeper down
  [SEG_SHORT,  -CURVE_HARD, HILL_LOW],   # tight left, small rise
  [SEG_SHORT,  CURVE_HARD, -HILL_LOW],   # tight right, small drop
  [SEG_MEDIUM, CURVE_MED,   HILL_HIGH],  # sweeping right up the last big hill
  [SEG_MEDIUM, -CURVE_MED, -HILL_HIGH],  # sweeping left, back to flat
  [SEG_SHORT,  0,           0]           # settle into the loop
].freeze

TRACK.each { |len, curve, hill| add_road.call(len, curve, hill) }

TRACK_SEGMENTS = segments.length
TRACK_LENGTH = TRACK_SEGMENTS * SEGMENT_LENGTH

# === Persistent renderables ===

# Sky: vertical gradient from deep purple at the top to sunset orange at the
# horizon. Drawn at z:-10 so the render block's road quads (z:0) stack on top.
Quad.new(
  x1: 0, y1: 0, x2: WIDTH, y2: 0,
  x3: WIDTH, y3: HEIGHT * 0.55, x4: 0, y4: HEIGHT * 0.55,
  color: [SKY_TOP, SKY_TOP, SKY_HORIZON, SKY_HORIZON],
  z: -10
)

# Distant ground: a haze band from the horizon down to the bottom, continuing
# the gradient into grass. The road's grass quads cover it during normal
# driving; it only shows through where a big hill crest leaves the far road out
# of view, so those gaps read as distant haze instead of the bare background.
Quad.new(
  x1: 0, y1: HEIGHT * 0.55, x2: WIDTH, y2: HEIGHT * 0.55,
  x3: WIDTH, y3: HEIGHT, x4: 0, y4: HEIGHT,
  color: [SKY_HORIZON, SKY_HORIZON, GRASS_DARK, GRASS_DARK],
  z: -10
)

sun_glow = Circle.new(x: WIDTH * 0.7, y: HEIGHT * 0.32,
                      radius: 130, color: SUN_GLOW, opacity: 0.45, z: -9)
sun = Circle.new(x: WIDTH * 0.7, y: HEIGHT * 0.32,
                 radius: 75, color: SUN, z: -8)

speed_label = Text.new('Speed: 0 km/h', x: 16, y: 12,
                       size: 18, color: '#ffffff', z: 30)
Text.new('↑ throttle  ↓ brake  ←/→ steer  R restart',
         x: 16, y: HEIGHT - 28, size: 13,
         color: '#ffffff', z: 30, opacity: 0.75)

# === Mutable state ===

position = 0.0       # camera z along the track (player is PLAYER_Z ahead)
player_x = 0.0       # lateral offset; -1 = left rumble, +1 = right rumble
speed = 0.0
throttle = false
brake = false
steer = 0
sun_offset = 0.0

reset = lambda do
  position = 0.0
  player_x = 0.0
  speed = 0.0
  throttle = false
  brake = false
  steer = 0
  sun_offset = 0.0
  sun.x = WIDTH * 0.7
  sun_glow.x = WIDTH * 0.7
end
reset.call

# === Input ===

on :key_down do |event|
  case event.key
  when 'up' then throttle = true
  when 'down' then brake = true
  when 'left' then steer = -1
  when 'right' then steer = 1
  when 'r' then reset.call
  end
end

on :key_up do |event|
  case event.key
  when 'up' then throttle = false
  when 'down' then brake = false
  when 'left' then steer = 0 if steer == -1
  when 'right' then steer = 0 if steer == 1
  end
end

# === Per-frame update ===

update do |dt|
  if throttle
    speed += ACCEL * dt
  elsif brake
    speed += BRAKING * dt
  else
    speed += DECEL * dt
  end

  if player_x.abs > 1.0 && speed > OFF_ROAD_LIMIT
    speed += OFF_ROAD_DECEL * dt
  end

  speed = speed.clamp(0, MAX_SPEED)
  speed_pct = speed / MAX_SPEED

  player_x += STEER_RATE * speed_pct * steer * dt

  # Centrifugal pull uses the curve under the player (not the camera),
  # interpolated across the segment boundary so the auto-turn drifts smoothly
  # instead of stepping once per segment.
  ahead = position + PLAYER_Z
  player_idx = (ahead / SEGMENT_LENGTH).floor % TRACK_SEGMENTS
  next_idx = (player_idx + 1) % TRACK_SEGMENTS
  player_frac = (ahead % SEGMENT_LENGTH) / SEGMENT_LENGTH
  curve_here = lerp(segments[player_idx][:curve], segments[next_idx][:curve], player_frac)
  player_x -= dt * speed_pct * curve_here * CENTRIFUGAL

  position = (position + speed * dt) % TRACK_LENGTH

  # Sun parallax: drift opposite to the road's heading so curves "feel" like
  # they're carrying the world past the camera.
  sun_offset -= curve_here * speed_pct * dt * 28
  sun.x = WIDTH * 0.7 + sun_offset
  sun_glow.x = sun.x

  speed_text = "Speed: #{(speed_pct * 280).round} km/h"
  speed_label.content = speed_text unless speed_label.content == speed_text
end

# === Render ===

# The road draws at z:0 — above the sky/sun (z:-10..-8) and below the HUD (z:30).
render z: 0 do
  base_idx = (position / SEGMENT_LENGTH).floor % TRACK_SEGMENTS
  base_percent = (position % SEGMENT_LENGTH) / SEGMENT_LENGTH

  player_idx = ((position + PLAYER_Z) / SEGMENT_LENGTH).floor % TRACK_SEGMENTS
  player_percent = ((position + PLAYER_Z) % SEGMENT_LENGTH) / SEGMENT_LENGTH
  player_y = lerp(segments[(player_idx - 1) % TRACK_SEGMENTS][:y],
                  segments[player_idx][:y], player_percent)

  cam_x = player_x * ROAD_WIDTH
  cam_y = CAMERA_HEIGHT + player_y

  x = 0.0
  # Pre-load the curve accumulator with the slice of the base segment already
  # behind the camera. Without it the road's bend snaps by a whole segment's
  # curve each time the camera crosses a boundary — the "jerk" on turns.
  dx = -(segments[base_idx][:curve] * base_percent)
  maxy = HEIGHT.to_f

  # Walk segments near→far, accumulating curve via `x`/`dx`. `maxy` tracks the
  # highest screen-y already drawn so hill crests can hide segments behind them.
  DRAW_DISTANCE.times do |n|
    i = (base_idx + n) % TRACK_SEGMENTS
    seg = segments[i]
    near_z = (base_idx + n) * SEGMENT_LENGTH
    far_z = near_z + SEGMENT_LENGTH
    near_y = segments[(i - 1) % TRACK_SEGMENTS][:y]
    far_y = seg[:y]

    p1 = project(x, near_y, near_z, cam_x, cam_y, position)
    p2 = project(x + dx, far_y, far_z, cam_x, cam_y, position)

    x += dx
    dx += seg[:curve]

    next if p1[4] <= CAMERA_DEPTH    # behind the camera plane
    next if p2[1] >= maxy            # hidden behind a closer hill crest

    grass = seg[:color] == :dark ? GRASS_DARK : GRASS_LIGHT
    Quad.render(x1: 0, y1: p2[1], x2: WIDTH, y2: p2[1],
                x3: WIDTH, y3: p1[1], x4: 0, y4: p1[1], color: grass)

    rumble = seg[:color] == :dark ? RUMBLE_DARK : RUMBLE_LIGHT
    rw1 = p1[2] * 1.18
    rw2 = p2[2] * 1.18
    Quad.render(x1: p2[0] - rw2, y1: p2[1], x2: p2[0] + rw2, y2: p2[1],
                x3: p1[0] + rw1, y3: p1[1], x4: p1[0] - rw1, y4: p1[1],
                color: rumble)

    road = seg[:color] == :dark ? ROAD_DARK : ROAD_LIGHT
    Quad.render(x1: p2[0] - p2[2], y1: p2[1], x2: p2[0] + p2[2], y2: p2[1],
                x3: p1[0] + p1[2], y3: p1[1], x4: p1[0] - p1[2], y4: p1[1],
                color: road)

    if seg[:color] == :light
      lw1 = p1[2] * 0.025
      lw2 = p2[2] * 0.025
      (1...LANES).each do |l|
        offset = -1.0 + 2.0 * l / LANES
        Quad.render(
          x1: p2[0] + offset * p2[2] - lw2, y1: p2[1],
          x2: p2[0] + offset * p2[2] + lw2, y2: p2[1],
          x3: p1[0] + offset * p1[2] + lw1, y3: p1[1],
          x4: p1[0] + offset * p1[2] - lw1, y4: p1[1],
          color: LANE_COLOR
        )
      end
    end

    maxy = p2[1]
  end

  # Player car, centered on screen; steering leans it into the turn.
  draw_car(WIDTH / 2.0, HEIGHT - 8, steer * 7, brake)
end

show
