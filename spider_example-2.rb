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

DeleteUnvalid.delete("#{down_dir}/*", size_threshold: 300)

task_list = []
task_list << TaskStruct.new('http://www.yinwang.org/', down_dir+'index.html', parse_method: method(:parse_index_item))

ListSpider.get_list(task_list)
ListSpider.get_list($next_list, max: 50)

DeleteUnvalid.delete("#{down_dir}/*", size_threshold: 300)
