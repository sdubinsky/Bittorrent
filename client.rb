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
require "./threading"

$version = "HT0002"
$my_id = "-SD00011234567890123"

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
    zeroes = [0, 0, 0, 0, 0, 0, 0, 0].pack("C*")
    handshake = "#{(19).chr}Bittorrent protocol#{zeroes}#{torrent.info_hash}#{$my_id}"

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
    #TODO: move handshake into this peer creation loop
    peers = []
    #string means compact response
    if response["peers"].is_a? String
      list = response["peers"].unpack("C*")
      list.each_slice 6 do |slice|
        peer = {}
        peer["ip"] = "#{slice[0]}.#{slice[1]}.#{slice[2]}.#{slice[3]}"
        x = 0
        x |= slice[4]
        x <<= 8
        x |= slice[5]
        peer["port"] = x
        #no id given, so use -1 to match anything
        peer["peer id"] = -1
        peers << peer
      end
    else
      peers = response["peers"]
    end

    peers.each do |peer|
      p = Peer.new(peer["ip"], peer["port"], peer["peer id"], torrent.bitfield.size)
      begin
        @timeout = 10
        Timeout::timeout(@timeout){
          s = TCPSocket.new(peer["ip"], peer["port"])
          p.socket = s
          #send handshake
          p.socket.puts handshake
          #unpack the response string into: 
          #[19, "Bittorrent protocol", eight zeroes(single bytes), 20-byte info hash, 20-byte peer id]
          peer_shake = p.socket.recv(68)
          
          #wrong peer id for some reason
          if (p.peer_id != -1) && peer_shake[28..47] != 
              p.peer_id
            puts "bad handshake"
            peer.socket.close
            torrent.peers.delete p.socket
          else
            puts "got handshake"
            torrent.peers[s] =  p            
          end
        }
      rescue Exception => e
        puts e.message
        next
      end
    end
    #Current plan: Hash where the keys are the sockets and the values are the corresponding peers.  Select on torrent.peers.keys
  
    #TODO: Threading.  One per peer.
		threads = []
		torrent.peers.values.each do |peer|
			threads << Thread.new{Threading.talk_with_peer peer, torrent}
		end
		threads.each do |thread|
			thread.join
		end
    "Threads need to: Send interested message.  Process unchoke message.  Send request messages.  Send keepalives.  Respond to requests for pieces.  Add those pieces to the data file."
    "What does each thread need?  access to the torrent, so it can see what pieces are needed next.  Locks on the bitfield parameter."
  end
end
