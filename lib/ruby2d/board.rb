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
      if piece.collider.active_tags != nil
        piece.collider.active_tags.each do |tag|
          if @collision_layers[tag] == nil then @collision_layers[tag] = CollisionLayer.new end
          @collision_layers[tag].active_pieces << piece
        end
      end
      if piece.collider.passive_tags != nil
        piece.collider.passive_tags.each do |tag|
          if @collision_layers[tag] == nil then @collision_layers[tag] = CollisionLayer.new end
          @collision_layers[tag].passive_pieces << piece
        end
      end
    end

    def remove_piece(piece)
      @pieces.delete piece
      @collision_layers.each_value do |layer|
        layer.remove_piece piece if layer.include? piece
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

    def add_active_collision_tag(tag, piece)
      piece.collider.add_active_collision_tag tag
      if @collision_layers[tag] == nil then @collision_layers[tag] = CollisionLayer.new end
      @collision_layers[tag].active_pieces << piece
    end

    def remove_active_collision_tag(tag, piece)
      piece.remove_active_collision_tag tag
      @collision_layers[tag].active_pieces.delete piece
    end

    def add_passive_collision_tag(tag, piece)
      piece.collider.add_passive_collision_tag tag
      if @collision_layers[tag] == nil then @collision_layers[tag] = CollisionLayer.new end
      @collision_layers[tag].passive_pieces << piece
    end

    def remove_passive_collision_tag(tag, piece)
      piece.remove_passive_collision_tag tag
      @collision_layers[tag].passive_pieces.delete piece
    end
  end
end
