require 'em-http-request'
require 'nokogiri'
require 'fileutils'
require 'set'
require "addressable/uri"
require File.expand_path('../spider_helper', __FILE__)
require File.expand_path('../delete_unvalid', __FILE__)

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

  attr_accessor :origin_href , :href, :local_path, :http_method, :params, :extra_data, :parse_method, :request_object

end

module ListSpider

  RANDOM_TIME = -1
  NO_LIMIT_CONCURRENT = -1
  DEFAULT_CONCURRNET_MAX = 50
  DEFAULT_INTERVAL = 0

  @random_time_range = 3..10
  @conver_to_utf8 = false
  @connection_opts = {connect_timeout: 60}
  @overwrite_exist = false
  @max_redirects = 10
  @@local_path_set = Set.new

  class << self

    attr_accessor :random_time_range, :conver_to_utf8, :overwrite_exist, :max_redirects

    def set_proxy(proxy_addr, proxy_port, username: nil, password: nil)
      @connection_opts = {
        :proxy => {
        :host => proxy_addr,
        :port => proxy_port
      }
      }
      @connection_opts[:proxy][:authorization] = [username, password] if username && password
    end

    def connect_timeout(max_connect_time)
      @connection_opts[:connect_timeout] = max_connect_time
    end

    def set_header_option(header_option)
      @@header_option = header_option
    end

    def event_machine_down(link_struct_list, callback = nil)
      failed_list = []
      succeed_list = []
      multi = EventMachine::MultiRequest.new
      begin_time = Time.now

      for_each_proc = proc do |e|
        opt = {}
        opt = {:redirects => @max_redirects}
        opt[:head] = @@header_option if defined? @@header_option
        if e.http_method == :post
          opt[:body] = e.params unless e.params.empty?
          if @connection_opts
            w = EventMachine::HttpRequest.new(e.href, @connection_opts).post opt
          else
            w = EventMachine::HttpRequest.new(e.href).post opt
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

        w.callback {
          s = w.response_header.status
          puts s
          if s != 404
            local_dir = File.dirname(e.local_path)
            FileUtils.mkdir_p(local_dir) unless Dir.exist?(local_dir)
            begin
              File.open(e.local_path, "w") do |f|
                if @conver_to_utf8 == true
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

        begin
          multi.add e.local_path, w
        rescue Exception => exception
          puts exception
          puts e.href
          puts e.local_path
          stop_machine
        end
      end

      cb = Proc.new do
        end_time = Time.now
        puts "use time:#{end_time-begin_time} seconds"
        if callback.nil?
          stop_machine
        else
          callback.call(multi, succeed_list, failed_list)
        end
      end
      link_struct_list.each &for_each_proc
      multi.callback &cb
    end

    def stop_machine
      puts "success size:#{@@succeed_size}"
      puts "failed size:#{@@failed_size}"
      @@end_time = Time.now
      puts "total use time:#{@@end_time-@@begin_time} seconds"
      EventMachine.stop
      @@local_path_set.clear
    end

    def get_next_task
      return @@down_list.shift(@@max)
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
        else
          puts "Error! The number of arguments is:#{pm.arity}. While expected number is 1, 2, 3"
        end
      end
    end

    def complete(multi, success_list, failed_list)
      @@succeed_size += success_list.size
      @@failed_size += failed_list.size
      success_list.each do |e|
        call_parse_method(e)
      end

      todo = get_next_task

      if todo.empty?
        stop_machine
      else
        if @@inter_val != 0
          if success_list.size != 0 || failed_list.size != 0
            if @@inter_val == RANDOM_TIME
              sleep(rand(@random_time_range))
            else
              sleep(@@inter_val)
            end
          end
        end
        event_machine_down(todo, method(:complete))
      end
    end

    def event_machine_start_list(down_list, callback = nil)
      EventMachine.run {
        @@begin_time = Time.now
        if down_list.empty?
          if callback
            callback.call(nil, [], [])
          else
            stop_machine
          end
        else
          event_machine_down(down_list, callback)
        end
      }
    end

    def filter_list(down_list)
      need_down_list = []
      down_list.each do |ts|
        if !@overwrite_exist && File.exist?(ts.local_path)
          call_parse_method(ts)
        elsif @@local_path_set.add?(ts.local_path)
          need_down_list << ts
        end
      end
      return need_down_list
    end

    def get_list(down_list, inter_val: DEFAULT_INTERVAL, max: DEFAULT_CONCURRNET_MAX)
      @@down_list = []

      need_down_list = filter_list(down_list)

      @@down_list = @@down_list + need_down_list
      @@inter_val = inter_val
      @@max = max
      @@max = @@down_list.size if @@max == NO_LIMIT_CONCURRENT
      @@succeed_size = 0
      @@failed_size = 0

      puts "total size:#{@@down_list.size}"
      event_machine_start_list(get_next_task, method(:complete))
    end

    def get_one(task, inter_val: DEFAULT_INTERVAL, max: DEFAULT_CONCURRNET_MAX)
      get_list([task], inter_val: inter_val, max: max)
    end

    def add_task(task)
      if task.is_a?Array
        need_down_list = filter_list(task)
        @@down_list = @@down_list + need_down_list
      elsif task.is_a?TaskStruct
        need_down_list = filter_list([task])
        @@down_list = @@down_list + need_down_list
      else
        puts "error task type:#{task.class}"
      end
    end
  end

  Signal.trap("INT") do
    ListSpider.stop_machine
    exit!
  end

end
