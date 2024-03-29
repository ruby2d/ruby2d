require 'ruby2d'

set width: 800
set height: 600

atlas = PixmapAtlas.new
atlas.load_and_keep_image "#{Ruby2D.test_media}/colors.png", as: 'colors'

Square.new(size: 500, color: 'red')

# Canvas options:
#  x, y, z, width, height, rotate, fill, color, update
# If `update: false` is set, `canvas.update` must be manually called to update the rendered texture
canvas = Canvas.new(x: 50, y: 50, width: Window.width - 100, height: Window.height - 100, fill: [1, 1, 1, 0.5])

clear_between_draw = false
draw_shape = :square

update do
  canvas.clear if clear_between_draw

  case draw_shape
  when :circle
    canvas.draw_circle(
      x: Window.mouse_x - 25, y: Window.mouse_y - 25,
      radius: 25, sectors: 10,
      color: [rand, rand, rand, 1]
    )
    canvas.fill_circle(
      x: Window.mouse_x - 25, y: Window.mouse_y - 25,
      radius: 20, sectors: 10,
      color: [rand, rand, rand, 1]
    )
  when :pixmap
    canvas.draw_pixmap(
      atlas['colors'],
      x: Window.mouse_x - 50, y: Window.mouse_y - 50,
      width: 50, height: 50
    )
  else
    canvas.draw_rectangle(
      x: Window.mouse_x - 50, y: Window.mouse_y - 50,
      width: 50, height: 50,
      color: [rand, rand, rand, 1]
    )
    canvas.fill_rectangle(
      x: Window.mouse_x - 50 + 5, y: Window.mouse_y - 50 + 5,
      width: 40, height: 40,
      color: [rand, rand, rand, 1]
    )
  end

  canvas.draw_line(
    x1: 0, y1: 0, x2: Window.mouse_x - 50, y2: Window.mouse_y - 50, stroke_width: 1,
    color: [rand, rand, rand, 1]
  )
end

draw_shape_options = %i[square circle pixmap]

#
# Press space to enable/disable clearing between frame while moving the mouse
# Press s to switch between square and circle
#
on :key_down do |event|
  case event.key
  when 'escape'
    close
  when 's'
    draw_shape = draw_shape_options[(draw_shape_options.index(draw_shape) + 1) % draw_shape_options.count]
  when 'space'
    clear_between_draw = !clear_between_draw
  end
  canvas.update
end

puts '
Press Esc to exit.
Press s or S to switch between shapes: square, circle, pixmap
Press space to toggle between clearing background or just drawing on top while moving

Move the mouse.
'

show
