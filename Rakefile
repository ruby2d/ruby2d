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

def get_args
  ARGV.each { |a| task a.to_sym do ; end }
end

def print_task(task)
  print "\n", "==> ".blue, task.bold, "\n\n"
end

def run_cmd(cmd)
  puts "==> #{cmd}\n"
  system cmd
end

def run_mri_test(file)
  print_task "Running MRI test: #{file}.rb"
  system "( cd test/ ; ruby #{file}.rb )"
end

def run_native_test(file)
  print_task "Running native test: #{file}.rb"
  run_cmd "ruby2d build --native test/#{file}.rb --debug"
  system "( cd test/ ; ../build/app )"
end

def run_web_test(file)
  print_task "Running web test: #{file}.rb"
  run_cmd "ruby2d build --web test/#{file}.rb --debug"
  open_cmd = 'open'
  if RUBY_PLATFORM =~ /linux/ then open_cmd = "xdg-#{open_cmd}" end
  system "#{open_cmd} build/app.html"
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
  t.pattern = "test/*spec.rb"
end

namespace :test do
  desc "Run MRI test"
  task :mri do
    get_args
    run_mri_test ARGV[1]
  end
  
  desc "Run native test"
  task :native do
    get_args
    run_native_test ARGV[1]
  end
  
  desc "Run web test"
  task :web do
    get_args
    run_web_test ARGV[1]
  end
end

desc "Uninstall, build, install, and test"
task :all do
  Rake::Task['uninstall'].invoke
  Rake::Task['build'].invoke
  Rake::Task['install'].invoke
  Rake::Task['spec'].invoke
end
