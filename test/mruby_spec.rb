require 'ruby2d'

RSpec.describe Ruby2D do

  it "builds mruby" do
    expect(system("ruby2d build --native test/triangle.rb")).to be true
  end

end
