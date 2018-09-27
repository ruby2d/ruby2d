require 'ruby2d'

RSpec.describe Ruby2D::Window do

  it "returns class values" do
    expect(Window.current).to be_a(Ruby2D::Window)
    expect(Window.width).to eq(640)
    set width: 200
    expect(Window.width).to eq(200)
  end

end
