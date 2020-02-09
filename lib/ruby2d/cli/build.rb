# Build a Ruby 2D app natively and for the web

require 'fileutils'

# The installed gem directory
@gem_dir = "#{Gem::Specification.find_by_name('ruby2d').gem_dir}"

# The Ruby 2D library files
@lib_files = [
  'cli/colorize',
  'exceptions',
  'renderable',
  'color',
  'window',
  'dsl',
  'quad',
  'line',
  'circle',
  'rectangle',
  'square',
  'triangle',
  'image',
  'sprite',
  'font',
  'text',
  'sound',
  'music',
  '../ruby2d'
]


# Check if source file provided is good
def check_build_src_file(rb_file)
  if !rb_file
    puts "Please provide a Ruby file to build"
    exit
  elsif !File.exist? rb_file
    puts "Can't find file: #{rb_file}"
    exit
  end
end


# Assemble the Ruby 2D library in one `.rb` file
def make_lib
  FileUtils.mkdir_p 'build'

  lib_dir = "#{@gem_dir}/lib/ruby2d/"

  lib = ''
  @lib_files.each do |f|
    lib << File.read("#{lib_dir + f}.rb") + "\n\n"
  end

  File.write('build/lib.rb', lib)
end


# Remove `require 'ruby2d'` from source file
def strip_require(file)
  output = ''
  File.foreach(file) do |line|
    output << line unless line =~ /require ('|")ruby2d('|")/
  end
  return output
end


# Build a native version of the provided Ruby application
def build_native(rb_file)
  check_build_src_file(rb_file)

  # Check if MRuby exists; if not, quit
  if `which mruby`.empty?
    puts "#{'Error:'.error} Can't find MRuby, which is needed to build native Ruby 2D applications.\n"
    exit
  end

  # Add debugging information to produce backtrace
  if @debug then debug_flag = '-g' end

  # Assemble the Ruby 2D library in one `.rb` file and compile to bytecode
  make_lib
  `mrbc #{debug_flag} -Bruby2d_lib -obuild/lib.c build/lib.rb`

  # Read the provided Ruby source file, copy to build dir and compile to bytecode
  File.open('build/src.rb', 'w') { |file| file << strip_require(rb_file) }
  `mrbc #{debug_flag} -Bruby2d_app -obuild/src.c build/src.rb`

  # Combine contents of C source files and bytecode into one file
  open('build/app.c', 'w') do |f|
    f << "#define MRUBY 1" << "\n\n"
    f << File.read("build/lib.c") << "\n\n"
    f << File.read("build/src.c") << "\n\n"
    f << File.read("#{@gem_dir}/ext/ruby2d/ruby2d.c")
  end

  # Compile to a native executable
  `cc build/app.c -lmruby \`simple2d --libs\` -o build/app`

  # Clean up
  clean_up unless @debug

  # Success!
  puts "Native app created at `build/app`"
end


# Build a web-based version of the provided Ruby application
def build_web(rb_file)
  puts "Warning: ".warn + "This feature is currently disabled while it's being upgraded."
end


# Build an app bundle for macOS
def build_macos(rb_file)

  # Build native app for macOS
  build_native(rb_file)

  # Property list source for the bundle
  info_plist = %(
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>app</string>
  <key>CFBundleIconFile</key>
  <string>app.icns</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>NSHighResolutionCapable</key>
  <string>True</string>
</dict>
</plist>
)

  # Create directories
  FileUtils.mkpath 'build/App.app/Contents/MacOS'
  FileUtils.mkpath 'build/App.app/Contents/Resources'

  # Create Info.plist and copy over assets
  File.open('build/App.app/Contents/Info.plist', 'w') { |f| f.write(info_plist) }
  FileUtils.cp 'build/app', 'build/App.app/Contents/MacOS/'
  # Consider using an icon:
  #   FileUtils.cp "#{@gem_dir}/assets/app.icns", 'build/App.app/Contents/Resources'

  # Clean up
  FileUtils.rm_f 'build/app' unless @debug

  # Success!
  puts 'macOS app bundle created: `build/App.app`'
end


# Build an iOS or tvOS app
def build_ios_tvos(rb_file, device)
  check_build_src_file(rb_file)

  # Check for Simple 2D framework,
  unless File.exist?('/usr/local/Frameworks/Simple2D/iOS/Simple2D.framework') && File.exist?('/usr/local/Frameworks/Simple2D/tvOS/Simple2D.framework')
    puts "#{'Error:'.error} Simple 2D iOS and tvOS frameworks not found. Install them and try again.\n"
    exit
  end

  # Check if MRuby exists; if not, quit
  if `which mruby`.empty?
    puts "#{'Error:'.error} Can't find MRuby, which is needed to build native Ruby 2D applications.\n"
    exit
  end

  # Add debugging information to produce backtrace
  if @debug then debug_flag = '-g' end

  # Assemble the Ruby 2D library in one `.rb` file and compile to bytecode
  make_lib
  `mrbc #{debug_flag} -Bruby2d_lib -obuild/lib.c build/lib.rb`

  # Read the provided Ruby source file, copy to build dir and compile to bytecode
  File.open('build/src.rb', 'w') { |file| file << strip_require(rb_file) }
  `mrbc #{debug_flag} -Bruby2d_app -obuild/src.c build/src.rb`

  # Copy over iOS project
  FileUtils.cp_r "#{@gem_dir}/assets/#{device}", "build"

  # Combine contents of C source files and bytecode into one file
  File.open("build/#{device}/main.c", 'w') do |f|
    f << "#define RUBY2D_IOS_TVOS 1" << "\n\n"
    f << "#define MRUBY 1" << "\n\n"
    f << File.read("build/lib.c") << "\n\n"
    f << File.read("build/src.c") << "\n\n"
    f << File.read("#{@gem_dir}/ext/ruby2d/ruby2d.c")
  end

  # Build the Xcode project
  `simple2d build --#{device} build/#{device}/MyApp.xcodeproj`

  # Clean up
  clean_up unless @debug

  # Success!
  puts "App created: `build/#{device}`"
end


# Clean up unneeded build files
def clean_up(cmd = nil)
  FileUtils.rm(
    Dir.glob('build/{src,lib}.{rb,c,js}') +
    Dir.glob('build/app.c')
  )
  if cmd == :all
    puts "cleaning up..."
    FileUtils.rm_f 'build/app'
    FileUtils.rm_f 'build/app.js'
    FileUtils.rm_f 'build/app.html'
    FileUtils.rm_rf 'build/App.app'
    FileUtils.rm_rf 'build/ios'
    FileUtils.rm_rf 'build/tvos'
  end
end
