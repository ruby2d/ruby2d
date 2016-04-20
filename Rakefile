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

def run_cmd(cmd)
  print "\n==> ".blue, cmd.bold, "\n\n"
  system cmd
end

def run_test(file)
  Rake::Task['build'].invoke
  Rake::Task['spec'].invoke
  print "==> ".blue, "running tests/#{file}.rb".bold, "\n"
  system "( cd tests/ ; ruby #{file}.rb )"
end

# Tasks

task default: 'all'

desc "Run the RSpec tests"
RSpec::Core::RakeTask.new do |t|
  print "\n==> ".blue, "running RSpec".bold, "\n\n"
  t.pattern = "spec/*spec.rb"
end

desc "Build gem"
task :build do
  run_cmd "gem uninstall ruby2d --executables"
  run_cmd "gem build ruby2d.gemspec --verbose"
  run_cmd "gem install ruby2d-#{Ruby2D::VERSION}.gem --local --verbose"
end

desc "Run testcard"
task :testcard do
  run_test 'testcard'
end

desc "Run input tests"
task :input do
  run_test 'input'
end

desc "Run controller tests"
task :controller do
  run_test 'controller'
end

desc "Test and build"
task :all do
  Rake::Task['build'].invoke
  Rake::Task['spec'].invoke
end
