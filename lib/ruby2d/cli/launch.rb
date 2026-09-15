# Launch a built Ruby 2D app
require_relative '../../../assets/target'
require_relative 'colorize'
require_relative 'messages'
require_relative 'static_server'


# Serve a directory over HTTP and open it in the browser. Backed by a minimal
# `socket`-based server (no WEBrick dependency) — see static_server.rb.
def serve(dir:, port: 8080, path: '')
  Ruby2D::CLI::StaticServer.serve(dir: dir, port: port, path: path)
end


# Launch a native app in place of this process, so its console output, exit
# status, and signal are the app's own: `ruby2d launch --native` in a script or
# CI step then fails when the app does. The build dir is the working directory
# so the app resolves its bundled media by relative path, the way the built
# app expects (it changes to its own directory at startup regardless).
def launch_native
  exe = AssetsTarget.host_os == 'windows' ? 'app.exe' : 'app'
  unless File.exist?("build/native/#{exe}")
    error 'No native app found. Run `ruby2d build --native` first.'
    exit 1
  end
  # The `[path, argv0]` form runs the file directly, where a lone string is a
  # command line: a project directory with a space or a shell character in its
  # name (`My Game (v2)`) would be split or handed to the shell.
  path = File.expand_path("build/native/#{exe}")
  exec([path, path], chdir: 'build/native')
rescue SystemCallError => e
  error "Couldn't launch `build/native/#{exe}`: #{e.message}"
  exit 1
end


# Launch a web app
def launch_web
  unless File.exist?('build/web/app.html')
    error 'No web app found. Run `ruby2d build --web` first.'
    exit 1
  end
  serve(dir: File.expand_path('build/web'), port: 8080, path: 'app.html')
end
