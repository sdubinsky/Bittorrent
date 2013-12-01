#! /usr/bin/ruby 
require_relative "./ruby-bencode/lib/bencode.rb"
require "./metainfo.rb"
require "open-uri"
require "net/http"
require "digest"


def make_options(hash, uploaded, downloaded, left, event)
  peer_id = "-DS00011234567890123"
  port = "7474"
  sprintf("?info_hash=%s&peer_id=%s&port=%s&uploaded=%d&downloaded=%d&left=%s&compact=1&event=%s", URI::encode(hash), peer_id, port, uploaded, downloaded, left, event)
end

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



def usage
  puts "Usage: \"ruby %s <torrent-file>\"" % [$PROGRAM_NAME]
    puts "\tby default, config is assumed to be in ./.config"
end

if __FILE__ == $PROGRAM_NAME

  case ARGV.length

  when 0
    usage
  when 1
    torrent = ARGV[0]

  end   

  metainfo = MetaInfo.new(torrent)

  url = metainfo.dict["announce"]

  uploaded = 0
  downloaded = 0

  left = 0

  event = "started"

  hash = Digest::SHA1.digest(metainfo.dict["info"].bencode)

  options = make_options(hash, uploaded, downloaded, left, event)

  uri = URI(url + options)

  response = Net::HTTP.get(uri)


  puts response

  response = BEncode.load(response)

  puts response
  options = make_options(hash, uploaded, downloaded, left, "stopped")

  uri = URI(url + options)

  Net::HTTP.get(uri)

  print_peer_list(response["peers"])

end

