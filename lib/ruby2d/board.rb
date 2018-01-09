# board.rb

module Ruby2D
  class Board

    attr_accessor :x_offset, :y_offset
    attr_reader :pieces, :collision_layers

    def initialize
      @x_offset         = 0
      @y_offset         = 0
      @pieces           = []
      @collision_layers = Hash.new
    end

    def add_piece(piece)
      @pieces << piece
      if piece.active_collision_tags != nil
        puts "Piece Active Collision: #{piece.active_collision_tags}"
        piece.active_collision_tags.each do |tag|
          if @collision_layers[tag] == nil then @collision_layers[tag] = CollisionLayer.new end
          @collision_layers[tag].active_pieces << piece
        end
      end
      if piece.passive_collision_tags != nil
        piece.passive_collision_tags.each do |tag|
          if @collision_layers[tag] == nil then @collision_layers[tag] = CollisionLayer.new end
          @collision_layers[tag].passive_pieces << piece
        end
      end
    end

    def remove_piece(piece)
      @pieces.delete piece
      @collision_layers.each_value do |layer|
        layer.delete piece
      end
    end

    def update
      @collision_layers.each_value do |layer| layer.update end
      update_render
    end

    def update_render
      @pieces.each do |piece|
        piece.renderable.x = @x_offset + piece.x
        piece.renderable.y = @y_offset + piece.y
      end
    end
  end
end
