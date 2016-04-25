# dsl.rb

module Ruby2D::DSL
  def get(sym)
    Ruby2D::Application.get(sym)
  end
  
  def set(opts)
    Ruby2D::Application.set(opts)
  end
  
  def on(mouse: nil, key: nil, key_down: nil, controller: nil, &proc)
    Ruby2D::Application.on(mouse: mouse, key: key, key_down: key_down, controller: controller, &proc)
  end
  
  def update(&proc)
    Ruby2D::Application.update(&proc)
  end
  
  def show
    Ruby2D::Application.show
  end
  
  def clear
    Ruby2D::Application.clear
  end
end
