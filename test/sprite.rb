# Sprite
#
# Visual test of every Sprite feature in six panels:
#   1. BASICS              — single-image sheets at multiple scales, default loop, one-shot
#   2. NAMED ANIMATIONS    — hero with walk / climb / cheer (press 1 / 2 / 3)
#   3. FLIP                — same animation in four flip modes
#   4. ATLAS               — explicit frames with per-frame timing
#   5. SPRITE SHEET (XML)  — Sparrow XML atlas: shared texture, named frames, named animations
#   6. SPEED + CONTROLS    — speed multiplier and key reference

require 'ruby2d'

W = 1500
H = 970

set title: 'Ruby 2D — Sprite', width: W, height: H
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

Text.new('SPRITE TEST', x: 16, y: 12, size: 16, color: HEAD)
hairline(16, 38, W - 16, 38, color: LINE)

# --- Layout -----------------------------------------------------------------

PANEL_W = 480
PANEL_H = 440
COL_X   = [15, 510, 1005].freeze
ROW_Y   = [60, 515].freeze

SHEETS_DIR      = "#{Ruby2D.test_spritesheets}".freeze
COIN            = "#{SHEETS_DIR}/coin.png".freeze
SPRITE_SHEET    = "#{SHEETS_DIR}/sprite_sheet.png".freeze
BOOM            = "#{SHEETS_DIR}/boom.png".freeze
HERO            = "#{SHEETS_DIR}/hero.png".freeze
ATLAS           = "#{SHEETS_DIR}/texture_atlas.png".freeze
SPRITESHEET_XML = "#{SHEETS_DIR}/spritesheet.xml".freeze

# --- Panel 1: BASICS -------------------------------------------------------

p1x, p1y = COL_X[0], ROW_Y[0]
frame(p1x, p1y, PANEL_W, PANEL_H)
panel_label(p1x + 10, p1y + 8, '[ BASICS ]')

# Coin sprite at three scales — basic clip-based animation with width/height modifiers.
section(p1x + 15, p1y + 32, 'coin sprite — scales 84 / 60 / 42')
coin_full = Sprite.new(COIN, x: p1x + 30, y: p1y + 60,
                       clip_width: 84, time: 300, loop: true)
coin_full.play

coin_med = Sprite.new(COIN, x: p1x + 140, y: p1y + 75,
                      width: 60, height: 60, clip_width: 84, time: 300, loop: true)
coin_med.play

coin_sm = Sprite.new(COIN, x: p1x + 220, y: p1y + 95,
                     width: 42, height: 42, clip_width: 84, time: 300, loop: true)
coin_sm.play

# Sprite sheet with default frame timing.
section(p1x + 15, p1y + 172, 'sprite_sheet.png — default loop')
sheet = Sprite.new(SPRITE_SHEET, x: p1x + 30, y: p1y + 195,
                   clip_width: 50, time: 250, loop: true)
sheet.play

# Boom — one-shot animation with completion callback. Press B to fire.
section(p1x + 15, p1y + 292, 'boom (one-shot, callback) — press B')
boom = Sprite.new(BOOM, x: p1x + 30, y: p1y + 315,
                  width: 80, height: 80, clip_width: 127, time: 75)
boom_status = Text.new('idle', x: p1x + 130, y: p1y + 345, size: 12, color: DIM)
boom_dot = Circle.new(x: p1x + PANEL_W - 20, y: p1y + 315, radius: 4, sectors: 16, color: DIM)

# --- Panel 2: NAMED ANIMATIONS ---------------------------------------------

p2x, p2y = COL_X[1], ROW_Y[0]
frame(p2x, p2y, PANEL_W, PANEL_H)
panel_label(p2x + 10, p2y + 8, '[ NAMED ANIMATIONS ]')

section(p2x + 15, p2y + 32, 'hero — walk / climb / cheer (press 1 / 2 / 3)')
hero = Sprite.new(
  HERO,
  x: p2x + 30, y: p2y + 70,
  width: 130, height: 166, clip_width: 78, time: 250,
  animations: { walk: 1..2, climb: 3..4, cheer: 5..6 }
)
hero.play animation: :walk, loop: true

hero_status = Text.new('walk', x: p2x + 200, y: p2y + 130, size: 24, color: ACCENT)
hint(p2x + 200, p2y + 165, 'current animation')

# --- Panel 3: FLIP ---------------------------------------------------------

p3x, p3y = COL_X[2], ROW_Y[0]
frame(p3x, p3y, PANEL_W, PANEL_H)
panel_label(p3x + 10, p3y + 8, '[ FLIP ]')

section(p3x + 15, p3y + 32, 'flip — none / horizontal / vertical / both')
flip_sprites = []
[
  [nil,         'none'],
  [:horizontal, 'horiz'],
  [:vertical,   'vert'],
  [:both,       'both']
].each_with_index do |(mode, name), i|
  x = p3x + 20 + i * 110
  s = Sprite.new(
    HERO,
    x: x, y: p3y + 70,
    width: 70, height: 89, clip_width: 78, time: 250,
    animations: { walk: 1..2 }
  )
  s.play animation: :walk, loop: true, flip: mode
  flip_sprites << s
  hint(x, p3y + 170, name)
end

# --- Panel 4: ATLAS — explicit frames -------------------------------------

p4x, p4y = COL_X[0], ROW_Y[1]
frame(p4x, p4y, PANEL_W, PANEL_H)
panel_label(p4x + 10, p4y + 8, '[ ATLAS — EXPLICIT FRAMES ]')

section(p4x + 15, p4y + 32,
        'texture_atlas.png — 5 explicit frames with per-frame timing (300/400/500/600/700ms)')
atlas = Sprite.new(
  ATLAS, x: p4x + 30, y: p4y + 70,
  animations: {
    count: [
      { x: 0,  y: 0,  width: 35, height: 41, time: 300 },
      { x: 26, y: 46, width: 35, height: 38, time: 400 },
      { x: 65, y: 10, width: 32, height: 41, time: 500 },
      { x: 10, y: 99, width: 32, height: 38, time: 600 },
      { x: 74, y: 80, width: 32, height: 38, time: 700 }
    ]
  }
)
atlas.play animation: :count, loop: true

# --- Panel 5: SPRITE SHEET (XML) ------------------------------------------

p5x, p5y = COL_X[1], ROW_Y[1]
frame(p5x, p5y, PANEL_W, PANEL_H)
panel_label(p5x + 10, p5y + 8, '[ SPRITE SHEET (XML) ]')

# Load the Sparrow atlas once. Every Sprite built from this sheet shares a
# single GPU texture — the load happens once even with many sprites on screen.
sheet_xml = Ruby2D::SpriteSheet.new(SPRITESHEET_XML)

# Static frames — five different sprites, all sharing one texture.
section(p5x + 15, p5y + 32, "static frames — frame: '<name>' (all sprites share one texture)")
[
  ['block_blue',   p5x + 25],
  ['block_coin',   p5x + 105],
  ['block_green',  p5x + 185],
  ['block_red',    p5x + 265],
  ['block_yellow', p5x + 345]
].each do |name, x|
  Sprite.new(sheet_xml, frame: name, x: x, y: p5y + 60, width: 64, height: 64)
  hint(x, p5y + 130, name.delete_prefix('block_'))
end

# Named animation built from frame names.
section(p5x + 15, p5y + 172, "animation — count: %w[hud_character_0 hud_character_1 ... hud_character_9]")
xml_anim = Sprite.new(
  sheet_xml,
  x: p5x + 30, y: p5y + 200,
  width: 80, height: 80, time: 200,
  animations: { count: (0..9).map { |n| "hud_character_#{n}" } }
)
xml_anim.play animation: :count, loop: true
hint(p5x + 30, p5y + 290, '0 → 9 loop')

# --- Panel 6: SPEED + CONTROLS --------------------------------------------

p6x, p6y = COL_X[2], ROW_Y[1]
frame(p6x, p6y, PANEL_W, PANEL_H)
panel_label(p6x + 10, p6y + 8, '[ SPEED + CONTROLS ]')

section(p6x + 15, p6y + 32, 'speed — same animation, different speed multipliers')
speed_coins = []
[0.5, 1.0, 2.0].each_with_index do |speed, i|
  x = p6x + 30 + i * 130
  s = Sprite.new(COIN, x: x, y: p6y + 55,
                 width: 84, height: 84, clip_width: 84, time: 300, loop: true, speed: speed)
  s.play
  speed_coins << s
  hint(x + 25, p6y + 145, "#{speed}×")
end

section(p6x + 15, p6y + 192, 'controls')
[
  ['B',     'boom! (one-shot with callback)'],
  ['1 / 2 / 3', 'hero: walk / climb / cheer'],
  ['F',     'cycle hero flip mode'],
  ['S',     'stop all'],
  ['P',     'play all'],
  ['Space', 'pause / resume toggle']
].each_with_index do |(key, desc), i|
  y = p6y + 220 + i * 26
  Text.new(key,  x: p6x + 25, y: y, size: 12, color: HEAD)
  Text.new(desc, x: p6x + 130, y: y, size: 12, color: TEXT)
end

# --- Sprite controls -------------------------------------------------------

# All animated sprites; used for global stop / play / pause.
ANIMATED = [coin_full, coin_med, coin_sm, sheet, hero, atlas, xml_anim,
            *flip_sprites, *speed_coins].freeze

hero_flip_idx = 0
HERO_FLIPS = [nil, :horizontal, :vertical, :both].freeze

on :key_down do |e|
  case e.key
  when 'b'
    boom_dot.color = ACCENT
    boom_status.content = 'playing…'
    boom_status.color = ACCENT
    boom.play do
      boom_dot.color = DIM
      boom_status.content = 'done'
      boom_status.color = DIM
    end
  when '1'
    hero.play animation: :walk, loop: true
    hero_status.content = 'walk'
  when '2'
    hero.play animation: :climb, loop: true
    hero_status.content = 'climb'
  when '3'
    hero.play animation: :cheer
    hero_status.content = 'cheer'
  when 'f'
    hero_flip_idx = (hero_flip_idx + 1) % HERO_FLIPS.length
    hero.play animation: :walk, loop: true, flip: HERO_FLIPS[hero_flip_idx]
    hero_status.content = 'walk'
  when 's'
    ANIMATED.each(&:stop)
  when 'p'
    coin_full.play; coin_med.play; coin_sm.play
    sheet.play
    hero.play animation: :walk, loop: true
    hero_status.content = 'walk'
    atlas.play animation: :count, loop: true
    xml_anim.play animation: :count, loop: true
    flip_sprites.each_with_index { |s, i| s.play animation: :walk, loop: true, flip: HERO_FLIPS[i] }
    speed_coins.each(&:play)
  when 'space'
    ANIMATED.each { |s| s.paused? ? s.resume : s.pause }
  end
end

show
