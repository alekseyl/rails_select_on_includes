# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rails_select_on_includes/version'

Gem::Specification.new do |spec|
  spec.name          = "rails_select_on_includes"
  spec.version       = RailsSelectOnIncludes::VERSION
  spec.authors       = ["alekseyl"]
  spec.email         = ["leshchuk@gmail.com"]

  spec.summary       = %q{Patching rails include/select/virtual attributes issue}
  spec.description   = %q{Patching rails include/select/virtual attributes issue ( https://github.com/rails/rails/issues/15185 )}
  spec.homepage      = "https://github.com/alekseyl/rails_select_on_includes"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", '>= 5', '<= 5.1.4'

  spec.add_development_dependency "rails", ">=5"
  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency 'sqlite3'

  spec.add_development_dependency 'byebug'

  spec.add_development_dependency 'niceql'
end
