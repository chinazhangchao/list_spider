
class FileFilter
  # 4033
  # 920
  def initialize(dir_pattern, size_threshold: 1000, cust_judge: nil, process_block: nil)
    @dir_pattern = dir_pattern
    @size_threshold = size_threshold
    @cust_judge = cust_judge ? cust_judge : method(:default_judge)
    @total = 0
    @process_block = process_block
  end

  def default_judge(f)
    File.size(f) <= @size_threshold
  end

  def filter_file(f)
    if @cust_judge.call(f)
      @total += 1
      @process_block.call(f)
    end
  end

  def start
    Dir.glob(@dir_pattern) do |f|
      filter_file(f)
    end
    puts "total:#{@total}"
  end

  def self.delete(dir_pattern, size_threshold: 1000, cust_judge: nil)
    FileFilter.new(
      dir_pattern,
      size_threshold: size_threshold,
      cust_judge: cust_judge,
      process_block:
      proc do |f|
        puts "deleted file: #{f}"
        File.delete(f)
      end
    ).start
  end

  def self.check(dir_pattern, size_threshold: 1000, cust_judge: nil)
    FileFilter.new(
      dir_pattern,
      size_threshold: size_threshold,
      cust_judge: cust_judge,
      process_block:
      proc do |f|
        puts "filterd file: #{f}"
      end
    ).start
  end

  def self.check_save_result(dir_pattern, save_file_name: 'filtered_file.txt', size_threshold: 1000, cust_judge: nil)
    result_file = File.open(save_file_name, 'wt')
    FileFilter.new(
      dir_pattern,
      size_threshold: size_threshold,
      cust_judge: cust_judge,
      process_block:
      proc do |f|
        puts "filterd file: #{f}"
        result_file << f << "\n"
      end
    ).start
    result_file.close
  end
end
