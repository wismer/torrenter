require 'socket'
require 'digest/sha1'
require 'bencode'
require 'fileutils'
require 'pry'
# require 'torrenter/message/messager'
# require 'torrenter/message/message_types'
# require 'torrenter/peer'
# require 'torrenter/reactor'
# require 'torrenter/torrent_reader'
# require 'torrenter/http_tracker'
# require 'torrenter/udp_tracker'

# reader just reads the torrent file
# trackers just get peer ips and ports
# peers just hold peer data
# reactor uses the peer data to connect to the peers
# the buffer state should be a class on its own.


module Torrenter
  class Torrent
    def start(file)
      IO.write($data_dump, '', 0) if !File.exists?($data_dump)
      stream  = BEncode.load_file(file)
      torrent_file = Torrenter::TorrentReader.new(stream)
      trackers = torrent_file.access_trackers
      loop do
        @torrent = trackers.shift
        @torrent.connect
        break if @torrent.connected?
      end

      @peers = @torrent.bound_peers
      binding.pry
      reactor = Reactor.new(@peers, stream)
    end
  end
end
