require 'socket'
require 'digest/sha1'
require 'bencode'
require 'pry'
require 'fileutils'


module Torrenter
  class TorrentReader
    attr_reader :stream
    def initialize(stream)
      @stream       = stream
      @file_list    = stream['info']['files'] || stream['info']
      @sha          = Digest::SHA1.digest(stream['info'].bencode)
      @piece_length = stream['info']['piece length']
      @sha_list     = stream['info']['pieces']
    end

    def determine_protocol
      trackers =  if @stream['announce-list']
                    @stream['announce-list'].flatten << @stream['announce']
                  else
                    [@stream['announce']]
                  end
      
      trackers.each do |track|
        tracker = build_tracker(track)

        tracker.connect
        if tracker.connected?
          @peers = tracker.address_list
          break
        end
      end

      establish_reactor if @peers
    end

    def peer_info
      {
        :info_hash    => @sha,
        :piece_length => @piece_length,
        :sha_list     => @sha_list,
        :piece_index  => Array.new(@sha_list.size) { false }
      }
    end

    def parse_addresses(addr, size)
      Array.new(size) do
        peer = { :ip   => addr.slice!(0..3).bytes.join('.'), 
                 :port => port(addr.slice!(0..1)) }
        Peer.new(peer, @file_list, peer_info)
      end
    end

    def port(addr)
      addr.unpack("S>").first
    end

    def build_tracker(track)
      track.include?('http://') ? HTTPTracker.new(track, stream) : UDPTracker.new(track, stream)
    end

    def sha_pieces
      Array.new(@sha_list.bytesize / 20) { @sha_list.slice!(0..19) }
    end

    def establish_reactor
      react = Reactor.new(@peers, @sha_list, @piece_length, @file_list)
      begin
        react.message_reactor
      end
    end
  end
end


