class Bitfield
	attr_reader :size, :bitfield
  def initialize size
		@size = size
    @bitfield = [0]*size
  end

  def [] point
		if point >= size
			return nil
		end
    remainder = point % 8
    spot = point / 8
    byte = @bitfield[spot]
    return byte[7 - remainder]
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

	def copy bitstring
		@bitfield = bitstring.unpack("C*")
	end
	
	def pieces
		arr = []
		0.upto @size do |i|
			if self.[](i) == 1
				arr << i
			end
		end
		arr
	end
end
