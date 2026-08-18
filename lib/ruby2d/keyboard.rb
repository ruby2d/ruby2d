# Ruby2D::Keyboard

module Ruby2D
  # The keyboard's name vocabulary.
  #
  # The names live in the C extension, next to the SDL scancodes they map (see
  # `R2D_KeyName` in `ext/ruby2d/keyboard.c`). Key events arrive from
  # `drain_events` already carrying their symbol, so no scancode ever reaches
  # Ruby and there is no second copy of the table to keep in step.
  #
  # What lives here is the Ruby-side view of that vocabulary: the set of names
  # that exist, used to reject a misspelled key rather than let it match
  # nothing forever.
  module Keyboard
    # `:unknown` is part of the vocabulary the extension supplies: a key with
    # no name reports it, so an unmapped key still delivers events and can
    # still be matched.
    #
    # Built on first use, not at load: `core.rb` requires the native extension
    # after the rest of `lib/`, so `Ext` does not exist yet when this is read.
    def self.keys
      @keys ||= Vocabulary.new(
        'key', Ext.key_names,
        'see `Ruby2D::Keyboard.names` for the full list ' \
        '(e.g. :space, :left_shift, :digit_1)'
      )
    end

    # Every key name this build can report, including `:unknown`.
    def self.names = keys.names

    def self.key?(name) = keys.valid?(name)

    def self.validate!(name) = keys.validate!(name)
  end
end
