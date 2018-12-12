rb_file = ARGV[1]

# Check if source file provided is good
if !rb_file
  puts "Provide a Ruby file to run"
  exit 1
elsif !File.exist? rb_file
  puts "Can't find file: #{rb_file}"
  exit 1
end

# Add libraries
require 'open3'
require 'readline'
require 'io/wait'

line = 1  # the current line number, to be incremented

# Open a new process for the  Ruby file
stdin, stdout, stderr, wait_thr = Open3.popen3("ruby -r 'ruby2d/cli/enable_console' #{rb_file}")

loop do

  # Read the next command
  cmd = Readline.readline("ruby2d:#{line}> ", true)

  # Quit if command is 'exit'
  if cmd == 'exit'
    Process.kill 'INT', wait_thr.pid
    wait_thr.value
    exit
  end

  # Skip if command is an empty string
  unless cmd.empty?

    # Send command to the Ruby file
    stdin.puts cmd

    # Read and print output from the Ruby file
    puts stdout.gets
    while stdout.ready? do
      puts stdout.gets
    end
  end

  # Advance to next line
  line += 1
end
