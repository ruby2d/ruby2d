require 'ruby2d'

set width: 300, height: 200, title: "Ruby 2D — Audio"

snd = Sound.new("#{Ruby2D.test_media}/sound.wav")
mus = Music.new("#{Ruby2D.test_media}/music.wav")

music_vol_label = Text.new("Music Volume: 100",  x: 65, y: 10, z:2, color: 'white', size: 20)
music_volume_bar = Rectangle.new(color: 'green', z:1, width: 300, height: 50)
music_click_bar = Rectangle.new(color: 'black', width: 300, height: 50)

sound_vol_label = Text.new("Sound Volume: 100",  x: 65, y: 110, z:2, color: 'white', size: 20)
sound_volume_bar = Rectangle.new(color: 'green', y: 100, z:1, width: 300, height: 50)
sound_click_bar = Rectangle.new(color: 'black', y: 100, width: 300, height: 50)

on :mouse_down do |event|
  if music_click_bar.contains? event.x, event.y
    Music.volume = event.x / Window.width.to_f * 100
    music_volume_bar.width = Music.volume / 100.0 * Window.width
    music_vol_label.text = "Music Volume: "+"#{Music.volume}".rjust(3)
    puts "Music volume: #{Music.volume}%"
  end
  if sound_click_bar.contains? event.x, event.y
    snd.volume = (event.x / Window.width.to_f * 100)
    sound_volume_bar.width = snd.volume / 100.0 * Window.width
    sound_vol_label.text = "Sound Volume: "+"#{snd.volume}".rjust(3)
    puts "Sound volume: #{snd.volume}%"
  end
end

on :key_down do |event|
  case event.key
  when 'p'
    puts "Playing sound"
    snd.play
    puts "Sound volume: #{snd.volume}"
  when 'm'
    puts "Playing music"
    mus.play
    mus.volume = 100
    music_volume_bar.width = Window.width
    music_vol_label.text = "Music Volume: "+"#{Music.volume}".rjust(3)
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
