require 'digest'
require 'net/http'
require 'open-uri'
require 'timeout'

require "socket"

class Tracker
  attr_reader :trackers, :failed_trackers
  attr_accessor :successful_trackers
  def initialize data, options = {}
    @trackers = [] # all trackers for torrent
    @failed_trackers = [] #all trackers that have failed
    @successful_trackers = []
    #6881-6889 is the range of standard TCP port number the client should listen on for BitTorrent 
    @options = {:port => 6881}.merge(options)

    #urlencoded 20-byte SHA1 hash of the value of the info key from the Metainfo file
    @info_hash = URI.encode(Digest::SHA1.digest(data["info"].bencode))

    #urlencoded 20-byte string used as a unique ID for the client, 
    #generated by the client at startup. This is allowed to be any value, and may be binary data.
    @peer_id = URI.encode @options[:peer_id]

    #establish the list of trackers for the torrent if there is one
    if data['announce-list']
      data['announce-list'].each { |list|
        list.each { |tracker|
          parse_and_add_tracker tracker
        }
      }
    else
      parse_and_add_tracker data['announce']
    end
  end

  #parses a tracker URI and adds its info to the list
  def parse_and_add_tracker tracker
    uri = URI.parse tracker
    @trackers << {:url => uri.to_s, 
      :host => uri.host, 
      :path => uri.path, 
      :port => uri.port, 
      :scheme => uri.scheme}
  end

  #handles TCP connections
  #rm!!!??? modify to try to connect to all trackers
  def connect_to_tracker index
    connected = false
    if @trackers[index][:scheme] == 'http'
      begin
        #the connection should be stopped if the tracker 
        #takes > timeout seconds to connect
        timeout(@options[:timeout]) do
          @successful_trackers << {:tracker => @trackers[index],
            :connection => Net::HTTP.start(@trackers[index][:host], @trackers[index][:port])}
          connected = true
          return connected
        end
      rescue => error
        puts "TIMED OUT"
        @failed_trackers << {:tracker => @trackers[index], :error => error}
      end
    end
    connected
  end

  def make_tracker_request request_params
    
    if @successful_trackers.empty?
      raise Exception, "Connection to trackers has failed."
    end

    #required parameters for a request (from spec)

    required_params = [:index, :uploaded, :downloaded, :left, :compact, :no_peer_id, :event]
    param_diff = required_params - request_params.keys
    
    connection = nil #no connections currently

    if param_diff.empty?
      for tracker in @successful_trackers
        if tracker[:tracker] == @trackers[request_params[:index]]
          connection = tracker[:connection]
        end
      end
      
      if connection.nil?
        connection = connect_to_tracker(request_params[:index]) ?
        @successful_trackers[-1] : raise(Exception, "Couldn't connect")
      end

      
      request_str = "#{@trackers[request_params[:index]][:url]}?" +
        "info_hash=#{@info_hash}&"             +
        "peer_id=#{@peer_id}&"                 +
        "port=#{@options[:port]}&"             +
        "uploaded=#{request_params[:uploaded]}&"       +
        "downloaded=#{request_params[:downloaded]}&"   +
        "left=#{request_params[:left]}&"               +
        "compact=#{request_params[:compact]}&"         +
        "no_peer_id=#{request_params[:no_peer_id]}&"   +
        "event=#{request_params[:event]}"

    else
      raise Exception, "Required parameters missing for #{param_diff.to_s}"
    end
    raise Exception, "connection not made" if connection.nil?
    
    #actually make the request 
    uri = URI(request_str)
    response = Net::HTTP.get(uri)

    response = BEncode.load(response)
  end
end
