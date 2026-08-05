RSpec.describe Ruby2D::Canvas do

  subject(:canvas) do
    Canvas.new(width: 200, height: 200, fill: [0, 0, 0, 0], add: false)
  end

  describe '#new' do
    it 'creates a canvas with defaults' do
      c = Canvas.new(width: 100, height: 100, add: false)
      expect(c.x).to eq(0)
      expect(c.y).to eq(0)
      expect(c.width).to eq(100)
      expect(c.height).to eq(100)
      expect(c.rotate).to eq(0)
    end

    it 'creates a canvas with options' do
      c = Canvas.new(
        x: 10, y: 20, z: 30,
        width: 200, height: 150,
        rotate: 45,
        fill: [1, 1, 1, 0.5],
        tint: 'red', opacity: 0.8,
        add: false
      )
      expect(c.x).to eq(10)
      expect(c.y).to eq(20)
      expect(c.width).to eq(200)
      expect(c.height).to eq(150)
      expect(c.rotate).to eq(45)
      expect(c.fill).to be_a(Ruby2D::Color)
      expect(c.tint).to be_a(Ruby2D::Color)
      expect(c.tint.opacity).to eq(0.8)
    end
  end

  describe '#fill_triangle' do
    it 'draws a filled triangle with a named color' do
      expect {
        canvas.fill_triangle(x1: 10, y1: 10, x2: 50, y2: 10, x3: 30, y3: 50, color: 'red')
      }.not_to raise_error
    end

    it 'draws a filled triangle with an RGBA array' do
      expect {
        canvas.fill_triangle(x1: 0, y1: 0, x2: 100, y2: 0, x3: 50, y3: 100, color: [0.5, 0.5, 0.5, 0.5])
      }.not_to raise_error
    end

    it 'uses the canvas tint when no color is given' do
      expect {
        canvas.fill_triangle(x1: 10, y1: 10, x2: 50, y2: 10, x3: 30, y3: 50)
      }.not_to raise_error
    end
  end

  describe '#fill_quad' do
    it 'draws a filled quad' do
      expect {
        canvas.fill_quad(
          x1: 10, y1: 10, x2: 90, y2: 10,
          x3: 80, y3: 90, x4: 20, y4: 90,
          color: 'blue'
        )
      }.not_to raise_error
    end

    it 'uses the canvas tint when no color is given' do
      expect {
        canvas.fill_quad(
          x1: 10, y1: 10, x2: 90, y2: 10,
          x3: 80, y3: 90, x4: 20, y4: 90
        )
      }.not_to raise_error
    end
  end

  describe '#fill_rectangle' do
    it 'draws a filled rectangle with a named color' do
      expect {
        canvas.fill_rectangle(x: 10, y: 10, width: 80, height: 60, color: 'green')
      }.not_to raise_error
    end

    it 'draws a semi-transparent rectangle' do
      expect {
        canvas.fill_rectangle(x: 10, y: 10, width: 80, height: 60, color: [1, 0, 0, 0.5])
      }.not_to raise_error
    end
  end

  describe '#fill_rectangles' do
    it 'fills many rectangles with a shared color' do
      expect {
        canvas.fill_rectangles(
          rectangles: [[10, 10, 20, 20], [40, 40, 30, 30], [80, 80, 10, 10]],
          color: 'green'
        )
      }.not_to raise_error
    end

    it 'is a no-op on empty input' do
      expect {
        canvas.fill_rectangles(rectangles: [], color: 'green')
      }.not_to raise_error
    end

    it 'raises on a tuple of the wrong length' do
      expect {
        canvas.fill_rectangles(rectangles: [[10, 10, 20]], color: 'green')
      }.to raise_error(ArgumentError)
    end

    it 'accepts a semi-transparent color' do
      expect {
        canvas.fill_rectangles(rectangles: [[0, 0, 50, 50]], color: [1, 0, 0, 0.5])
      }.not_to raise_error
    end
  end

  describe '#fill_square' do
    it 'draws a filled square' do
      expect {
        canvas.fill_square(x: 10, y: 10, size: 50, color: 'yellow')
      }.not_to raise_error
    end
  end

  describe '#fill_circle' do
    it 'draws a filled circle' do
      expect {
        canvas.fill_circle(x: 100, y: 100, radius: 40, color: 'orange')
      }.not_to raise_error
    end

    it 'draws a semi-transparent circle' do
      expect {
        canvas.fill_circle(x: 100, y: 100, radius: 40, color: [0, 1, 0, 0.5])
      }.not_to raise_error
    end

    it 'is a no-op (no out-of-bounds write) at radius 0' do
      expect {
        canvas.fill_circle(x: 100, y: 100, radius: 0, color: 'orange')
      }.not_to raise_error
    end
  end

  describe '#fill_ellipse' do
    it 'draws a filled ellipse' do
      expect {
        canvas.fill_ellipse(x: 100, y: 100, xradius: 60, yradius: 30, color: 'purple')
      }.not_to raise_error
    end

    it 'draws a semi-transparent ellipse' do
      expect {
        canvas.fill_ellipse(x: 100, y: 100, xradius: 60, yradius: 30, color: [1, 0, 1, 0.5])
      }.not_to raise_error
    end

    it 'is a no-op (no out-of-bounds write) when either radius is 0' do
      expect {
        canvas.fill_ellipse(x: 100, y: 100, xradius: 0, yradius: 30, color: 'purple')
        canvas.fill_ellipse(x: 100, y: 100, xradius: 60, yradius: 0, color: 'purple')
      }.not_to raise_error
    end
  end

  describe '#draw_lines' do
    it 'draws many line segments with a shared color' do
      expect {
        canvas.draw_lines(
          segments: [[[0, 0], [100, 0]], [[0, 100], [100, 100]], [[50, 0], [50, 100]]],
          color: 'white'
        )
      }.not_to raise_error
    end

    it 'accepts a stroke_width' do
      expect {
        canvas.draw_lines(
          segments: [[[0, 0], [100, 100]]],
          stroke_width: 3, color: 'white'
        )
      }.not_to raise_error
    end

    it 'is a no-op on empty input' do
      expect {
        canvas.draw_lines(segments: [], color: 'white')
      }.not_to raise_error
    end

    it 'raises on a malformed segment' do
      expect {
        canvas.draw_lines(segments: [[[0, 0], [100]]], color: 'white')
      }.to raise_error(ArgumentError)
    end
  end

  describe 'per-vertex fill opacity' do
    it 'accepts a per-vertex opacity array on fill_triangle with a Color::Set' do
      expect {
        canvas.fill_triangle(points: [[0, 0], [50, 0], [25, 50]],
                             color: %w[red green blue], opacity: [0.2, 0.5, 0.9])
      }.not_to raise_error
    end

    it 'accepts a per-vertex opacity array on fill_polygon with a single color' do
      expect {
        canvas.fill_polygon(points: [[0, 0], [50, 0], [50, 50], [0, 50]],
                            color: 'red', opacity: [0.1, 0.4, 0.7, 1.0])
      }.not_to raise_error
    end

    it 'accepts a per-vertex opacity array on fill_quad' do
      expect {
        canvas.fill_quad(points: [[0, 0], [50, 0], [50, 50], [0, 50]],
                        color: 'blue', opacity: [0.1, 0.4, 0.7, 1.0])
      }.not_to raise_error
    end

    it 'routes fill_rectangle with a per-vertex opacity array through the quad path' do
      expect {
        canvas.fill_rectangle(x: 0, y: 0, width: 50, height: 50,
                             color: 'green', opacity: [0.1, 0.4, 0.7, 1.0])
      }.not_to raise_error
    end

    it 'raises a clear error when the opacity array length does not match the vertices' do
      expect {
        canvas.fill_triangle(points: [[0, 0], [50, 0], [25, 50]], color: 'red', opacity: [0.2, 0.5])
      }.to raise_error(ArgumentError, /opacity array for fill_triangle must have 3/)
    end

    it 'rejects a per-vertex opacity array on the rasterized fill_ellipse' do
      expect {
        canvas.fill_ellipse(x: 50, y: 50, xradius: 20, yradius: 10, color: 'red', opacity: [0.1, 0.5])
      }.to raise_error(ArgumentError, /does not support a per-vertex opacity/)
    end
  end

  describe 'coordinate validation' do
    # Malformed coordinates must raise a clear ArgumentError in Ruby rather than
    # passing nil/garbage into the C extension, which would surface as a cryptic
    # "no implicit conversion to Float" from deep in the native call.

    it 'raises when fill_triangle is missing a numbered vertex' do
      expect {
        canvas.fill_triangle(x1: 0, y1: 0, x2: 10, y2: 0, color: 'red')
      }.to raise_error(ArgumentError, /fill_triangle: every coordinate must be a number/)
    end

    it 'raises when fill_polygon is given a nil point' do
      expect {
        canvas.fill_polygon(points: [[0, 0], [10, 0], nil], color: 'red')
      }.to raise_error(ArgumentError, /points must be an array of \[x, y\] pairs/)
    end

    it 'raises when fill_polygon point tuples hold a non-number' do
      expect {
        canvas.fill_polygon(points: [[0, 0], [10, 0], [20, 'x']], color: 'red')
      }.to raise_error(ArgumentError, /fill_polygon: every coordinate must be a number/)
    end

    it 'raises when draw_polyline is given a malformed point tuple' do
      expect {
        canvas.draw_polyline(points: [[0, 0], [50], [100, 0]], color: 'red')
      }.to raise_error(ArgumentError, /points must be an array of \[x, y\] pairs/)
    end

    it 'raises when draw_line is missing a numbered endpoint' do
      expect {
        canvas.draw_line(x1: 0, y1: 0, x2: 100, color: 'red')
      }.to raise_error(ArgumentError, /draw_line: every coordinate must be a number/)
    end
  end

  describe 'non-finite coordinates' do
    # A NaN/Inf coordinate or size must no-op cleanly rather than reaching the C
    # rasterizer's integer casts (undefined behavior, potential out-of-bounds
    # write). The Ruby guards skip the draw; the C isfinite checks are the
    # load-bearing backstop. This matches the no-op philosophy for degenerate
    # geometry (zero radius, empty input) elsewhere in the API.

    it 'no-ops fill_rectangle with a NaN coordinate' do
      expect {
        canvas.fill_rectangle(x: Float::NAN, y: 0, width: 1, height: 1, color: 'red')
      }.not_to raise_error
    end

    it 'no-ops fill_rectangle with an infinite size' do
      expect {
        canvas.fill_rectangle(x: 0, y: 0, width: Float::INFINITY, height: 1, color: 'red')
      }.not_to raise_error
    end

    it 'no-ops fill_ellipse with a NaN radius' do
      expect {
        canvas.fill_ellipse(x: 50, y: 50, xradius: Float::NAN, yradius: 10, color: 'red')
      }.not_to raise_error
    end

    it 'no-ops fill_triangle with a non-finite vertex' do
      expect {
        canvas.fill_triangle(x1: Float::INFINITY, y1: 0, x2: 50, y2: 0, x3: 25, y3: 50, color: 'red')
      }.not_to raise_error
    end

    it 'no-ops fill_polygon with a non-finite vertex' do
      expect {
        canvas.fill_polygon(points: [[0, 0], [Float::NAN, 0], [25, 50]], color: 'red')
      }.not_to raise_error
    end

    it 'skips only the non-finite rects in fill_rectangles' do
      expect {
        canvas.fill_rectangles(rectangles: [[0, 0, 10, 10], [Float::NAN, 0, 10, 10]], color: 'red')
      }.not_to raise_error
    end

    it 'no-ops fill_pixel_grid with a non-finite cell size' do
      expect {
        canvas.fill_pixel_grid(cols: 2, rows: 2, cell_w: Float::NAN, cell_h: 4,
                               colors: Array.new(2 * 2 * 4, 1.0))
      }.not_to raise_error
    end

    it 'no-ops draw_image with a NaN coordinate' do
      img = Image.new(test_image('image.png'))
      expect {
        canvas.draw_image(img, x: Float::NAN, y: 0)
      }.not_to raise_error
    end

    it 'no-ops draw_text with an infinite size' do
      txt = Text.new('hello')
      expect {
        canvas.draw_text(txt, x: 0, y: 0, width: Float::INFINITY, height: 10)
      }.not_to raise_error
    end

    it 'no-ops clear with a non-finite region' do
      expect {
        canvas.clear(x: Float::NAN, y: 0, width: 10, height: 10)
      }.not_to raise_error
    end
  end

  describe 'non-numeric coordinate types' do
    # A non-Numeric coordinate or size is a programming mistake (e.g. `x: '10'`),
    # so the four-coordinate methods raise a clear ArgumentError just like the
    # vertex-based ones — rather than silently no-opping as they used to. NaN/Inf
    # (a Numeric) still no-ops; only the type error raises.

    it 'raises when fill_rectangle is given a string coordinate' do
      expect {
        canvas.fill_rectangle(x: '10', y: 0, width: 1, height: 1, color: 'red')
      }.to raise_error(ArgumentError, /fill_rectangle: every coordinate must be a number/)
    end

    it 'raises when fill_ellipse is given a string radius' do
      expect {
        canvas.fill_ellipse(x: 50, y: 50, xradius: '10', yradius: 10, color: 'red')
      }.to raise_error(ArgumentError, /fill_ellipse: every coordinate must be a number/)
    end

    it 'raises when a fill_rectangles tuple holds a non-number' do
      expect {
        canvas.fill_rectangles(rectangles: [[0, 0, 10, 10], [0, 0, '10', 10]], color: 'red')
      }.to raise_error(ArgumentError, /fill_rectangles: every coordinate must be a number/)
    end

    it 'raises when fill_pixel_grid is given a string cell size' do
      expect {
        canvas.fill_pixel_grid(cols: 2, rows: 2, cell_w: '4', cell_h: 4,
                               colors: Array.new(2 * 2 * 4, 1.0))
      }.to raise_error(ArgumentError, /fill_pixel_grid: every coordinate must be a number/)
    end

    it 'raises when draw_image is given a string coordinate' do
      img = Image.new(test_image('image.png'))
      expect {
        canvas.draw_image(img, x: '10', y: 0)
      }.to raise_error(ArgumentError, /draw_image: every coordinate must be a number/)
    end

    it 'raises when draw_text is given a string size' do
      txt = Text.new('hello')
      expect {
        canvas.draw_text(txt, x: 0, y: 0, width: '10', height: 10)
      }.to raise_error(ArgumentError, /draw_text: every coordinate must be a number/)
    end

    it 'raises when clear is given a string region bound' do
      expect {
        canvas.clear(x: '10', y: 0, width: 10, height: 10)
      }.to raise_error(ArgumentError, /clear: every coordinate must be a number/)
    end
  end

  describe 'opacity: keyword' do
    # opacity: is accepted on every public draw method. Each entry is a callable
    # that draws on a fresh canvas with opacity: 0.5 — failure means the method
    # signature dropped the keyword.
    OPACITY_DRAW_CALLS = [
      ->(c) { c.draw_line(x1: 0, y1: 0, x2: 100, y2: 0, color: 'red', opacity: 0.5) },
      ->(c) { c.fill_rectangle(x: 0, y: 0, width: 50, height: 50, color: 'red', opacity: 0.5) },
      ->(c) { c.stroke_rectangle(x: 0, y: 0, width: 20, height: 20, color: 'red', opacity: 0.5) },
      ->(c) { c.fill_square(x: 0, y: 0, size: 20, color: 'red', opacity: 0.5) },
      ->(c) { c.stroke_square(x: 0, y: 0, size: 20, color: 'red', opacity: 0.5) },
      ->(c) { c.fill_circle(x: 50, y: 50, radius: 20, color: 'red', opacity: 0.5) },
      ->(c) { c.stroke_circle(x: 50, y: 50, radius: 20, color: 'red', opacity: 0.5) },
      ->(c) { c.fill_ellipse(x: 50, y: 50, xradius: 20, yradius: 10, color: 'red', opacity: 0.5) },
      ->(c) { c.stroke_triangle(x1: 0, y1: 0, x2: 50, y2: 0, x3: 25, y3: 50, color: 'red', opacity: 0.5) },
      ->(c) { c.draw_polyline(points: [[0, 0], [50, 50], [100, 0]], color: 'red', opacity: 0.5) },
      ->(c) { c.fill_polygon(points: [[0, 0], [50, 0], [25, 50]], color: 'red', opacity: 0.5) }
    ].freeze

    it 'is accepted on every public draw method' do
      OPACITY_DRAW_CALLS.each { |call| expect { call.call(canvas) }.not_to raise_error }
    end

    it 'overrides the color alpha without mutating the caller\'s Color' do
      color = Ruby2D::Color.new([1.0, 0, 0, 1.0])
      canvas.draw_line(x1: 0, y1: 0, x2: 100, y2: 100, color: color, opacity: 0.25)
      expect(color.a).to eq(1.0)
    end

    it 'accepts a Color::Set with an opacity override' do
      corners = [[1.0, 0, 0, 1.0], [0, 1.0, 0, 1.0], [0, 0, 1.0, 1.0], [1.0, 1.0, 0, 1.0]]
      expect {
        canvas.fill_rectangle(x: 0, y: 0, width: 50, height: 50, color: corners, opacity: 0.35)
      }.not_to raise_error
    end

    it 'clamps an out-of-range opacity into 0.0..1.0 (scalar, array, and nil pass-through)' do
      expect(canvas.send(:clamp_opacity, 1.4)).to eq(1.0)
      expect(canvas.send(:clamp_opacity, -0.2)).to eq(0.0)
      expect(canvas.send(:clamp_opacity, 0.3)).to eq(0.3)
      expect(canvas.send(:clamp_opacity, nil)).to be_nil
      expect(canvas.send(:clamp_opacity, [1.5, -0.1, 0.5])).to eq([1.0, 0.0, 0.5])
    end

    it 'does not raise (or wrap the alpha) for an out-of-range opacity' do
      expect {
        canvas.fill_rectangle(x: 0, y: 0, width: 50, height: 50, color: 'red', opacity: -0.1)
      }.not_to raise_error
      expect {
        canvas.fill_triangle(points: [[0, 0], [50, 0], [25, 50]], color: 'red', opacity: 1.8)
      }.not_to raise_error
    end
  end

  describe 'draw_line dash and gradient' do
    it 'accepts dash: and gap: kwargs' do
      expect {
        canvas.draw_line(x1: 0, y1: 0, x2: 100, y2: 0, stroke_width: 2,
                         dash: 10, gap: 5, color: 'white')
      }.not_to raise_error
    end

    it 'accepts a Color::Set of 2 (start, end)' do
      expect {
        canvas.draw_line(x1: 0, y1: 0, x2: 100, y2: 0, stroke_width: 2,
                         color: %w[red aqua])
      }.not_to raise_error
    end

    it 'accepts dash + Color::Set for gradient dashed lines' do
      expect {
        canvas.draw_line(x1: 0, y1: 0, x2: 100, y2: 0, stroke_width: 2,
                         dash: 10, gap: 5, color: %w[red aqua])
      }.not_to raise_error
    end

    it 'raises when Color::Set length is not 2' do
      expect {
        canvas.draw_line(x1: 0, y1: 0, x2: 100, y2: 0, color: %w[red green blue])
      }.to raise_error('Color::Set for draw_line must have 2 colors (start, end)')
    end
  end

  describe 'per-vertex stroke gradients' do
    it 'accepts Color::Set on stroke_triangle (3 colors)' do
      expect {
        canvas.stroke_triangle(x1: 0, y1: 0, x2: 50, y2: 0, x3: 25, y3: 50,
                               stroke_width: 3, color: %w[red green blue])
      }.not_to raise_error
    end

    it 'raises when stroke_triangle Color::Set length is not 3' do
      expect {
        canvas.stroke_triangle(x1: 0, y1: 0, x2: 50, y2: 0, x3: 25, y3: 50,
                               stroke_width: 3, color: %w[red green])
      }.to raise_error(/must have 3 colors/)
    end

    it 'accepts Color::Set on stroke_quad (4 colors)' do
      expect {
        canvas.stroke_quad(x1: 0, y1: 0, x2: 50, y2: 0, x3: 50, y3: 50, x4: 0, y4: 50,
                           stroke_width: 3, color: %w[red green blue yellow])
      }.not_to raise_error
    end

    it 'accepts Color::Set on stroke_rectangle (4 colors)' do
      expect {
        canvas.stroke_rectangle(x: 0, y: 0, width: 50, height: 50, stroke_width: 3,
                                color: %w[red green blue yellow])
      }.not_to raise_error
    end

    it 'accepts Color::Set on stroke_square (4 colors)' do
      expect {
        canvas.stroke_square(x: 0, y: 0, size: 50, stroke_width: 3,
                             color: %w[red green blue yellow])
      }.not_to raise_error
    end

    it 'accepts Color::Set on draw_polyline matching vertex count' do
      expect {
        canvas.draw_polyline(points: [[0, 0], [50, 50], [100, 0]], stroke_width: 3,
                             color: %w[red green blue])
      }.not_to raise_error
    end

    it 'raises when draw_polyline Color::Set length does not match vertex count' do
      expect {
        canvas.draw_polyline(points: [[0, 0], [50, 50], [100, 0]], color: %w[red green])
      }.to raise_error(/must have 3 colors/)
    end
  end

end
