# Constellations
# Click to place stars that auto-link to nearby neighbors into emerging patterns.
#
# A deep field of background stars twinkles softly behind the foreground.
# Click anywhere to place a bright star — new stars link to their nearest
# neighbors within range, so constellations emerge as you go. Press `r`
# to wipe the sky and start over.

require 'ruby2d'

# === Tunables ===

WIDTH = 800              # window width in pixels
HEIGHT = 600             # window height in pixels
BG_STAR_COUNT = 300      # twinkling background stars
TWINKLE_SPEED = 0.8      # background twinkle frequency (cycles/sec)
LINK_RADIUS = 140        # max pixel distance for two stars to auto-link
MAX_NEW_LINKS = 3        # max edges added per click (keeps the sky readable)

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ Constellations', width: WIDTH, height: HEIGHT, background: '#02020a'
set close_on_esc: true

# === Background twinkling stars ===

BgStar = Struct.new(:circle, :base, :phase)

bg_stars = Array.new(BG_STAR_COUNT) do
  size = rand < 0.85 ? 1 : 2
  base = 0.25 + rand * 0.4
  BgStar.new(
    Circle.new(
      x: rand(WIDTH), y: rand(HEIGHT), radius: size,
      color: [0.85, 0.9, 1.0, base]
    ),
    base,
    rand * Math::PI * 2
  )
end

# === Foreground "placed" stars + their links ===

PlacedStar = Struct.new(:x, :y, :glow, :core)

placed = []
links = []

def add_star(placed, links, x, y)
  glow = Circle.new(x: x, y: y, radius: 8,
                    color: [1.0, 0.95, 0.8, 0.18], z: 2)
  core = Circle.new(x: x, y: y, radius: 3,
                    color: [1.0, 0.98, 0.85, 1.0], z: 4)

  near = placed
         .map { |s| [(s.x - x)**2 + (s.y - y)**2, s] }
         .select { |d2, _| d2 < LINK_RADIUS * LINK_RADIUS }
         .sort_by(&:first)
         .first(MAX_NEW_LINKS)

  near.each do |d2, other|
    fade = 1.0 - Math.sqrt(d2) / LINK_RADIUS
    links << Line.new(
      x1: x, y1: y, x2: other.x, y2: other.y,
      stroke_width: 1,
      color: [0.85, 0.9, 1.0, 0.15 + 0.35 * fade],
      z: 3
    )
  end

  placed << PlacedStar.new(x, y, glow, core)
end

# === Input ===

on mouse_down: :left do |event|
  add_star(placed, links, event.x, event.y)
end

on key_down: :r do
  placed.each do |s|
    s.glow.remove
    s.core.remove
  end
  placed.clear
  links.each(&:remove)
  links.clear
end

# === Update ===

update do
  t = elapsed
  bg_stars.each do |bs|
    bs.circle.opacity =
      bs.base + 0.25 * Math.sin(t * TWINKLE_SPEED * 2 * Math::PI + bs.phase)
  end
end

show
