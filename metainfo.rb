#! /usr/bin/ruby 
require_relative "./ruby-bencode/lib/bencode.rb"

class MetaInfo
  attr_accessor :dict
  def initialize(filepath)
    metainfo_file = File.read(filepath)
    @dict = BEncode.load(metainfo_file)
  end
end
