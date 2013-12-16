require "socket"

class Peer
  attr_accessor :address, :port, :interested, :interesting, :choked, :choking, :socket, :bitfield, :peer_id
  def initialize(address, port, id, bitfield_size)
    @address = address
    @port = port
    @peer_id = id
		@requests = []
    @socket = socket

    @bitfield = Bitfield.new bitfield_size

		@interested = false
		@interesting = false
		@choking = true
		@choked = true
  end
	
	def to_s
		"Address: #{@address}:#{@port}, ID:#{@peer_id}"
	end

	def handle_message msg, torrent
		case Message::ID_LIST[msg.id]
		when :choke
			puts "choke"
			@choking = true

		when :unchoke
			puts "unchoke"
			@choking = false

		when :interested
			puts "interested"
			@is_interested = true

		when :not_interested
			puts "uninterested"
			@is_interested = false

		when :have
			puts "have piece at index: #{msg.params[:index]}" 
			#update the piece frequency  here
			
		when :bitfield
			bitfield = msg.params[:bitfield]
			puts "bitfield (#{bitfield.length}):\n#{bitfield.to_x}"
			if bitfield.length != @bitfield.length
				return true
			end
			@bitfield.copy bitfield
		when :request
			puts "Requesting piece at index #{msg.params[:index]}."
			@requests << msg
			
		when :piece  
			puts "Data block at index #{msg.params[:index]}."
			torrent.add_block_to_piece msg.params[:index], msg.params[:begin], msg.params[:length], msg.params[:block]
		when :cancel
			puts "Cancelling piece at index #{msg.params[:index]}." 
			#TODO
		else
			puts "Error - message does not exist."
		end 
	end
end
