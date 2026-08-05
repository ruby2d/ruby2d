# UI controls
# A small control panel made from Ruby 2D shapes: tabs, buttons, toggle, sliders.
#
# Adjust the controls to change the preview shape.

require 'ruby2d'

# === Tunables ===

WIDTH = 760         # window width in pixels
HEIGHT = 500        # window height in pixels
PULSE_RATE = 4.8    # preview pulse angular speed (rad/sec)

# === Window ===

set title: 'Ruby 2D ▸ Examples ▸ UI controls', width: WIDTH, height: HEIGHT, background: '#111827'
set close_on_esc: true
set render_mode: :on_demand

# === UI build ===

Rectangle.new(x: 0, y: 0, width: 260, height: HEIGHT, color: '#1f2937')
preview = Circle.new(x: 510, y: 250, radius: 70, color: [0.25, 0.75, 1.0, 1])
Text.new('Controls', x: 22, y: 18, size: 22, color: '#f9fafb')

# Tabs and buttons are `Button`s — each centers its own label and hit-tests
# itself, so there's no manual text offset or bounds math anywhere below.
tabs = ['Circle', 'Square'].map.with_index do |name, i|
  Button.new(x: 20 + i * 110, y: 62, width: 100, height: 34,
             label: name, label_size: 15, color: '#374151', label_color: '#f9fafb')
end

# Pulse toggle — an iOS-style pill: a center bar capped by two circles, with a
# knob that slides between the caps. The pill pieces (`toggle_bg`) recolor as
# one; only the knob moves. A visual-less Button over the pill is the hit area.
toggle_x, toggle_y, toggle_w, toggle_h = 20, 125, 56, 28
cap_r = toggle_h / 2
toggle_bg = [
  Rectangle.new(x: toggle_x + cap_r, y: toggle_y,
                width: toggle_w - 2 * cap_r, height: toggle_h, color: '#4b5563'),
  Circle.new(x: toggle_x + cap_r, y: toggle_y + cap_r, radius: cap_r, color: '#4b5563'),
  Circle.new(x: toggle_x + toggle_w - cap_r, y: toggle_y + cap_r, radius: cap_r, color: '#4b5563')
]
toggle_knob = Circle.new(x: toggle_x + cap_r, y: toggle_y + cap_r, radius: 10, color: '#f9fafb')
toggle_btn = Button.new(x: toggle_x, y: toggle_y, width: toggle_w, height: toggle_h)
Text.new('Pulse', x: 90, y: 128, size: 17, color: '#e5e7eb')

slider_specs = [
  ['Red', 0.25, '#ef4444'],
  ['Green', 0.75, '#22c55e'],
  ['Blue', 1.0, '#38bdf8'],
  ['Size', 0.55, '#facc15']
]
sliders = slider_specs.map.with_index do |(name, value, color), i|
  y = 190 + i * 58
  {
    name: name, value: value, color: color, y: y,
    label: Text.new(name, x: 20, y: y - 24, size: 14, color: '#d1d5db'),
    track: Rectangle.new(x: 20, y: y, width: 190, height: 6, color: '#374151'),
    fill: Rectangle.new(x: 20, y: y, width: 190 * value, height: 6, color: color),
    knob: Circle.new(x: 20 + 190 * value, y: y + 3, radius: 9, color: '#f9fafb')
  }
end

reset_btn = Button.new(x: 20, y: 440, width: 100, height: 34,
                       label: 'Reset', label_size: 15, color: '#374151', label_color: '#f9fafb')
random_btn = Button.new(x: 134, y: 440, width: 106, height: 34,
                        label: 'Random', label_size: 15, color: '#374151', label_color: '#f9fafb')

mode = :circle
pulse = false
drag_slider = nil
t = 0.0

redraw = lambda do
  tabs.each_with_index do |tab, i|
    selected = (mode == :circle && i.zero?) || (mode == :square && i == 1)
    tab.color = selected ? '#2563eb' : '#374151'
  end

  toggle_color = pulse ? '#16a34a' : '#4b5563'
  toggle_bg.each { |part| part.color = toggle_color }
  toggle_knob.x = pulse ? toggle_x + toggle_w - cap_r : toggle_x + cap_r

  sliders.each do |s|
    s[:fill].width = 190 * s[:value]
    s[:knob].x = 20 + 190 * s[:value]
  end

  color = [sliders[0][:value], sliders[1][:value], sliders[2][:value], 1]
  size = 35 + sliders[3][:value] * 95
  preview.remove
  preview = if mode == :circle
              Circle.new(x: 510, y: 250, radius: size / 2, color: color)
            else
              Square.new(x: 510 - size / 2, y: 250 - size / 2, size: size, color: color)
            end
  request_render
end

# === Helpers ===

set_slider = lambda do |slider, x|
  slider[:value] = ((x - 20) / 190.0).clamp(0.0, 1.0)
  redraw.call
end

# === Input ===

# Buttons hit-test themselves and fire `:click`, so the clickable controls just
# attach handlers — no coordinate math.
tabs.each_with_index do |tab, i|
  tab.on(:click) do
    mode = i.zero? ? :circle : :square
    redraw.call
  end
end

toggle_btn.on(:click) do
  pulse = !pulse
  redraw.call
end

reset_btn.on(:click) do
  slider_specs.each_with_index { |(_, value, _), i| sliders[i][:value] = value }
  redraw.call
end

random_btn.on(:click) do
  sliders.each { |s| s[:value] = rand }
  redraw.call
end

# Sliders drag rather than click, so they stay on the window's mouse handlers.
on :mouse_down do |event|
  sliders.each do |s|
    next unless event.x.between?(15, 215) && event.y.between?(s[:y] - 10, s[:y] + 16)

    drag_slider = s
    set_slider.call(s, event.x)
  end
end

on :mouse_up do
  drag_slider = nil
end

on :mouse_move do |event|
  set_slider.call(drag_slider, event.x) if drag_slider
end

# === Update ===

update do |dt|
  next unless pulse

  t += PULSE_RATE * dt
  preview.opacity = 0.65 + Math.sin(t) * 0.25
  request_render
end

redraw.call
show
