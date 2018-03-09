# 关于list_spider

list_spider是一个基于[em-http-request](https://github.com/igrigorik/em-http-request)的爬虫工具。

许多情况下，爬虫的工作是爬取链接，解析返回数据，从中提取链接，继续爬取，list_spider就是适用这种场景的爬虫工具。

## 功能特点
* 去重过滤 (使用本地文件路径做唯一性校验)。

* 支持UTF-8编码转换。

* 默认增量爬取，已爬取的不再重复爬取（可以通过选项强制重新获取）。

* 自由设置最大并发数和爬取任务间隔时间。

* 支持http所有选项设置。

## 开始

```ruby
gem install list_spider
```

或者添加到Gemfile

```ruby
gem 'list_spider'
```

## 使用方法
```ruby
require 'list_spider'

DOWNLOAD_DIR = 'coolshell/'.freeze

@next_list = []

def parse_index_item(e)
  content = File.read(e.local_path)
  doc = Nokogiri::HTML(content)
  list_group = doc.css('h2.entry-title')
  link_list = list_group.css('a')

  link_list.each do |link|
    href = link['href']
    local_path = DOWNLOAD_DIR + link.content + '.html'
    # 可以存入数据库后续处理
    @next_list << TaskStruct.new(href, local_path)
  end
end

task_list = []
task_list << TaskStruct.new(
  'https://coolshell.cn/',
  DOWNLOAD_DIR + 'index.html',
  parse_method: method(:parse_index_item)
)

ListSpider.get_list(task_list)
ListSpider.get_list(@next_list, max: 60)
```

## 或者使用更简单的一步完成
```ruby
require 'list_spider'

DOWNLOAD_DIR = 'coolshell/'.freeze

def parse_index_item(e)
  content = File.read(e.local_path)
  doc = Nokogiri::HTML(content)
  list_group = doc.css('h2.entry-title')
  link_list = list_group.css('a')

  link_list.each do |link|
    href = link['href']
    local_path = DOWNLOAD_DIR + link.content + '.html'
    ListSpider.add_task(TaskStruct.new(href, local_path))
  end
end

# get_one是封装了get_list的简化形式，方便一个任务时调用
ListSpider.get_one(
  TaskStruct.new(
    'https://coolshell.cn/',
    DOWNLOAD_DIR + 'index.html',
    parse_method: method(:parse_index_item)
  ),
  max: 60
)
```

## get_list/get_one参数
```
# down_list: 要请求的TaskStruct数组
# interval: 任务间隔，默认为0。若参数为Range对象，则随机间隔Range范围内的秒数。若设为RANDOM_TIME则随机间隔3到10秒。
# max: 最大并发数，默认为50。若设为NO_LIMIT_CONCURRENT，则所有请求任务全部一起并发执行
get_list(down_list, interval: DEFAULT_INTERVAL, max: DEFAULT_CONCURRNET_MAX)
get_one(task, interval: DEFAULT_INTERVAL, max: DEFAULT_CONCURRNET_MAX)
```

## 下面是TaskStruct可以设置的选项，与[em-http-request](https://github.com/igrigorik/em-http-request)基本一致

```ruby
new(href, # 请求链接
                 local_path, # 保存数据的本地路径（此路径作为去重标准）
                 # http方法，取值：:get, :head, :delete, :put, :post, :patch, :options
                 http_method: :get,
                 custom_data: nil, # 自定义数据
                 parse_method: nil, # 解析保存文件的回调，参数是TaskStruct对象本身
                 # 请求成功后的回调，此时可能没有保存文件，比如301，404
                 # 参数是TaskStruct对象本身和对应的EventMachine::HttpRequest对象
                 # http_req.response_header.status 状态码
                 # http_req.response_header  返回头
                 # http_req.response 返回体
                 callback: nil,
                 # 请求失败后的回调
                 # 参数是TaskStruct对象本身和对应的EventMachine::HttpRequest对象
                 errback: nil,
                 stream_callback: nil, # 流数据处理回调
                 convert_to_utf8: false, # 是否转换为utf8编码
                 overwrite_exist: false, # 是否覆盖现有文件
                 # 请求设置
                 redirects: 3, # 重定向次数
                 keepalive: nil, # （暂不支持复用）
                 file: nil, # 要上传的文件路径
                 path: nil, # 请求路径，在流水线方式请求时有用（暂不支持）
                 query: nil, # 查询字符串，可以是string或hash类型
                 body: nil, # 请求体，可以是string或hash类型
                 head: nil, # 请求头
                 # 连接设置
                 connect_timeout: 60, # 连接超时时间
                 inactivity_timeout: nil, # 连接后超时时间
                 # ssl设置
                 # ssl: {
                 #     :private_key_file => '/tmp/server.key',
                 #     :cert_chain_file => '/tmp/server.crt',
                 #     :verify_peer => false
                 # }
                 ssl: nil,
                 # bind: {
                 #     :host => '123.123.123.123',   # use a specific interface for outbound request
                 #     :port => '123'
                 # }
                 bind: nil,
                 # 代理设置
                 # proxy: {
                 #     :host => '127.0.0.1',    # proxy address
                 #     :port => 9000,           # proxy port
                 #     :type => :socks5         # default proxy mode is HTTP proxy, change to :socks5 if required

                 #     :authorization => ['user', 'pass']  # proxy authorization header
                 # }
                 proxy: nil)
```

## 回调函数形式

```ruby
# 文件成功保存后调用，通过parse_method参数传入
def parse_eresponse(task_struct)
  # ...
end

# http请求成功后调用，通过callback参数传入
def call_back(task_struct, http_req)
  # http_req 是EventMachine::HttpRequest对象
  # http_req.response_header.status
  # ...
end

# http请求出错后调用，通过errback参数传入
def err_back(task_struct, http_req)
  # ...
end
```

## License

(MIT License) - Copyright (c) 2016 Charles Zhang
