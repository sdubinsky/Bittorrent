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
require 'io/console'


$version = "HT0002"
$my_id = "-DS00011234567890123"
$data_file = ""

def print_peer_list(peers)
  list = peers.unpack("C*")
  list.each_slice(6) do |slice|
    x = 0
    x |= slice[4]
    x <<= 8
    x |= slice[5]
    printf("%d.%d.%d.%d:%d\n", slice[0], slice[1], slice[2], slice[3], x)
  end
end

#writing the data to this file
def make_data_file 

    data_file = Hash.new

    if File.exist?($data_file) #if a data file exists...
        
        encoded =  File.open($data_file, "rb").read.strip
        data_file = BEncode.load(encoded)
        $my_id = data_file['my_id']
    elsif $data_file == "data.dat" #if not, and there's no user supplied string
        puts "Default data file not found."
        data_file['my_id'] =  $my_id
        save $data_file
    else
        abort("Error: file not found.")
    end

    data_file
end

#save the data file and bencode it
def save data_file 
	File.open($data_file, "wb") do |f|
		f.write(data_file.bencode + "\n")
	end
end

#update the data file
def update data_file, torrent
    data_file[torrent.info_hash] = torrent.bitfield
end

#for debugging
def print_metadata(torrent)
    torrent.decoded_data.each { |key, val|
        if key == "info" 
            puts "info =>"
            val.each {   |info_key, info_val|
                if info_key == "pieces"
                    puts "\tSkipping printing pieces."
                elsif info_key == "files"
                    puts "\tFiles:"
                    info_val.each{  |file|
                        fn = file['path']
                        flen = file['length']
                        puts "\t\t#{fn}, #{flen} bytes"
                    }
                elsif info_key == "length"
                    puts "\tLength of single file torrent: #{info_val}"
                elsif
                    puts "\t#{info_key} => #{info_val}"
                end
            }
        else  
            puts "#{key} => #{val}"
        end
    }
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
    $data_file = "data.dat"
  when 2
    torrent_file = ARGV[0]
    $data_file = ARGV[1]
  end


  torrent = Torrent.new(torrent_file)

  puts "Storing data in #{$data_file}.\n"

  #print_metadata(torrent) #debug

  data_file = make_data_file


  #This code sets up a data file that contains the bitfield representing which pieces have been downloaded successfully.
  #The reason I'm using the info hash in the first if statement is to have an identifier for the torrent (the info_hash will serve as a unique key for the torrent).

  if data_file.has_key? torrent.info_hash
		#previously connected torrent
      puts "Torrent found."
      torrent.bitfield = data_file[torrent.info_hash] #This code allows us to recreate the downloaded pieces if there is a data file that matches the info_hash of the torrent that's passed in as an argument.
  else
      puts "Adding torrent to data_file"
      puts "TORRENT INFO PIECES #{torrent.decoded_data["info"]["pieces"].length}\n\n\n"
      bitfield_length = torrent.decoded_data["info"]["pieces"].length / 20
      #this is why we need to divide by 20 - SHA1 hash:
      #http://stackoverflow.com/questions/9506667/calculate-sha1-pieces-when-creating-torrent-file
      
      puts "BITFIELD LENGTH: #{bitfield_length}\n\n\n"
      if bitfield_length % 8 != 0 #bitfield length in bytes
          bitfield_length = bitfield_length / 8
          bitfield_length += 1 
      else
          bitfield_length = bitfield_length / 8
      end
      torrent.bitfield = "\x0" * bitfield_length #initializing the bitfield with 0 bytes
      puts torrent.bitfield.length
      puts "Bitfield: #{torrent.bitfield}" #should currently have nothing - debug
      update data_file, torrent  
      save data_file
  end

	#array of all the pieces - frequency starts at 0
	torrent.pieces = [Piece.new] * torrent.bitfield.length

  # initialize a Tracker object
  options = {:timeout => 5, :peer_id => $my_id}
  connection = Tracker.new(torrent, options)

  #array of available trackers
  trackers = connection.trackers
  #puts "Getting tracker updates from #{trackers}."  #debug tracker info

  #connect to first tracker in the list
  success = connection.connect_to_tracker 0
  connected_tracker = connection.successful_trackers.last

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

		response["peers"].each do |peer|
			p = Peer.new(peer["ip"], peer["port"], peer["peer id"], TCPSocket.new(peer["ip"], peer["port"]))
			s = p.socket
			torrent.peers[s] =  p
		end

		#Current plan: Hash where the keys are the sockets and the values are the corresponding peers.  Select on torrent.peers.keys
		#Alternative plan:  Select will return the list of sockets.  Find each socket's position in the torrent.sockets list.  Its corresponding peer is in the torrent.peers list.

		#TODO: Send handshake
		zeroes = ["0", "0", "0", "0", "0", "0", "0", "0"].pack("C*")
		handshake = "19Bittorrent protocol#{zeroes}#{info_hash}#{peer_id}"
		torrent.peers.values.each do |peer|
			#send handshake
			peer.socket.puts handshake
			#unpack the response string into: 
			#[19, "Bittorrent protocol", eight zeroes(single bytes), 20-byte info hash, 20-byte peer id]
			peer_shake = peer.socket.gets.unpack("l2a19C8C20C20")
			#wrong peer id for some reason
			if peer_shake.last != peer.id
				peer.socket.close
				torrent.peers.delete
			end
		end

		readers,writers, = select(torrent.peers.keys, torrent.peers.keys)

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
