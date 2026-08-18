# Ruby2D::Mouse

module Ruby2D
  # The mouse's name vocabulary.
  #
  # Mirrors `Window::MOUSE_BTN_MAP`, which translates SDL's button codes into
  # these symbols on the way in; a spec asserts the two stay in step.
  module Mouse
    BUTTONS = Vocabulary.new(
      'mouse button', %i[left middle right x1 x2],
      'one of :left, :middle, :right, :x1, :x2'
    )

    def self.button?(name) = BUTTONS.valid?(name)

    def self.validate!(name) = BUTTONS.validate!(name)
  end
end
