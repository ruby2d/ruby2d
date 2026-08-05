# Logo animation
# An animated version of the gem logo with staggered assembly and idle shimmer.
#
# Features staggered facet assembly with overshoot, idle floating with
# color shimmer, a glow layer, sparkle particles, and a fade-in title.

require 'ruby2d'

# === Tunables ===

WIDTH = 600          # window width in pixels
HEIGHT = 500         # window height in pixels
INTRO_DUR = 1.5      # seconds for each facet to ease into place
STAGGER = 0.12       # seconds between successive facet starts
SPARKLE_RATE = 21    # sparkles spawned per second along the outline

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ Logo animation', width: WIDTH, height: HEIGHT
set close_on_esc: true

# === Geometry (same vertices as logo.rb) ===

CX, CY = 299.0, 211.0

VERTICES = {
  left:  [ 75, 145], tl: [165,  55], tc: [299,  55], tr: [434,  55],
  right: [524, 145], bot: [299, 368], il: [201, 145], ir: [398, 145]
}

FACETS = [
  # Crown (left to right)
  [:left, :tl, :il,    [0.91, 0.45, 0.43]],   # #e7746e
  [:tl,   :tc, :il,    [0.86, 0.29, 0.25]],   # #dc4b40
  [:il,   :tc, :ir,    [0.90, 0.39, 0.36]],   # #e5645c
  [:tc,   :tr, :ir,    [0.82, 0.28, 0.24]],   # #d2473e
  [:tr,   :right, :ir, [0.89, 0.36, 0.33]],   # #e35c53
  # Pavilion (left to right)
  [:left, :il, :bot,   [0.89, 0.33, 0.29]],   # #e3534b
  [:il,   :ir, :bot,   [0.85, 0.28, 0.22]],   # #d84738
  [:right, :ir, :bot,  [0.78, 0.26, 0.23]]    # #c7433a
]

OUTLINE_KEYS = [:left, :tl, :tc, :tr, :right, :bot]

# === Intro: random starting offsets per facet ===

srand(42)
INTRO_OFFSETS = FACETS.map do
  [rand(-500..500).to_f, rand(-400..400).to_f, rand(-200..200).to_f]
end
INTRO_END = FACETS.length * STAGGER + INTRO_DUR

# === Text (drawn manually in render block) ===

logo_text = Text.new('Ruby 2D', x: 0, y: 0, size: 40, add: false)

# === Particles ===

particles = []

# === Starfield (fixed positions, each star twinkles independently) ===

STARS = 90.times.map do
  {
    x: rand(0.0..WIDTH.to_f), y: rand(0.0..HEIGHT.to_f),
    size: rand(1.0..2.5), brightness: rand(0.3..0.8),
    phase: rand(0.0..Math::PI * 2), speed: rand(0.5..2.0)
  }
end

# === Helpers ===

def ease_out_back(t)
  t = t.clamp(0.0, 1.0)
  c1 = 1.70158
  c3 = c1 + 1.0
  1.0 + c3 * (t - 1.0) ** 3 + c1 * (t - 1.0) ** 2
end

def rotate_pt(x, y, cx, cy, a)
  c, s = Math.cos(a), Math.sin(a)
  dx, dy = x - cx, y - cy
  [cx + dx * c - dy * s, cy + dx * s + dy * c]
end

def xform(vx, vy, cx, cy, sc, rot, tx, ty)
  x = cx + (vx - cx) * sc
  y = cy + (vy - cy) * sc
  x, y = rotate_pt(x, y, cx, cy, rot)
  [x + tx, y + ty]
end

# Wrap a flat [r, g, b, a] into a per-vertex color array for .render methods
def color3(c) = [c, c, c]
def color4(c) = [c, c, c, c]

# === Update loop (particle state) ===

update do |dt|
  t = elapsed
  idle_t = [t - INTRO_END, 0.0].max

  # Spawn sparkles along the outline after intro settles
  if idle_t > 0.5 && rand < SPARKLE_RATE * dt
    vx, vy = VERTICES[OUTLINE_KEYS.sample]
    float_y = Math.sin(idle_t * 1.2) * 10.0
    particles << {
      x: vx + rand(-20.0..20.0),
      y: vy + rand(-20.0..20.0) + float_y,
      vx: rand(-42.0..42.0),
      vy: rand(-84.0..-18.0),
      life: 1.0,
      size: rand(2.0..5.0)
    }
  end

  particles.each do |p|
    p[:x] += p[:vx] * dt
    p[:y] += p[:vy] * dt
    p[:life] -= dt
  end
  particles.reject! { |p| p[:life] <= 0 }
end

# === Render loop (all drawing) ===

render do
  t = elapsed
  idle_t = [t - INTRO_END, 0.0].max

  # Global idle transforms
  float_y    = Math.sin(idle_t * 1.2) * 10.0
  global_rot = Math.sin(idle_t * 0.5) * 0.03
  global_sc  = 1.0 + Math.sin(idle_t * 2.0) * 0.015

  # --- Background gradient (deep navy → dark charcoal, slowly shifting) ---
  shift = Math.sin(t * 0.15) * 0.02
  top_l = [0.05 + shift, 0.06 + shift, 0.13 + shift * 2, 1.0]
  top_r = [0.07 + shift, 0.06 + shift, 0.15 + shift * 2, 1.0]
  bot_l = [0.10 - shift, 0.07 - shift, 0.09 - shift, 1.0]
  bot_r = [0.08 - shift, 0.07 - shift, 0.11 - shift, 1.0]
  Rectangle.render(x: 0, y: 0, width: 600, height: 500, color: [top_l, top_r, bot_r, bot_l])

  # --- Starfield ---
  STARS.each do |s|
    twinkle = (Math.sin(t * s[:speed] + s[:phase]) * 0.5 + 0.5) * s[:brightness]
    Square.render(
      x: s[:x], y: s[:y], size: s[:size],
      color: color4([0.7, 0.75, 1.0, twinkle])
    )
  end

  # Smooth ramp for idle effects (0→1 over ~1.5 seconds after intro)
  idle_blend = (idle_t / 1.5).clamp(0.0, 1.0)

  # --- Glow layer (slightly larger, semi-transparent echo) ---
  if idle_blend > 0.01
    glow_pulse = (Math.sin(idle_t * 1.8) * 0.5 + 0.5) * 0.12 * idle_blend
    glow_sc = global_sc * 1.07

    FACETS.each do |v1k, v2k, v3k, rgb|
      pts = [v1k, v2k, v3k].map do |k|
        xform(*VERTICES[k], CX, CY, glow_sc, global_rot, 0, float_y)
      end
      Triangle.render(
        x1: pts[0][0], y1: pts[0][1],
        x2: pts[1][0], y2: pts[1][1],
        x3: pts[2][0], y3: pts[2][1],
        color: color3([rgb[0], rgb[1], rgb[2], glow_pulse])
      )
    end
  end

  # --- Facets ---
  FACETS.each_with_index do |(v1k, v2k, v3k, rgb), i|
    off_x, off_y, off_deg = INTRO_OFFSETS[i]

    # Intro: ease from scattered position to final
    ft   = (t - i * STAGGER) / INTRO_DUR
    ease = ease_out_back(ft)

    dx  = off_x * (1.0 - ease)
    dy  = off_y * (1.0 - ease)
    rot = off_deg * Math::PI / 180.0 * (1.0 - ease)
    alpha = ft.clamp(0.0, 1.0)

    # Color shimmer (fades in gradually via idle_blend)
    shimmer = Math.sin(idle_t * 3.0 + i * 0.9) * 0.07 * idle_blend
    color = [
      (rgb[0] + shimmer).clamp(0.0, 1.0),
      (rgb[1] + shimmer * 0.5).clamp(0.0, 1.0),
      (rgb[2] + shimmer * 0.3).clamp(0.0, 1.0),
      alpha
    ]

    pts = [v1k, v2k, v3k].map do |k|
      xform(*VERTICES[k], CX, CY, global_sc, global_rot + rot, dx, dy + float_y)
    end

    Triangle.render(
      x1: pts[0][0], y1: pts[0][1],
      x2: pts[1][0], y2: pts[1][1],
      x3: pts[2][0], y3: pts[2][1],
      color: color3(color)
    )
  end

  # --- Border (fades in after facets land) ---
  border_alpha = ((t - FACETS.length * STAGGER) / INTRO_DUR).clamp(0.0, 1.0)

  if border_alpha > 0.01
    outline_pts = OUTLINE_KEYS.map do |k|
      xform(*VERTICES[k], CX, CY, global_sc, global_rot, 0, float_y)
    end

    border_color = [1.0, 1.0, 1.0, border_alpha]

    outline_pts.each_with_index do |pt, i|
      npt = outline_pts[(i + 1) % outline_pts.length]
      Line.render(
        x1: pt[0], y1: pt[1], x2: npt[0], y2: npt[1],
        stroke_width: 8, color: border_color
      )
    end

    # Cap the joints with circles to close corner gaps
    outline_pts.each do |pt|
      Circle.render(x: pt[0], y: pt[1], radius: 4, sectors: 16, color: border_color)
    end
  end

  # --- Sparkle particles ---
  particles.each do |p|
    a  = (p[:life] ** 0.6).clamp(0.0, 1.0)
    sz = p[:size] * (0.3 + 0.7 * p[:life])
    Square.render(
      x: p[:x], y: p[:y] + float_y * 0.15,
      size: sz, color: color4([1.0, 0.85, 0.7, a * 0.7])
    )
  end

  # --- Logo text (slides up and fades in after intro) ---
  text_t = [(t - INTRO_END - 0.3) * 1.5, 0.0].max.clamp(0.0, 1.0)
  if text_t > 0.01
    text_y = 400.0 + float_y + (1.0 - text_t) * 25.0
    logo_text.render(x: 210, y: text_y, color: [0.93, 0.90, 0.88, text_t])
  end
end

show
