# -*- ruby -*-
 
require 'rubygems'
require 'hoe'
require "spec/rake/spectask"
require './lib/gdata'
 
class Hoe
  def extra_deps; @extra_deps.reject { |x| Array(x).first == "hoe" } end
end # copied from the Rakefile of the sup project
 
Hoe.new('gdata2', "0.1") do |p|
  p.rubyforge_name = 'gdata2'
  p.author = 'Ivan R. Judson'
  p.email = 'ivan.judson@montana.edu'
  p.summary = 'Ruby Wrapper for the Google Data APIs'
  p.description = p.paragraphs_of('README.txt', 2..3).join("\n\n")
  p.url = p.paragraphs_of('README.txt', 0).first.split(/\n/)[1..-1]
  p.changes = p.paragraphs_of('History.txt', 0..1).join("\n\n")
  p.remote_rdoc_dir = ''
end
 
 
RDOC_OPTS = [
  '--quiet',
  '--title', 'gdata2 APIs',
  '--main', 'README.txt',
  '--charset', 'utf-8',
  '--inline-source',
  '--tab-width', '2',
  '--line-numbers',
]
 
Rake::RDocTask.new do |rdoc|
    rdoc.rdoc_dir = 'doc/'
    rdoc.options = RDOC_OPTS
    rdoc.main = "README.txt"
    rdoc.rdoc_files.add [
      'LICENSE.txt',
      'README.txt',
      'History.txt',
      'lib/**/*.rb'
    ]
end
 
# desc "Run all specs"
# Spec::Rake::SpecTask.new do |t|
#   t.spec_files = FileList["spec/**/*_spec.rb"]
#   t.spec_opts = ["--options", "spec/spec.opts"]
# end
#  
# desc "Run all specs and get coverage statistics"
# Spec::Rake::SpecTask.new('spec:rcov') do |t|
#   t.spec_files = FileList["spec/**/*_spec.rb"]
#   t.rcov = true
#   t.spec_opts = ["--options", "spec/spec.opts"]
# end
#  
# Rake::Task[:default].prerequisites.clear
# task :default => :spec
 
# vim: syntax=Ruby
