require 'ruby2d'

set title: "Ruby 2D — Sprite", width: 400, height: 300

coin1 = Sprite.new(
  "#{Ruby2D.test_media}/coin.png",
  clip_width: 84,
  time: 300,
  loop: true
)

coin1.play

coin2 = Sprite.new(
  "#{Ruby2D.test_media}/coin.png",
  y: 90,
  width: 42,
  height: 42,
  clip_width: 84,
  time: 300,
  loop: true
)

coin2.play

boom = Sprite.new(
  "#{Ruby2D.test_media}/boom.png",
  x: 109,
  clip_width: 127,
  time: 75
)

hero = Sprite.new(
  "#{Ruby2D.test_media}/hero.png",
  x: 261,
  width: 78,
  height: 99,
  clip_width: 78,
  time: 250,
  animations: {
    walk: 1..2,
    climb: 3..4,
    cheer: 5..6
  }
)

atlas = Sprite.new(
  "#{Ruby2D.test_media}/texture_atlas.png",
  x: 50, y: 90,
  animations: {
    count: [
      {
        x: 0, y: 0,
        width: 35, height: 41,
        time: 300
      },
      {
        x: 26, y: 46,
        width: 35, height: 38,
        time: 400
      },
      {
        x: 65, y: 10,
        width: 32, height: 41,
        time: 500
      },
      {
        x: 10, y: 99,
        width: 32, height: 38,
        time: 600
      },
      {
        x: 74, y: 80,
        width: 32, height: 38,
        time: 700
      }
    ]
  }
)

atlas.play animation: :count, loop: true


on :key_down do |e|
  close if e.key == 'escape'

  case e.key
  when 'p'
    coin1.play
    coin2.play
    boom.play
    atlas.play animation: :count
  when 'b'
    boom.play do
      puts "Boom animation finished!"
    end
  when 's'
    coin1.stop
    coin2.stop
    hero.stop
    atlas.stop
  when 'left'
    hero.play animation: :walk, loop: true, flip: :horizontal
  when 'right'
    hero.play animation: :walk, loop: true
  when 'up'
    hero.play animation: :climb, loop: true
  when 'down'
    hero.play animation: :climb, loop: true, flip: :vertical
  when 'h'
    hero.play animation: :climb, loop: true, flip: :both
  when 'c'
    hero.play animation: :cheer
  end
end

on :key_held do |e|
  case e.key
  when 'a'
    hero.play animation: :walk, loop: true, flip: :horizontal
    hero.x -= 1
  when 'd'
    hero.play animation: :walk, loop: true
    hero.x += 1
  when 'w'
    hero.play animation: :climb, loop: true
    hero.y -= 1
  when 's'
    hero.play animation: :climb, loop: true, flip: :vertical
    hero.y += 1
  when 'z'
    hero.width  = get(:mouse_x)
    hero.height = get(:mouse_y)
  end
end

on :key_up do |e|
  if ['w', 'a', 's', 'd'].include? e.key
    hero.stop
  end
end

show
