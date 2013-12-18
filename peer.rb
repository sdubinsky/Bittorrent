require "socket"
require './piece'
require './bitfield'

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
		print ""
		case msg.id
		when :choke
			puts "Peer #{@address} is choking"
			@choking = true

		when :unchoke
			puts "Peer #{@address} is no longer choking"
			@choking = false

		when :interested
			puts "Peer #{@address} is interested"
			@interested = true

		when :not_interested
			puts "Peer #{@address} is uninterested"
			@interested = false

		when :have
			puts "Peer #{@address} has piece at index: #{msg.params[:index]}" 
			@bitfield[msg.params[:index]] = 1
			#update the piece frequency  here
			
		when :bitfield
			puts "copying bitfield"
			bitfield = msg.params[:bitfield]
			@bitfield.copy bitfield

		when :request
			puts "Peer #{@address} is requesting piece at index #{msg.params[:index]}."
			@requests << msg
			
		when :piece  
			puts "Peer #{@address} is sending data block for piece #{msg.params[:index]}."
			torrent.add_block_to_piece msg.params[:index], msg.params[:begin], msg.params[:block]
			puts "set block"
		when :cancel
			puts "Cancelling piece at index #{msg.params[:index]}." 
			#TODO
		else
			puts "Error - message does not exist."
		end 
	end
end
