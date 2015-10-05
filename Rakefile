# require 'rake/testtask'

task default: 'all'

# Rake::TestTask.new do |t|
#   t.test_files = FileList['test/*_test.rb']
#   t.verbose = true
# end

desc "Build Gem"
task :build do
  puts "==> uninstall gem"
  system "gem uninstall ruby2d --executables"

  puts "==> build gem"
  system "gem build ruby2d.gemspec --verbose"

  puts "==> install gem"
  system "gem install ruby2d-0.0.0.gem --local"  # --verbose
end


desc "Run Testcard"
task :testcard do
  Rake::Task['build'].invoke
  system '( cd tests/ ; ruby testcard.rb )'
end


desc "Test and Build"
task :all do
  # Rake::Task['test'].invoke
  Rake::Task['build'].invoke
end
