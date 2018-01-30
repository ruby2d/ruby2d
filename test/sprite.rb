require 'ruby2d'

if RUBY_ENGINE == 'opal'
  media = "../test/media"
else
  media = "media"
end

set title: "Ruby 2D — Sprite", width: 350, height: 150


coin = Sprite.new(
  "#{media}/coin.png",
  clip_width: 84,
  time: 300,
  loop: true
)

coin.play

boom = Sprite.new(
  "#{media}/boom.png",
  x: 109,
  clip_width: 127,
  time: 75
)

hero = Sprite.new(
  "#{media}/hero.png",
  x: 261,
  clip_width: 78,
  time: 250,
  animations: {
    walk: 1..2,
    climb: 3..4,
    cheer: 5..6
  }
)

atlas = Sprite.new(
  "#{media}/texture_atlas.png",
  x: 10, y: 100,
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

atlas.play :count, :loop


on :key_down do |e|
  close if e.key == 'escape'

  case e.key
  when 'p'
    coin.play
    boom.play
    atlas.play :count
  when 's'
    coin.stop
    hero.stop
    atlas.stop
  when 'right'
    hero.play :walk, :loop
  when 'up'
    hero.play :climb, :loop
  when 'down'
    hero.play :cheer
  end
end


show
