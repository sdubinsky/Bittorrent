class Piece
	attr_accessor :frequency, :have, :hash, :number, :size
	def initialize hash, number, size
		#20-byte SHA hash
		@hash = hash
		@frequency = 0
		#The number the piece is in the set.
		@number = number
		@data = nil
		@lock = Mutex.new
		#size because it makes it easier to split into blocks and not all pieces are the same size
		@size = size
	end

	def set_data data
		@lock.synchronize {
			@data = data
		}
	end

	def data
		@data
	end
end
