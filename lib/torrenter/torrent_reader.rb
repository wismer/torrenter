module Torrenter
  # torrent reader should only read the torrent file and return either
  # a UDP tracker object or an HTTP tracker object
  class TorrentReader
    attr_reader :stream
    def initialize(stream)
      @stream = stream
    end

    def info_hash
      Digest::SHA1.digest(@stream['info'].bencode)
    end

    def sha_hashes
      @stream['info']['pieces']
    end

    def total_file_size
      file_list.is_a?(Array) ? file_list.inject { |x,y| x + y } : file_list['length']
    end

    def piece_length
      @stream['info']['piece length']
    end

    def file_list
      @stream['info']['files'] || @stream['info']
    end

    def announce_url
      @stream['announce']
    end

    def announce_list
      @stream['announce-list']
    end

    def url_list
      announce_list ? announce_list.flatten << announce_url : [announce_url]
    end

    def access_trackers
      url_list.map do |track|
        if track.include?("http://")
          HTTPTracker.new(track, @stream)
        else
          UDPTracker.new(track, @stream)
        end
      end
    end

    def peer_list(bytestring)
      bytestring.chars.each_slice(6).map do |peer_data|
        ip = peer_data[0..3].join('').bytes.join('.')
        port = peer_data[4..5].join('').unpack("S>").first
        Peer.new(ip, port, info_hash, piece_length)
      end
    end
  end
end
