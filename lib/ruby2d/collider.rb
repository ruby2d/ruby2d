# collider.rb

module Ruby2D
  class Collider
    attr_accessor :form, :x, :y, :height, :width, :radius
    attr_reader :active_tags, :passive_tags

    def initialize(opts = {})
      @form         = opts[:form]         || nil
      @x            = opts[:x]            || 0
      @y            = opts[:y]            || 0
      @height       = opts[:height]       || nil
      @width        = opts[:width]        || nil
      @radius       = opts[:radius]       || nil
      @active_tags  = opts[:active_tags]  || nil
      @passive_tags = opts[:passive_tags] || nil
    end

    def right
      return @x + @width
    end

    def bottom
      return @y + @height
    end

    def add_active_tag(tag)
      if @active_tags == nil then @active_tags = [] end
      @active_tags << tag
    end

    def remove_active_tag(tag)
      @active_tags.delete tag
    end

    def add_passive_tag(tag)
      if @passive_tags == nil then @passive_tags = [] end
      @passive_tags << tag
    end

    def remove_passive_tag(tag)
      @passive_tags.delete tag
    end
  end

  def collision_check?(first, second)
    case first.form
    when :rectangle
      case second.form
      when :rectangle
        return collision_check_rect_rect?(first, second)
      when :circle
        return collision_check_rect_circle?(first, second)
      when :point
        return collision_check_rect_point?(first, second)
      end
    when :circle
      case second.form
      when :rectangle
        return collision_check_rect_circle?(second, first)
      when :circle
        return collision_check_circle_circle?(first, second)
      when :point
        return collision_check_circle_point?(first, second)
      end
    when :point
      case second.form
      when :rectangle
        return collision_check_rect_point?(second, first)
      when :circle
        return collision_check_circle_point?(second, first)
      when :point
        return collision_check_point_point?(first, second)
      end
    end
    return false
  end

  def collision_check_rect_rect?(first, second)
    x_overlap = first.x < second.right && first.right > second.x
    x_overlap = second.x < first.right && second.right > first.x
    return false unless x_overlap
    y_overlap = first.y < second.bottom && first.bottom > second.y
    y_overlap = second.y < first.bottom && second.bottom > first.y
    return y_overlap
  end

  def collision_check_rect_circle?(rect, circle)
    rect_point_x = [rect.x, circle.x].max [rect.right, circle.x].max
    rect_point_y = [rect.y, circle.y].max [rect.bottom, circle.y].max
    rect_point = Collider.new(
      x: rect_point_x,
      y: rect_point_y
    )
    return collision_check_circle_point?(circle, rect_point)
  end

  def collision_check_rect_point?(rect, point)
    return false unless point.x > rect.x && point.x < rect.right
    return point.y > rect.y && point.y < rect.bottom
  end

  def collision_check_circle_circle?(first, second)
    distance = sqrt((second.x - first.x)**2 + (second.y - first.y)**2)
    return distance < first.radius + second.radius
  end

  def collision_check_circle_point?(circle, point)
    distance = sqrt((circle.x - point.x)**2 + (circle.y - point.y)**2)
    return distance < circle.radius
  end

  def collision_check_point_point?(first, second)
    return first.x == second.x && first.y == second.y
  end
end
