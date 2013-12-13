#! /usr/bin/ruby 
require_relative "./ruby-bencode/lib/bencode.rb"
require "./torrent.rb"
require "open-uri"
require "net/http"
require "digest"
require "./tracker.rb"
require "./peer.rb"
require "./piece.rb"
require "./message.rb"
require "socket"
require "timeout"
require 'io/console'
require "./piece.rb"


$version = "HT0002"
$my_id = "-DS00011234567890123"

# update the data file
def update data_file, torrent
    data_file[torrent.info_hash] = torrent.bitfield
end

def usage
  puts "Usage: \"ruby %s <torrent-file> <data-file\"" % [$PROGRAM_NAME]
    puts "\tby default, config is assumed to be in ./.config"
end

if __FILE__ == $PROGRAM_NAME

  case ARGV.length
  when 0
    usage
    exit
  when 1
    torrent_file = ARGV[0]
  when 2
    torrent_file = ARGV[0]
  end

  torrent = Torrent.new(torrent_file)

  # initialize a Tracker object
  options = {:timeout => 5, :peer_id => $my_id}
  connection = Tracker.new torrent.decoded_data, options
	
  #array of available trackers
  trackers = connection.trackers

  #connect to first tracker in the list
  success = connection.connect_to_tracker 0
  connected_tracker = connection.successful_trackers[0]
  puts "connected to tracker"
  # make a request to a successfully connected tracker
  if not success
    puts "could not connect to a tracker"
    exit
  else
    #TODO: Compact = 0 won't work for all trackers, so it'd be easier not to bother with it.  Something to worry about later
    response = 
      connection.make_tracker_request( 
                                      :uploaded => 0, 
                                      :downloaded => 0,	
                                      :left => 0, 
                                      :compact => 0, 
                                      :no_peer_id => 0, 
                                      :event => 'started', 
                                      :index => 0)
    
    #close the connection to be polite
    connection.make_tracker_request(
                                    :uploaded => 0, 
                                    :downloaded => 0,
                                    :left => 0, 
                                    :compact => 0,  
                                    :no_peer_id => 0, 
                                    :event => 'stopped', 
                                    :index => 0)
    puts "making peers"
    #TODO: move handshake into this peer creation loop
    puts "#{response}"
    peers = []
    #string means compact response
    if response["peers"].is_a? String
      puts "compact response"
      list = response["peers"].unpack("C*")
      i = 0
      list.each_slice 6 do |slice|
        peer = {}
        peer["ip"] = "#{slice[0]}.#{slice[1]}.#{slice[2]}.#{slice[3]}"
        x = 0
        x |= slice[4]
        x <<= 8
        x |= slice[5]
        peer["port"] = x
        #no id given, so assign our own
        peer["peer id"] = i
        i+=1
        peers << peer
      end
    else
      peers = response["peers"]
    end
    peers.each do |peer|
      puts "#{peer['ip']}:#{peer["port"]}"
      p = Peer.new(peer["ip"], peer["port"], peer["peer id"])
      begin
        @timeout = 10
        Timeout::timeout(@timeout){
          s = TCPSocket.new(peer["ip"], peer["port"])
          p.socket = s
          torrent.peers[s] =  p
          puts "made peer #{p}"
        }
      rescue
        puts "socket connection failed"
        next
      end
    end
    puts "peers made"
    #Current plan: Hash where the keys are the sockets and the values are the corresponding peers.  Select on torrent.peers.keys
    
    zeroes = [0, 0, 0, 0, 0, 0, 0, 0].pack("C*")
    handshake = "19Bittorrent protocol#{zeroes}#{torrent.info_hash}#{$my_id}"
    puts handshake
    torrent.peers.values.each do |peer|
      #send handshake
      peer.socket.puts handshake
      #unpack the response string into: 
      #[19, "Bittorrent protocol", eight zeroes(single bytes), 20-byte info hash, 20-byte peer id]
      peer_shake = peer.socket.gets.unpack("l2a19C8C20C20")
      #wrong peer id for some reason
      if peer_shake.last != peer.peer_id
        peer.socket.close
        torrent.peers.delete peer.socket
      end
      puts peer_shake
    end
    puts "after handshake"
    readers,writers, = select(torrent.peers.keys, torrent.peers.keys, nil, 5)
    
    readers.each do |reader|
      #TODO: get have messages/bitfield message
    end
    
    writers.each do |writer|
      #TODO: send our have/bitfield message - we have nothing
    end
    
    #TODO: Threading.  One per peer.
    "Threads need to: Send interested message.  Process unchoke message.  Send request messages.  Send keepalives.  Respond to requests for pieces.  Add those pieces to the data file."
    "What does each thread need?  access to the torrent, so it can see what pieces are needed next.  Locks on the bitfield parameter."
  end
end
