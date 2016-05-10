require 'list_spider'

DOWNLOAD_DIR = 'wangyin/'

def parse_index_item(file_name, extra_data, response_header)
  # response_header is a EventMachine::HttpResponseHeader object
  # you can use it like this:
  # response_header.status
  # response_header['Last-Modified']

  content = File.read(file_name)
  doc = Nokogiri::HTML(content)
  list_group = doc.css("ul.list-group")
  link_list = list_group.css("a")

  article_list = []
  link_list.each do |link|
    href = link['href']
    local_path = DOWNLOAD_DIR + link.content + ".html"
    article_list << TaskStruct.new(href, local_path)
  end
  ListSpider.add_task(article_list)
end

#get_one is a simple function for one taskstruct situation
ListSpider.get_one(TaskStruct.new('http://www.yinwang.org/', DOWNLOAD_DIR + 'index.html', parse_method: method(:parse_index_item)), max: 60)
