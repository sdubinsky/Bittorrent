def get_message socket
	msg_length = peer.recv(4).unpack("I")
	msg_id = peer.recv(1)
	#TODO: receive message here.  Return that message.
end

#this method contains the main loop for the connection to the peer
#note that ruby is pass-by-reference, so all threads will have access to the same torrent.  
#Need to figure out how to write to the files
def talk_with_peer peer_socket, torrent
	peer = torrent.peers[peer_socket]
	#TODO: Timeout for keepalive
	while True
		#if this peer has any pieces we need, send an interested message
		#check this with the bitfield param
		
		piece = nil
		#if we can get a piece from this peer
		torrent.pieces.each do |p|
			#Not sure this is how you have it set up, but for integers you can access the 
			if peer.bitfield[number] > 0 and not p.data
				peer.interesting = true
				piece = p
				#TODO: peer_socket.send("interested request")
				break
			else
				peer.interesting = false
			end
		end
		#hopefully unchoke
		msg = recv_message peer_socket
		if peer.interesting and not peer.choking
			#TODO: send request message for piece
		end
		#hopefully the piece we requested
		msg = recv_message peer_socket
		#lock is in the piece class
		#also need to check piece hash
		#and I'm not sure we need a lock at all - the worst that could happen is it gets overwritten with an identical copy of the data
#		piece.set_data data
		
 	end
end
