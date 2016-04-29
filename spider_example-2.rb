$LOAD_PATH.unshift('/Users/zhangchao/github/list-spider')
require 'list-spider'

def down_dir
  'wangyin/'
end

$next_list = []

def parse_index_item(file_name, extra_data, spider)
  content = File.read(file_name)
  doc = Nokogiri::HTML(content)
  list_group = doc.css("ul.list-group")
  link_list = list_group.css("a")

  $next_list = []
  link_list.each do |link|
    href = link['href']
    local_path = down_dir + link.content + ".html"
    $next_list<< TaskStruct.new(href, local_path)
  end
end

task_list = []
task_list << TaskStruct.new('http://www.yinwang.org/', down_dir+'index.html', parse_method: method(:parse_index_item))

ListSpider.new(task_list).start
ListSpider.new($next_list).start
