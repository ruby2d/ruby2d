# Minimal static-file HTTP server for previewing a local web (WASM) build.
#
# Ruby 2D used to depend on WEBrick for `ruby2d launch --web`, but WEBrick was
# removed from Ruby's default gems in 3.0 and is no longer guaranteed present on
# a stock install. This server uses only `socket` from the standard library, so
# the published gem needs no extra runtime dependency. It serves static files
# with the MIME types a browser needs for an Emscripten build — most importantly
# `application/wasm`, which browsers require for streaming WebAssembly.

require_relative '../../../assets/target'
require_relative 'colorize'
require_relative 'messages'

module Ruby2D
  module CLI
    module StaticServer
      CONTENT_TYPES = {
        '.html'  => 'text/html; charset=utf-8',
        '.htm'   => 'text/html; charset=utf-8',
        '.js'    => 'text/javascript; charset=utf-8',
        '.mjs'   => 'text/javascript; charset=utf-8',
        '.wasm'  => 'application/wasm',
        '.json'  => 'application/json',
        '.css'   => 'text/css; charset=utf-8',
        '.data'  => 'application/octet-stream',
        '.png'   => 'image/png',
        '.jpg'   => 'image/jpeg',
        '.jpeg'  => 'image/jpeg',
        '.gif'   => 'image/gif',
        '.svg'   => 'image/svg+xml',
        '.ico'   => 'image/x-icon',
        '.wav'   => 'audio/wav',
        '.mp3'   => 'audio/mpeg',
        '.ogg'   => 'audio/ogg',
        '.ttf'   => 'font/ttf',
        '.woff'  => 'font/woff',
        '.woff2' => 'font/woff2',
        '.txt'   => 'text/plain; charset=utf-8'
      }.freeze

      DEFAULT_CONTENT_TYPE = 'application/octet-stream'

      # Content-Type for a file path, by extension.
      def self.content_type(path)
        CONTENT_TYPES.fetch(File.extname(path).downcase, DEFAULT_CONTENT_TYPE)
      end

      # Resolve an HTTP request target (e.g. "/app.html?v=1") to a real file
      # under `root`. A directory request (e.g. "/") serves its `index.html`.
      # Returns the absolute path, or nil if the file does not exist or the
      # request escapes `root` (directory-traversal protection).
      def self.resolve(root, target)
        path = decode(target.split(/[?#]/, 2).first.to_s)
        # A NUL byte (e.g. from `%00`) makes File.expand_path/File.file? raise
        # ArgumentError; treat such a path as a non-existent file (clean 404).
        return nil if path.include?("\u0000")

        root_real = File.expand_path(root)
        full = File.expand_path(File.join(root_real, path))
        return nil unless full == root_real || full.start_with?(root_real + File::SEPARATOR)
        # Serve the directory index for a directory request. `full` is already
        # confirmed within `root`, so the joined index stays in bounds too.
        full = File.join(full, 'index.html') if File.directory?(full)
        return nil unless File.file?(full)

        full
      end

      # Percent-decode a URL path (e.g. "%20" -> " ").
      def self.decode(str)
        str.gsub(/%([0-9a-fA-F]{2})/) { Regexp.last_match(1).hex.chr }
      end

      # Serve `dir` over HTTP on `port` and open `path` in the browser. Blocks
      # until interrupted with Ctrl-C.
      def self.serve(dir:, port: 8080, path: '')
        require 'socket'
        server =
          begin
            TCPServer.new('127.0.0.1', port)
          rescue Errno::EADDRINUSE
            error "Port #{port} is already in use. Stop the other server and try again."
            exit 1
          end

        url = "http://localhost:#{port}/#{path}"
        puts "  Serving at #{url.bold}"
        puts "  #{'Press Ctrl-C to stop.'.dim}"

        open_browser(url)

        # Block in accept until Ctrl-C. Let the default SIGINT -> Interrupt
        # exception unwind the loop and close the socket in `ensure`. Closing
        # the server from a `trap` handler instead would deadlock with
        # "recursive locking" — the handler runs on this same thread while it is
        # mid-`accept`, so it would try to re-lock the socket accept already holds.
        loop do
          client = server.accept
          Thread.new(client) { |c| handle(c, dir) }
        end
      rescue Interrupt
        puts # finish the "^C" line cleanly
      ensure
        server&.close
      end

      # Handle one HTTP connection: read the request line, serve the file or 404.
      def self.handle(client, dir)
        request_line = client.gets
        return if request_line.nil?

        target = request_line.split(' ')[1]
        # Drain the remaining request headers up to the blank line.
        while (line = client.gets) && line != "\r\n"; end

        full = target && resolve(dir, target)
        if full
          write_response(client, 200, 'OK', content_type(full), File.binread(full))
        else
          write_response(client, 404, 'Not Found', 'text/plain; charset=utf-8', "404 Not Found\n")
        end
      rescue Errno::EPIPE, Errno::ECONNRESET, IOError
        # Client disconnected mid-response — nothing to do.
      ensure
        client.close rescue nil
      end

      # Write a complete HTTP/1.1 response and close (no keep-alive).
      def self.write_response(client, code, reason, type, body)
        body = body.to_s
        client.write("HTTP/1.1 #{code} #{reason}\r\n")
        client.write("Content-Type: #{type}\r\n")
        client.write("Content-Length: #{body.bytesize}\r\n")
        client.write("Cache-Control: no-cache\r\n")
        client.write("Connection: close\r\n\r\n")
        client.write(body)
      end

      # Open `url` in the default browser, shortly after the server starts.
      def self.open_browser(url)
        cmd = browser_command(url)
        return unless cmd

        Thread.new do
          sleep 0.5
          system(*cmd)
        end
      end

      # The platform command (as an argv array) to open a URL in the browser.
      def self.browser_command(url)
        case AssetsTarget.host_os
        when 'macos'   then ['open', url]
        when 'windows' then ['cmd', '/c', 'start', '', url]
        else                ['xdg-open', url] # linux, bsd
        end
      end
    end
  end
end
