class Bitfield
	attr_reader :size
  def initialize size
		@size = size
    @bitfield = [0]*size
  end

  def [] point
    remainder = point % 8
    spot = point / 8
    byte = @bitfield[7 - spot]
    return byte[remainder]
  end

  def []= point, binary
    remainder = point % 8
    spot = point / 8
    byte = @bitfield[7 - spot]
    if binary == 1
      @bitfield[7 - spot] =  byte | (binary << 7 - remainder)
    else#binary = 0
      @bitfield[7 - spot] =  byte & (binary << 7 - remainder)      
    end
  end

  def bitstring
    @bitfield.pack "C*"
  end

	def length
		@size
	end

	def copy bitstring
		0.upto @size do |i|
			@bitfield[i] = bitstring[i] 
		end
	end
	
	def pieces
		arr = []
		0.upto @size do |i|
			if @bitfield[i] = 1
				arr << i
			end
		end
		arr
	end
end
