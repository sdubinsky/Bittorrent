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
				msg = nil
				if not peer.interesting and
						torrent.want_piece(peer.bitfield.pieces)
					msg = Message.new(:interested).to_peer
					peer.socket.send msg, 0
					peer.interesting = true
					msg = nil
					# request a piece from them
				elsif peer.interesting and
						not peer.choking
					#get a new block
					if not block or block.data
						piece = torrent.get_next_piece peer.bitfield.pieces
						if not piece
							#Got everything
							Thread.exit
						end
						puts "Requesting block for piece #{piece.number}"
						block = piece.next_block
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
				end

				if peer.interested and peer.choked
					msg = Message.new(:unchoke).to_peer
					peer.socket.send msg, 0
					peer.choked = false
				end

				if peer.interested and not peer.choked and not peer.requests.is_empty?
					request = peer.requests.pop
					block = torrent.get_block_from_piece(request.params[:index],request.params[:begin])
					msg = Message.new(:piece, {index: request.params[:index].to_be,
													begin: request.params[:begin].to_be,
													block: block.data})
					torrent.uploaded_count += block.length
				end
				if Time.now.to_i - last_sent > 100
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
			Thread.exit
		end
	end	
end
