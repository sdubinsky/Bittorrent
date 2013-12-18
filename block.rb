class Block
	attr_accessor :beginning, :is_requested, :start_of_piece, :length
	attr_reader :data
	def initialize start_of_piece, beginning, length
		@is_requested = false
		@start_of_piece = start_of_piece
		@beginning = beginning
		@data = nil
		@length = length
	end
	
	def requested?
		@is_requested
	end
	
	def to_s
		"Block beginning at #{@beginning} length #{@length}"
	end

	def data= data
		@data = data
	end
end
