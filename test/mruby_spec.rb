require 'ruby2d'

RSpec.describe Ruby2D do
  if ENV.include? 'RUBY2D_DEV_MODE'
    it "builds mruby" do
      expect(system("ruby2d build test/triangle.rb", out: File::NULL)).to be true
    end
  end
end
