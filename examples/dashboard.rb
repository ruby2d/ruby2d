# Dashboard widgets
# An analog clock, live gauges, and an activity chart built from primitive shapes.
#
# Demonstrates how to compose a small dashboard from Ruby 2D primitives.
# Press `r` to randomize the chart values.

require 'ruby2d'

# === Tunables ===

WIDTH = 800              # window width in pixels
HEIGHT = 600             # window height in pixels
PHASE_RATE = 2.1         # gauge oscillation rate (rad/sec)
CHART_SHIFT_RATE = 2.4   # mean chart shifts per second
CHART_LENGTH = 28        # number of bars in the activity chart

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ Dashboard widgets', width: WIDTH, height: HEIGHT, background: '#111827'
set close_on_esc: true

# === Helpers ===

def gauge(cx, cy, radius, value, color, label)
  Circle.render(x: cx, y: cy, radius: radius, sectors: 64,
                color: [0.12, 0.16, 0.23, 1])
  Circle.render(x: cx, y: cy, radius: radius, sectors: 64,
                color: [0.22, 0.28, 0.38, 1])
  start = Math::PI * 0.75
  finish = Math::PI * 2.25
  # Draw the filled portion as one polyline so its mitered joints render a solid
  # arc — separate Line segments leave a small gap at every joint.
  points = []
  48.times do |i|
    t = i / 47.0
    break if t > value
    angle = start + (finish - start) * t
    points << [cx + Math.cos(angle) * radius * 0.72, cy + Math.sin(angle) * radius * 0.72]
  end
  Polyline.render(points: points, stroke_width: 8, color: color) if points.length >= 2
  # Center the label on the gauge using its measured size, so any width centers.
  label.render(x: cx - label.width / 2.0, y: cy - label.height / 2.0)
end

# === Mutable state ===

chart = Array.new(CHART_LENGTH) { rand(0.2..1.0) }
cpu = 0.35
memory = 0.62
phase = 0.0

# === HUD ===

Text.new('Dashboard', x: 24, y: 18, size: 26, color: '#f9fafb')
Text.new('Clock', x: 100, y: 80, size: 18, color: '#d1d5db')
Text.new('CPU', x: 400, y: 84, size: 18, color: '#d1d5db')
Text.new('Memory', x: 605, y: 84, size: 18, color: '#d1d5db')
Text.new('Activity', x: 78, y: 355, size: 18, color: '#d1d5db')

# Gauge percentage labels ▸ created once and updated each frame.
cpu_label    = Text.new('', size: 18, color: '#f9fafb', add: false)
memory_label = Text.new('', size: 18, color: '#f9fafb', add: false)

# === Input ===

on(key_down: :r) { chart.replace(Array.new(CHART_LENGTH) { rand(0.2..1.0) }) }

# === Per-frame update ===

update do |dt|
  phase += PHASE_RATE * dt
  cpu = 0.48 + Math.sin(phase * 1.7) * 0.28
  memory = 0.58 + Math.sin(phase * 0.9 + 1.8) * 0.18

  # Update the gauge labels here (not in `render`), and only when the displayed
  # percentage changes — Text#content= rebuilds the texture, so assigning it
  # every frame would re-rasterize 60+ times/sec (see examples/README.md).
  cpu_text = "#{(cpu.clamp(0, 1) * 100).round}%"
  cpu_label.content = cpu_text unless cpu_label.content == cpu_text
  mem_text = "#{(memory.clamp(0, 1) * 100).round}%"
  memory_label.content = mem_text unless memory_label.content == mem_text

  if rand < CHART_SHIFT_RATE * dt
    chart.shift
    chart << rand(0.25..1.0)
  end
end

# === Render ===

render do
  now = Time.now

  Circle.render(x: 170, y: 205, radius: 100, sectors: 72, color: '#1f2937')
  Circle.render(x: 170, y: 205, radius: 92, sectors: 72, color: '#0f172a')

  12.times do |i|
    a = i / 12.0 * Math::PI * 2 - Math::PI / 2
    r1 = i % 3 == 0 ? 76 : 84
    r2 = 88
    Line.render(x1: 170 + Math.cos(a) * r1, y1: 205 + Math.sin(a) * r1,
                x2: 170 + Math.cos(a) * r2, y2: 205 + Math.sin(a) * r2,
                stroke_width: i % 3 == 0 ? 4 : 2, color: '#64748b')
  end

  sec = now.sec
  min = now.min + sec / 60.0
  hour = (now.hour % 12) + min / 60.0
  [[hour / 12.0, 48, 5, '#f9fafb'], [min / 60.0, 68, 4, '#38bdf8'],
   [sec / 60.0, 78, 2, '#ef4444']].each do |turn, len, width, color|
    a = turn * Math::PI * 2 - Math::PI / 2
    Line.render(x1: 170, y1: 205, x2: 170 + Math.cos(a) * len,
                y2: 205 + Math.sin(a) * len, stroke_width: width, color: color)
  end
  Circle.render(x: 170, y: 205, radius: 6, color: '#f9fafb')

  gauge(430, 205, 82, cpu.clamp(0, 1), '#38bdf8', cpu_label)
  gauge(640, 205, 82, memory.clamp(0, 1), '#a78bfa', memory_label)

  x0 = 70
  y0 = 520
  w = 20
  gap = 5
  chart.each_with_index do |v, i|
    h = 135 * v
    Rectangle.render(x: x0 + i * (w + gap), y: y0 - h,
                     width: w, height: h, color: '#22c55e')
  end
  Line.render(x1: x0 - 8, y1: y0, x2: x0 + CHART_LENGTH * (w + gap), y2: y0,
              stroke_width: 2, color: '#475569')
end

show
