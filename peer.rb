class Peer
  attr_accessor :address, :port, :interested, :interesting, :choked, :choking
  def initialize(address, port, id)
    @address = address
    @port = port
    @peer_id = id
    @interested = false
    @interesting = false
    @choking = true
    @choked = true
		@socket = TCPSocket.new address, port
  end
	
	def to_s
		"Address: #{@address}:#{@port}, ID:#{@peer_id}"
	end
end
