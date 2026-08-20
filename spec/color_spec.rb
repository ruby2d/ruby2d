RSpec.describe Ruby2D::Color do

  describe ".valid?" do
    it "determines if a color string is valid" do
      expect(Ruby2D::Color.valid? 'red').to eq true
      expect(Ruby2D::Color.valid? 'balloons').to eq false
    end

    it "determines if a color string is a valid hex value" do
      expect(Ruby2D::Color.valid? '#c0c0c0').to eq true
      expect(Ruby2D::Color.valid? '#FF0').to eq true
      expect(Ruby2D::Color.valid? '#FF000080').to eq true
      expect(Ruby2D::Color.valid? '#00000').to eq false
      expect(Ruby2D::Color.valid? '123456').to eq false
      expect(Ruby2D::Color.valid? '#ZZZZZZ').to eq false
    end

    it "determines if an array is a valid color" do
      expect(Ruby2D::Color.valid? [1, 0, 0.0, 1.0]).to eq true # rgba
      expect(Ruby2D::Color.valid? [1.0, 0, 0]).to eq true      # rgb (alpha optional)
      expect(Ruby2D::Color.valid? [1, 0]).to eq false          # too few
      expect(Ruby2D::Color.valid? [1, 0, 0, 0, 0]).to eq false # too many
    end
  end

  describe "#new" do
    it "raises error on bad color" do
      expect { Ruby2D::Color.new 42 }.to raise_error Ruby2D::Error
    end

    it "accepts an existing color object" do
      expect { Ruby2D::Color.new(Ruby2D::Color.new('red')) }.to_not raise_error
    end

    it "assigns rgba from an existing color" do
      c1 = Ruby2D::Color.new([0.2, 0.6, 0.8, 0.5])
      c2 = Ruby2D::Color.new(c1)

      expect([c2.r, c2.g, c2.b, c2.a]).to eq([0.2, 0.6, 0.8, 0.5])
    end
  end

  # Array colors are plain numbers on the 0.0..1.0 scale (the graphics
  # convention used internally), whether given as integers or floats.
  describe "array colors (0.0..1.0 scale)" do
    before { Ruby2D.instance_variable_set(:@warned_messages, {}) }

    it "treats RGB floats literally on the 0.0..1.0 scale" do
      c = Ruby2D::Color.new([1.0, 0.5, 0.0])
      expect([c.r, c.g, c.b, c.a]).to eq([1.0, 0.5, 0.0, 1.0]) # 3-element rgb is opaque
    end

    it "treats integer 0 and 1 as the scale's endpoints, stored as floats" do
      c = Ruby2D::Color.new([1, 0, 0])
      expect([c.r, c.g, c.b]).to eq([1.0, 0.0, 0.0]) # full-intensity red
      expect(c.r).to be_a(Float)
    end

    it "reads alpha on the same 0.0..1.0 scale, whether integer or float" do
      expect(Ruby2D::Color.new([1.0, 0, 0, 0.5]).a).to eq(0.5)
      expect(Ruby2D::Color.new([1.0, 0, 0, 1]).a).to eq(1.0) # integer 1 is opaque
    end

    it "warns and clamps an out-of-range channel" do
      c = nil
      expect { c = Ruby2D::Color.new([1.5, 0, 0]) }.to output(/color value 1.5.*0\.0\.\.1\.0/).to_stderr
      expect(c.r).to eq(1.0)
    end

    it "warns and clamps a 0..255-style byte value" do
      expect { Ruby2D::Color.new([255, 0, 0]) }.to output(/color value 255.*0\.0\.\.1\.0/).to_stderr
      expect(Ruby2D::Color.new([255, 0, 0]).r).to eq(1.0) # clamped (already warned, silent now)
    end

    it "warns only once per distinct message" do
      expect { Ruby2D::Color.new([1.5, 0, 0]) }.to output(/color value/).to_stderr
      expect { Ruby2D::Color.new([1.5, 0, 0]) }.not_to output.to_stderr
    end
  end

  describe "#opacity" do
    it "sets and returns the opacity" do
      c = Ruby2D::Color.new('red')
      c.opacity = 0.5
      expect(c.opacity).to eq(0.5)
      expect(c.a).to eq(0.5)
    end

    it "rejects a non-numeric opacity instead of corrupting the alpha" do
      c = Ruby2D::Color.new('red')
      expect { c.opacity = [0.1, 0.2] }.to raise_error(ArgumentError)
      expect { c.opacity = 'half' }.to raise_error(ArgumentError)
      expect(c.a).to eq(1.0) # unchanged
    end

    it "rejects a non-numeric opacity on a Color::Set" do
      s = Ruby2D::Color::Set.new(%w[red green blue])
      expect { s.opacity = [0.1, 0.2, 0.3] }.to raise_error(ArgumentError)
    end

    it "clamps an out-of-range opacity into 0.0..1.0 (animation-safe, no wrap)" do
      c = Ruby2D::Color.new('red')
      c.opacity = 1.5
      expect(c.opacity).to eq(1.0)
      c.opacity = -0.3
      expect(c.opacity).to eq(0.0)
    end

    it "clamps every vertex alpha when clamping a Color::Set" do
      s = Ruby2D::Color::Set.new(%w[red green blue])
      s.opacity = 2.0
      s.each { |col| expect(col.opacity).to eq(1.0) }
    end
  end

  it "allows British English spelling of color" do
    expect(Ruby2D::Colour).to eq(Ruby2D::Color)
    expect(Square.new.colour.class).to eq(Ruby2D::Color)
  end

  describe "#vertex" do
    it "returns self for any index on a single Color" do
      c = Ruby2D::Color.new('red')
      expect(c.vertex(0)).to equal(c)
      expect(c.vertex(5)).to equal(c)
      expect(c.vertex(-1)).to equal(c)
    end

    it "returns the i-th color on a Color::Set" do
      s = Ruby2D::Color::Set.new(%w[red green blue])
      expect(s.vertex(0).r).to eq(Ruby2D::Color.new('red').r)
      expect(s.vertex(1).r).to eq(Ruby2D::Color.new('green').r)
      expect(s.vertex(2).r).to eq(Ruby2D::Color.new('blue').r)
    end

    it "allows per-vertex rendering code to ignore the single-vs-set distinction" do
      # Four distinct, float-exact channels (not all-red) so a wrong channel or
      # color would surface instead of passing trivially.
      rgba   = [0.25, 0.5, 0.75, 1.0]
      single = Ruby2D::Color.new(rgba)
      set    = Ruby2D::Color::Set.new([rgba, rgba, rgba])
      # Both yield the real per-vertex color when iterated via #vertex
      3.times do |i|
        expect(single.vertex(i).to_a).to eq(rgba)
        expect(set.vertex(i).to_a).to eq(single.vertex(i).to_a)
      end
    end
  end

  describe ".set" do
    it "builds a Color::Set from a non-empty array of valid colors" do
      expect(Ruby2D::Color.set(%w[red green blue])).to be_a(Ruby2D::Color::Set)
    end

    it "treats a plain RGBA array as a single Color, not a set" do
      expect(Ruby2D::Color.set([1.0, 0.5, 0.0])).to be_a(Ruby2D::Color)
    end

    it "rejects an empty array at the mistake site instead of making an empty set" do
      expect { Ruby2D::Color.set([]) }.to raise_error(Ruby2D::Error, /not a valid color/)
    end

    it "rejects an empty array passed straight to Color::Set.new" do
      expect { Ruby2D::Color::Set.new([]) }.to raise_error(Ruby2D::Error, /at least one color/)
    end
  end

  describe ".for_render" do
    it "returns the same shared instance for a repeated color string" do
      expect(Ruby2D::Color.for_render('#e5e7eb')).to equal(Ruby2D::Color.for_render('#e5e7eb'))
    end

    it "resolves named colors to the same values as .new" do
      expect(Ruby2D::Color.for_render('red').r).to eq(Ruby2D::Color.new('red').r)
    end

    it "never caches 'random'" do
      expect(Ruby2D::Color.for_render('random')).not_to equal(Ruby2D::Color.for_render('random'))
    end

    it "returns the same shared instance for a repeated [r, g, b, a] array" do
      rgba = [0.1, 0.2, 0.3, 1.0]
      expect(Ruby2D::Color.for_render(rgba)).to equal(Ruby2D::Color.for_render(rgba))
    end

    it "looks up array colors by value, so equal arrays share and mutation can't corrupt" do
      shared = Ruby2D::Color.for_render([0.4, 0.5, 0.6, 1.0])
      expect(Ruby2D::Color.for_render([0.4, 0.5, 0.6, 1.0])).to equal(shared)

      mutated = [0.4, 0.5, 0.6, 1.0]
      Ruby2D::Color.for_render(mutated)
      mutated[0] = 0.9
      expect(Ruby2D::Color.for_render(mutated).r).to eq(0.9)
      # The original entry is untouched by the mutation.
      expect(Ruby2D::Color.for_render([0.4, 0.5, 0.6, 1.0]).r).to eq(0.4)
    end

    it "resolves array colors to the same values as .new, including 3-element arrays" do
      expect(Ruby2D::Color.for_render([0.1, 0.2, 0.3]).a).to eq(1.0)
      expect(Ruby2D::Color.for_render([0.1, 0.2, 0.3, 0.5]).a).to eq(0.5)
    end

    it "delegates other non-string input to .set (fresh instance each call)" do
      expect(Ruby2D::Color.for_render(%w[red blue])).to be_a(Ruby2D::Color::Set)
      nested = [[0.1, 0.2, 0.3, 1.0]]
      expect(Ruby2D::Color.for_render(nested)).not_to equal(Ruby2D::Color.for_render(nested))
    end

    it "raises on invalid strings like .new" do
      expect { Ruby2D::Color.for_render('#nope') }.to raise_error(Ruby2D::Error, /not a valid color/)
    end
  end

  # Shapes cache their flattened RGBA arrays against this counter instead of
  # rescanning every channel each frame, so every in-place mutation must bump
  # it, and a Color::Set must reflect its members' changes.
  describe "#_rev (mutation revision)" do
    it "starts at zero and increments on every channel write" do
      c = Ruby2D::Color.new('red')
      expect(c._rev).to eq(0)
      c.r = 0.5
      c.g = 0.5
      c.b = 0.5
      c.a = 0.5
      c.opacity = 0.25
      expect(c._rev).to eq(5)
    end

    it "propagates a member's change to the Color::Set revision" do
      s = Ruby2D::Color::Set.new(%w[red green blue])
      expect(s._rev).to eq(0)
      s[1].r = 0.5
      expect(s._rev).to eq(1)
      s.opacity = 0.5
      expect(s._rev).to eq(4)
    end

    it "gives a Color::Set its own member copies, so the source color has no owner" do
      src = Ruby2D::Color.new('red')
      s = Ruby2D::Color::Set.new([src, 'blue'])
      src.r = 0.1
      expect(s._rev).to eq(0)
      expect(s[0].r).to eq(1.0)
    end
  end
end
