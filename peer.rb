class Peer
  attr_accessor :address, :port, :interested, :interesting, :choked, :choking
  def initialize(address, port)
    @address = address
    @port = port
    @interested = false
    @interesting = false
    @choking = true
    @choked = true
  end
end
