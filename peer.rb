# contains the peer information
module Torrenter
  class Peer
    PROTOCOL = "\x13BitTorrent protocol\x00\x00\x00\x00\x00\x00\x00\x00"

    # for non outside vars use the @ and remove them from

    attr_reader :socket, :peer, :sha_list, :piece_len
    attr_accessor :piece_index, :status, :buffer, :shaken, :ready, :bitfield, :blocks, :request_sent


    def initialize(peer, peer_info={})
      @peer        = peer
      @info_hash   = peer_info[:info_hash]
      @piece_len   = peer_info[:piece_length]
      @sha_list    = peer_info[:sha_list]
      @piece_index = peer_info[:piece_index]
      @buffer      = ''
      @shaken      = false
      @status      = false
      @ready       = false
      @bitfield    = false
      @blocks      = nil
      @request_sent = false
    end

    def connect
      puts "\nConnecting to IP: #{peer[:ip]} PORT: #{peer[:port]}"
      begin
        Timeout::timeout(3) { @socket = TCPSocket.new(peer[:ip], peer[:port]) }
      rescue Timeout::Error
        puts "Timed out."
      rescue Errno::EADDRNOTAVAIL
        puts "Address not available."
      rescue Errno::ECONNREFUSED
        puts "Connection refused."
      rescue Errno::ECONNRESET
        puts "bastards."
      end

      if @socket
        @status = true
      end
    end

    def block_retrieved?
      peer.buffer[13..-1].bytesize == peer.buffer[0..3].unpack("N*").first
    end

    def handshake
      "#{PROTOCOL}#{@info_hash}#{PEER_ID}"
    end

    def read_response(type)
      
    end

    def piece_verified?(index)
      piece = peer.buffer[13..-1]
      Digest::SHA1.digest(piece) == @sha_list[index]
    end

    def request_message(index, offset)
      pack_request(13) + "\x06" + pack_request(index) + pack_request(offset) + pack_request(BLOCK)
    end

    def interested?
      @message.interest(:msg => 5) == "\x00\x00\x00\x01\x01"
    end

    def peer_hash(msg)
      msg.slice(28..47)
    end

    def hash_match?(msg)
      peer_hash(msg) == @info_hash
    end

    def pack_request(i)
      [i].pack("I>")
    end

    def block_started?
      buffer.empty?
    end

    def select_piece
      @piece_index.index(true)
    end
  end
end
