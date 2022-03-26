require 'ruby2d'

RSpec.describe Ruby2D do

  it "builds mruby" do
    expect(system("ruby2d build test/triangle.rb", out: File::NULL)).to be true
  end

end
