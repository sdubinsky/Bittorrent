class Integer
    def to_be #int --> [int] --> "packedint"
        [self].pack('N')
    end
end

class String
    def from_be #"packedint" --> [int] --> [int][0] = int
        self.unpack('N')[0] #32-bit unsigned, network (big-endian) byte order
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

    attr_accessor :id

    def initialize(id, params=nil)
        @id = id
        @params = params
    end

    #preparing a message to give to a peer
    #see this link for explanation of the length prefixes for each message (0,1,5,13, etc)
    #http://bit.ly/1d2mVzg (.doc from Baylor that's a good explanation for the protocol in general)
    def to_peer
        case @id
        when :keepalive
            0.to_be
        when :choke, :unchoke, :interested, :not_interested #these have no payloads, so just take the id and convert to correct char
            1.to_be + ID_LIST.index(@id).chr
        when :have #payyload is index of a piece that has been successfully downloaded/verified by hash
            5.to_be + ID_LIST.index(@id).chr + @params[:index].to_be
        when :bitfield #varies in length, payload is the bitfield itself
            (1+@params[:bitfield].length).to_be + ID_LIST.index[@id].chr + @params[:bitfield]
        when :request, :cancel #payloads for these two are identical
            13.to_be + ID_LIST.index[@id].chr + @params[:index].to_be + @params[:begin].to_be + @params[:length].to_be
        when :piece
            (9 + @params[:block].length).to_be + ID_LIST.index[@id].chr + @params[:index].to_be + @params[:begin].to_be + @params[:block]
        end
    end

    #making a message received from a peer
    def self.from_peer id, info

        start = 0
        inc = 4

        msg = ID_LIST.index(id)

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
                            :begin => info[start + inc, inc].from_be})
        else
            return :error
        end
    end
end
