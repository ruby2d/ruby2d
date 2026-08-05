# Symbolic alignment (`x: :center`, etc.) resolves at draw time against the
# window viewport. These tests stub the viewport and the native draw calls so
# the resolution math runs without an open window. Center-anchored shapes
# (Circle, Ellipse) align their bounding box like a rectangle, then offset to
# their center.
RSpec.describe 'Symbolic alignment' do
  before do
    allow(Ruby2D::Window).to receive(:viewport_width).and_return(800)
    allow(Ruby2D::Window).to receive(:viewport_height).and_return(600)
    allow(Ruby2D::Ext).to receive(:draw_circle)
    allow(Ruby2D::Ext).to receive(:draw_ellipse)
    allow(Ruby2D::Ext).to receive(:draw_quad)
    allow(Ruby2D::Ext).to receive(:draw_quad_uniform)
  end

  describe Ruby2D::Circle do
    it 'centers the circle for x: :center, y: :center' do
      c = Ruby2D::Circle.new(x: :center, y: :center, radius: 50, add: false)
      c.send(:render)
      expect(c.x).to eq(400)
      expect(c.y).to eq(300)
    end

    it 'hugs the left/top walls with the bounding box for :left/:top' do
      c = Ruby2D::Circle.new(x: :left, y: :top, radius: 50, add: false)
      c.send(:render)
      expect(c.x).to eq(50) # left edge at 0 → center at radius
      expect(c.y).to eq(50) # top edge at 0
    end

    it 'respects padding on an edge-aligned axis' do
      c = Ruby2D::Circle.new(x: :left, radius: 50, padding: 10, add: false)
      c.send(:render)
      expect(c.x).to eq(60) # left edge at 10
    end

    it 'keeps the alignment intent across renders, but clears it on a numeric set' do
      c = Ruby2D::Circle.new(x: :center, radius: 50, add: false)
      c.send(:render)
      expect(c.x_align).to eq(:center)
      expect(c.x).to eq(400)

      c.x = 123
      expect(c.x_align).to be_nil
      expect(c.x).to eq(123)
    end
  end

  describe Ruby2D::Ellipse do
    it 'centers the ellipse for x: :center, y: :center' do
      e = Ruby2D::Ellipse.new(x: :center, y: :center, xradius: 100, yradius: 40, add: false)
      e.send(:render)
      expect(e.x).to eq(400)
      expect(e.y).to eq(300)
    end

    it 'hugs the right wall for :right' do
      e = Ruby2D::Ellipse.new(x: :right, xradius: 100, yradius: 40, add: false)
      e.send(:render)
      expect(e.x).to eq(700) # right edge at 800 → center at 800 - xradius
    end
  end

  describe Ruby2D::Rectangle do
    it 'still resolves alignment through render (regression guard)' do
      r = Ruby2D::Rectangle.new(x: :center, y: :center, width: 100, height: 60, add: false)
      r.send(:render)
      expect(r.x).to eq(350) # top-left for centering a 100-wide box in 800
      expect(r.y).to eq(270) # top-left for centering a 60-tall box in 600
    end
  end

  # Shapes with no single anchor reject a symbolic position with a clear error,
  # rather than leaking a `Symbol#-` NoMethodError (vertex shapes) or silently
  # storing the symbol until it crashes at draw time (Canvas). BitmapText has its
  # own guard — see bitmap_text_spec.rb.
  describe 'shapes without an alignment anchor' do
    it 'reject a symbolic position on the centroid-translated vertex shapes' do
      shapes = [
        Ruby2D::Triangle.new(add: false),
        Ruby2D::Quad.new(add: false),
        Ruby2D::Polygon.new(points: [[0, 0], [100, 0], [50, 100]], add: false),
        Ruby2D::Polyline.new(points: [[0, 0], [100, 100]], add: false)
      ]
      shapes.each do |shape|
        expect { shape.x = :center }.to raise_error(Ruby2D::Error, /must be a number/)
        expect { shape.y = :top }.to raise_error(Ruby2D::Error, /must be a number/)
      end
    end

    it 'rejects a symbolic position on Canvas, at construction and at assignment' do
      expect { Ruby2D::Canvas.new(width: 50, height: 50, x: :center, add: false) }
        .to raise_error(Ruby2D::Error, /must be a number/)
      c = Ruby2D::Canvas.new(width: 50, height: 50, add: false)
      expect { c.x = :center }.to raise_error(Ruby2D::Error, /must be a number/)
      expect { c.y = :bottom }.to raise_error(Ruby2D::Error, /must be a number/)
    end

    it 'still translates the centroid for a numeric assignment' do
      t = Ruby2D::Triangle.new(x1: 0, y1: 0, x2: 30, y2: 0, x3: 0, y3: 30, add: false)
      t.x = 100
      expect(t.x).to be_within(1e-9).of(100)
    end
  end

  # Alignment intent can be set two ways — a symbol through `x=` / `y=`, or
  # `x_align=` / `y_align=` directly — and both must agree with the `x_align`
  # getter. None of that was covered before, on any shape.
  describe 'setting intent after construction' do
    def aligned_shapes
      [
        Ruby2D::Circle.new(radius: 10, add: false),
        Ruby2D::Ellipse.new(xradius: 10, yradius: 5, add: false),
        Ruby2D::Rectangle.new(width: 20, height: 10, add: false),
        Ruby2D::Square.new(size: 20, add: false),
        Ruby2D::Image.new(test_image('image.png'), add: false),
        Ruby2D::Text.new('hi', add: false)
      ]
    end

    it 'accepts a symbol through x= / y= on every aligning shape' do
      aligned_shapes.each do |shape|
        shape.x = :center
        shape.y = :top
        expect(shape.x_align).to eq(:center)
        expect(shape.y_align).to eq(:top)
      end
    end

    it 'accepts intent through x_align= / y_align= too' do
      aligned_shapes.each do |shape|
        shape.x_align = :right
        shape.y_align = :bottom
        expect(shape.x_align).to eq(:right)
        expect(shape.y_align).to eq(:bottom)
      end
    end

    it 'takes symbolic alignment from the constructor' do
      c = Ruby2D::Circle.new(x: :center, y: :bottom, radius: 10, add: false)
      expect(c.x_align).to eq(:center)
      expect(c.y_align).to eq(:bottom)
    end

    it 'resolves intent set after construction at draw time' do
      c = Ruby2D::Circle.new(x: 0, y: 0, radius: 50, add: false)
      c.x_align = :center
      c.y_align = :bottom
      c.send(:render)
      expect(c.x).to eq(400)
      expect(c.y).to eq(550) # bottom edge at 600 → center one radius up
    end

    it 'clears intent when a number is assigned' do
      c = Ruby2D::Circle.new(x: :center, radius: 10, add: false)
      c.x = 42
      expect(c.x_align).to be_nil
      expect(c.x).to eq(42)
    end

    describe Ruby2D::Button do
      def owned_button
        Ruby2D::Button.new(x: 0, y: 0, width: 40, height: 20,
                           color: '#333', add: false)
      end

      # Button's `x_align` getter reads the owned visual, so its setter has to
      # write there too — otherwise the two disagree and setting alignment
      # appears to do nothing.
      it 'round-trips intent through x_align= and the getter' do
        b = owned_button
        b.x_align = :center
        b.y_align = :bottom
        expect(b.x_align).to eq(:center)
        expect(b.y_align).to eq(:bottom)
      end

      it 'round-trips intent through a symbol on x= too' do
        b = owned_button
        b.x = :right
        expect(b.x_align).to eq(:right)
      end

      it 'takes symbolic alignment from the constructor' do
        b = Ruby2D::Button.new(x: :center, y: 5, width: 40, height: 20,
                               color: '#333', add: false)
        expect(b.x_align).to eq(:center)
      end

      it 'ignores intent on a visual-less button rather than raising' do
        b = Ruby2D::Button.new(x: 0, y: 0, width: 40, height: 20, add: false)
        b.x_align = :center
        expect(b.x_align).to be_nil
      end
    end
  end
end
