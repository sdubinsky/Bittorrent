require './message'

class Threading
	#this method contains the main loop for the connection to the peer
	#note that ruby is pass-by-reference, so all threads will have access to the same torrent.  
	#Need to figure out how to write to the files

	def self.talk_with_peer peer, torrent
		msg = Message.new(:bitfield, {length: torrent.bitfield.length, bitfield: torrent.bitfield}).to_peer
		peer.socket.puts msg
		while true
			
			readers, writers, = select([peer.socket], [peer.socket], nil, 5)
			readers.each do |reader|
				msg = Message.get_message reader
				if msg == nil
					break
				end
				if msg == :error
					puts "got error message from peer #{peer}"
					Thread.exit
				end
				err = peer.handle_message msg, torrent
				if err
					puts "got error message when making message for  #{peer}"
					Thread.exit
				end
			end

			writers.each do |writer|
				msg = peer.make_message
				writer.send msg
			end
		end
	end
end
