require 'rspec/core/rake_task'
require './lib/ruby2d/version'

# Helpers

class String
  def colorize(c); "\e[#{c}m#{self}\e[0m" end
  def bold; colorize('1')    end
  def blue; colorize('1;34') end
  def red;  colorize('1;31') end
end

# Simple 2D is required for these tasks
if `which simple2d`.empty?
  puts "Simple 2D not found!".red
  puts "Install before running Rake tasks."
  exit
end

def print_task(task)
  print "\n", "==> ".blue, task.bold, "\n\n"
end

def run_cmd(cmd)
  puts "==> #{cmd}\n"
  system cmd
end

def run_test(file)
  print_task "Running tests/#{file}.rb"
  system "( cd tests/ ; ruby #{file}.rb )"
end

# Tasks

task default: 'all'

desc "Uninstall gem"
task :uninstall do
  print_task "Uninstalling"
  run_cmd "gem uninstall ruby2d --executables"
end

desc "Build gem"
task :build do
  print_task "Building"
  run_cmd "gem build ruby2d.gemspec --verbose"
end

desc "Install gem"
task :install do
  print_task "Installing"
  run_cmd "gem install ruby2d-#{Ruby2D::VERSION}.gem --local --verbose"
end

desc "Run the RSpec tests"
RSpec::Core::RakeTask.new do |t|
  print_task "Running RSpec"
  t.pattern = "spec/*spec.rb"
end

desc "Run testcard"
task :testcard do
  run_test 'testcard'
end

desc "Run input tests"
task :input do
  run_test 'input'
end

desc "Run native build test"
task :native do
  print_task "Running native build test"
  run_cmd "ruby2d build native tests/testcard.rb"
  print_task "Running native tests/testcard.rb"
  system "( cd tests/ ; ../build/app )"
end

desc "Run web build test"
task :web do
  print_task "Running web build test"
  run_cmd "ruby2d build web tests/testcard.rb"
end

desc "Uninstall, build, install, and test"
task :all do
  Rake::Task['uninstall'].invoke
  Rake::Task['build'].invoke
  Rake::Task['install'].invoke
  Rake::Task['spec'].invoke
end
