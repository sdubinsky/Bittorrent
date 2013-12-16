#a torrent file
class TorrentFile
  # takes a relative filename
  def initialize(filename, first_piece, last_piece, first_offset, last_offset)
    # filename to write this file to
    @filename = filename
    # number of the first piece
    @first_piece = first_piece
    # the number of bytes this file extends into the last piece
		@last_offset = last_offset
    #the byte at which this file starts in the first piece
    @first_offset = first_offset
		@last_piece = last_piece

  end
  def write_file(piece_set, piece_size)
    FileUtils.mkpath(File.dirname(@filename))
    file = File.open(@filename, "wb")
    @first_piece.upto @last_piece do |i|
      piece_file = File.open piece_set[i].filename, "rb"
      file.write(piece_file.read piece_size)
    end
  end
  
  def check_completion piece_set, piece_size
    @first_piece.upto @last_piece do |i|
      if not piece_set[i].complete
        return
      end
    end
    write_file piece_set, piece_size
  end
end
