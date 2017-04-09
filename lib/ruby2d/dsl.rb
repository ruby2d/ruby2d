# dsl.rb

module Ruby2D::DSL
  def get(sym)
    Application.get(sym)
  end
  
  def set(opts)
    Application.set(opts)
  end
  
  def on(event, &proc)
    Application.on(event, &proc)
  end
  
  def on_key(&proc)
    Application.on_key(&proc)
  end
  
  def on_controller(&proc)
    Application.on_controller(&proc)
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
