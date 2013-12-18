require_relative "./ruby-bencode/lib/bencode.rb"
require_relative "./torrent_file.rb"
require_relative "./bitfield.rb"
require_relative "./piece"
require 'digest/sha1'
require 'cgi'
require "fileutils"


class Torrent
  #create/bencode a new Torrent file
  attr_accessor :torrent_file, :bitfield, :decoded_data, :info_hash, :peers, :pieces, :files, :tracker
  
  def initialize(filepath)
    @torrent_file = File.read(filepath)
    @decoded_data = BEncode.load(torrent_file)
    @info_hash = Digest::SHA1.digest(@decoded_data["info"].bencode)
    #Hash of peer ids to peers
    @peers = { }
    @piece_directory = FileUtils.mkdir_p(Dir.pwd << "/temp/" << filepath.gsub("/", ""))[0]
    @files = { }
		
    @bitfield_length = @decoded_data["info"]["pieces"].length / 20

    @bitfield = Bitfield.new @bitfield_length
    #array of all the pieces - frequency starts at 0
    @pieces = []
    0.upto @bitfield_length do |i|
      @pieces << Piece.new(@decoded_data["info"]["pieces"][i*20, 20], i, @decoded_data["info"]["piece length"], @piece_directory)
    end
    #Set up files for the torrents to write to.
    #Open files for each file in the torrent.
    if @decoded_data["info"].key? "name"
      #single file
      @files[@decoded_data["info"]["name"]] = TorrentFile.new(@decoded_data["info"]["name"], 0, @bitfield_length - 1, 0, @decoded_data["info"]["piece length"].to_i)
    else
      #multiple files
			total_len = 0
			first_piece = 0
      @decoded_data["info"]["files"].each do |file|
				length = file["length"]
				#distance into the first piece this one starts
				first_offset = total_len % @decoded_data["info"]["piece length"]
				#distance into the last piece this one ends
				last_offset = ((length - first_offset) + length) % @decoded_data["info"]["piece length"]
        name = "./".concat(file["path"].join("/"))
				#last relevant piece.  The first piece plus any complete intervening pieces
				last_piece = first_piece + ((total_len + length) / @decoded_data["info"]["piece length"])
				#if it extends partway into an extra piece
				if last_offset != 0
					last_piece += 1
				end
        @files[name] = TorrentFile.new(name, first_piece, last_piece, first_offset, last_offset)
				first_piece = last_piece
				total_len += length
      end
    end
  end

	
  def add_block_to_piece piece_num, offset, data
    piece = @pieces[piece_num]
    piece.add_block offset, data
    if piece.is_complete?
      piece.write_to_file

      @bitfield[piece_num] = 1
			@files.values.each do |file|
				file.check_completion pieces
			end
    end
  end

  def get_block_from_piece piece_number, block_number
    if @bitfield[piece_number]
      @pieces[piece_number].get_block block_number
    end
  end
	
	#get the next piece to request
	#pieces is an array of integers, representing the pieces' index
	def get_next_piece pieces
		pieces.each do |i|
			if @pieces[i].next_block
				return @pieces[i]
			end
		end
	end
	
	def want_piece pieces
		pieces.each do |piece|
			if not @pieces[piece].is_complete?
				return true
			end
		end
		return false
	end
end
