require "socket"

class Peer
  attr_accessor :address, :port, :interested, :interesting, :choked, :choking, :socket, :bitfield
  def initialize(address, port, id, socket)
    @address = address
    @port = port
    @peer_id = id
    @interested = false
    @interesting = false
    @choking = true
    @choked = true
		@socket = socket
		@bitfield = 0
  end
	
	def to_s
		"Address: #{@address}:#{@port}, ID:#{@peer_id}"
	end
end
