# The "class pattern" subclasses Ruby2D::Window and overrides #update and/or
# #render. Detection is independent per method, so overriding only one still
# runs it every frame. Regression test for the bug where overriding just
# #update left it uncalled because #render was not also overridden.
RSpec.describe 'Window class pattern' do
  it 'calls an overridden #update even when #render is not overridden' do
    klass = Class.new(Ruby2D::Window) do
      attr_reader :updated
      def update
        @updated = true
      end
    end
    win = klass.new
    win.update_callback
    expect(win.updated).to be true
  end

  it 'calls an overridden #render even when #update is not overridden' do
    klass = Class.new(Ruby2D::Window) do
      attr_reader :rendered
      def render
        @rendered = true
      end
    end
    win = klass.new
    win.render_callback
    expect(win.rendered).to be true
  end

  it 'calls an #update mixed into a subclass by a module' do
    hook = Module.new do
      def update
        @updated = true
      end
    end
    klass = Class.new(Ruby2D::Window) do
      include hook
      attr_reader :updated
    end
    win = klass.new
    win.update_callback
    expect(win.updated).to be true
  end

  it 'treats a module prepended to Window as instrumentation, not an override' do
    # Wrapping #update — to count frames, or to hook into an app whose update
    # block you can't edit — fronts the DSL setter the same way a subclass
    # override does. Mistaking it for the class pattern calls the setter with no
    # block every frame, which raises. (The wrapper only delegates, so leaving it
    # prepended for the rest of the suite changes nothing.)
    wrapper = Module.new do
      def update(&blk)
        super
      end
    end
    Ruby2D::Window.prepend(wrapper)

    win = Ruby2D::Window.new
    ran = []
    win.update { ran << :block }
    expect { win.update_callback }.not_to raise_error
    expect(ran).to eq([:block])
  end

  it 'does not invoke the DSL setters as frame callbacks for a plain window' do
    # A plain Window uses #update / #render as DSL block setters; the frame loop
    # must run the registered blocks, not call the setter methods (which would
    # clobber @update_proc / @render_proc).
    win = Ruby2D::Window.new
    ran = []
    win.update { ran << :update_block }
    win.render { ran << :render_block }
    win.update_callback
    win.render_callback
    expect(ran).to eq([:update_block, :render_block])
  end
end
