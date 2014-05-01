module Torrenter
  class HTTPTracker < TorrentReader
    attr_reader :response
    def initialize(tracker, stream)
      super(stream)
      @address   = URI(tracker)
    end

    def connect
      @address.query = URI.encode_www_form(tracker_params)
      @response =
        begin
          BEncode.load(Net::HTTP.get(@address))
        rescue
          false
        end
    end

    def address_hashes
      @response['peers']
    end

    def tracker_params
      {
        :info_hash => info_hash,
        :peer_id   => PEER_ID,
        :left      => piece_length,
        :pieces    => file_list
      }
    end

    def bound_peers
      peer_list(@response['peers'])
    end

    def connected?
      @response
    end
  end
end
