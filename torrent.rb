require_relative "./ruby-bencode/lib/bencode.rb"

class Torrent
	#create/bencode a new Torrent file
	attr_accessor :bitfield, :decoded_data, :info_hash, :peers, :pieces
	
	def initialize(filepath)
		@torrent_file = File.read(filepath)
		@decoded_data = BEncode.load(torrent_file)
		@info_hash = Digest::SHA1.digest(@decoded_data["info"].bencode)
		#Hash of peer ids to peers
		@peers = { }
		#TODO: sort pieces by
		@pieces = []
		@piece_directory = Dir.mkdir (Dir.pwd << filepath.gsub("/", ""))
		@files = { }
		#Set up files for the torrents to write to.
		#single file
		#array of all the pieces - frequency starts at 0
		@torrent.pieces = [Piece.new] * torrent.bitfield.length
		

		#Open files for each file in the torrent.
		if @decoded_data["info"].has_key "name"
			@files[@decoded_data["info"]["name"]] = File.new(@decoded_data["info"]["name"], "rb")
		else
			@decoded_data["info"]["files"].each do |file|
				name = "./".concat(file["path"].join("/"))
				@files[name] = new File(name, "rb")
			end
		end
	end

	def add_block_to_piece piece_num, block_num, data
		piece = @pieces[piece_num]
		piece.add_block block_num, data
		if piece.is_complete?
			write_to_file piece
			#not sure this is the right way to set it as one.
			@bitfield[piece_num] = "0x01"
		end
	end

	def write_to_file piece
		if piece.data
			f = File.new("#{@directory.path}/piece#{piece.number}", "rb")
			f.write piece.data
			#problematic and slow, but this will do until we think of a better way to do it.
			@files.each do |file|
				file.check_completion
			end
		end
	end
end
