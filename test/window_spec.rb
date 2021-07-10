require 'ruby2d'

RSpec.describe Ruby2D::Window do

  it "returns class values" do
    expect(Window.current).to be_a(Ruby2D::Window)
    set width: 200
    expect(Window.width).to eq(200)
  end

  it "does not allow screenshots until shown" do
    expect(Window.screenshot).to be false
  end

end
