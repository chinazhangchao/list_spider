require 'list_spider'
# require File.expand_path('../lib/list_spider', __FILE__)

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
