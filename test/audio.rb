require 'ruby2d'

if RUBY_ENGINE == 'opal'
  media = "../test/media"
else
  media = "media"
end

set width: 300, height: 200, title: "Ruby 2D — Audio"

on key: 'escape' do
  close
end

snd = Sound.new("#{media}/sound.wav")
mus = Music.new("#{media}/music.wav")

on key_down: 'p' do
  puts "Playing sound..."
  snd.play
end

on key_down: 'm' do
  puts "Playing music..."
  mus.play
end

on key_down: 'l' do
  puts "Loop music true..."
  mus.loop = true
end

on key_down: 'a' do
  puts "Pause music..."
  mus.pause
end

on key_down: 'r' do
  puts "Resume music..."
  mus.resume
end

on key_down: 's' do
  puts "Stop music..."
  mus.stop
end

on key_down: 'f' do
  puts "fade out music..."
  mus.fadeout 2000
end

show
