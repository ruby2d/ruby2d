# Ruby2D::DSL

module Ruby2D::DSL

  $ruby2d_dsl_window = Ruby2D::Window.new

  def get(sym, opts = nil)
    $ruby2d_dsl_window.get(sym, opts)
  end

  def set(opts)
    $ruby2d_dsl_window.set(opts)
  end

  def on(event, &proc)
    $ruby2d_dsl_window.on(event, &proc)
  end

  def off(event_descriptor)
    $ruby2d_dsl_window.off(event_descriptor)
  end

  def update(&proc)
    $ruby2d_dsl_window.update(&proc)
  end

  def render(&proc)
    $ruby2d_dsl_window.render(&proc)
  end

  def clear
    $ruby2d_dsl_window.clear
  end

  def show
    $ruby2d_dsl_window.show
  end

  def close
    $ruby2d_dsl_window.close
  end

end
