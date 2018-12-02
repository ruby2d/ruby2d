require 'ruby2d'

set width: 300, height: 200, title: "Ruby 2D — Audio"

snd = Sound.new('media/sound.wav')
mus = Music.new('media/music.wav')

volume_bar = Rectangle.new(color: 'green', width: 300, height: 50)

on :mouse_down do |event|
  Music.volume = event.x / Window.width.to_f * 100
  volume_bar.width = Music.volume / 100.0 * Window.width
  puts "Music volume: #{Music.volume}%"
end

on :key_down do |event|
  case event.key
  when 'p'
    puts "Playing sound"
    snd.play
  when 'm'
    puts "Playing music"
    mus.play
    mus.volume = 100
    volume_bar.width = Window.width
    puts "Music volume: #{mus.volume}"
  when 'l'
    puts "Looping music"
    mus.loop = true
  when 'a'
    puts "Music paused"
    mus.pause
  when 'r'
    puts "Music resumed"
    mus.resume
  when 's'
    puts "Music stopped"
    mus.stop
  when 'f'
    puts "Music fading out"
    mus.fadeout 2000
  when 'escape'
    close
  end
end

show
