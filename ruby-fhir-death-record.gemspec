# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = 'ruby-fhir-death-record'
  spec.version       = '0.1.4'
  spec.authors       = ['aholmes@mitre.org']
  spec.email         = ['aholmes@mitre.org']

  spec.summary       = 'ruby-fhir-death-record'
  spec.description   = 'ruby-fhir-death-record'
  spec.homepage      = 'https://github.com/projecttacoma/ruby-fhir-death-record'
  spec.license       = 'Apache-2.0'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'activesupport'
  spec.add_development_dependency 'bundler', '~> 1.15'
  spec.add_development_dependency 'byebug'
  spec.add_runtime_dependency 'nokogiri'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
end
