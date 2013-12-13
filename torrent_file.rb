#a torrent file
class TorrentFile
	#takes a relative filename
	def initialize filename, first_piece, last_piece, offset
		#filename to write this file to
		@filename = filename
		#number of the first piece
		@first_piece = first_piece
		#number of the last piece
		@last_piece = last_piece
		#the number of bytes this file extends into the last piece
		@offset = offset
	end
	def write_file piece_set, piece_size
		file = File.new @filename, "wb"
		@first_piece.upto @last_piece do |i|
			file.write
		end
	end
	
	def check_completion piece_set, piece_size
		@first_piece.upto @last_piece do |i|
			if not piece_set[i].complete
				return
			end
		end
		write_file piece_set, piece_size
	end
end
