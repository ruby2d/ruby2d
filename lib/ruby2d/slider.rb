module Ruby2D
class Slider
  attr_accessor :enabled
  attr_reader :x, :y, :length, :min, :max, :z, :size, :value, :displayName, :id, :shown

  @@sliders = []
  def self.sliders
    @@sliders
  end

  def initialize(args = {})
    @@sliders.push(self)

    @x = args[:x]             || 0
    @y = args[:y]             || 0
    @length = args[:length]   || 100
    @min = args[:min]         || 0
    @max = args[:max]         || 100
    @z = args[:z]             || 1
    @size = args[:size]       || 10
    @value = args[:value]     || @min
    @enabled = args[:enabled] || true
    @displayName = args[:displayName].to_s || "default"
    @id = args[:id] || @displayName.to_s

    @labelColor  = args[:labelColor]  || 'white'
    @sliderColor = args[:sliderColor] || 'gray'
    @knobColor   = args[:knobColor]   || 'green'

    build()
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
  def length=(length)
    @length = length.clamp(1, Window.width-@x)
    rebuild()
  end
  def labelColor=(c)
    @labelColor = c
    rebuild()
  end
  def sliderColor=(c)
    @sliderColor = c
    rebuild()
  end
  def knobColor=(c)
    @knobColor = c
    rebuild()
  end

  def moveKnob(x)
    if x.between?(@x, @x+@length)
      @knob.x = x

      to_max = @max
      to_min = @min
      from_max = @x + @length
      from_min = @x
      pos = @knob.x
      @value = ((to_max - to_min) * (pos - from_min)) / (from_max - from_min) + to_min

      @label.text = @value
    end
  end

  def setValue(value)
    if value.between?(@min, @max)
      to_max = @x + @length
      to_min = @x
      from_max = @max
      from_min = @min
      pos = value
      knobX = ((to_max - to_min) * (pos - from_min)) / (from_max - from_min) + to_min
      moveKnob(knobX)
    end
  end

  def remove()
    if @shown == false
      return
    end
    @sliderLine.remove
    @knob.remove
    @label.remove
    @nameLabel.remove
    @shown = false
  end

  def add()
    if @shown == true
      return
    end
    @sliderLine.add
    @knob.add
    @label.add
    @nameLabel.add
    @shown = true
  end

  def rebuild()
    remove()
    build()
  end

  def build()
    @shown = true

    @sliderLine = Line.new(
      x1: @x, y1: @y,
      x2: @x+@length, y2: @y,
      width: @size,
      color: @sliderColor,
      z: @z
    )

    @knob = Circle.new(
      x: @x, y: @y,
      radius: @size * 1.2,
      color: @knobColor,
      z: @z+1
    )

    @label = Text.new(
      @value.to_s,
      x: @x + @length + @size, y: @y - @size * 1.25,
      size: @size * 2.5,
      color: @labelColor,
      z: @z+1
    )

    @nameLabel = Text.new(
      @displayName.to_s,
      x: @x, y: @y - @size * 3 - @size,
      size: @size * 2.5,
      color: @labelColor,
      z: @z+2
    )
    setValue(@value)
  end
end
end
