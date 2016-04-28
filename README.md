# spider

a spider based on em-http-request

easy to use:

```ruby
require 'get_item'

down_list = []

down_list << LinkStruct.new('https://www.baidu.com/', 'baidu.html')

GetItem.new(down_list).start
```

capable of complicate process:

```ruby
#setting http header
Spider.set_header_option({})

#designate http method and parmas
down_list << LinkStruct.new('https://www.baidu.com/', 'baidu.html', http_method: :post params:{})

#designate interval between downloads, max concurrent download number, parse mthod
GetItem.new(down_list, inter_val: 10, max: 10, parse_method: (:process)).start

#you can even use a random interval time to imitate human behavior ^_^
GetItem.new(down_list, inter_val: GetItem::RANDOM_TIME, max: 1).start

```
