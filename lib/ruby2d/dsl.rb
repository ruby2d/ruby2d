# dsl.rb

module Ruby2D::DSL
  def get(sym)
    Application.get(sym)
  end
  
  def set(opts)
    Application.set(opts)
  end
  
  def on(mouse: nil, key: nil, key_down: nil, controller: nil, &proc)
    Application.on(mouse: mouse, key: key, key_down: key_down, controller: controller, &proc)
  end
  
  def update(&proc)
    Application.update(&proc)
  end
  end
  
  def show
    Application.show
  end
  
  def clear
    Ruby2D::Application.clear
  end
end
