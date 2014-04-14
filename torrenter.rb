require_relative 'peer.rb'
require_relative 'message.rb'
require_relative 'reactor.rb'
require_relative 'message_types'
require_relative 'torrent_reader.rb'

module Torrenter
  def self.start
    file    = ARGV[0]
    DATA_DUMP = "#{file}-data"
    IO.write("#{DATA_DUMP}", '', 0) if !File.exists?(DATA_DUMP)
    stream  = BEncode.load_file(file)
    peers   = Torrenter::TorrentReader.new(stream)
    peers.uri_hash
    peers.establish_reactor
  end
end

Torrenter.start
