require 'socket'
require './message'

class Threading
	#this method contains the main loop for the connection to the peer
	#note that ruby is pass-by-reference, so all threads will have access to the same torrent.  
	#Need to figure out how to write to the files

	def self.talk_with_peer peer, torrent
		begin
			msg = Message.new(:bitfield, {length: torrent.bitfield.size, bitfield: torrent.bitfield}).to_peer
			last_sent = Time.now.to_i
			last_received = Time.now.to_i
			block = nil
			#Listen for bitfield message
			readers, = select([peer.socket], nil, nil, 5)
			if readers
				readers.each do |reader|
					msg = Message.get_message reader
					if msg.id != :keepalive
						peer.handle_message msg, torrent
					end
					last_received = Time.now.to_i
				end
			end
			
			while true
				puts "starting loop"
				msg = nil
				puts ""
				if not peer.interesting and
						torrent.want_piece(peer.bitfield.pieces)
					msg = Message.new(:interested).to_peer
					puts "sending interested message"
					peer.socket.send msg, 0
					peer.interesting = true
					msg = nil
					# request a piece from them
				elsif peer.interesting and
						not peer.choking
					puts "getting a block"
					#get a new block
					if not block or block.data
						puts "new block"
						piece = torrent.get_next_piece peer.bitfield.pieces
						block = piece.next_block
						puts "got block: #{block.to_s}"
					end
					if block and not block.requested?
						if peer.choking
							block = nil
						else
							puts "\trequesting #{block.to_s}"
							msg = Message.new(:request, {index: piece.number, offset: block.beginning, length: block.length }).to_peer
							peer.socket.send msg, 0
							block.is_requested = true
							last_sent = Time.now.to_i
							msg = nil
						end
					end
					
				elsif Time.now.to_i - last_sent > 100
					puts "sending keepalive"
					msg = Message.new(:keepalive).to_peer
					peer.socket.send msg, 0
					msg = nil
				end

				if Time.now.to_i - last_received > 120
					puts "#{peer.to_s} timed out"
					Thread.exit()
				end
				readers, = select([peer.socket], nil, nil, 5)
				if readers
					readers.each do |reader|
						msg = Message.get_message reader
						if msg.id != :keepalive
							peer.handle_message msg, torrent
						end
						last_received = Time.now.to_i
					end
				end
				sleep(0.2)
			end
		rescue Exception => e
			puts e.message
			puts e.backtrace
			Thread.exit
		end
	end	
end
