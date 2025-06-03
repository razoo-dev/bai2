# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = 'bai2'
  spec.version       = '2.1.0'
  spec.authors       = ['Kenneth Ballenegger', 'Bryce Melvin']
  spec.email         = ['kenneth@ballenegger.com', 'bryce@mightycause.com']
  spec.summary       = %q{Parse BAI2 files with enhanced format support and custom integrity checking.}
  spec.description   = %q{Parse BAI2 files with support for variable continuation records, lenient integrity checking, and business-level validation.}
  spec.homepage      = 'https://github.com/razoo-dev/bai2'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) {|f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler',  '~> 1.7'
  spec.add_development_dependency 'rake',     '~> 10.0'
  spec.add_development_dependency 'minitest', '~> 5.5'
  spec.add_development_dependency 'minitest-reporters', '~> 1.0'
end
