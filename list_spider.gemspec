
lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'list_spider/version'

Gem::Specification.new do |spec|
  spec.name          = 'list_spider'
  spec.version       = ListSpider::VERSION
  spec.authors       = ['Charles Zhang']
  spec.email         = ['gis05zc@163.com']

  spec.summary       = 'List Spider'
  spec.description   = 'A url list spider based on em-http-request.'
  spec.homepage      = 'https://github.com/chinazhangchao/list_spider'
  spec.license = 'MIT'

  spec.files =
    `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{^(test|spec|features)/})
    end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.16'
  spec.add_development_dependency 'rake', '~> 10.0'

  spec.add_dependency 'em-http-request', '~> 1.1', '>= 1.1.3'
  spec.add_dependency 'nokogiri', '~> 1.10'
  spec.add_dependency 'rchardet', '~> 1.6', '>= 1.6.1'
end
