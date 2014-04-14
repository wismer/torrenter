require_relative 'lib/peer.rb'
require_relative 'lib/message.rb'
require_relative 'lib/reactor.rb'
require_relative 'lib/message_types'
require_relative 'lib/torrent_reader.rb'

module Torrenter
  def self.start(file)

    IO.write("#{$data_dump}", '', 0) if !File.exists?($data_dump)
    stream  = BEncode.load_file(file)
    peers   = Torrenter::TorrentReader.new(stream)
    peers.uri_hash
    peers.establish_reactor
  end
end
file    = ARGV[0]
$data_dump = "#{file}-data"
Torrenter.start(file)
