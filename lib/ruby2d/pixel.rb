# Ruby2D::Pixel

module Ruby2D
  class Pixel

    def self.draw(opts = {})
      ext_draw([
        opts[:x]              , opts[:y],
        opts[:x] + opts[:size], opts[:y],
        opts[:x] + opts[:size], opts[:y] + opts[:size],
        opts[:x]              , opts[:y] + opts[:size],
        opts[:color][0], opts[:color][1], opts[:color][2], opts[:color][3]
      ])
    end

  end
end
