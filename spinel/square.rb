# The goal of this branch, in eight lines: an ordinary Ruby 2D script, built
# with `ruby2d build --spinel square.rb` into a standalone binary.
#
# This is USAGE.md's opening example, copied verbatim — nothing here is written
# for Spinel, and that is the whole point. Anything this file needs that the
# target can't do is a gap in the target, not a compromise to make here.
#
#   RUBY2D_SPINEL=../spinel/bin/spinel ruby2d build --spinel spinel/square.rb
#   ruby2d launch --native

require 'ruby2d'

set title: 'My App'
set background: 'navy'

Square.new(x: 50, y: 50, size: 100, color: 'red')

show
