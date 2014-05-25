# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-eval-filter"
  spec.version       = "0.0.5"
  spec.authors       = ["Yuzuki Masaru"]
  spec.email         = ["ephemeralsnow@gmail.com"]
  spec.description   = %q{Fluentd Output eval filter plugin.}
  spec.summary       = %q{Fluentd Output eval filter plugin.}
  spec.homepage      = "https://github.com/ephemeralsnow/fluent-plugin-eval-filter"
  spec.license       = "Apache 2.0"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "fluentd", "~> 0"
  spec.add_development_dependency "rake", "~> 0"
end
