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
		@files = { }
		#Set up files for the torrents to write to.
		#single file
		#array of all the pieces - frequency starts at 0
		torrent.pieces = [Piece.new] * torrent.bitfield.length

		#Open files for each file in the torrent.
		if decoded_data["info"].has_key "name"
			files[decoded_data["info"]["name"]] = File.new(decoded_data["info"]["name"], "rb")
		else
			decoded_data["info"]["files"].each do |file|
				name = "./".concat(file["path"].join("/"))
				files[name] = new File(name, "rb")
			end
		end
	end
end
