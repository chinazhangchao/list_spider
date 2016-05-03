# list_spider

A url list spider based on em-http-request.

Many times we only need to spider by url list then parse them and spider again. This is for the purpose.

## Getting started

    gem install list_spider
    
## Use like this:
```ruby
require 'list_spider'

def down_dir
  'wangyin/'
end

$next_list = []

def parse_index_item(file_name, extra_data, spider)
  content = File.read(file_name)
  doc = Nokogiri::HTML(content)
  list_group = doc.css("ul.list-group")
  link_list = list_group.css("a")

  link_list.each do |link|
    href = link['href']
    local_path = down_dir + link.content + ".html"
    #or you can save them to database
    $next_list<< TaskStruct.new(href, local_path)
  end
end

task_list = []
task_list << TaskStruct.new('http://www.yinwang.org/', down_dir+'index.html', parse_method: method(:parse_index_item))

ListSpider.get_list(task_list)
ListSpider.get_list($next_list)

```

## Or in one step (in simple situation)
```ruby
require 'list_spider'

def down_dir
  'wangyin/'
end

def parse_index_item(file_name, extra_data, spider)
  content = File.read(file_name)
  doc = Nokogiri::HTML(content)
  list_group = doc.css("ul.list-group")
  link_list = list_group.css("a")

  article_list = []
  link_list.each do |link|
    href = link['href']
    local_path = down_dir + link.content + ".html"
    article_list << TaskStruct.new(href, local_path)
  end
  spider.add_task(article_list)
end

task_list = []
task_list << TaskStruct.new('http://www.yinwang.org/', down_dir+'index.html', parse_method: method(:parse_index_item))

ListSpider.get_list(task_list)
```



## And there are many options you can use

```ruby
TaskStruct.new(href, local_path, http_method: :get, params: {}, extra_data: nil, parse_method: nil)
```

```ruby
#no concurrent limit
ListSpider.new(down_list, inter_val: 0, max: ListSpider::NO_LIMIT_CONCURRENT).start

#sleep random time, often used in site which limit spider
ListSpider.new(down_list, inter_val: ListSpider::RANDOM_TIME, max: 1).start
```

```ruby
#set proxy
ListSpider.set_proxy(proxy_addr, proxy_port, username: nil, password: nil)

#set http header
ListSpider.set_header_option(header_option)

#convert the file encoding to utf-8
ListSpider.conver_to_utf8 = false

#set connect timeout
ListSpider.connect_timeout = 2*60

#over write exist file
ListSpider.overwrite_exist = false

#set redirect depth
ListSpider.max_redirects = 10

#set random time range when use ListSpider::RANDOM_TIME
ListSpider.random_time_range = 3..10
```

## There are a util class to help delete unvalid file

```ruby
DeleteUnvalid.delete("#{down_dir}/*", size_threshold: 300)

#its params
DeleteUnvalid.delete(dir_pattern, size_threshold: 1000, cust_judge: nil)
```

### License

(MIT License) - Copyright (c) 2016 Charles Zhang
