require File.expand_path('../spider_base', __FILE__)
require File.expand_path('../delete_unvalid', __FILE__)

class ListSpider
  
  RANDOM_TIME = -1
  NO_LIMIT_CONCURRENT = -1

  @@random_time_range = 3..10

  include SpiderBase

  def initialize(down_list, inter_val: 0, max: 30)
    @down_list = down_list
    @inter_val = inter_val
    @max = max
    @max = @down_list.size if @max == NO_LIMIT_CONCURRENT
    @succeed_size = 0
    @failed_size = 0
  end

  attr_reader :succeed_size, :failed_size

  class << self

    attr_accessor :random_time_range

  end

  def add_task(task)
    if task.is_a?Array
      @down_list = @down_list + task
    elsif task.is_a?TaskStruct
      @down_list << task
    else
      puts "error task type:#{task.class}"
    end
  end

  def complete(multi, success_list, failed_list)
    @succeed_size += success_list.size
    @failed_size += failed_list.size
    # puts "success size:#{success_list.size}"
    # puts "failed size:#{failed_list.size}"
    success_list.each do |e|
      e.parse_method.call(e.local_path, e.extra_data, self) if e.parse_method
    end
    
    todo = @down_list.slice!(0, @max)
    if todo.empty?
      puts "success size:#{@succeed_size}"
      puts "failed size:#{@failed_size}"
      EventMachine.stop
    else
      if @inter_val != 0
        if success_list.size != 0 || failed_list.size !=0
          if @inter_val == RANDOM_TIME
            sleep(rand(@@random_time_range))
          else
            sleep(@inter_val)
          end
        end
      end
      batch_down_list(todo, method(:complete))
    end
  end

  def start
    puts "total size:#{@down_list.size}"
    event_machine_start_list(@down_list.slice!(0, @max), method(:complete))
  end

  def self.get_list(down_list, inter_val: 0, max: 30)
    ListSpider.new(down_list, inter_val: inter_val, max: max).start
  end

  def self.get_one(task)
    ListSpider.new([task]).start
  end

end
