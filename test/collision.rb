require 'ruby2d'

set title: "Ruby 2D — Collision", width: 400, height: 300

class Avatar < Piece
  def collide_with other_piece
    puts "COLLISION! - #{other_piece}"
  end
end

main_board = Board.new
avatar_appearance = Square.new(size: 50, color: [1, 1, 0, 1])
avatar_collider = Collider.new(form: :rectangle, height: 50, width: 50)
avatar = Avatar.new(
  renderable: avatar_appearance,
  collider: avatar_collider,
  active_collision_tags: [:main]
)
main_board.add_piece avatar

on :key do |event|
  case event.key
  when 'left'
    avatar.x -= 3
  when 'right'
    avatar.x += 3
  when 'up'
    avatar.y -= 3
  when 'down'
    avatar.y += 3
  end
end

overlapper_appearance = Square.new(size: 100, color: [1, 0, 1, 1], z: -1)
overlapper_collider = Collider.new(form: :rectangle, height: 100, width: 100)
overlapper = Piece.new(
  x: 150,
  y: 100,
  renderable: overlapper_appearance,
  collider: overlapper_collider,
  passive_collision_tags: [:main]
)
main_board.add_piece overlapper

update do
  main_board.update
end

show
