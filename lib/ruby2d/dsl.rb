# dsl.rb

module Ruby2D::DSL

  Ruby2D::Window.new

  def get(sym)
    Window.get(sym)
  end

  def set(opts)
    Window.set(opts)
  end

  def on(event, &proc)
    Window.on(event, &proc)
  end

  def off(event_descriptor)
    Window.off(event_descriptor)
  end

  def update(&proc)
    Window.update(&proc)
  end

  def clear
    Window.clear
  end

  def show
    Window.show
  end

  def close
    Window.close
  end

end
