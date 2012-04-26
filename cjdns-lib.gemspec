# -*- encoding: utf-8 -*-
require File.expand_path('../lib/cjdns-lib/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["kris kechagia"]
  gem.email         = ["kk@rndsec.net"]
  gem.description   = %q{library to connect to the cjdns admin interface}
  gem.summary       = %q{library to connect to the cjdns admin interface}
  gem.homepage      = "https://github.com/kechagia/cjdns-lib"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "cjdns-lib"
  gem.require_paths = ["lib"]
  gem.version       = Cjdns::Lib::VERSION

  gem.rubyforge_project = "cjdns-lib"

  # specify any dependencies here
  gem.add_runtime_dependency 'bencode'
end
