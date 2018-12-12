require 'ruby2d'

s1 = Square.new(x: 0, y: 0, size: 100, color: 'white')
s2 = Square.new(x: 100, y: 100, size: 50, color: 'green')
c = 0.0
switch = true

update do

  if switch
    c += 0.01
    if c > 1.0
      switch = false
    end
  else
    c -= 0.01
    if c < 0.0
      switch = true
    end
  end

  s1.color = [1, 1, 1, c]
end

show
