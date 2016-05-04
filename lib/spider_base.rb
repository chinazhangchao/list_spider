require 'em-http-request'
require 'nokogiri'
require 'fileutils'
require 'set'
require File.expand_path('../spider_helper', __FILE__)
require "addressable/uri"

class TaskStruct
  def initialize(href, local_path, http_method: :get, params: {}, extra_data: nil, parse_method: nil)
    @origin_href = href
    @href = href
    if @href.class == "".class
      @href = SpiderHelper.string_to_uri(@href)
    end
    @local_path = local_path
    @http_method = http_method
    @params = params
    @extra_data = extra_data
    @parse_method = parse_method
  end

  def == (o)
    o.class == self.class && o.href == href && o.local_path == local_path && o.http_method == http_method && o.params == params && o.extra_data == extra_data
  end

  attr_accessor :origin_href , :href, :local_path, :http_method, :params, :extra_data, :parse_method

end

module SpiderBase

  @@conver_to_utf8 = false
  @@connection_opts = {:connect_timeout => 2*60}
  @@overwrite_exist = false
  @@max_redirects = 10
  @@url_set = Set.new

  class << self

    attr_accessor :conver_to_utf8, :overwrite_exist, :max_redirects

    def set_proxy(proxy_addr, proxy_port, username: nil, password: nil)
      @@connection_opts = {
        :proxy => {
          :host => proxy_addr,
          :port => proxy_port
        }
      }
      @@connection_opts[:proxy][:authorization] = [username, password] if username && password
    end

    def connect_timeout(max_connect_time)
      @@connection_opts[:connect_timeout] = max_connect_time
    end

    def set_header_option(header_option)
      @@header_option = optHash
    end

    def event_machine_down(link_struct_list, callback = nil)
      failed_list = []
      succeed_list = []
      # puts "event_machine_down callback:#{callback}"
      multi = EventMachine::MultiRequest.new
      no_job = true
      begin_time = Time.now

      for_each_proc = proc do |e|
        if !@@overwrite_exist && File.exist?(e.local_path)
          succeed_list << e
        else
          next unless @@url_set.add?(e.href)
          no_job = false
          opt = {}
          opt = {:redirects => @@max_redirects}
          opt[:head] = @@header_option if defined? @@header_option
          if e.http_method == :post
            opt[:body] = e.params unless e.params.empty?
            if @@connection_opts
              w = EventMachine::HttpRequest.new(e.href, @@connection_opts).post opt
            else
              w = EventMachine::HttpRequest.new(e.href).post opt
            end
          else
            if @@connection_opts
              opt[:query] = e.params unless e.params.empty?
              w = EventMachine::HttpRequest.new(e.href, @@connection_opts).get opt
            else
              w = EventMachine::HttpRequest.new(e.href).get opt
            end
          end

          w.callback {
            @@url_set.delete(e.href)
            # puts "complete:#{w.response_header}"
            s = w.response_header.status
            puts s
            if s == 403 || s == 502 #Forbidden
              # EventMachine.stop
            elsif s != 404
              local_dir = File.dirname(e.local_path)
              FileUtils.mkdir_p(local_dir) unless Dir.exist?(local_dir)
              begin
                File.open(e.local_path, "w") do |f|
                  if @@conver_to_utf8 == true
                    f << SpiderHelper.to_utf8( w.response)
                  else
                    f << w.response
                  end
                end
                succeed_list << e
              rescue Exception => e
                puts e
              end
            end
          }
          w.errback {
            @@url_set.delete(e.href)
            puts "errback:#{w.response_header}"
            puts e.origin_href
            puts e.href
            puts w.response_header.status
            failed_list << e
            if e.http_method == :get
              SpiderHelper.direct_http_get(e.href, e.local_path)
            elsif e.http_method == :post
              SpiderHelper.direct_http_post(e.href, e.local_path, e.params)
            end
          }
          multi.add e.local_path, w
        end
      end

      # em_for_each_proc = proc do |e, iter|
      #   for_each_proc.call(e)
      #   iter.next
      # end

      cb = Proc.new do
        end_time = Time.now
        puts "use time:#{end_time-begin_time} seconds"
        if callback.nil?
          puts "success size:#{self.succeed_size}"
          puts "failed size:#{self.failed_size}"
          EventMachine.stop
        else
          callback.call(multi, succeed_list, failed_list)
        end
      end

      after_proc = proc {
        if no_job #没有任务直接调回调
          cb.call
        else
          multi.callback &cb
        end
      }

      # if DownLoadConfig::MaxConcurrent <= 0
        link_struct_list.each &for_each_proc
        after_proc.call
      # else
        # EM::Iterator.new(link_struct_list, DownLoadConfig::MaxConcurrent).each(em_for_each_proc, after_proc)
      # end
    end

    def event_machine_start(url, down_dir, file_name, callback = nil)
      down_dir << "/" unless down_dir.end_with?("/")
      FileUtils.mkdir_p(down_dir) unless Dir.exist?(down_dir)
      down_list = []
      down_list << TaskStruct.new(url, down_dir + file_name)
      EventMachine.run {
        index = 0
        begin_time = Time.now
        event_machine_down(down_list, callback)
        end_time = Time.now
      }
    end

    def event_machine_start_list(down_list, callback = nil)
      EventMachine.run {
        index = 0
        begin_time = Time.now
        event_machine_down(down_list, callback)
        end_time = Time.now
      }
    end

  end#self end
end#SpiderBase end

def batch_down_list(down_list, callback = nil)
  SpiderBase.event_machine_down(down_list, callback)
end

def event_machine_start_list(down_list, callback = nil)
  SpiderBase.event_machine_start_list(down_list, callback)
end

def parse_down_load_url(url, down_dir, file_name, callback = nil)
  SpiderBase.event_machine_start(url, down_dir, file_name, callback)
end

class GetRelative

  def initialize(base_url,down_dir,get_depth = 2,suffix=".html")
    @get_depth = get_depth
    @base_url = base_url
    @down_dir = down_dir
    @suffix = suffix
  end

  def down_node (multi, succeed_list, failed_list, base_url, down_dir, callback)
    puts "success"
    puts succeed_list.size
    puts "error"
    puts failed_list.size
    puts failed_list
    puts "get index complete"
    if succeed_list.size > 0
      link_list = []
      succeed_list.each do |e|
        doc = Nokogiri::HTML(open(e.local_path))
        link_list.concat(doc.css("a"))
      end
      puts "extrat href complete"

      down_dir << "/" unless down_dir.end_with?("/")
      FileUtils.mkdir_p(down_dir) unless Dir.exist?(down_dir)

      down_list = []
      set_list = Set.new
      link_list.each do |link|
        href = link['href']
        next if href.nil? || !href.include?(@suffix) 
        #process such as "scheme_2.html#SEC15"
        href = href[0, href.index(@suffix) + 5]
        #process such as "./preface.html"
        href = href[2..-1] if href.start_with?("./")

        next if !set_list.add?(href)
        unless base_url.end_with?("/")
          i = base_url.rindex"/"
          base_url = base_url[0..i]
        end

        #process such as "http://www.ccs.neu.edu/~dorai"
        next if href.start_with?("http:") || href.start_with?("https:")

        local_path = down_dir + href

        down_list.push( TaskStruct.new(base_url + href, local_path))
      end
      puts "down list complete,size:#{down_list.size}"
      batch_down_list(down_list, callback)
    end
  end

  def down_other_node (multi, succeed_list, failed_list)
    puts "down_other_node"
    @get_depth = @get_depth - 1
    puts "depth:#{@get_depth}"
    if @get_depth <= 0
      down_node(multi, succeed_list, failed_list, @base_url, @down_dir, method(:event_all_complete));
    else
      down_node(multi, succeed_list, failed_list, @base_url, @down_dir, method(:down_other_node));
    end
  end

  def event_all_complete (multi, succeed_list, failed_list)
    puts "all complete"
    puts "success"
    puts succeed_list.size
    puts "error"
    puts failed_list.size
    puts failed_list
    EventMachine.stop
  end

  attr_writer :get_depth,:base_url,:down_dir

  def start
    index_file_name = "index.html"
    #http://www.ccs.neu.edu/home/dorai/t-y-scheme/t-y-scheme-Z-H-1.html
    unless @base_url.end_with?("/")
      i = @base_url.rindex"/"
      index_file_name = @base_url[i+1 .. -1]
    end

    @get_depth = @get_depth - 1
    puts @get_depth
    if @get_depth <= 0
      parse_down_load_url(@base_url, @down_dir, index_file_name, method(:event_all_complete))
    else
      parse_down_load_url(@base_url, @down_dir, index_file_name, method(:down_other_node))
    end
  end

  def self.Get(base_url, down_dir, get_depth = 2, suffix = ".html")
    GetRelative.new(base_url,down_dir, get_depth, suffix).start
  end
end #GetRelative
