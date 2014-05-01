require 'bencode'
require 'pry'
require 'digest/sha1'
require './lib/torrenter/torrent_reader.rb'
require './lib/torrenter/udp_tracker.rb'
require './lib/torrenter/http_tracker.rb'

stream = BEncode.load_file('thrones.torrent')
reader = TorrentReader.new(stream)
binding.pry
