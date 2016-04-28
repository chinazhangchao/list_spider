# spider
a spider based on em-http-request

use easily:
```ruby
down_list = []

down_list << LinkStruct.new('https://www.baidu.com/', 'baidu.html')

GetItem.new(down_list).start
```

capable of complicate process:
```ruby
down_list << LinkStruct.new('https://www.baidu.com/', 'baidu.html', params:{})
GetItem.new(down_list, inter_val: 10, max: 10, parse_method: (:process)).start
```
