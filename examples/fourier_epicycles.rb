# Fourier epicycles
# A chain of rotating circles traces a heart — the DFT made visible.
#
# Any closed 2D curve is a sum of rotating vectors — what the discrete
# Fourier transform tells us. Each frequency component is a circle that
# rotates at its own rate; chained tip-to-tail in order of decreasing
# radius, the end of the chain traces the original shape. Here, that
# shape is a heart. Press R to redraw the trail.

require 'ruby2d'

# === Tunables ===

WIDTH = 800              # window width in pixels
HEIGHT = 600             # window height in pixels
N = 128                  # number of samples and DFT components
TRAIL_PERIOD = 8.0       # seconds for one full revolution / heart trace
SHAPE_SCALE = 14         # how big to draw the heart
TRAIL_LEN = 800          # max points retained in the trace history
MIN_CIRCLE_R = 0.6       # circles smaller than this aren't drawn (clutter)

CENTER_X = WIDTH  / 2.0
CENTER_Y = HEIGHT / 2.0

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ Fourier epicycles',
    width: WIDTH, height: HEIGHT, background: '#0b1020'
set close_on_esc: true

# === Target shape: parametric heart ===

# Math y-up, screen y-down — negate y when laying it on the canvas.
target = N.times.map do |i|
  t = 2 * Math::PI * i / N
  hx = 16 * Math.sin(t)**3
  hy = 13 * Math.cos(t) - 5 * Math.cos(2 * t) - 2 * Math.cos(3 * t) - Math.cos(4 * t)
  Complex(CENTER_X + SHAPE_SCALE * hx, CENTER_Y - SHAPE_SCALE * hy)
end

# === DFT ===

# c_k = (1/N) Σ_n target[n] * exp(-2πi k n / N).
# Frequencies wrap: indices ≥ N/2 represent negative frequencies.
coeffs = N.times.map do |k|
  sum = Complex(0, 0)
  N.times do |n|
    angle = -2 * Math::PI * k * n / N
    sum += target[n] * Complex(Math.cos(angle), Math.sin(angle))
  end
  sum / N
end
freqs = N.times.map { |k| k < N / 2 ? k : k - N }

# Chain components in order of descending amplitude. Drop k=0 — the DC
# component is the centroid; we use it as the chain's anchor instead of
# drawing it as a giant first vector.
order = (0...N).reject { |i| i == 0 }.sort_by { |i| -coeffs[i].abs }
ANCHOR_X = coeffs[0].real
ANCHOR_Y = coeffs[0].imaginary

# === State ===

# chain[i] is the position of the i-th joint in the epicycle chain at
# the current time. chain[0] is the anchor; chain[-1] is the trace.
chain = Array.new(order.length + 1) { [0.0, 0.0] }
trail = []
time = 0.0

# === Input ===

on key_down: :r do
  trail.clear
  time = 0.0
end

# === Per-frame update ===

# Walk the chain once per frame, accumulating each component's rotated
# vector. The inner work is straight complex multiplication unrolled
# into pairs of reals; with N≈128 this stays well under a millisecond.
update do |dt|
  time += dt
  t = (time / TRAIL_PERIOD) % 1.0

  px = ANCHOR_X
  py = ANCHOR_Y
  chain[0][0] = px
  chain[0][1] = py
  order.each_with_index do |k, idx|
    angle = 2 * Math::PI * freqs[k] * t
    rotor_re = Math.cos(angle)
    rotor_im = Math.sin(angle)
    cre = coeffs[k].real
    cim = coeffs[k].imaginary
    px += cre * rotor_re - cim * rotor_im
    py += cre * rotor_im + cim * rotor_re
    slot = chain[idx + 1]
    slot[0] = px
    slot[1] = py
  end

  trail << [px, py]
  trail.shift while trail.length > TRAIL_LEN
end

# === Render ===

EPI_STROKE = [0.62, 0.78, 1.0, 0.18].freeze   # faint blue circle outlines
ARM_COLOR  = [0.62, 0.78, 1.0, 0.55].freeze   # arm linking the centers
TRAIL_COLOR = '#fbbf24'
TIP_OUTER = [0.99, 0.95, 0.55, 0.45].freeze
TIP_INNER = '#fef3c7'

render do
  # Each epicycle: faint outline circle at the joint, then a line out
  # to the next joint. Tiny components are skipped so the eye isn't
  # buried under hairline circles.
  n = chain.length - 1
  i = 0
  while i < n
    px = chain[i][0]
    py = chain[i][1]
    nx = chain[i + 1][0]
    ny = chain[i + 1][1]
    r = Math.hypot(nx - px, ny - py)
    if r > MIN_CIRCLE_R
      Circle.render(x: px, y: py, radius: r,
                    fill: false, stroke_width: 1, stroke_color: EPI_STROKE)
    end
    Line.render(x1: px, y1: py, x2: nx, y2: ny, stroke_width: 1, color: ARM_COLOR)
    i += 1
  end

  Polyline.render(points: trail, stroke_width: 2.5, color: TRAIL_COLOR) if trail.length >= 2

  tip = chain.last
  Circle.render(x: tip[0], y: tip[1], radius: 8, color: TIP_OUTER)
  Circle.render(x: tip[0], y: tip[1], radius: 3, color: TIP_INNER)
end

show
