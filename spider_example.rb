require 'list_spider'

DOWNLOAD_DIR = 'wangyin/'

def parse_index_item(file_name)

  content = File.read(file_name)
  doc = Nokogiri::HTML(content)
  list_group = doc.css("ul.list-group")
  link_list = list_group.css("a")

  link_list.each do |link|
    href = link['href']
    local_path = DOWNLOAD_DIR + link.content + ".html"
    ListSpider.add_task(TaskStruct.new(href, local_path))
  end
end

#get_one is a simple function for one taskstruct situation
ListSpider.get_one(TaskStruct.new(
  'http://www.yinwang.org/',
  DOWNLOAD_DIR + 'index.html',
  parse_method: method(:parse_index_item)),
max: 60)
