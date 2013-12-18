require 'socket'

class Integer
	def to_be #int --> [int] --> "packedint"
		[self].pack('N')
	end
end

class String
	def from_be #"packedint" --> [int] --> [int][0] = int
		arr = self.unpack('N')
		arr[0] #32-bit unsigned, network (big-endian) byte order
	end
	
	def to_x
		self.unpack('H*')[0] #hex string (high nibble first)
	end

	def from_byte
		self.unpack("C*")[0] #8-bit unsigned (unsigned char)
	end
end

class Message

	ID_LIST = [:choke, :unchoke, :interested, :not_interested, :have, :bitfield, :request, :piece, :cancel]
	#do we want the port? I guess if we implement DHT...
	#id is a symbol, not an int
	attr_accessor :id, :params

	def initialize(id, params=nil)
		@id = id
		@params = params
	end

	#preparing a message to give to a peer
	#see this link for explanation of the length prefixes for each message (0,1,5,13, etc)
	def to_peer
		case @id
		when :keepalive
			0.to_be
		#these have no payloads, so just take the id and convert to correct char
		when :choke, :unchoke, :interested, :not_interested 
			1.to_be + ID_LIST.index(@id).chr
		#payload is index of a piece that has been successfully downloaded/verified by hash
		when :have
			5.to_be + ID_LIST.index(@id).chr + @params[:index].to_be
			#varies in length, payload is the bitfield itself
		when :bitfield
			(@params[:length]).to_be +
				ID_LIST.index(@id).chr +
				@params[:bitfield].bitstring
		when :request, :cancel #payloads for these two are identical
			13.to_be +
				ID_LIST.index(@id).chr +
				@params[:index].to_be +
				@params[:offset].to_be +
				@params[:length].to_be
		when :piece
			(9 + @params[:block].length).to_be +
				ID_LIST.index(@id).chr +
				@params[:index].to_be +
				@params[:offset].to_be +
				@params[:block]
		end
	end

	#making a message received from a peer
	def self.from_peer id, info
		start = 0
		inc = 4
		msg = ID_LIST[id]

		case msg
		when :choke, :unchoke, :interested, :not_interested
			Message.new(msg)

		when :have
			Message.new(msg, {:index => info[start, inc].from_be})

		when :bitfield
			Message.new(msg, {:bitfield => info}) 
			
		when :request, :cancel
			Message.new(msg, {:index => info[start, inc].from_be,
										:begin => info[start + inc, inc].from_be,
										:length => info[start + (2 * inc), inc].from_be})
		when :piece
			Message.new(msg, {:index => info[start, inc].from_be,
										:begin => info[start + inc, inc].from_be,
										block: info[(start + inc + inc..-1)]})
		else
			return Message.new(msg)
		end
	end
	
	def self.get_message socket
		msg_length = socket.recv(4)
		if not msg_length
			return Message.new(:keepalive)
		end
		msg_length = msg_length.from_be
		
		if msg_length == 0 or not msg_length
			return Message.new(:keepalive)
		end
		msg_id = socket.recv(1)
		msg_id = msg_id.from_byte
		msg_length -= 1
		msg = socket.read (msg_length) unless msg_length.to_i <= 0
		msg = from_peer msg_id, msg
		msg
	end

	def to_s
		@id.to_s << @params.to_s
	end
end
