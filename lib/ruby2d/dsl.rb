# dsl.rb

module Ruby2D::DSL
  def window
    Application.window
  end

  def get(sym)
    Application.get(sym)
  end

  def set(opts)
    Application.set(opts)
  end

  def on(event, &proc)
    Application.on(event, &proc)
  end

  def off(event_descriptor)
    Application.off(event_descriptor)
  end

  def update(&proc)
    Application.update(&proc)
  end

  def clear
    Application.clear
  end

  def show
    Application.show
  end

  def close
    Application.close
  end

end
