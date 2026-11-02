# Per-example resets, in `support/` so the mruby spec build runs them too.

RSpec.configure do |config|
  # Ruby 2D is single-window; `Window.new` refuses a second live instance. Reset
  # the shared DSL window between examples so each starts from a clean slate.
  config.before(:each) { Ruby2D::DSL.window = nil }

  # `Ruby2D.warn` dedupes by message for the life of the process, so a spec that
  # expects a warning would silently depend on no earlier example having emitted
  # the same text. Start every example with an empty dedup set.
  config.before(:each) { Ruby2D.instance_variable_set(:@warned_messages, {}) }
end
