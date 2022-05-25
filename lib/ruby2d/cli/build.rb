# Build a compiled Ruby 2D app with mruby

require 'ruby2d'
require 'fileutils'
require 'ruby2d/cli/colorize'
require 'ruby2d/cli/platform'


# The Ruby 2D library files
@ruby2d_lib_files = [
  'cli/colorize',
  'cli/platform',
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
  'pixmap',
  'pixmap_atlas',
  'image',
  'sprite',
  'tileset',
  'font',
  'text',
  'canvas',
  'sound',
  'music',
  'texture',
  'vertices',
  '../ruby2d'
]


# Helpers ######################################################################

def run_cmd(cmd)
  puts "#{'$'.info} #{cmd.bold}\n" if @debug
  system cmd
end


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
def build(ruby2d_app, assets_dir)

  # Check if source file provided is good
  if !ruby2d_app
    puts "Provide a Ruby file to build"
    exit 1
  elsif !File.exist? ruby2d_app
    puts "Can't find file: #{ruby2d_app}"
    exit 1
  end

  # If assets directory provided, make sure it exists
  if assets_dir && !Dir.exist?(assets_dir)
    puts "Cannot find assets directory `#{assets_dir}`"
    exit 1
  end

  # Clean the build directory
  clean_up(:all)

  # Get build platforms
  build_platforms = {}
  case $RUBY2D_PLATFORM
  when :macos
    build_platforms[:macos] = 'macOS'
  when :windows
    build_platforms[:windows] = 'Windows'
  when :linux
    build_platforms[:linux] = 'Linux'
  end
  if system('which emcc', out: File::NULL)
    build_platforms[:wasm] = 'WebAssembly'
  end

  # Print status
  puts '=== Building ==='.bold
  puts "Platforms: #{build_platforms.values.join(', ')}"
  puts "Ruby Engine: mruby"
  puts "File: #{ruby2d_app}"
  puts "Assets: #{assets_dir}" if assets_dir
  print "Compiling..."

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

  # Select `mrbc` executable based on platform
  case $RUBY2D_PLATFORM
  when :macos
    mrbc = "#{Ruby2D.assets}/macos/universal/bin/mrbc"
  when :windows
    mrbc = "#{Ruby2D.assets}/windows/mingw-w64-x86_64/bin/mrbc.exe"
  else
    mrbc = 'mrbc'
  end

  # Compile the Ruby 2D lib (`.rb` files) to mruby bytecode
  run_cmd "#{mrbc} #{debug_flag} -Bruby2d_lib -obuild/ruby2d_lib.c build/ruby2d_lib.rb"

  # Read the user's provided Ruby source file, copy to build dir and compile to bytecode
  File.open('build/ruby2d_app.rb', 'w') { |f| f << strip_require(ruby2d_app) }
  run_cmd "#{mrbc} #{debug_flag} -Bruby2d_app -obuild/ruby2d_app.c build/ruby2d_app.rb"

  # Combine contents of C source files and bytecode into one file
  open('build/app.c', 'w') do |f|
    ['ruby2d_app', 'ruby2d_lib', 'ruby2d_ext'].each do |c_file|
      f << File.read("build/#{c_file}.c") << "\n\n"
    end
  end

  # Compile the final application based on the target platform
  compile_native(assets_dir)

  # Compile for WebAssembly if Emscripten tools are present
  if build_platforms.has_key? :wasm
    compile_web(assets_dir)
  end

  # Remove files used in the build process
  clean_up unless @debug

  # Print summary
  puts "done"

  puts "Outputs:"
  puts "  build/macos" if build_platforms.has_key? :macos
  puts "  build/windows" if build_platforms.has_key? :windows
  puts "  build/linux" if build_platforms.has_key? :linux
  puts "  build/web" if build_platforms.has_key? :wasm

  puts "Build complete 🏁".success
end


# Create a native executable using the available C compiler
def compile_native(assets_dir)

  # Get include directories
  incl_dir_ruby2d = "#{Ruby2D.gem_dir}/ext/ruby2d/"
  incl_dir_deps = "#{Ruby2D.assets}/include/"

  FileUtils.mkpath "build/#{$RUBY2D_PLATFORM}"

  # Add compiler flags for each platform
  case $RUBY2D_PLATFORM

  when :macos
    ld_dir = "#{Ruby2D.assets}/macos/universal/lib"

    c_flags = '-arch arm64 -arch x86_64'

    ld_flags = ''
    ['mruby', 'SDL2', 'SDL2_image', 'SDL2_mixer', 'SDL2_ttf',
     'jpeg', 'png16', 'tiff', 'webp',
     'mpg123', 'ogg', 'FLAC', 'vorbis', 'vorbisfile', 'modplug',
     'freetype', 'harfbuzz', 'graphite2'].each do |name|
      add_ld_flags(ld_flags, name, :archive, ld_dir)
    end

    ld_flags << "-lz -lbz2 -liconv -lstdc++ "
    ['Cocoa', 'Carbon', 'CoreVideo', 'OpenGL', 'Metal', 'CoreAudio', 'AudioToolbox',
     'IOKit', 'GameController', 'ForceFeedback', 'CoreHaptics'].each do |name|
      add_ld_flags(ld_flags, name, :framework)
    end

  when :linux, :linux_rpi, :bsd
    # TODO: implement this
    # ld_flags = '-lSDL2 -lSDL2_image -lSDL2_mixer -lSDL2_ttf -lm -lGL'

  when :windows

    if RUBY_PLATFORM =~ /ucrt/
      ld_dir = "#{Ruby2D.assets}/windows/mingw-w64-ucrt-x86_64/lib"
    else
      ld_dir = "#{Ruby2D.assets}/windows/mingw-w64-x86_64/lib"
    end

    ld_flags = '-static -Wl,--start-group '
    ['mruby',
     'SDL2',
     'SDL2_image', 'jpeg', 'png16', 'tiff', 'webp', 'jbig', 'deflate', 'lzma', 'zstd', 'Lerc',
     'SDL2_mixer', 'mpg123', 'FLAC', 'vorbis', 'vorbisfile', 'ogg', 'modplug', 'opus', 'opusfile', 'sndfile',
     'SDL2_ttf', 'freetype', 'harfbuzz', 'graphite2', 'bz2', 'brotlicommon', 'brotlidec',
     'glew32', 'stdc++', 'z', 'ssp'
    ].each do |name|
      add_ld_flags(ld_flags, name, :archive, ld_dir)
    end
    ld_flags << '-lmingw32 -lopengl32 -lole32 -loleaut32 -limm32 -lversion -lwinmm -lrpcrt4 -mwindows -lsetupapi -ldwrite '\
                '-lws2_32 -lshlwapi '
    ld_flags << '-Wl,--end-group'
  end

  # Compile the app
  run_cmd "cc #{c_flags} -I#{incl_dir_ruby2d} -I#{incl_dir_deps} build/app.c #{ld_flags} -o build/#{$RUBY2D_PLATFORM}/app"

  # TODO: Copy assets if provided
  # FileUtils.cp_r("#{assets_dir}/.", "build/#{$RUBY2D_PLATFORM}") if assets_dir

  create_macos_bundle(assets_dir) if $RUBY2D_PLATFORM == :macos
end


# Create a WebAssembly executable using Emscripten
def compile_web(assets_dir)

  wasm_assets = "#{Ruby2D.assets}/wasm"

  # Get include directories
  incl_dir_ruby2d = "#{Ruby2D.gem_dir}/ext/ruby2d/"
  incl_dir_deps = "#{Ruby2D.assets}/include/"

  optimize_flags = '-Os --closure 1'
  ld_flags = "#{wasm_assets}/libmruby.a"

  FileUtils.mkpath 'build/web'

  # Compile using Emscripten
  run_cmd "emcc -s WASM=1 -I#{incl_dir_ruby2d} -I#{incl_dir_deps} "\
          "-s USE_SDL=2 -s USE_SDL_IMAGE=2 -s USE_SDL_MIXER=2 -s USE_SDL_TTF=2 -s "\
          "#{if assets_dir then "--preload-file #{assets_dir}@" end} "\
          "--use-preload-plugins -s ALLOW_MEMORY_GROWTH=1 "\
          "build/app.c #{ld_flags} -o build/web/app.js "\
          "#{unless @debug then '&> /dev/null' end}"

  # Copy HTML template from gem assets to build directory
  FileUtils.cp "#{wasm_assets}/template.html", 'build/web/app.html'
end


# Build an app bundle for macOS
def create_macos_bundle(assets_dir)

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

  build_dir = 'build/macos'

  # Create directories
  FileUtils.mkpath "#{build_dir}/App.app/Contents/MacOS"
  FileUtils.mkpath "#{build_dir}/App.app/Contents/Resources"

  # Create Info.plist and copy over assets
  File.open("#{build_dir}/App.app/Contents/Info.plist", 'w') { |f| f.write(info_plist) }
  FileUtils.cp "#{build_dir}/app", "#{build_dir}/App.app/Contents/MacOS/"

  # TODO: Copy assets if provided
  # FileUtils.cp_r("#{assets_dir}/.", "#{build_dir}/App.app/Contents/MacOS/") if assets_dir

  # Consider using an icon:
  #   FileUtils.cp "#{@gem_dir}/assets/app.icns", 'build/App.app/Contents/Resources'
end


# Clean up unneeded build files
def clean_up(cmd = nil)
  FileUtils.rm(
    Dir.glob('build/*.{rb,c,js}')
  )
  if cmd == :all
    FileUtils.rm_rf 'build/macos'
    FileUtils.rm_rf 'build/linux'
    FileUtils.rm_rf 'build/windows'
    FileUtils.rm_rf 'build/web'
  end
end


# Start a local server and open a built web app
def serve(html_file)

  # Check if file provided is good
  if !html_file
    puts "Provide an HTML file to serve"
    exit 1
  elsif !File.exist? html_file
    puts "Can't find file: #{html_file}"
    exit 1
  elsif File.extname(html_file) != '.html'
    puts "File must be of type `.html`"
    exit 1
  end

  case $RUBY2D_PLATFORM
  when :macos
  open_cmd = 'open'
  when :linux
    open_cmd = 'xdg-open'
  when :windows
    open_cmd = 'start'
  end

  pid = Process.spawn "ruby -rwebrick -e 'WEBrick::HTTPServer.new(:Port => 4001, :DocumentRoot => Dir.pwd).start'", err: '/dev/null'
  sleep 0.5
  system "#{open_cmd} http://localhost:4001/#{html_file}"
  sleep 1
  Process.kill 'QUIT', pid
end
