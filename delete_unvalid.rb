
class DeleteUnvalid
# 4033
# 920
  def initialize(dir_pattern, size_threshold: 1000, cust_judge: nil)
    @dir_pattern = dir_pattern
    @size_threshold = size_threshold
    if cust_judge
      @cust_judge = cust_judge
    else
      @cust_judge = method(:default_judge)
    end
    @total = 0
  end
  
  def default_judge(f)
    File.size(f) <= @size_threshold
  end

  def delete_unvaild(f)
    if @cust_judge.call(f)
      @total += 1
      puts f
      File.delete(f)
    end
  end

  def start
    Dir.glob(@dir_pattern) do |f|
      # puts f
      delete_unvaild(f)
    end
    puts "total:#{@total}"
  end
end
