module Torrenter
  class HTTPTracker < TorrentReader

    def initialize(address, stream)
      @address = URI(address)
      super(stream)
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

    def address_list
      parse_addresses(address_hashes, address_hashes.bytesize / 6)
    end

    def tracker_params
      {
        :info_hash => @sha,
        :peer_id   => PEER_ID,
        :left      => @piece_length,
        :pieces    => @file_list
      }
    end

    def connected?
      @response
    end
  end
end