require 'socket'
require 'digest/sha1'
require 'bencode'
require 'net/http'
require 'pry'
require 'fileutils'
require 'json'

require_relative 'peer.rb'
require_relative 'message.rb'
require_relative 'reactor.rb'
require_relative 'message_types'

module Torrenter
  class TorrentReader
    attr_reader :stream
    def initialize(stream)
      @stream   = stream
      @uri      = URI(stream['announce']) 
      @list     = stream['announce-list'].flatten.map { |u| URI(u) }
    end

    # url gets reformatted to include query parameters

    def raw_peers
      BEncode.load(Net::HTTP.get(@uri))['peers'].bytes
    end

    def uri_hash
      @uri.query = URI.encode_www_form(peer_hash)
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
        :pieces    => stream['info']['files']
      }
    end

    # Using the peers key of the torrent file, the hex-encoded data gets reinterpreted as ips addresses.

    def peer_list
      ip_list = []
      raw_peers.each_slice(6) { |e| ip_list << e if e.length == 6 }

      ip_list.map! { |e| { :ip => e[0..3].join('.'), :port => (e[4] * 256) + e[5] } }
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
        :piece_index  => Array.new(sha_list.size) { false },
        :peer_list    => peer_list
      }
    end

    def peers
      peer_list.map { |peer| Peer.new(peer, file_list, peer_info) }
    end

    def file_list
      stream['info']['files'] || stream['info']
    end

    def establish_reactor
      react = Reactor.new(peers, sha_list, piece_length, file_list)
      react.connect
      begin 
        react.message_reactor
      end
    end
  end
end


