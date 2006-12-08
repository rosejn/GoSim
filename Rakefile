require 'rubygems' 
require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

PKG_VERSION = "0.2"

$VERBOSE = nil
TEST_CHANGES_SINCE = Time.now - 600 # Recent tests = changed in last 10 minutes

desc "Run all the unit tests"
task :default => :test

# Run all the unit tests
desc "Run the unit tests in test"
Rake::TestTask.new(:test) { |t|
#  t.loader = :testrb
  t.libs << "test"
  t.test_files = FileList['test/*_test.rb']
  t.verbose = false
}

# Generate the RDoc documentation
Rake::RDocTask.new(:doc) { |rdoc|
  rdoc.main = 'README'
  rdoc.rdoc_files.include('lib/**/*.rb', 'README')
  rdoc.rdoc_files.include('GPL', 'COPYING')
  rdoc.rdoc_dir = 'docs/api'
  rdoc.title    = "GoSim -- Discrete Event Simulation System"
  rdoc.options << "--include examples/ --line-numbers --inline-source"
}

Gem::manage_gems 
require 'rake/gempackagetask'

spec = Gem::Specification.new do |s| 
  s.name = "gosim" 
  s.version = PKG_VERSION 
  s.homepage = "http://gosim.rubyforge.org/" 
  s.platform = Gem::Platform::RUBY 
  s.summary = "Flexible, discrete event simulation system." 
  s.description = "A discrete event simulator for exploring ideas."

  s.files = FileList["{test,lib,docs,examples}/**/*"].to_a
  s.files += ["Rakefile", "README", "COPYING", "GPL" ]
  s.require_path = "lib" 
  s.autorequire = "gosim" 
  s.has_rdoc = true 
  s.extra_rdoc_files = ["README", "COPYING", "GPL"]
  s.rdoc_options.concat ['--main', 'README']

  s.author = "Jeff Rose & Cyrus Hall"
  s.email = "rosejn@gmail.com, hallcp@gmail.com" 
end 

Rake::GemPackageTask.new(spec) do |pkg| 
  pkg.gem_spec = spec
  pkg.need_tar = true
  pkg.need_zip = true
end

desc 'Install the gem globally (requires sudo)'
task :install => :package do |t|
  `gem install pkg/gosim-#{PKG_VERSION}.gem`
end
