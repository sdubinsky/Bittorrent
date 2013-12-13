require_relative "./ruby-bencode/lib/bencode.rb"
require_relative "./torrent_file.rb"
require_relative "./bitfield.rb"
require_relative "./piece"
require "fileutils"

class Torrent
  #create/bencode a new Torrent file
  attr_accessor :torrent_file, :bitfield, :decoded_data, :info_hash, :peers, :pieces, :files, :tracker
  
  def initialize(filepath)
    @torrent_file = File.read(filepath)
    @decoded_data = BEncode.load(torrent_file)
    @info_hash = CGI.escape(Digest::SHA1.digest(@decoded_data["info"].bencode)).gsub("+", "%20")
    #Hash of peer ids to peers
    @peers = { }
    @piece_directory = FileUtils.mkdir_p(Dir.pwd << "/temp/" << filepath.gsub("/", ""))[0]
    @files = { }

    @bitfield_length = @decoded_data["info"]["pieces"].length / 20
    if @bitfield_length % 8 != 0 #bitfield length in bytes
      @bitfield_length = @bitfield_length / 8
      @bitfield_length += 1 
    else
      @bitfield_length = @bitfield_length / 8
    end
    @bitfield = Bitfield.new @bitfield_length
    #array of all the pieces - frequency starts at 0
    @pieces = []
    0.upto @bitfield_length do |i|
      @pieces << Piece.new(@decoded_data["info"]["pieces"][i*20, 20], i, @decoded_data["info"]["piece_length"], @piece_directory)
    end
    #Set up files for the torrents to write to.
    #Open files for each file in the torrent.
    if @decoded_data["info"].key? "name"
      #single file
      @files[@decoded_data["info"]["name"]] = TorrentFile.new(@decoded_data["info"]["name"], 0, @bitfield_length - 1, 0, @decoded_data["info"]["piece_length"].to_i)
    else
      #multiple files
      @decoded_data["info"]["files"].each do |file|
        name = "./".concat(file["path"].join("/"))
        #TODO: figure out which pieces belong to which files
        # @files[name] = TorrentFile.new(name)
      end
    end
  end
  
  def add_block_to_piece piece_num, block_num, data
    piece = @pieces[piece_num]
    piece.add_block block_num, data
    if piece.is_complete?
      piece.write_to_file
      #not sure this is the right way to set it as one.
      @bitfield[piece_num] = "0x01"
    end
  end

  def get_block_from_piece piece_number, block_number
    if @bitfield[piece_number]
      @pieces[piece_number].get_block block_number
    end
  end
end
