# list_spider

A url list spider based on em-http-request.

Many times we only need to spider by url list then parse them and spider again. This is for the purpose.

## Features
* Duplicate url filtering (based on local path, so you can custom your behavior).

* Convert to UTF-8 support.

* Increased spider support (don't spider exist).

* Customize concurrent number and interval between task.

* Http options support.

## Getting started

```ruby
gem install list_spider
```

Or add it to your Gemfile

```ruby
gem 'list_spider'
```

## Use like this
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
    # or you can save them to database for later use
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

## Or in one step
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

# get_one is a simple function for one taskstruct situation
ListSpider.get_one(
  TaskStruct.new(
    'https://coolshell.cn/',
    DOWNLOAD_DIR + 'index.html',
    parse_method: method(:parse_index_item)
  ),
  max: 60
)
```

## And there are many options you can use

```ruby
def initialize(href, # 请求链接
                 local_path, # 保存数据的本地路径（此路径作为去重标准）
                 # http方法，取值：:get, :head, :delete, :put, :post, :patch, :options
                 http_method: :get,
                 custom_data: nil, # 自定义数据
                 parse_method: nil, # 解析保存文件的回调，参数是TaskStruct对象本身
                 # 请求成功后的回调，此时可能没有保存文件，比如301，404
                 # 参数是TaskStruct对象本身和对应的EventMachine::HttpRequest对象
                 # http.response_header.status 状态码
                 # http.response_header  返回头
                 # http.response 返回体
                 callback: nil,
                 # 请求失败后的回调
                 # 参数是TaskStruct对象本身和对应的EventMachine::HttpRequest对象
                 errback: nil,
                 stream_callback: nil, # 流数据处理回调
                 convert_to_utf8: false, # 是否转换为utf8编码
                 overwrite_exist: false, # 是否覆盖现有文件
                 # request options
                 redirects: 3, # 重定向次数
                 keepalive: nil, # （暂不支持复用）
                 file: nil, # 要上传的文件路径
                 path: nil, # 请求路径，在流水线方式请求时有用（暂不支持）
                 query: nil, # 查询字符串，可以是string或hash类型
                 body: nil, # 请求体，可以是string或hash类型
                 head: nil, # 请求头
                 # connection options
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

## Callback methods form

```ruby
# called when the file is saved successfully
def parse_eresponse(task_struct)
  # ...
end

def call_back(task_struct, http_req)
  # http_req is a EventMachine::HttpRequest object
  # http_req.response_header.status
  # ...
end

def err_back(task_struct, http_req)
  # ...
end
```

### License

(MIT License) - Copyright (c) 2016 Charles Zhang
