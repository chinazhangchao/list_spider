require File.expand_path('../spider', __FILE__)

class GetItem
  
  RANDOM_TIME = -1

  def initialize(down_list, inter_val: 0, max: 10, parse_method: nil)
    @down_list = down_list
    @inter_val = inter_val
    @max = max
    @max = @down_list.size if @max == -1
    @parse_method = parse_method
    # Spider.conver_to_utf8
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
    
    def parse_item(file_name, e)
    end
    
  end

  def complete (multi, success_list, failed_list)
    puts "success size:#{success_list.size}"
    success_list.each do |e|
      itm = e.extra_data
      # puts itm.class
      if @parse_method.nil?
        GetItem.parse_item(e.local_path, itm)
      else
        @parse_method.call(e.local_path, itm)
      end
    end
    puts "failed size:#{failed_list.size}"
    todo = @down_list.slice!(0, @max)
    if todo.empty?
      EventMachine.stop
      puts "succeed size:#{GetItem.succeed_size}"
    else
      if @inter_val != 0
        if success_list.size != 0 || failed_list.size !=0
          if @inter_val == RANDOM_TIME
            sleep(rand(5..10))
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
