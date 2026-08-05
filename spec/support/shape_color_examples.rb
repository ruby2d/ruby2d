# Shared examples for shape color handling.
#
# All Renderable subclasses share the same color/opacity plumbing. Rather than
# repeat the same three blocks (default white, color: + opacity:, color set/read)
# in every shape spec, specs `include_examples 'renderable color defaults'` and
# pass the class plus any required kwargs.
#
# `vertex color set` covers the per-vertex Color::Set normalization for shapes
# with a fixed vertex count (Triangle = 3, Quad/Rectangle/Square = 4).

# Every shape exposes numeric width/height (bounding-box extents). These are
# the universal accessors documented for all shapes — never nil.
shared_examples 'shape dimensions' do |klass, kwargs = {}|
  it 'exposes numeric, non-negative width and height' do
    obj = klass.new(**kwargs)
    expect(obj.width).to be_a(Numeric)
    expect(obj.height).to be_a(Numeric)
    expect(obj.width).to be >= 0
    expect(obj.height).to be >= 0
  end
end

# Renderable color defaults: white-by-default and color/opacity kwargs.
shared_examples 'renderable color defaults' do |klass, kwargs = {}|
  it 'defaults to white' do
    obj = klass.new(**kwargs)
    expect(obj.color).to be_a(Ruby2D::Color)
    expect(obj.color.r).to eq(1)
    expect(obj.color.g).to eq(1)
    expect(obj.color.b).to eq(1)
    expect(obj.color.a).to eq(1)
  end

  it 'accepts color: and opacity: kwargs' do
    obj = klass.new(**kwargs, color: 'gray', opacity: 0.5)
    expect(obj.color.r).to eq(2 / 3.0)
    expect(obj.opacity).to eq(0.5)
  end
end

# Per-vertex Color::Set acceptance and length validation.
shared_examples 'vertex color set' do |klass, vertex_count, kwargs = {}|
  string_palette = %w[red green blue black fuchsia yellow]
  array_palette  = (0...6).map { |i| [0.1 + i * 0.1, 0.2, 0.3, 0.4 + i * 0.1] }

  it 'accepts a single color via string' do
    obj = klass.new(**kwargs, color: 'red')
    expect(obj.color).to be_a(Ruby2D::Color)
  end

  it 'accepts a single color via [r, g, b, a]' do
    obj = klass.new(**kwargs, color: [0.1, 0.3, 0.5, 0.7])
    expect(obj.color).to be_a(Ruby2D::Color)
  end

  it "accepts #{vertex_count} colors via array of strings" do
    obj = klass.new(**kwargs, color: string_palette[0, vertex_count])
    expect(obj.color).to be_a(Ruby2D::Color::Set)
  end

  it "accepts #{vertex_count} colors via array of [r, g, b, a]" do
    obj = klass.new(**kwargs, color: array_palette[0, vertex_count])
    expect(obj.color).to be_a(Ruby2D::Color::Set)
  end

  it "raises when given #{vertex_count - 1} colors" do
    expect do
      klass.new(**kwargs, color: string_palette[0, vertex_count - 1])
    end.to raise_error(
      "`#{klass.name}` requires #{vertex_count} colors, one for each vertex. #{vertex_count - 1} were given."
    )
  end

  it "raises when given #{vertex_count + 1} colors" do
    expect do
      klass.new(**kwargs, color: string_palette[0, vertex_count + 1])
    end.to raise_error(
      "`#{klass.name}` requires #{vertex_count} colors, one for each vertex. #{vertex_count + 1} were given."
    )
  end
end
