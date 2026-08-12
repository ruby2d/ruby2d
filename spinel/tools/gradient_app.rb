# Second fixture for `rake compare`: per-vertex colors, the one shape family
# whose FFI path takes different arguments from the single-color one.
#
# Kept separate from `cli_app.rb` because the two answer different questions.
# That one names its three exact colors, which is how an inert stroke gets
# caught; a gradient has thousands and no count worth asserting. What this one
# proves is only meaningful against mruby: that the same four corner colors
# land in the same places.
#
# It exists because they did not. `Ext.draw_quad` took its 24 floats with the
# coordinates grouped first while `Quad#render` passes them interleaved, so the
# adapter re-interleaved already-interleaved data and drew a smear across the
# top-left corner. Every single-color fixture passed throughout — they go
# through `draw_quad_uniform`, a different entry point.
#
# `FRAMES` caps the run and `SHOT` writes a screenshot, so the built binary can
# be inspected without a human watching the window.

require 'ruby2d'

set title: 'Spinel gradient check', width: 320, height: 240, background: 'navy'

# Four corners, four distinct hues: any transposition of the vertex order shows
# up as colors in the wrong corners rather than as a plausible-looking blend.
Square.new(x: 120, y: 80, size: 80, color: %w[red lime blue yellow])

frames = (ENV['FRAMES'] || '30').to_i
shot = ENV['SHOT'] || ''

n = 0
update do
  n += 1
  Ruby2D::DSL.window.screenshot(shot) if !shot.empty? && n == frames
  close if n > frames
end

show
puts "ran #{n} frames"
