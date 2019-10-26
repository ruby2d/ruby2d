module Ruby2D
class ButtonList
  attr_reader :options, :selected

  @@buttonLists = []
  def self.buttonLists
    @@buttonLists
  end

  def initialize(args = {})
    @@buttonLists.push(self)

    @type = args[:type] || 'checkbox'
    @options = {}
    @selected = []
  end

  def addOption(optionParams)
    newOption = Option.new(optionParams)
    @options[newOption.id] = newOption
    return newOption
  end

  def toggle(option)
    if @type == 'checkbox'
      if option.selected == true
        deselect(option)
      else
        select(option)
      end
    elsif @type == 'radio'
      select(option)
    end
  end

  def select(option)
    if @type == 'checkbox'
      @selected.push(option)
      option.select
    elsif @type == 'radio'
      @options.each do |name, option|
        option.deselect
      end
      @selected.clear
      @selected.push(option)
      option.select
    end
  end

  def deselect(option)
    if @type == 'checkbox'
      @selected.delete(option)
      option.deselect
    elsif @type == 'radio'
      #Can not deselect a radio
    end

  end

  class Option
    attr_accessor :value, :enabled
    attr_reader :x, :y, :z, :size, :selected, :displayName, :id, :shown

    def initialize(args = {})
      @displayName = args[:displayName].to_s || "default"
      @value = args[:value] || 0
      @x = args[:x] || 0
      @y = args[:y] || 0
      @z = args[:z] || 1
      @size = args[:size] || 10
      @baseColor = args[:baseColor] || 'white'
      @selectedColor = args[:selectedColor] || 'blue'
      @labelColor = args[:labelColor] || 'white'
      @selected = args[:selected] || false
      @enabled = args[:enabled] || true
      @id = args[:id] || @displayName

      build()

      if @selected == true
        select()
      else
        @selectCircle.remove
      end
    end

    def x=(x)
      @x = x
      rebuild()
    end
    def y=(y)
      @y = y
      rebuild()
    end
    def z=(z)
      @z = z
      rebuild()
    end
    def size=(size)
      @size = size.abs
      rebuild()
    end
    def displayName=(displayName)
      @displayName = displayName
      rebuild()
    end
    def baseColor=(c)
      @baseColor = c
      rebuild()
    end
    def selectedColor=(c)
      @selectedColor = c
      rebuild()
    end
    def labelColor=(c)
      @labelColor = c
      rebuild()
    end

    def select()
      @selectCircle.add
      @selected = true
    end

    def deselect()
      @selectCircle.remove
      @selected = false
    end

    def remove()
      if @shown == false
        return
      end
      @nameLabel.remove
      @baseCircle.remove
      @selectCircle.remove
      @shown = false
    end

    def add()
      if @shown == true
        return
      end
      @nameLabel.add
      @baseCircle.add
      @selectCircle.add
      @shown = true
    end

    def rebuild()
      remove()
      build()
    end

    def build()
      @shown = true

      @nameLabel = Text.new(
        @displayName.to_s,
        x: @x + @size * 2, y: @y - @size,
        size: @size * 2,
        color: @labelColor
      )
      @baseCircle = Circle.new(
        x: @x, y: @y,
        radius: @size,
        color: @baseColor,
        z: @z
      )
      @selectCircle = Circle.new(
        x: @x, y: @y,
        radius: @size * 0.8,
        color: @selectedColor,
        z: @z+1
      )
    end
  end

end

on :mouse_down do |event|
  if event.button == :left
    ButtonList.buttonLists.each do |buttonList|
      buttonList.options.each do |name, button|
        if button.shown && button.enabled
          if event.x.between?(button.x-button.size,button.x+button.size) && event.y.between?(button.y-button.size,button.y+button.size)
            buttonList.toggle(button)
          end
        end
      end
    end
  end
end
end
