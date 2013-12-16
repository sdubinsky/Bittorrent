class Piece
  attr_accessor :frequency, :hash, :number, :size, :block_count, :blocks, :complete, :filename
  def initialize hash, number, size, directory
    #according to the unofficial spec
    @block_size = 2**14
    #20-byte SHA hash
    @hash = hash
    @frequency = 0
    #The number the piece is in the set.
    @number = number
    @lock = Mutex.new
    #size because it makes it easier to split into blocks and not all pieces are the same size
    @size = size
    #blocks needed
    @block_count = (size.to_f / @block_size).ceil 
    @complete = false
    @filename = "#{directory}/piece#{@number}.pc"
    @blocks = []
  end
  
  #writes all the blocks to file
  def write_to_file
    FileUtils.mkdir_p(File.dirname @filename)
    file = File.open(@filename, "wb")
    @blocks.each do |block|
      file.write block
    end
    file.close
    #clear the blocks to save RAM
    @blocks = []
  end

  def get_block block_num
    if @complete
      file = File.open @filename, "rb"
      file.seek block_num*@block_size
      block = file.read @filename, @block_size
      file.close
      return block
    end
    blocks[block_num]
  end
  
  def add_block block_num, data
    @blocks[block_num] = data
    if @blocks.compact.size == @block_count
      @complete = true
    end
  end

	#next block needed
	#TODO: Use least-requested algorithm here
	def next_block
		0.upto @block_count do |i|
			if @blocks[i] == nil
				return i
			end
		end
	end
end
