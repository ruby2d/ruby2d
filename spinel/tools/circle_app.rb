# Third fixture for `rake compare`: the circle entry points, which are the only
# ones in the adapter that do not go through `R2D_DrawQuad`.
#
# Kept separate from `cli_app.rb` for the reason that one is separate from
# `gradient_app.rb` — a fixture only proves the entry points it reaches, and
# these two are reached by nothing else. `draw_circle` takes a sector count
# where every quad entry point takes coordinates, and `stroke_circle` maps onto
# `R2D_StrokeEllipse` with the radius passed twice, so a transposed argument
# here would draw a plausible-looking wrong shape that no quad fixture sees.
#
# A non-default `sectors` is deliberate: the count reaches C as an `:int` while
# everything around it is `:float`, and the default would still be produced by
# an adapter that dropped the argument.
#
# The fill is a numeric `[r, g, b, a]` array, which no other fixture uses. That
# form crashed every app that used one until `Color.valid?` stopped handing a
# non-String key to a String-keyed Hash — see matz/spinel#3810 — and it went
# unnoticed for as long as it did precisely because nothing here reached it. The
# alpha is deliberate too: it blends against the background, so the two engines
# have to agree on the float color math and not just on the geometry.
#
# `FRAMES` caps the run and `SHOT` writes a screenshot, so the built binary can
# be inspected without a human watching the window.

require 'ruby2d'

set title: 'Spinel circle check', width: 320, height: 240, background: 'navy'

Circle.new(x: 160, y: 120, radius: 70, sectors: 12,
           color: [0.4, 0.6, 0.9, 0.85],
           stroke_width: 6, stroke_color: 'lime')

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
