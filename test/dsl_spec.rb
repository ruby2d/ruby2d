require 'ruby2d'
include Ruby2D::DSL

RSpec.describe Ruby2D::DSL do

  describe "#get" do
    it "gets the default window attributes" do
      expect(get :width).to eq 640
      expect(get :height).to eq 480
      expect(get :title).to eq "Ruby 2D"
    end
  end

  describe "#set" do
    it "sets a single window attribute" do
      set width: 300
      expect(get :width).to eq 300
      expect(get :height).to eq 480
      expect(get :title).to eq "Ruby 2D"
    end

    it "sets multiple window attributes at a time" do
      set width: 800, height: 600, title: "Hello tests!"
      expect(get :width).to eq 800
      expect(get :height).to eq 600
      expect(get :title).to eq "Hello tests!"
    end
  end

end
