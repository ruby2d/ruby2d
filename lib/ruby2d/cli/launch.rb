# Launch a built Ruby 2D app

# Launch a native app
def launch_native
  if !File.exist? 'build/app'
    puts "No native app built!"
    exit
  end
  `( cd build && ./app )`
end


# Launch a web app
def launch_web
  if !File.exist? 'build/app.html'
    puts "No web app built!"
    exit
  end
  open_cmd = 'open'
  case RUBY_PLATFORM
  when /linux/
    open_cmd = "xdg-#{open_cmd}"
  when /mingw/
    open_cmd = "start"
  end
  system "#{open_cmd} build/app.html"
end


# Launch an iOS or tvOS app in a simulator
def launch_apple(device)
  case device
  when 'ios'
    if !File.exist? 'build/ios/build/Release-iphonesimulator/MyApp.app'
      puts "No iOS app built!"
      exit
    end
    puts `simple2d simulator --open "iPhone X" &&
          simple2d simulator --install "build/ios/build/Release-iphonesimulator/MyApp.app" &&
          simple2d simulator --launch "Ruby2D.MyApp"`
  when 'tvos'
    if !File.exist? 'build/tvos/build/Release-appletvsimulator/MyApp.app'
      puts "No tvOS app built!"
      exit
    end
    puts `simple2d simulator --open "Apple TV 4K" &&
          simple2d simulator --install "build/tvos/build/Release-appletvsimulator/MyApp.app" &&
          simple2d simulator --launch "Ruby2D.MyApp"`
  end
end
