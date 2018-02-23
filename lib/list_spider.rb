require 'list_spider/version'
require 'em-http-request'
require 'nokogiri'
require 'fileutils'
require 'set'
require 'addressable/uri'
require File.expand_path('../spider_helper', __FILE__)
require File.expand_path('../file_filter', __FILE__)

class TaskStruct
  def initialize(href, # 请求链接
                 local_path, # 保存数据的本地路径（此路径作为去重标准）
                 # http方法，取值：:get, :head, :delete, :put, :post, :patch, :options
                 http_method: :get,
                 custom_data: nil, # 自定义数据
                 parse_method: nil, # 解析保存文件的回调，参数是TaskStruct对象本身
                 # 请求成功后的回调，此时可能没有保存文件，比如301，404
                 # 参数是TaskStruct对象本身和对应的EventMachine::HttpRequest对象
                 # http.response_header.status 状态码
                 # http.response_header  返回头
                 # http.response 返回体
                 callback: nil,
                 # 请求失败后的回调
                 # 参数是TaskStruct对象本身和对应的EventMachine::HttpRequest对象
                 errback: nil,
                 stream_callback: nil, # 流数据处理回调
                 convert_to_utf8: false, # 是否转换为utf8编码
                 overwrite_exist: false, # 是否覆盖现有文件
                 # request options
                 redirects: 3, # 重定向次数
                 keepalive: nil, # （暂不支持复用）
                 file: nil, # 要上传的文件路径
                 path: nil, # 请求路径，在流水线方式请求时有用（暂不支持）
                 query: nil, # 查询字符串，可以是string或hash类型
                 body: nil, # 请求体，可以是string或hash类型
                 head: nil, # 请求头
                 # connection options
                 connect_timeout: 60, # 连接超时时间
                 inactivity_timeout: nil, # 连接后超时时间
                 # ssl设置
                 # ssl: {
                 #     :private_key_file => '/tmp/server.key',
                 #     :cert_chain_file => '/tmp/server.crt',
                 #     :verify_peer => false
                 # }
                 ssl: nil,
                 # bind: {
                 #     :host => '123.123.123.123',   # use a specific interface for outbound request
                 #     :port => '123'
                 # }
                 bind: nil,
                 # 代理设置
                 # proxy: {
                 #     :host => '127.0.0.1',    # proxy address
                 #     :port => 9000,           # proxy port
                 #     :type => :socks5         # default proxy mode is HTTP proxy, change to :socks5 if required

                 #     :authorization => ['user', 'pass']  # proxy authorization header
                 # }
                 proxy: nil)
    @href = href
    @local_path = local_path
    @http_method = http_method
    @custom_data = custom_data
    @parse_method = parse_method
    @callback = callback
    @errback = errback
    @stream_callback = stream_callback
    @convert_to_utf8 = convert_to_utf8
    @overwrite_exist = overwrite_exist

    @request_options = {
      redirects: redirects,
      keepalive: keepalive,
      file: file,
      path: path,
      query: query,
      body: body,
      head: head
    }.compact

    @connection_options = {
      connect_timeout: connect_timeout,
      inactivity_timeout: inactivity_timeout,
      ssl: ssl,
      bind: bind,
      proxy: proxy
    }.compact
  end

  attr_accessor :href, :local_path,
                :http_method,
                :custom_data,
                :request_object,
                :parse_method,
                :callback,
                :errback,
                :stream_callback,
                :convert_to_utf8,
                :overwrite_exist,
                :request_options,
                :connection_options
end

module ListSpider
  RANDOM_TIME = -1
  NO_LIMIT_CONCURRENT = -1
  DEFAULT_CONCURRNET_MAX = 50
  DEFAULT_INTERVAL = 0

  @random_time_range = 3..10
  @local_path_set = Set.new

  class << self
    def event_machine_down(link_struct_list, callback = nil)
      failed_list = []
      succeed_list = []
      multi = EventMachine::MultiRequest.new
      begin_time = Time.now

      for_each_proc =
        proc do |task_struct|
          http_req = EventMachine::HttpRequest.new(task_struct.href, task_struct.connection_options).public_send(task_struct.http_method, task_struct.request_options)
          http_req.stream { |chunk| stream_callback.call(chunk) } if task_struct.stream_callback
          task_struct.request_object = http_req

          http_req.callback do
            s = http_req.response_header.status
            puts s

            if s == 200
              local_dir = File.dirname(task_struct.local_path)
              FileUtils.mkdir_p(local_dir) unless Dir.exist?(local_dir)
              begin
                File.open(task_struct.local_path, 'wb') do |f|
                  f << if @convert_to_utf8 == true
                         SpiderHelper.to_utf8(http_req.response)
                       else
                         http_req.response
                       end
                end
                call_parse_method(task_struct)
                succeed_list << task_struct
              rescue StandardError => exception
                puts exception
              end
            end
            task_struct.callback.call(task_struct, http_req) if task_struct.callback
          end

          http_req.errback do
            puts "errback:#{http_req.response_header},retry..."
            puts task_struct.href
            puts http_req.response_header.status

            if task_struct.errback
              task_struct.errback.call(task_struct, http_req)
            # else
            #   ret = false
            #   if task_struct.http_method == :get
            #     ret = SpiderHelper.direct_http_get(task_struct.href, task_struct.local_path, convert_to_utf8: @convert_to_utf8)
            #   elsif task_struct.http_method == :post
            #     ret = SpiderHelper.direct_http_post(task_struct.href, task_struct.local_path, task_struct.params, convert_to_utf8: @convert_to_utf8)
            #   end

            #   if ret
            #     call_parse_method(task_struct)
            #     succeed_list << task_struct
            #   else
            #     failed_list << task_struct
            #   end
            end
          end

          begin
            multi.add task_struct.local_path, http_req
          rescue StandardError => exception
            puts exception
            puts task_struct.href
            puts task_struct.local_path
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

    def call_parse_method(task_struct)
      task_struct.parse_method.call(task_struct) if task_struct.parse_method
    end

    def complete(_multi, success_list, failed_list)
      @succeed_size += success_list.size
      @failed_size += failed_list.size
      @succeed_list.concat(success_list)
      @failed_list.concat(failed_list)

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
        @succeed_list = []
        @failed_list = []
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
        if !ts.overwrite_exist && File.exist?(ts.local_path)
          call_parse_method(ts)
        elsif @local_path_set.add?(ts.local_path)
          need_down_list << ts
        end
      end
      need_down_list
    end

    def get_list(down_list, interval: DEFAULT_INTERVAL, max: DEFAULT_CONCURRNET_MAX)
      if interval.is_a? Range
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
      if task.is_a? Array
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
