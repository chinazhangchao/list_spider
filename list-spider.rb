require File.expand_path('../spider_base', __FILE__)

class ListSpider
  
  RANDOM_TIME = -1
  NO_LIMIT_CONCURRENT = -1

  include SpiderBase

  def initialize(down_list, inter_val: 0, max: 30)
    @down_list = down_list
    @inter_val = inter_val
    @max = max
    @max = @down_list.size if @max == NO_LIMIT_CONCURRENT
  end

  @@succeed = 0
  @@failed = 0

  class << self

    def succeed_size
      @@succeed
    end

    def failed_size
      @@failed
    end

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
    puts "success size:#{success_list.size}"
    success_list.each do |e|
      e.parse_method.call(e.local_path, e.extra_data, self) if e.parse_method
    end
    puts "failed size:#{failed_list.size}"
    todo = @down_list.slice!(0, @max)
    if todo.empty?
      EventMachine.stop
      puts "succeed size:#{ListSpider.succeed_size}"
    else
      if @inter_val != 0
        if success_list.size != 0 || failed_list.size !=0
          if @inter_val == RANDOM_TIME
            sleep(rand(3..10))
          else
            sleep(@inter_val)
          end
        end
      end
      batch_down_list(todo, method(:complete))
    end
  end

  def start
    event_machine_start_list(@down_list.slice!(0, @max), method(:complete))
  end

end
