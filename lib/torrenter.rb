require 'socket'
require 'digest/sha1'
require 'bencode'
require 'fileutils'
require 'pry'
require 'torrenter/message/messager'
require 'torrenter/message/message_types'
require 'torrenter/peer'
require 'torrenter/reactor'
require 'torrenter/torrent_reader'
require 'torrenter/http_tracker'
require 'torrenter/udp_tracker'

module Torrenter
  class Torrent
    def start(file)
      IO.write($data_dump, '', 0) if !File.exists?($data_dump)
      stream  = BEncode.load_file(file)
      peers   = Torrenter::TorrentReader.new(stream)
      peers.determine_protocol
    end
  end
end
