require 'ruby2d'

set title: "Ruby 2D — Controller", width: 600, height: 425
set diagnostics: true

# Controller outline image
controller = Image.new("#{Ruby2D.test_media}/controller.png")

scale = 80

axis_left_x = Quad.new(
  x1: 156, y1: 130,
  x2: 156, y2: 130,
  x3: 156, y3: 159,
  x4: 156, y4: 159,
  color: [0, 1, 0, 1]
)

axis_left_y = Quad.new(
  x1: 142, y1: 145,
  x2: 171, y2: 145,
  x3: 171, y3: 145,
  x4: 142, y4: 145,
  color: [0, 1, 0, 1]
)

axis_right_x = Quad.new(
  x1: 374, y1: 215,
  x2: 374, y2: 215,
  x3: 374, y3: 244,
  x4: 374, y4: 244,
  color: [0, 1, 0, 1]
)

axis_right_y = Quad.new(
  x1: 359, y1: 229,
  x2: 388, y2: 229,
  x3: 388, y3: 229,
  x4: 359, y4: 229,
  color: [0, 1, 0, 1]
)

axis_trigger_left = Quad.new(
  x1:  8, y1: 71,
  x2: 42, y2: 71,
  x3: 42, y3: 71,
  x4:  8, y4: 71,
  color: [0, 1, 0, 1]
)

axis_trigger_right = Quad.new(
  x1:  8 + 550, y1: 71,
  x2: 42 + 550, y2: 71,
  x3: 42 + 550, y3: 71,
  x4:  8 + 550, y4: 71,
  color: [0, 1, 0, 1]
)

@btn_a = Quad.new(
  x1: 426,      y1: 167,
  x2: 426 + 33, y2: 167,
  x3: 426 + 33, y3: 167 + 33,
  x4: 426,      y4: 167 + 33,
  color: [0, 1, 0, 0]
)

@btn_b = Quad.new(
  x1: 464,      y1: 129,
  x2: 464 + 33, y2: 129,
  x3: 464 + 33, y3: 129 + 33,
  x4: 464,      y4: 129 + 33,
  color: [1, 0, 0, 0]
)

@btn_x = Quad.new(
  x1: 388,      y1: 128,
  x2: 388 + 33, y2: 128,
  x3: 388 + 33, y3: 128 + 33,
  x4: 388,      y4: 128 + 33,
  color: [0, 0.7, 1, 0]
)

@btn_y = Quad.new(
  x1: 426,      y1: 91,
  x2: 426 + 33, y2: 91,
  x3: 426 + 33, y3: 91 + 33,
  x4: 426,      y4: 91 + 33,
  color: [1, 1, 0, 0]
)

@btn_back = Quad.new(
  x1: 248,      y1: 133,
  x2: 248 + 23, y2: 133,
  x3: 248 + 23, y3: 133 + 23,
  x4: 248,      y4: 133 + 23,
  color: [1, 0.5, 0, 0]
)

@btn_guide = Quad.new(
  x1: 281,      y1: 69,
  x2: 281 + 38, y2: 69,
  x3: 281 + 38, y3: 69 + 38,
  x4: 281,      y4: 69 + 38,
  color: [0.5, 1, 0.5, 0]
)

@btn_start = Quad.new(
  x1: 331,      y1: 133,
  x2: 331 + 23, y2: 133,
  x3: 331 + 23, y3: 133 + 23,
  x4: 331,      y4: 133 + 23,
  color: [1, 0.5, 0, 0]
)

@btn_left_stick = Quad.new(
  x1: 8,      y1: 4,
  x2: 8 + 34, y2: 4,
  x3: 8 + 38, y3: 4 + 67,
  x4: 8 -  4, y4: 4 + 67,
  color: [1, 0, 0, 0]
)

@btn_right_stick = Quad.new(
  x1: 558,      y1: 4,
  x2: 558 + 34, y2: 4,
  x3: 558 + 38, y3: 4 + 67,
  x4: 558 -  4, y4: 4 + 67,
  color: [1, 0, 0, 0]
)

@btn_left_shoulder = Quad.new(
  x1: 111, y1: 84,
  x2: 117, y2: 64,
  x3: 198, y3: 39,
  x4: 225, y4: 52,
  color: [0.5, 0, 1, 0]
)

@btn_right_shoulder = Quad.new(
  x1: 494, y1: 85,
  x2: 484, y2: 64,
  x3: 401, y3: 39,
  x4: 378, y4: 51,
  color: [0.5, 0, 1, 0]
)

@btn_up = Quad.new(
  x1: 216,      y1: 194,
  x2: 216 + 23, y2: 194,
  x3: 216 + 23, y3: 194 + 28,
  x4: 216,      y4: 194 + 28,
  color: [1, 0, 0.5, 0]
)

@btn_down = Quad.new(
  x1: 216,      y1: 243,
  x2: 216 + 23, y2: 243,
  x3: 216 + 23, y3: 243 + 27,
  x4: 216,      y4: 243 + 27,
  color: [1, 0, 0.5, 0]
)

@btn_left = Quad.new(
  x1: 189,      y1: 221,
  x2: 189 + 28, y2: 221,
  x3: 189 + 28, y3: 221 + 22,
  x4: 189,      y4: 221 + 22,
  color: [1, 0, 0.5, 0]
)

@btn_right = Quad.new(
  x1: 238,      y1: 221,
  x2: 238 + 28, y2: 221,
  x3: 238 + 28, y3: 221 + 22,
  x4: 238,      y4: 221 + 22,
  color: [1, 0, 0.5, 0]
)

on :controller do |event|
  puts event
end

on :controller_axis do |event|
  puts "Axis: #{event.axis}, Value: #{event.value}"
  case event.axis
  when :left_x
    axis_left_x.x2 = 156 + event.value * scale
    axis_left_x.x3 = 156 + event.value * scale
  when :left_y
    axis_left_y.y1 = 145 + event.value * scale
    axis_left_y.y2 = 145 + event.value * scale
  when :right_x
    axis_right_x.x2 = 374 + event.value * scale
    axis_right_x.x3 = 374 + event.value * scale
  when :right_y
    axis_right_y.y1 = 229 + event.value * scale
    axis_right_y.y2 = 229 + event.value * scale
  when :trigger_left
    axis_trigger_left.y1 = 71 - event.value * 67
    axis_trigger_left.y2 = 71 - event.value * 67
  when :trigger_right
    axis_trigger_right.y1 = 71 - event.value * 67
    axis_trigger_right.y2 = 71 - event.value * 67
  end
end

on :controller_button_down do |event|
  instance_variable_get("@btn_#{event.button}").opacity = 1.0
end

on :controller_button_up do |event|
  instance_variable_get("@btn_#{event.button}").opacity = 0
end

on :key_down do |event|
  close if event.key == 'escape'
end

show
