module Torrenter
  class Tracker < TorrentReader
    def initialize(tracker_url)
      @tracker_url = tracker_url
    end

    def tracker_connect
      if @tracker_url.include?("http://")
        @tracker_url = URI(@tracker_url)
        @tracker_url.query = URI.encode_www_form(peer_hash)
    end
  end
end