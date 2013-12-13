require "socket"

class Peer
  attr_accessor :address, :port, :interested, :interesting, :choked, :choking, :socket, :bitfield, :peer_id
  def initialize(address, port, id)
    @address = address
    @port = port
    @peer_id = id

    @socket = socket
    #TODO: update bitfield
    @bitfield = 0

    #   @to_send = Queue.new #this holds the blocks and mesages that will be sent - how do you want to handle the block abstraction? new class, I'm guessing. i'll write the message handling stuff now, but i don't want to write a new block abstraction before we talk about it.
    
    @choked = true
    @interested = false

    @peer_interested = false
    @peer_choked = true

    # This naming is a little confusing - can we separate this like I did above choked/peer_choked, etc.?
    # @interested = false
    # @interesting = false
    # @choking = true
    # @choked = true


  end
	
	def to_s
		"Address: #{@address}:#{@port}, ID:#{@peer_id}"
	end
end


def handle_message msg

    case Message::ID_LIST[msg.id]
    when :choke
        puts "choke"
        @peer_choked = 1

    when :unchoke
        puts "unchoke"
        @peer_choked = 0

    when :interested
        puts "interested"
        @peer_interested = 1

    when :not_interested
        puts "uninterested"
        @peer_interested = 0

    when :have
        puts "have piece at index: #{msg.params[:index]}" 
        #update the piece frequency  here
    
    when :bitfield
        bitfield = msg.params[:bitfield]
        puts "bitfield (#{bitfield.length}):\n#{bitfield.to_x}"

    when :request
       puts "Requesting piece at index #{msg.params[:index]}."

    when :piece  
        puts "Data block at index #{msg.params[:index]}."
    
    when :cancel
        puts "Cancelling piece at index #{msg.params[:index]}." 
    
    else
        puts "Error - message does not exist."
    end 
end

#this will be called from the thread that handles a request for a piece - it deletes it from the list of blocks that we want
def get_data_from_peer
    data = convert_recvd_data

    case Data
    when Message
        handle_message data
    #when it's a block -- handle the block 
    else
        puts "Error. Data of unknown type."
    end
end

def convert_recvd_data

    #check for keep alive message
    length = -1

    #convert data received from 32-bit big endian format
    while(0 == (length = receive_data(4).from_be))
        puts "Received keep alive message." 
    end

    #get the message ID
    id = receive_data(1).from_byte

    #if the id is piece, we want to get the next block 
    if :piece == Message::ID_LIST[id] 
        #create a new block...rm - we'll figure out how to store the block
    else
    #else it's a normal message
        msg = Message.from_peer(id, receive_data(length))
    end

end

#for sending blocks from pieces and messages
def send_data_from_q
    data = @to_send.deq

    case data
    #when Block
        #send block data straight-forwardly send_data data.to_peer
    when Message #sending the message that accompanies block
        msg = Message.new(:piece, {:index => data.begin, :begin => data.begin}, :block => data).to_peer
        send_data data.to_peer
    else
        puts "Error. Data is invalid."
    end

end

def send_data data
    if data
        @socket.send(data, 0)
    end
end

def recv_data length

    data_so_far = ""

    while data_so_far < length
        data_from_wire = @socket.recv(length-data_so_far.length)
        data_so_far += data_from_wire
    end

    data_so_far
end
