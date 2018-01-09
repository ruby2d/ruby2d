# piece.rb

module Ruby2D
  class Piece
    attr_accessor :x, :y, :renderable, :collider
    attr_reader :active_collision_tags, :passive_collision_tags

    def initialize(opts = {})
      @x                      = opts[:x]                      || 0
      @y                      = opts[:y]                      || 0
      @renderable             = opts[:renderable]             || nil
      @collider               = opts[:collider]               || nil
      @active_collision_tags  = opts[:active_collision_tags]  || nil
      @passive_collision_tags = opts[:passive_collision_tags] || nil
    end
  end
end
