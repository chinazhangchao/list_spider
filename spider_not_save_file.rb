require 'list_spider'
# require File.expand_path('../lib/list_spider', __FILE__)

def call_back(task_struct, http_req)
  puts "succeed"
  puts http_req.response_header.status
  content = http_req.response
  doc = Nokogiri::HTML(content)
  list_group = doc.css('h2.entry-title')
  link_list = list_group.css('a')

  link_list.each do |link|
    href = link['href']
    ListSpider.add_task(TaskStruct.new(href,
      callback: method(:call_back),
      errback: method(:err_back)))
  end
end

def err_back(task_struct, http_req)
  puts "failed"
  puts http_req.response_header.status
end

ListSpider.save_file = false

# get_one is a simple function for one taskstruct situation
ListSpider.get_one(
  TaskStruct.new(
    'https://coolshell.cn/',
    callback: method(:call_back),
    errback: method(:err_back)
  )
)
