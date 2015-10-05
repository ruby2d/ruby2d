# dsl.rb

module Ruby2D::DSL
  def hello
    puts "hi"
  end
  
  def get(sym)
    Ruby2D::Application.get(sym)
  end
  
  def set(opts)
    Ruby2D::Application.set(opts)
  end
  
  def on(mouse: nil, key: nil, &proc)
    Ruby2D::Application.on(mouse: mouse, key: key, &proc)
  end
  
  def update(&proc)
    Ruby2D::Application.update(&proc)
  end
  
  def show
    Ruby2D::Application.show
  end
end
