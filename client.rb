#! /usr/bin/ruby 
require_relative "./ruby-bencode/lib/bencode.rb"
require "./metainfo.rb"
require "open-uri"

metainfo = MetaInfo.new("./torrents/KNOPPIX_V7.0.5DVD-2012-12-21-EN.torrent")

url = metainfo.dict["announce"].sub("http://", "")
announce = '/' + url.partition('/').last
peer_id = "-DS00011234567890123"
port = "7474"
uploaded = 0
downloaded = 0
left = metainfo.dict["info"]["length"].to_s
event = "started"
get_request = sprintf("GET %s?info_hash=%s&peer_id=%s&port=%s&uploaded=%d&downloaded=%d&left=%s&compact=1&event=%s HTTP/1.1 \r\n\r\n", announce, "hash", peer_id, port, uploaded, downloaded, left, event)

print get_request
