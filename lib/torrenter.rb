require 'torrenter/message/messager'
require 'torrenter/message/message_types'
require 'torrenter/peer'
require 'torrenter/reactor'
require 'torrenter/udp'
require 'torrenter/torrent_reader'
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
