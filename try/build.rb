# Build script for the "Try Ruby 2D" interactive webpage
#
# Assembles all Ruby 2D source into a single C file with a custom main(),
# compiles it to WebAssembly via Emscripten, and produces the output files
# needed to host the interactive "Try Ruby 2D" page.
#
# Usage: ruby try/build.rb

require 'fileutils'
require_relative '../lib/ruby2d/lib_files'
require_relative '../lib/ruby2d/cli/colorize'
require_relative '../lib/ruby2d/cli/messages'

# Resolve all paths relative to the repository root
REPO_DIR = File.expand_path('..', __dir__)

ASSETS_DIR    = File.join(REPO_DIR, 'assets')
EXT_DIR       = File.join(REPO_DIR, 'ext', 'ruby2d')
LIB_DIR       = File.join(REPO_DIR, 'lib', 'ruby2d')
TRY_DIR       = File.join(REPO_DIR, 'try')
BUILD_DIR     = File.join(TRY_DIR, 'build')
INCL_RUBY2D   = EXT_DIR
INCL_DEPS     = File.join(ASSETS_DIR, 'platform', 'include')
WASM_LIB_DIR  = File.join(ASSETS_DIR, 'platform', 'wasm', 'lib')
FONTS_DIR     = File.join(ASSETS_DIR, 'resources', 'fonts')

# The Ruby 2D library files — shared with the native/web build via the single
# source of truth in lib/ruby2d/lib_files.rb, so the two can't drift.
RUBY2D_LIB_FILES = Ruby2D::LIB_FILES


# Collapse consecutive blank lines. `rake try:build` runs this script right after
# its own `$ …` echo (which ends in a blank), and our build commands (`mrbc`,
# `emcc`) are silent on success — so a step banner can land directly after a
# command's trailing blank. Track whether the last line printed was blank and
# skip a redundant one, so every gap stays a single line. Seeded `true` for the
# rake echo above (and harmless standalone — the first banner just starts flush).
@last_blank = true

def blank
  return if @last_blank
  puts
  @last_blank = true
end

def run_cmd(cmd)
  puts "  #{"$ #{cmd}".dim}"
  @last_blank = false
  blank  # separate the command from its output; collapsed when the command is silent
  system(cmd) || abort_error("Command failed: #{cmd}")
end


# Print a build-step banner — a ruby-red diamond and a bold title — to match the
# `ruby2d` CLI and `rake` output. A leading blank separates it from the previous
# step, collapsed when a preceding command already left one.
def step(title)
  blank
  puts "  #{'◆'.ruby2d_red} #{title.bold}"
  @last_blank = false
end


# List a file the build produced, beneath its step banner. The dim `wrote` label
# marks it as an output without competing with the path itself.
def wrote(path)
  puts "    #{'wrote'.dim} #{path}"
  @last_blank = false
end


# Find the mrbc executable (bundled or system)
def find_mrbc
  require_relative '../assets/target'
  bundled = File.join(AssetsTarget.platform_dir(root: ASSETS_DIR), 'bin', 'mrbc')
  return bundled if File.exist?(bundled)

  system_mrbc = `which mrbc 2>/dev/null`.chomp
  return system_mrbc unless system_mrbc.empty?

  nil
end


# Step 1: Create build directory
FileUtils.rm_rf(BUILD_DIR)
FileUtils.mkdir_p(BUILD_DIR)

# Step 2: Assemble ruby2d_lib.rb from library source files
step 'Assembling library source'
ruby2d_lib_source = ''
RUBY2D_LIB_FILES.each do |f|
  ruby2d_lib_source << File.read(File.join(LIB_DIR, "#{f}.rb")) << "\n\n"
end
ruby2d_lib_source << "include Ruby2D\nextend Ruby2D::DSL\n"
File.write(File.join(BUILD_DIR, 'ruby2d_lib.rb'), ruby2d_lib_source)

# Step 3: Compile ruby2d_lib.rb to C bytecode via mrbc
mrbc = find_mrbc
unless mrbc
  abort_error "Can't find `mrbc`, the mruby compiler.\n" \
              'Install mruby or ensure `mrbc` is in your PATH.'
end

step 'Compiling library to bytecode'
run_cmd "#{mrbc} -Bruby2d_lib -o#{File.join(BUILD_DIR, 'ruby2d_lib.c')} #{File.join(BUILD_DIR, 'ruby2d_lib.rb')}"

# Step 4: Assemble the combined C source file
step 'Assembling C source'

# Read all .c files from ext/ruby2d/, with ruby2d.c first
c_files = Dir[File.join(EXT_DIR, '*.c')].sort
main_file = c_files.delete(File.join(EXT_DIR, 'ruby2d.c'))
c_files.unshift(main_file) if main_file

combined_c = "#define MRUBY 1\n\n#include <mruby/compile.h>\n\n"

c_files.each do |c_file|
  content = File.read(c_file)

  # Strip the #ifdef MRUBY main block from ruby2d.c
  # This removes the int main() { ... } block that loads ruby2d_app bytecode
  if c_file == main_file
    stripped = content.sub(
      /^#ifdef MRUBY\n\/\*\n \* MRuby entry point.*?^int main\(\) \{.*?^#endif\n\}/m,
      <<~REPLACEMENT.chomp
        #ifdef MRUBY
        /* main() provided by try_main.c */
        #endif
      REPLACEMENT
    )
    # The regex is coupled to the exact source text. Fail loudly if it stops
    # matching (e.g. the block's formatting changed) rather than silently
    # emitting a second main() that collides with try_main.c's.
    abort_error "couldn't strip the mruby main() block from ruby2d.c (try/build.rb regex needs updating)" if stripped == content
    content = stripped
  end

  # In window.c, disable simulate_infinite_loop for emscripten_set_main_loop.
  # When called from a function invoked via ccall (as try_run_code is), the
  # throw/unwind mechanism corrupts the mruby VM's exception handler state.
  # With false, ext_show returns normally and the main loop still runs via
  # requestAnimationFrame -- the only difference is mrb_load_string completes.
  if File.basename(c_file) == 'window.c'
    patched = content.sub(
      'emscripten_set_main_loop(wasm_tick_trampoline, 0, true)',
      'emscripten_set_main_loop(wasm_tick_trampoline, 0, false)'
    )
    # The substitution is coupled to the exact source text. Fail loudly if it
    # stops matching (e.g. the call was renamed) rather than silently shipping
    # simulate_infinite_loop=true, which corrupts mruby state under ccall.
    abort_error "couldn't patch simulate_infinite_loop in window.c (try/build.rb needs updating)" if patched == content
    content = patched
  end

  combined_c << content << "\n\n"
end

# Append the bytecode and try_main.c
combined_c << File.read(File.join(BUILD_DIR, 'ruby2d_lib.c')) << "\n\n"
combined_c << File.read(File.join(TRY_DIR, 'try_main.c')) << "\n\n"

File.write(File.join(BUILD_DIR, 'app.c'), combined_c)

# Step 5: Compile with Emscripten
if `which emcc 2>/dev/null`.chomp.empty?
  abort_error "Can't find `emcc`. Install the Emscripten SDK and source emsdk_env.sh"
end

# Gather all .a library files from the WASM lib directory. An empty glob would
# link nothing and bury the cause under a wall of undefined SDL/mruby symbols,
# so fail loudly here instead.
ld_flags = Dir[File.join(WASM_LIB_DIR, '*.a')].join(' ')
if ld_flags.empty?
  abort_error "No WASM libraries found in #{WASM_LIB_DIR}\n" \
              'Check the `assets` submodule is present and up to date.'
end

step 'Compiling to WebAssembly'
# -DMRB_NO_BOXING matches the ABI of the vendored wasm libmruby.a — the boxing
# mode changes mrb_value's layout, so app.c must define the same mode the
# library was built with (see the same flag in lib/ruby2d/cli/build.rb).
run_cmd "emcc -O3 -DMRB_NO_BOXING " \
        "-I#{INCL_RUBY2D} -I#{INCL_DEPS} " \
        "-sUSE_SDL=0 " \
        "-sEXPORTED_FUNCTIONS=\"['_main','_try_run_code']\" " \
        "-sEXPORTED_RUNTIME_METHODS=\"['ccall']\" " \
        "-sINITIAL_MEMORY=64MB -sALLOW_MEMORY_GROWTH " \
        "--preload-file #{FONTS_DIR}@ruby2d/fonts " \
        "#{File.join(BUILD_DIR, 'app.c')} #{ld_flags} " \
        "-o #{File.join(BUILD_DIR, 'app.js')}"

# Step 6: Copy the HTML test page
FileUtils.cp(File.join(TRY_DIR, 'test.html'), File.join(BUILD_DIR, 'try.html'))

# Step 7: Remove intermediate files
%w[ruby2d_lib.rb ruby2d_lib.c app.c].each do |f|
  FileUtils.rm(File.join(BUILD_DIR, f))
end

# Done
step 'Build complete'
wrote File.join(BUILD_DIR, 'try.html')
wrote File.join(BUILD_DIR, 'app.js')
wrote File.join(BUILD_DIR, 'app.wasm')
wrote File.join(BUILD_DIR, 'app.data')
puts "    #{'Test locally with `rake try:serve`'.dim}"
blank
