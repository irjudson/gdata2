Gem::Specification.new do |s|
  s.name = %q{gdata2}
  s.version = "0.1"
  s.authors = ["Jérôme Bousquié", "Ivan R. Judson"]
  s.email = "ivan.judson@montana.edu"
  s.date = %q{2009-02-20}
  s.homepage = ""
  s.summary = "Ruby wrapper for Google Data API's"
  s.description = "gdata2 is a ruby wrapper for the google data apis"

  s.has_rdoc = true
  s.extra_rdoc_files = ["History.txt", "Manifest.txt", "README.txt"]
  s.rdoc_options = ["--main", "README.txt"]
  s.remote_rdoc_dir = ''
  s.files = ["CREDITS", "History.txt", "Manifest.txt", "README.txt", 
             "Rakefile", "TODO", "gdata2.gemspec", "lib/gdata.rb", 
             "lib/gdata/apps/provisioning.rb"]
  s.require_paths = ["lib"]
  s.rubyforge_project = "gdata2"
  s.rubygems_version = "1.3.1"
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  
  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<hoe>, [">= 1.8.3"])
    else
      s.add_dependency(%q<hoe>, [">= 1.8.3"])
    end
  else
    s.add_dependency(%q<hoe>, [">= 1.8.3"])
  end
end