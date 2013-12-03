#! /usr/bin/ruby 
require_relative "./ruby-bencode/lib/bencode.rb"
require "./torrent.rb"
require "open-uri"
require "net/http"
require "digest"
require "./tracker.rb"


$version = "HT0002"
$my_id = "-DS00011234567890123"

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
  puts "Usage: \"ruby %s <torrent-file>\"" % [$PROGRAM_NAME]
    puts "\tby default, config is assumed to be in ./.config"
end

if __FILE__ == $PROGRAM_NAME

  case ARGV.length
  when 0
    usage
    exit
  when 1
    file = ARGV[0]
  end

  torrent = Torrent.new(file)

  print_metadata(torrent)

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
  if success


      response = connection.make_tracker_request( :uploaded => 0, :downloaded => 0,
                :left => 0, :compact => 0,
                :no_peer_id => 0, :event => 'started', 
                :index => 0)

      puts "RESPONSE: " + response.to_s      # debug - prints tracker response
  end
end
