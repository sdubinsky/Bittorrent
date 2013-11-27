#! /usr/bin/ruby 
require_relative "./ruby-bencode/lib/bencode.rb"

class MetaInfo
  def initialize(filepath)
    metainfo_file = File.read(filepath)
    @metainfo = BEncode.load(metainfo_file)
  end

  def dict
    @metainfo
  end
end
