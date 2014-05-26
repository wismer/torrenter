require 'socket'
require 'digest/sha1'
require 'bencode'
require 'fileutils'
require 'pry'
require 'torrenter/message/messager'
require 'torrenter/message/message_types'
require 'torrenter/peer'
require 'torrenter/torrent_reader'
require 'torrenter/reactor'
require 'torrenter/http_tracker'
require 'torrenter/udp_tracker'

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

      # returns an array of initialized UDP and/or HTTP Tracker class objects

      loop do
        @tracker = trackers.shift
        if @tracker
          begin
            Timeout::timeout(10) { @tracker.connect }
          rescue Timeout::Error
            puts 'Tracker not responding. Trying next.'
          end
        end
        
        if @tracker.connected?
          break
        elsif trackers.empty?
          raise 'Trackers non-responsive'
        end
      end

      peers = @tracker.bound_peers
      reactor = Reactor.new(peers, stream)
      reactor.check_for_existing_data
      unless reactor.finished?
        reactor.message_reactor
      else
        reactor.unpack_data
      end
    end
  end
end
