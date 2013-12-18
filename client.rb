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
require "./threading"

$version = "HT0002"
$my_id = "-SD00012234567890123"

def usage
  puts "Usage: \"ruby client.rb <torrent-file> "
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
  # make a request to a successfully connected tracker
  if not success
    puts "could not connect to a tracker"
    exit
  else
    
    zeroes = [0, 0, 0, 0, 0, 0, 0, 0].pack("C*")
    handshake = "#{19.chr}" << "BitTorrent protocol#{zeroes}#{torrent.info_hash}#{$my_id}"
		begin
    response = 
      connection.make_tracker_request( 
                                      :uploaded => 0, 
                                      :downloaded => 0,	
                                      :left => 0, 
                                      :compact => 0, 
                                      :no_peer_id => 0, 
                                      :event => 'started', 
                                      :index => 0)
    
		rescue
			puts "tracker timed out."
		end
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
          p.socket.send handshake, 0
					
          peer_shake = p.socket.read(68)
          #wrong peer id for some reason
          if peer_shake == nil
            p.socket.close
            torrent.peers.delete p.socket
          else
            torrent.peers[s] =  p
          end
        }
      rescue Exception => e
        puts e.message
        next
      end
			# if torrent.peers.length > 0
			# 	break
			# end
    end
    #Current plan: Hash where the keys are the sockets and the values are the corresponding peers.  Select on torrent.peers.keys
  
		threads = []
		puts "Got #{torrent.peers.length} peers"
		torrent.peers.values.each do |peer|
			threads << Thread.new{Threading.talk_with_peer peer, torrent}
		end
		threads.each do |thread|
			thread.join
		end
		torrent.files.values.each do |file|
			if not file.is_complete?
				puts "Error: didn't get the whole file."
				#close the connection to be polite
				connection.make_tracker_request(
																				:uploaded => torrent.uploaded_count, 
																				:downloaded => torrent.downloaded_count,
																				:left => 0, 
																				:no_peer_id => 0, 
																				:event => 'stopped', 
																				:index => 0)

			end
		end
		puts "file finished."
		connection.make_tracker_request(
																		:uploaded => torrent.uploaded_count, 
																		:downloaded => torrent.downloaded_count,
																		:left => 0, 
																		:no_peer_id => 0, 
																		:event => 'complete', 
																		:index => 0)
  end
end
