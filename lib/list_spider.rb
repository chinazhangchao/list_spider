require 'em-http-request'
require 'nokogiri'
require 'fileutils'
require 'set'
require 'addressable/uri'
require File.expand_path('../spider_helper', __FILE__)
require File.expand_path('../file_filter', __FILE__)

class TaskStruct
  def initialize(href, local_path, http_method: :get, params: {}, extra_data: nil, parse_method: nil, header: nil)
    @origin_href = href
    @href = href
    @href = SpiderHelper.string_to_uri(@href) if @href.class == ''.class
    @local_path = local_path
    @http_method = http_method
    @params = params
    @extra_data = extra_data
    @parse_method = parse_method
    @header = header
  end

  def ==(other)
    other.class == self.class && other.href == href && other.local_path == local_path && other.http_method == http_method && other.params == params && other.extra_data == extra_data && other.header == header
  end

  attr_accessor :origin_href, :href, :local_path, :http_method, :params, :extra_data, :parse_method, :request_object, :header
end

module ListSpider
  RANDOM_TIME = -1
  NO_LIMIT_CONCURRENT = -1
  DEFAULT_CONCURRNET_MAX = 50
  DEFAULT_INTERVAL = 0

  @random_time_range = 3..10
  @conver_to_utf8 = false
  @connection_opts = { connect_timeout: 60 }
  @overwrite_exist = false
  @max_redirects = 10
  @local_path_set = Set.new

  class << self
    attr_accessor :conver_to_utf8, :overwrite_exist, :max_redirects

    def set_proxy(proxy_addr, proxy_port, username: nil, password: nil)
      @connection_opts = {
        proxy: {
          host: proxy_addr,
          port: proxy_port
        }
      }
      @connection_opts[:proxy][:authorization] = [username, password] if username && password
    end

    def connect_timeout(max_connect_time)
      @connection_opts[:connect_timeout] = max_connect_time
    end

    def set_header_option(header_option)
      @header_option = header_option
    end

    def event_machine_down(link_struct_list, callback = nil)
      failed_list = []
      succeed_list = []
      multi = EventMachine::MultiRequest.new
      begin_time = Time.now

      for_each_proc =
        proc do |e|
          opt = { redirects: @max_redirects }
          if e.header
            opt[:head] = e.header
          elsif defined? @header_option
            opt[:head] = @header_option
          end

          if e.http_method == :post
            opt[:body] = e.params unless e.params.empty?
            w =
              if @connection_opts
                EventMachine::HttpRequest.new(e.href, @connection_opts).post opt
              else
                EventMachine::HttpRequest.new(e.href).post opt
              end
          else
            if @connection_opts
              opt[:query] = e.params unless e.params.empty?
              w = EventMachine::HttpRequest.new(e.href, @connection_opts).get opt
            else
              w = EventMachine::HttpRequest.new(e.href).get opt
            end
          end

          e.request_object = w

          w.callback do
            s = w.response_header.status
            puts s
            if s != 404
              local_dir = File.dirname(e.local_path)
              FileUtils.mkdir_p(local_dir) unless Dir.exist?(local_dir)
              begin
                File.open(e.local_path, 'wb') do |f|
                  f << if @conver_to_utf8 == true
                         SpiderHelper.to_utf8(w.response)
                       else
                         w.response
                       end
                end
                succeed_list << e
              rescue => e
                puts e
              end
            end
          end
          w.errback do
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
          end

          begin
            multi.add e.local_path, w
          rescue => exception
            puts exception
            puts e.href
            puts e.local_path
            stop_machine
          end
        end

      cb =
        proc do
          end_time = Time.now
          puts "use time:#{end_time - begin_time} seconds"
          if callback.nil?
            stop_machine
          else
            callback.call(multi, succeed_list, failed_list)
          end
        end
      link_struct_list.each(&for_each_proc)
      multi.callback(&cb)
    end

    def stop_machine
      puts "success size:#{@succeed_size}"
      puts "failed size:#{@failed_size}"
      @end_time = Time.now
      puts "total use time:#{@end_time - @begin_time} seconds"
      EventMachine.stop
      @local_path_set.clear
    end

    def next_task
      @down_list.shift(@max)
    end

    def call_parse_method(e)
      pm = e.parse_method
      if pm
        case pm.arity
        when 1
          pm.call(e.local_path)
        when 2
          pm.call(e.local_path, e.extra_data)
        when 3
          res_header = nil
          res_header = e.request_object.response_header if e.request_object
          pm.call(e.local_path, e.extra_data, res_header)
        when 4
          res_header = nil
          res_header = e.request_object.response_header if e.request_object

          req = nil
          req = e.request_object.req if e.request_object

          pm.call(e.local_path, e.extra_data, res_header, req)
        else
          puts "Error! The number of arguments is:#{pm.arity}. While expected number is 1, 2, 3, 4"
        end
      end
    end

    def complete(_multi, success_list, failed_list)
      @succeed_size += success_list.size
      @failed_size += failed_list.size
      success_list.each do |e|
        call_parse_method(e)
      end

      todo = next_task

      if todo.empty?
        stop_machine
      else
        if @interval != 0
          if !success_list.empty? || !failed_list.empty?
            if @interval == RANDOM_TIME
              sleep(rand(@random_time_range))
            else
              sleep(@interval)
            end
          end
        end
        event_machine_down(todo, method(:complete))
      end
    end

    def event_machine_start_list(down_list, callback = nil)
      EventMachine.run do
        @begin_time = Time.now
        if down_list.empty?
          if callback
            callback.call(nil, [], [])
          else
            stop_machine
          end
        else
          event_machine_down(down_list, callback)
        end
      end
    end

    def filter_list(down_list)
      need_down_list = []
      down_list.each do |ts|
        if !@overwrite_exist && File.exist?(ts.local_path)
          call_parse_method(ts)
        elsif @local_path_set.add?(ts.local_path)
          need_down_list << ts
        end
      end
      need_down_list
    end

    def get_list(down_list, interval: DEFAULT_INTERVAL, max: DEFAULT_CONCURRNET_MAX)
      if interval.is_a?Range
        @random_time_range = interval
        interval = RANDOM_TIME
      end

      @down_list = []

      need_down_list = filter_list(down_list)

      @down_list += need_down_list
      @interval = interval
      @max = max
      @max = @down_list.size if @max == NO_LIMIT_CONCURRENT
      @succeed_size = 0
      @failed_size = 0

      puts "total size:#{@down_list.size}"
      event_machine_start_list(next_task, method(:complete))
    end

    def get_one(task, interval: DEFAULT_INTERVAL, max: DEFAULT_CONCURRNET_MAX)
      get_list([task], interval: interval, max: max)
    end

    def add_task(task)
      if task.is_a?Array
        need_down_list = filter_list(task)
        @down_list += need_down_list
      elsif task.is_a?TaskStruct
        need_down_list = filter_list([task])
        @down_list += need_down_list
      else
        puts "error task type:#{task.class}"
      end
    end
  end

  Signal.trap('INT') do
    ListSpider.stop_machine
    exit!
  end
end
