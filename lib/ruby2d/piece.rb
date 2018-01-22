# piece.rb

module Ruby2D
  class Piece
    attr_accessor :x, :y, :renderable
    attr_reader :collider

    def initialize(opts = {})
      @x              = opts[:x]            || 0
      @y              = opts[:y]            || 0
      @renderable     = opts[:renderable]   || nil
      @collider       = opts[:collider]     || nil
    end
  end
end
