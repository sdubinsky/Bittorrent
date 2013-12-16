class Threading
	def self.get_message socket
		msg_length = socket.recv(4)
		puts msg_length.to_s
		msg_id = socket.recv(1).from_byte
		msg = socket.recv msg_length
		puts "Making Message: #{msg_id}:#{msg_length}"
		msg = Message.from_peer msg_id, msg_length
		msg
	end

	#this method contains the main loop for the connection to the peer
	#note that ruby is pass-by-reference, so all threads will have access to the same torrent.  
	#Need to figure out how to write to the files

	def self.talk_with_peer peer, torrent
		while true
			readers, writers, = select([peer.socket], [peer.socket], nil, 5)
			readers.each do |reader|
				msg = get_message reader
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
