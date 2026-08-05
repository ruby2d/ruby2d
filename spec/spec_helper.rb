require 'ruby2d'

Dir[File.join(__dir__, 'support', '*.rb')].sort.each { |f| require f }

RSpec.configure do |config|
  # Ruby 2D is single-window; `Window.new` refuses a second live instance. Reset
  # the shared DSL window between examples so each starts from a clean slate.
  config.before(:each) { Ruby2D::DSL.window = nil }
end
