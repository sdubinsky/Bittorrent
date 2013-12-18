require './block'

class Piece
  attr_accessor :frequency, :hash, :number, :size, :block_count, :blocks, :complete, :filename, :block_size
  def initialize hash, number, size, directory
    #according to the unofficial spec
    @block_size = 2**14
    #20-byte SHA hash
    @hash = hash
    @frequency = 0
    #The number the piece is in the set.
    @number = number
    @write_lock = Mutex.new
		@request_lock = Mutex.new
    #size because it makes it easier to split into blocks and not all pieces are the same size
    @size = size
    #blocks needed
    @block_count = (size.to_f / @block_size).ceil 
    @complete = false
    @filename = "#{directory}/piece#{@number}.pc"
		if File.exists? @filename
			puts "piece #{number} already exists!"
			@complete = true
		end
    @blocks = []
		0.upto @block_count do |i|
			@blocks << Block.new(false, i*@block_size, @block_size)
		end
		@blocks[0].start_of_piece = true
		@blocks[-1].length = (@block_size % size) unless
			(@block_size % size == 0)
  end
  
  #writes all the blocks to file
  def write_to_file
    FileUtils.mkdir_p(File.dirname @filename)
		@write_lock.synchronize{
			file = File.new(@filename, "wb")
			puts "writing piece to file: #{file.path}"

			@blocks.each do |block|
				file.write block.data
			end
			file.close
		}			
    #clear the blocks to save RAM
    @blocks = []
  end

  def get_block offset
    if @complete
      file = File.open @filename, "rb"
      file.seek offset
      block = file.read @filename, @block_size
      file.close
      return block
    end
		block_num = offset / block_size
    blocks[block_num]
  end
  
  def add_block offset, data
		block_num = offset / @block_size
		#need this one to make sure multiple threads don't both ask for the same block and double-decrement the counter
		@request_lock.synchronize{
			if not @blocks[block_num].data
				@blocks[block_num].data = data
				@block_count -= 1
				return @blocks[block_num].length
			end
			if @block_count == 0
				@complete = true
			end
		}
  end

	def needed_blocks
		ret = []
		blocks.each do |block|
			ret << block unless block.requested?
		end
		ret
	end
	
	#next block needed
	#TODO: Use least-requested algorithm here
	def next_block
		blocks.each do |block|
			if not block.requested?
				return block
			end
		end
		return nil
	end

	def is_complete?
		return @complete
	end

	def to_s
		"Piece number #{@number} complete? #{@complete}"
	end
end
