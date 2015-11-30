require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

desc 'bump and release patch version, create and push gem to Gemfury'
task release: [:rebase, :spec, :bump_patch, :build, :publish]

desc 'bump and release minor version, create and push gem to Gemfury'
task release_minor: [:rebase, :spec, :bump_minor, :build, :publish]

task :rebase do
  sh 'git pull --rebase'
end

desc 'publish gem'
task :publish do
  new_gem = Dir['*.gem'].sort_by { |file| File.stat(file).ctime }.last
  fail 'Could not find newly created gem!' unless new_gem
  sh "fury push #{new_gem}"
end

desc 'build gem'
task :build do
  gemspec = Dir['*.gemspec'].first
  fail 'No .gemspec could be found!' unless gemspec
  sh "gem build #{gemspec}"
end

desc 'bump patch'
task :bump_patch do
  sh 'gem bump ' \
    '--version patch ' \
    '--commit ' \
    '--tag ' \
    '--push'
end

desc 'bump minor'
task :bump_minor do
  sh 'gem bump ' \
    '--version minor ' \
    '--commit ' \
    '--tag ' \
    '--push'
end
