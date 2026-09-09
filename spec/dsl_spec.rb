RSpec.describe Ruby2D::DSL do
  # Mix the DSL into this example group only. A top-level `include` would land
  # on Object and make every object in the whole suite respond to `set`/`on`/
  # `update`/..., turning respond_to?-based assertions vacuous.
  include Ruby2D::DSL

  describe "#get" do
    it "gets the default window attributes" do
      expect(get :width).to eq(640)
      expect(get :height).to eq(480)
      expect(get :title).to eq("Ruby 2D")
    end
  end

  describe "#set" do
    it "sets a single window attribute" do
      set width: 300
      expect(get :width).to eq(300)
      expect(get :height).to eq(480)
      expect(get :title).to eq("Ruby 2D")
    end

    it "sets multiple window attributes at a time" do
      set width: 800, height: 600, title: "Hello tests!"
      expect(get :width).to eq(800)
      expect(get :height).to eq(600)
      expect(get :title).to eq("Hello tests!")
    end
  end

  describe "#elapsed" do
    it "returns monotonic, non-negative seconds since the engine started" do
      first = elapsed
      second = elapsed
      expect(first).to be_a(Float)
      expect(first).to be >= 0
      expect(second).to be >= first
    end
  end

  # USAGE.md promises every readable window attribute as a method on the
  # Window class too. Nothing at runtime tells a method `attr_reader` defined
  # from one written out, so the list is read from the source.
  describe "Window class getters" do
    it "cover every attribute reader on the window instance" do
      source = File.read(File.expand_path('../lib/ruby2d/window.rb', __dir__))
      readers = source[/^ *attr_reader (.*?)\n\n/m, 1].scan(/:(\w+)/).flatten.map(&:to_sym)
      expect(readers).to include(:title, :render_mode, :close_on_esc, :icon)
      missing = readers.reject { |name| Ruby2D::Window.respond_to?(name) }
      expect(missing).to be_empty
    end

    it "read the same values as the instance and `get`" do
      set title: 'Getter check', render_mode: :on_demand, close_on_esc: true
      %i[title render_mode close_on_esc icon].each do |name|
        expect(Ruby2D::Window.public_send(name)).to eq(get(name))
        expect(Ruby2D::Window.public_send(name)).to eq(Ruby2D::Window.current.public_send(name))
      end
      expect(Ruby2D::Window.render_mode).to eq(:on_demand)
      expect(Ruby2D::Window.close_on_esc).to be true
      expect(Ruby2D::Window.icon).to be_nil
    end
  end
end
