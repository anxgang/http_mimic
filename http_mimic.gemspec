# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'http_mimic/version'

Gem::Specification.new do |spec|
  spec.name          = "http_mimic"
  spec.version       = HttpMimic::VERSION
  spec.authors       = ["Ivan"]
  spec.summary       = "A HTTParty-like Ruby client wrapping curl-impersonate via Open3."
  spec.description   = "Simplifies making HTTP requests using curl-impersonate to mimic real browser TLS/HTTP2 fingerprints."
  spec.files         = Dir["lib/**/*.rb", "README.md", "http_mimic.gemspec"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.17"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest"
end
