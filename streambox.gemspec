# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'streambox/version'

Gem::Specification.new do |spec|
  spec.name          = "streambox"
  spec.version       = Streambox::VERSION
  spec.authors       = ["Phil Hofmann"]
  spec.email         = ["phil@voicerepublic.com"]
  spec.summary       = %q{The VR Audio Proxy in a box.}
  spec.description   = %q{The VR Audio Proxy in a box.}
  spec.homepage      = "https://gitlab.com/voicerepublic/streambox"
  spec.license       = "proprietary"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'rack', '~> 1.6.4'
  spec.add_dependency 'faraday', '0.9.2'
  spec.add_dependency 'trickery', '0.0.7'
  spec.add_dependency 'mkfifo', '0.1.1'
  spec.add_dependency 'rb-inotify', '0.9.7'

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
end
