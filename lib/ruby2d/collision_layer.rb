# collision_layer.rb

module Ruby2D
  class CollisionLayer

    attr_accessor :active_pieces, :passive_pieces, :interval

    def initialize(opts = {})
      @active_pieces  = opts[:active_pieces]  || []
      @passive_pieces = opts[:passive_pieces] || []
      @interval       = opts[:interval]       || 1
    end

    def update
      @active_pieces.each do |piece|
        piece.collider.x = piece.x
        piece.collider.y = piece.y
      end
      @passive_pieces.each do |piece|
        piece.collider.x = piece.x
        piece.collider.y = piece.y
      end

      @active_pieces.combination(2) do |first, second|
        collision = collision_check? first.collider, second.collider
        if collision
          first.collide_with second if first.respond_to? :collide_with
          second.collide_with first if second.respond_to? :collide_with
        end
      end

      @active_pieces.each do |active|
        @passive_pieces.each do |passive|
          collision = collision_check? active.collider, passive.collider
          if collision
            active.collide_with passive if active.respond_to? :collide_with
            passive.collide_with active if passive.respond_to? :collide_with
          end
        end
      end
    end

    def remove_piece piece
      @active_pieces.delete piece
      @passive_pieces.delete piece
    end
  end
end
