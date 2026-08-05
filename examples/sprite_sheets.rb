# Sprite sheets
# A platformer scene built entirely from `SpriteSheet`-loaded Kenney.nl atlases.
#
# Every visible thing — background, ground, decorations, bee, the
# player — comes from a `SpriteSheet`, so the four PNGs decode and
# upload to the GPU once and every sprite reuses them.
#
# Left/right (or dpad) to run, space/up (or south button) to jump,
# 1/2/3 to switch character color, r to reset.

require 'ruby2d'

# Bundle the atlas directory (see "Atlases" below) into web builds' virtual
# filesystem. `ruby2d build` reads this directive, so no `--assets` flag is
# needed; on native the files are read straight from disk.
# ruby2d:assets assets/resources/spritesheets

# === Tunables ===

WIDTH  = 800              # window width in pixels
HEIGHT = 600              # window height in pixels
TILE_SIZE = 64            # ground tile size on screen
GROUND_Y = HEIGHT - TILE_SIZE  # top edge of the ground row
PLAYER_W = 88             # player render width (atlas frame is 256×256)
PLAYER_H = 96             # player render height
PLAYER_GROUND_Y = GROUND_Y - PLAYER_H + 4  # grounded top edge; +4 seats the feet
BEE_SIZE = 56             # bee render size
GRAVITY   = 1980          # downward acceleration (px/sec²)
RUN_ACCEL = 2520          # horizontal acceleration (px/sec²)
FRICTION  = 11.9          # horizontal decay rate when no input (per-sec)
JUMP_V    = -780          # initial jump velocity (px/sec, negative is up)
MAX_SPEED = 380           # horizontal speed cap (px/sec)
WALK_FRAME_TIME = 110     # ms per walk-cycle frame
BEE_FRAME_TIME  = 90      # ms per bee-fly frame
BEE_SPEED = 110           # bee horizontal speed (px/sec)
BEE_BOB_AMP = 28          # bee bob amplitude (px)
BEE_BOB_RATE = 2.5        # bee bob rate (rad/sec)

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ Sprite sheets',
    width: WIDTH, height: HEIGHT, background: '#0c1a3a'
set close_on_esc: true

# === Atlases ===
#
# One PNG per sheet, from the bundled Kenney atlases. Every sprite below
# reaches into one of these via its named region, so this is the only
# place we touch the filesystem or the GPU for pixels. The path is
# relative, so run from the repo root; the `ruby2d:assets` directive at
# the top of the file bundles this directory into web builds.

sheets_dir = 'assets/resources/spritesheets'
tiles_sheet       = SpriteSheet.new("#{sheets_dir}/spritesheet-tiles.xml")
characters_sheet  = SpriteSheet.new("#{sheets_dir}/spritesheet-characters.xml")
backgrounds_sheet = SpriteSheet.new("#{sheets_dir}/spritesheet-backgrounds.xml")
enemies_sheet     = SpriteSheet.new("#{sheets_dir}/spritesheet-enemies.xml")

# === Helpers ===

# Every character color in this atlas uses the same naming scheme
# (`character_<color>_idle`, `_walk_a`, `_walk_b`, `_jump`), so we can
# template the color into each frame name and pass the resulting
# arrays straight to `Sprite.new` as named animations.
build_player = lambda do |color|
  Sprite.new(characters_sheet,
             x: 100, y: PLAYER_GROUND_Y,
             width: PLAYER_W, height: PLAYER_H, z: 5,
             animations: {
               idle: ["character_#{color}_idle"],
               walk: ["character_#{color}_walk_a", "character_#{color}_walk_b"],
               jump: ["character_#{color}_jump"]
             },
             time: WALK_FRAME_TIME)
end

# === Scene ===

# Backdrop fills the whole window. Setting width/height here scales
# whatever the atlas frame happens to be (these are 512×512) up to fit.
Sprite.new(backgrounds_sheet, frame: 'background_color_hills',
           x: 0, y: 0, width: WIDTH, height: HEIGHT, z: 0)

# Ground row.
((WIDTH / TILE_SIZE) + 1).times do |col|
  Sprite.new(tiles_sheet, frame: 'terrain_grass_block_top',
             x: col * TILE_SIZE, y: GROUND_Y,
             width: TILE_SIZE, height: TILE_SIZE, z: 2)
end

# Decorative tufts and props sitting on top of the ground row. Each is
# its own Sprite, all sharing the tiles texture under the hood.
[
  [70,  'mushroom_red',  44],
  [200, 'grass',         42],
  [310, 'bush',          48],
  [430, 'grass_purple',  42],
  [560, 'mushroom_brown', 44],
  [690, 'rock',          40]
].each do |x, name, size|
  Sprite.new(tiles_sheet, frame: name,
             x: x, y: GROUND_Y - size + 4,
             width: size, height: size, z: 3)
end

# Bee — animated, drifts left across the sky and wraps.
bee = Sprite.new(enemies_sheet,
                 x: WIDTH - 200, y: 200,
                 width: BEE_SIZE, height: BEE_SIZE, z: 4,
                 animations: { fly: %w[bee_a bee_b] },
                 time: BEE_FRAME_TIME)
bee.play(animation: :fly, loop: true)

# === Mutable state ===

PLAYER_COLORS = %i[beige green pink].freeze

color_index = 0
player = build_player.(PLAYER_COLORS[color_index])
player.play(animation: :idle, loop: true)

px = player.x.to_f
py = player.y.to_f
vx = 0.0
vy = 0.0
on_ground = true
facing = :right
left = false
right = false
state = :idle      # currently playing animation
bee_t = 0.0
bee_base_y = bee.y.to_f

# === Color switching ===

switch_color = lambda do |idx|
  next if idx == color_index || idx >= PLAYER_COLORS.length

  color_index = idx
  old = player
  player = build_player.(PLAYER_COLORS[color_index])
  player.x = old.x
  player.y = old.y
  # `:jump` is non-looping so the new sprite holds on the jump pose
  # mid-air; `:idle` and `:walk` keep cycling.
  player.play(animation: state,
              loop: state != :jump,
              flip: facing == :left ? :horizontal : nil)
  old.remove
end

# === Reset ===

reset = lambda do
  px = 100.0
  py = PLAYER_GROUND_Y.to_f
  vx = 0.0
  vy = 0.0
  on_ground = true
  facing = :right
  state = :idle
  player.play(animation: :idle, loop: true, flip: nil)
end

# === Input ===

on key_down: :left  do left = true  end
on key_down: :right do right = true end
on key_up:   :left  do left = false end
on key_up:   :right do right = false end

on key_down: %i[space up], gamepad_button_down: :south do
  if on_ground
    vy = JUMP_V
    on_ground = false
    state = :jump
    # Non-looping single-frame play: the sprite holds on the jump pose
    # until we transition back to walk/idle on landing.
    player.play(animation: :jump,
                flip: facing == :left ? :horizontal : nil)
  end
end

on(key_down: '1') { switch_color.call(0) }
on(key_down: '2') { switch_color.call(1) }
on(key_down: '3') { switch_color.call(2) }
on(key_down: :r)  { reset.call }

# === Per-frame update ===

update do |dt|
  go_left  = left  || gamepads.any? { |p| p.held?(:dpad_left) }
  go_right = right || gamepads.any? { |p| p.held?(:dpad_right) }

  vx -= RUN_ACCEL * dt if go_left  && !go_right
  vx += RUN_ACCEL * dt if go_right && !go_left
  vx *= Math.exp(-FRICTION * dt) unless go_left ^ go_right
  vx = vx.clamp(-MAX_SPEED, MAX_SPEED)
  vy += GRAVITY * dt

  px = (px + vx * dt).clamp(0, WIDTH - PLAYER_W)
  py += vy * dt

  # Ground collision
  if py >= PLAYER_GROUND_Y
    py = PLAYER_GROUND_Y.to_f
    just_landed = !on_ground
    on_ground = true
    vy = 0
    if just_landed
      desired = vx.abs > 20 ? :walk : :idle
      flip = facing == :left ? :horizontal : nil
      player.play(animation: desired, loop: true, flip: flip)
      state = desired
    end
  end

  # Facing follows the velocity sign (with a small dead-zone so easing
  # to a stop doesn't flip the sprite back).
  new_facing = if    vx >  20 then :right
               elsif vx < -20 then :left
               else                facing
               end

  # Animation transitions on the ground only — mid-air sticks on :jump.
  if on_ground
    desired = vx.abs > 20 ? :walk : :idle
    if desired != state || new_facing != facing
      flip = new_facing == :left ? :horizontal : nil
      player.play(animation: desired, loop: true, flip: flip)
      state = desired
    end
  end
  facing = new_facing

  player.x = px
  player.y = py

  # Bee: drift left forever, bob in a sine wave, wrap around the right.
  bee_t += dt
  bee.x -= BEE_SPEED * dt
  bee.x += WIDTH + BEE_SIZE if bee.x < -BEE_SIZE
  bee.y = bee_base_y + Math.sin(bee_t * BEE_BOB_RATE) * BEE_BOB_AMP
end

show
