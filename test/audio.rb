require 'ruby2d'

media = "media"

set width: 300, height: 200, title: "Ruby 2D — Audio"

snd = Sound.new("#{media}/sound.wav")
mus = Music.new("#{media}/music.wav")

on :key_down do |event|
  case event.key
  when 'p'
    puts "Playing sound..."
    snd.play
  when 'm'
    puts "Playing music..."
    mus.play
  when 'l'
    puts "Loop music true..."
    mus.loop = true
  when 'a'
    puts "Pause music..."
    mus.pause
  when 'r'
    puts "Resume music..."
    mus.resume
  when 's'
    puts "Stop music..."
    mus.stop
  when 'f'
    puts "fade out music..."
    mus.fadeout 2000
  when 'escape'
    close
  end
end

show
