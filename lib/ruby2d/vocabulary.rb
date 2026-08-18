# Ruby2D::Vocabulary

module Ruby2D
  # A closed set of input names.
  #
  # Every input device names its inputs with symbols drawn from a fixed set —
  # keys, mouse buttons, gamepad buttons, gamepad axes. Wrapping each set in a
  # Vocabulary gives them all the same behavior: a name outside the set raises
  # and says what was expected, instead of returning a `false` that can never
  # become true. A misspelled input name is a bug in the game, and a silent
  # `false` is the hardest possible way to find it — the program runs, the
  # branch never fires, and nothing says why.
  class Vocabulary
    # `kind` names the input in error messages ("key", "mouse button"), and
    # `hint` closes the message with where to find valid names.
    def initialize(kind, names, hint)
      @kind = kind
      @hint = hint
      @names = {}
      names.each { |name| @names[name] = true }
      @names.freeze
      freeze
    end

    def valid?(name)
      @names.key?(name)
    end

    def names
      @names.keys
    end

    # Returns `name` when it is valid, so a call site can wrap its argument
    # inline: `@buttons_held.include?(BUTTONS.validate!(button))`.
    def validate!(name)
      return name if valid?(name)

      if name.is_a?(String) && valid?(name.downcase.to_sym)
        raise Error, "`#{name.inspect}` is not a valid #{@kind} name — " \
                     "#{@kind} names are symbols, use " \
                     "`#{name.downcase.to_sym.inspect}`"
      end

      raise Error, "`#{name.inspect}` is not a valid #{@kind} name — #{@hint}"
    end
  end
end
