# Bezier curve editor
# Drag the four control points to reshape a cubic Bezier curve live.
#
# Handles and sample points update as you drag. Press `r` to restore
# the original curve.

require 'ruby2d'

# === Tunables ===

WIDTH = 800           # window width in pixels
HEIGHT = 600          # window height in pixels
CURVE_SAMPLES = 90    # number of line segments approximating the curve
GRAB_RADIUS = 18      # max pixel distance for picking up a control point

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ Bezier curve editor', width: WIDTH, height: HEIGHT, background: '#111827'
set close_on_esc: true
set render_mode: :on_demand

# === Setup ===

canvas = Canvas.new(width: WIDTH, height: HEIGHT, fill: [0.07, 0.10, 0.16, 1])

initial = [[90, 500], [230, 90], [560, 90], [710, 500]]
points = initial.map(&:dup)
handles = points.each_with_index.map do |(x, y), i|
  Circle.new(x: x, y: y, radius: i.zero? || i == 3 ? 10 : 8,
             color: i.zero? || i == 3 ? '#f97316' : '#38bdf8', z: 5)
end

drag_index = nil

def bezier_point(points, t)
  u = 1.0 - t
  x = u ** 3 * points[0][0] + 3 * u * u * t * points[1][0] +
      3 * u * t * t * points[2][0] + t ** 3 * points[3][0]
  y = u ** 3 * points[0][1] + 3 * u * u * t * points[1][1] +
      3 * u * t * t * points[2][1] + t ** 3 * points[3][1]
  [x, y]
end

redraw = lambda do
  canvas.clear
  canvas.draw_line(x1: points[0][0], y1: points[0][1], x2: points[1][0], y2: points[1][1],
                   stroke_width: 2, color: [0.55, 0.65, 0.8, 0.45])
  canvas.draw_line(x1: points[2][0], y1: points[2][1], x2: points[3][0], y2: points[3][1],
                   stroke_width: 2, color: [0.55, 0.65, 0.8, 0.45])

  prev = bezier_point(points, 0)
  1.upto(CURVE_SAMPLES) do |i|
    t = i / CURVE_SAMPLES.to_f
    cur = bezier_point(points, t)
    canvas.draw_line(x1: prev[0], y1: prev[1], x2: cur[0], y2: cur[1],
                     stroke_width: 4, color: [0.35, 0.9, 1.0, 0.95])
    prev = cur
  end

  points.each_with_index do |(x, y), i|
    handles[i].x = x
    handles[i].y = y
  end
  request_render
end

redraw.call

# === Input ===

on :mouse_down do |event|
  drag_index = points.each_index.find do |i|
    dx = points[i][0] - event.x
    dy = points[i][1] - event.y
    dx * dx + dy * dy <= GRAB_RADIUS * GRAB_RADIUS
  end
end

on :mouse_up do
  drag_index = nil
end

on :mouse_move do |event|
  next if drag_index.nil?

  points[drag_index][0] = event.x.clamp(0, WIDTH)
  points[drag_index][1] = event.y.clamp(0, HEIGHT)
  redraw.call
end

on key_down: :r do
  points.each_with_index { |p, i| p.replace(initial[i]) }
  redraw.call
end

show
