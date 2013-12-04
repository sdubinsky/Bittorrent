class Bitmap
	attr_accessor :bit_array
	def initialize piece_count
		#Creates a binary string of piece_count bytes initialized to 0
		@bit_array = Array.new(piece_count, 0).pack("C*")
		puts @bit_array
	end
end


