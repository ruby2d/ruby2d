# Build a compiled Ruby 2D app with mruby

require 'ruby2d'
require 'fileutils'
require 'ruby2d/cli/colorize'
require 'ruby2d/cli/platform'


# The Ruby 2D library files
@ruby2d_lib_files = [
  'cli/colorize',
  'exceptions',
  'renderable',
  'color',
  'window',
  'dsl',
  'entity',
  'quad',
  'line',
  'circle',
  'rectangle',
  'square',
  'triangle',
  'pixel',
  'image',
  'sprite',
  'tileset',
  'font',
  'text',
  'sound',
  'music',
  'texture',
  'vertices',
  '../ruby2d'
]


# Helpers ######################################################################

# Remove `require 'ruby2d'` from source file
def strip_require(file)
  output = ''
  File.foreach(file) do |line|
    output << line unless line =~ /require ('|")ruby2d('|")/
  end
  return output
end


# Add linker flags
def add_ld_flags(ld_flags, name, type, dir = nil)
  case type
  when :archive
    ld_flags << "#{dir}/lib#{name}.a "
  when :framework
    ld_flags << "-Wl,-framework,#{name} "
  end
end


# Build Tasks ##################################################################

# Build the user's application
def build(target, ruby2d_app)

  # Check if source file provided is good
  if !ruby2d_app
    puts "Please provide a Ruby file to build"
    exit
  elsif !File.exist? ruby2d_app
    puts "Can't find file: #{ruby2d_app}"
    exit
  end

  # Add debugging information to produce backtrace
  if @debug then debug_flag = '-g' end

  # Create build directory
  FileUtils.mkdir_p 'build'

  # Assemble Ruby 2D library files into one '.rb' file

  ruby2d_lib_dir = "#{Ruby2D.gem_dir}/lib/ruby2d/"

  ruby2d_lib = ''
  @ruby2d_lib_files.each do |f|
    ruby2d_lib << File.read("#{ruby2d_lib_dir + f}.rb") + "\n\n"
  end

  File.write('build/ruby2d_lib.rb', ruby2d_lib)

  # Assemble the Ruby 2D C extension files into one '.c' file

  ruby2d_ext_dir = "#{Ruby2D.gem_dir}/ext/ruby2d/"

  ruby2d_ext = "#define MRUBY 1" << "\n\n"
  Dir["#{ruby2d_ext_dir}*.c"].each do |c_file|
    ruby2d_ext << File.read(c_file)
  end

  File.write('build/ruby2d_ext.c', ruby2d_ext)

  # Compile the Ruby 2D lib (`.rb` files) to mruby bytecode
  system "mrbc #{debug_flag} -Bruby2d_lib -obuild/ruby2d_lib.c build/ruby2d_lib.rb"

  # Read the user's provided Ruby source file, copy to build dir and compile to bytecode
  File.open('build/ruby2d_app.rb', 'w') { |f| f << strip_require(ruby2d_app) }
  system "mrbc #{debug_flag} -Bruby2d_app -obuild/ruby2d_app.c build/ruby2d_app.rb"

  # Combine contents of C source files and bytecode into one file
  open('build/app.c', 'w') do |f|
    ['ruby2d_app', 'ruby2d_lib', 'ruby2d_ext'].each do |c_file|
      f << File.read("build/#{c_file}.c") << "\n\n"
    end
  end

  # Compile the final application based on the target platform
  case target
  when :native
    compile_native
  when :web
    compile_web
  end

  # Remove files used in the build process
  clean_up unless @debug

end


# Create a native executable using the available C compiler
def compile_native

  # Get include directories
  incl_dir_ruby2d = "#{Ruby2D.gem_dir}/ext/ruby2d/"
  incl_dir_deps = "#{Ruby2D.assets}/include/"

  # Add compiler flags for each platform
  case $RUBY2D_PLATFORM

  when :macos
    ld_dir = "#{Ruby2D.assets}/macos/universal"

    ld_flags = ''
    ['SDL2', 'SDL2_image', 'SDL2_mixer', 'SDL2_ttf',
     'jpeg', 'png16', 'tiff', 'webp',
     'mpg123', 'ogg', 'FLAC', 'vorbis', 'vorbisfile', 'modplug',
     'freetype'].each do |name|
      add_ld_flags(ld_flags, name, :archive, ld_dir)
    end

    ld_flags << "-lmruby -lz -lbz2 -liconv -lstdc++ "
    ['Cocoa', 'Carbon', 'CoreVideo', 'OpenGL', 'Metal', 'CoreAudio', 'AudioToolbox',
     'IOKit', 'GameController', 'ForceFeedback', 'CoreHaptics'].each do |name|
      add_ld_flags(ld_flags, name, :framework)
    end

  when :linux, :linux_rpi, :bsd
    # TODO: implement this
    # ld_flags = '-lSDL2 -lSDL2_image -lSDL2_mixer -lSDL2_ttf -lm -lGL'

  when :windows
    # TODO: implement this
    # ld_dir = "#{Ruby2D.assets}/..."
  end

  # Compile the app
  system "cc -I#{incl_dir_ruby2d} -I#{incl_dir_deps} build/app.c #{ld_flags} -o build/app"
end


# Create a WebAssembly executable using Emscripten
def compile_web

  wasm_assets = "#{Ruby2D.assets}/wasm"

  # Check for compiler toolchain issues
  if doctor_web(:building)
    puts "Fix errors before building.\n\n"
  end

  incl_mruby = "#{wasm_assets}/mruby/include/"
  incl_ruby2d = "#{Ruby2D.gem_dir}/ext/ruby2d/"

  optimize_flags = '-Os --closure 1'
  ld_flags = "#{wasm_assets}/mruby/libmruby.a"

  # Compile using Emscripten
  system "emcc -s WASM=1 -I#{incl_mruby} -I#{incl_ruby2d} -I#{wasm_assets} "\
         "-s USE_SDL=2 -s USE_SDL_IMAGE=2 -s USE_SDL_MIXER=2 -s "\
         "#{wasm_assets}/SDL2/libSDL2_ttf.a build/app.c #{ld_flags} -o build/app.html"

  # Copy HTML template from gem assets to build directory
  # FileUtils.cp "#{wasm_assets}/template.html", 'build/app.html'
end


def doctor_native
  # Check if MRuby exists; if not, quit
  if `which mruby`.empty?
    puts "#{'Error:'.error} Can't find `mruby`, which is needed to build native Ruby 2D applications.\n"
    exit
  end
end


# Check for problems with web build
def doctor_web(mode = nil)

  errors = false
  mruby_errors = false
  emscripten_errors = false

  puts "\nChecking for mruby"

  # Check for `mrbc`
  print '  mrbc...'
  if `which mrbc`.empty?
    puts 'not found'.error
    mruby_errors = true
  else
    puts 'found'.success
  end

  puts "\nChecking for Emscripten tools"

  # Check for `emcc`
  print '  emcc...'
  if `which emcc`.empty?
    puts 'not found'.error
    emscripten_errors = true
  else
    puts 'found'.success
  end

  # Check for `emar`
  print '  emar...'
  if `which emar`.empty?
    puts 'not found'.error
    emscripten_errors = true
  else
    puts 'found'.success
  end

  if mruby_errors || emscripten_errors then errors = true end

  if errors
    puts "\nErrors were found!\n\n"
    if mruby_errors
      puts "* Did you install mruby?"
    end
    if emscripten_errors
      puts "* Did you run \`./emsdk_env.sh\` ?", "  For help, check out the \"Getting Started\" guide on webassembly.org"
    end
    puts "\n"
    exit(1)
  else
    puts "\n👍 Everything looks good!\n\n" unless mode == :building
  end
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

  # TODO: Need add this functionality to the gem
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
    Dir.glob('build/*.{rb,c,js}')
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
