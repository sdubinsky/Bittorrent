require_relative "./ruby-bencode/lib/bencode.rb"

class Torrent
	#create/bencode a new Torrent file
	attr_accessor :bitfield, :decoded_data, :info_hash, :peers, :pieces
	
	def initialize(filepath)
		torrent_file = File.read(filepath)
		@decoded_data = BEncode.load(torrent_file)
		@info_hash = Digest::SHA1.digest(@decoded_data["info"].bencode)
		#Hash of peer ids to peers
		@peers = { }
		@pieces = []
	end
end
