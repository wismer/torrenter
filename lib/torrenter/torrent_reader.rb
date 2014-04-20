require 'socket'
require 'digest/sha1'
require 'bencode'
require 'pry'
require 'fileutils'


module Torrenter
  class TorrentReader
    attr_reader :stream
    def initialize(stream)
      @stream      = stream
    end

    def determine_protocol
      trackers =  if @stream['announce-list']
                    @stream['announce-list'].flatten << @stream['announce']
                  else
                    [@stream['announce']]
                  end

      @http_trackers = trackers.select { |tracker| tracker =~ /http\:\/\// }
      @udp_trackers  = trackers.select { |tracker| tracker =~ /udp\:\/\//  }
      # first try the http trackers...
      
      connect_to_http_tracker if @http_trackers.size > 0
      connect_to_udp_tracker if @peers.nil?

      peer_list
      establish_reactor
    end

    def connect_to_http_tracker
      @uri       = URI(@http_trackers.shift)
      @uri.query = URI.encode_www_form(peer_hash)
      @peers     = raw_peers
    end

    def connect_to_udp_tracker
      @udp_trackers.map! do |udp|
        udp.gsub!(/udp\:\/\/|\:\d+/, '')
        ip = Socket.getaddrinfo(udp, 80)[0][3]
        udp_socket = UDPConnection.new(ip, 80, sha)
        udp_socket.connect_to_udp_host
      end

      while @peers.nil?
        udp = @udp_trackers.shift
        begin
          @peers = udp.message_relay
        rescue
        end
      end
    end


    # url gets reformatted to include query parameters

    def raw_peers
      begin
        BEncode.load(Net::HTTP.get(@uri))['peers']
      rescue
        nil
      end
    end


    def piece_length
      stream['info']['piece length']
    end

    def sha
      Digest::SHA1.digest(stream['info'].bencode)
    end

    # data stored as a hash in the order made necessary

    def peer_hash
      {
        :info_hash => sha,
        :peer_id   => PEER_ID,
        :left      => piece_length,
        :pieces    => stream['info']['files'] || stream['info']['name']
      }
    end

    # Using the peers key of the torrent file, the hex-encoded data gets reinterpreted as ips addresses.

    def peer_list
      ip_list = []
      until @peers.empty?
        ip_list << { ip: @peers.slice!(0..3).bytes.join('.'), port: @peers.slice!(0..1).unpack("S>").first }
      end

      @peers = ip_list.map { |peer| Peer.new(peer, file_list, peer_info) }
    end

    def sha_list
      n, e = 0, 20
      list = []
      until stream['info']['pieces'].bytesize < e
        list << stream['info']['pieces'].byteslice(n...e)
        n += 20
        e += 20
      end
      list
    end

    def peer_info
      {
        :info_hash    => sha,
        :piece_length => piece_length,
        :sha_list     => sha_list,
        :piece_index  => Array.new(sha_list.size) { false }
      }
    end

    def file_list
      stream['info']['files'] || stream['info']
    end

    def establish_reactor
      react = Reactor.new(@peers, sha_list, piece_length, file_list)
      begin
        react.message_reactor
      end
    end
  end
end


