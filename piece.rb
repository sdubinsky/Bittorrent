class Piece
	attr_accessor :frequency, :have, :data, :hash, :number
	def initialize hash, number
		#20-byte SHA hash
		@hash = hash
		@frequency = 0
		#The number the piece is in the set.
		@number = number
		@data = nil
		@lock = Mutex.new
	end
	def set_data data
		@lock.synchronize {
			@data = data
		}
	end
end
