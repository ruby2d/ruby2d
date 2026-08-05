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


# Launch a native app, passing its stdio through so console output is visible.
def launch_native
  exe = AssetsTarget.host_os == 'windows' ? 'app.exe' : 'app'
  unless File.exist?("build/native/#{exe}")
    error 'No native app found. Run `ruby2d build --native` first.'
    exit 1
  end
  # Run with the build dir as the working directory so the app resolves its
  # bundled media by relative path, the way the built app expects.
  system(File.expand_path("build/native/#{exe}"), chdir: 'build/native')
end


# Launch a web app
def launch_web
  unless File.exist?('build/web/app.html')
    error 'No web app found. Run `ruby2d build --web` first.'
    exit 1
  end
  serve(dir: File.expand_path('build/web'), port: 8080, path: 'app.html')
end
