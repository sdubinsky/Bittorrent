#! /usr/bin/ruby 
require_relative "./ruby-bencode/lib/bencode.rb"
require "./torrent.rb"
require "open-uri"
require "net/http"
require "digest"
require "./tracker.rb"
require "./peer.rb"


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
    elsif $data_file == "data.dat" # if not, and there's no user supplied string
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

  #setting up the bitfield that represents which pieces have been downloaded successfully  
  if data_file.has_key? torrent.info_hash
      puts "Torrent found."
      torrent.bitfield = data_file[torrent.info_hash] 
  else
      puts "Adding torrent to data_file"
      puts "TORRENT INFO PIECES #{torrent.decoded_data["info"]["pieces"].length}\n\n\n"
      bitfield_length = torrent.decoded_data["info"]["pieces"].length / 20
      #this is why we need to divide by 20 - SHA1 hash:
      #http://stackoverflow.com/questions/9506667/calculate-sha1-pieces-when-creating-torrent-file
      
      puts "BITFIELD LENGTH: #{bitfield_length}\n\n\n"
      if bitfield_length % 8 != 0
          bitfield_length = bitfield_length / 8
          bitfield_length += 1 
      else
          bitfield_length = bitfield_length / 8
      end
      torrent.bitfield = "\x0" * bitfield_length
      puts torrent.bitfield.length
      puts "Bitfield: #{torrent.bitfield}"
      update data_file, torrent  
      save data_file
  end

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
		response = 
			connection.make_tracker_request( 
																			:uploaded => 0, 
																			:downloaded => 0,	
																			:left => 0, 
																			:compact => 0, 
																			:no_peer_id => 0, 
																			:event => 'started', 
																			:index => 0)

		puts "RESPONSE: " + response.to_s      # debug - prints tracker response
		response["peers"].each do |peer|
			torrent.peers << Peer.new(peer["ip"], peer["port"], peer["peer id"])
		end
		#we can access each bit of the fixnum using array notation
		bitmap = 0
		#close the connection to be polite
		connection.make_tracker_request(
																		:uploaded => 0, 
																		:downloaded => 0,
																		:left => 0, 
																		:compact => 0,  
																		:no_peer_id => 0, 
																		:event => 'stopped', 
																		:index => 0)
  end
end
