Gem::Specification.new do |s|
  s.name        = 'list_spider'
  s.version     = '0.1.0'
  s.date        = '2016-04-29'
  s.summary     = "List Spider"
  s.description = "A url list spider based on em-http-request."
  s.authors     = ["Charles Zhang"]
  s.email       = 'gis05zc@163.com'
  s.add_runtime_dependency 'em-http-request', '~> 1.1', '>= 1.1.3'
  s.add_runtime_dependency 'nokogiri', '~> 1.6', '>= 1.6.7'
  s.files       = ["lib/list_spider.rb", "lib/spider_helper.rb", "lib/spider_base.rb", "lib/delete_unvalid.rb"]
  s.homepage    =
    'https://github.com/chinazhangchao/list_spider'
  s.license       = 'MIT'
end

