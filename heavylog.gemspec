# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("./lib", __dir__)
require "heavylog/version"

Gem::Specification.new do |s|
  s.name      = "heavylog"
  s.version   = Heavylog::VERSION
  s.authors   = ["Signmax AB"]
  s.email     = ["team@signomatic.ee"]
  s.platform  = Gem::Platform::RUBY

  s.required_ruby_version = ">= 3.4"
  s.required_rubygems_version = ">= 3.2"

  s.summary       = "Format all Rails logging per request"
  s.homepage      = "https://github.com/skyltmax/heavylog"
  s.license       = "MIT"

  s.metadata      = {
    "homepage_uri"    => "https://github.com/skyltmax/heavylog#readme",
    "source_code_uri" => "https://github.com/skyltmax/heavylog",
    "bug_tracker_uri" => "https://github.com/skyltmax/heavylog/issues",
  }

  s.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features|.vscode)/})
  end
  s.require_paths = ["lib"]

  s.add_development_dependency "karafka", ">= 2.5.5"
  s.add_development_dependency "rake", "~> 13.0"
  s.add_development_dependency "rspec", "~> 3.0"
  s.add_development_dependency "rubocop", "< 1.84.1"
  s.add_development_dependency "sidekiq", ">= 6.0"
  s.add_development_dependency "skyltmax_config"

  s.add_dependency "actionpack", ">= 8.0", "< 8.2"
  s.add_dependency "activerecord", ">= 8.0", "< 8.2"
  s.add_dependency "activesupport", ">= 8.0", "< 8.2"
  s.add_dependency "railties",      ">= 8.0", "< 8.2"
  s.add_dependency "request_store", "~> 1.4"
end
