require 'ruby2d'

RSpec.describe Ruby2D::Circle do

  describe "#new" do
    it "creates a white circle by default" do
      circle = Circle.new
      expect(circle.color).to be_a(Ruby2D::Color)
      expect(circle.color.r).to eq(1)
      expect(circle.color.g).to eq(1)
      expect(circle.color.b).to eq(1)
      expect(circle.color.a).to eq(1)
    end
  end

end
