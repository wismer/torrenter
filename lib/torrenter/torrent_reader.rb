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
      bytestring.bytes.each_slice(6).map { |peer_data| Peer.new(peer_data) }
    end
  end
end
