# contains the peer information
module Torrenter
  class Peer
    include Torrenter
    # for non outside vars use the @ and remove them from

    attr_reader :socket, :peer, :sha_list, :piece_len, :info_hash, :orig_index, :status
    attr_accessor :piece_index, :offset, :buffer, :shaken, :ready, :bitfield, :block_map, :request_sent, :current_piece, :interested, :block_count


    def initialize(peer, file_list, peer_info={})
      @peer        = peer
      @info_hash   = peer_info[:info_hash]
      @piece_len   = peer_info[:piece_length]
      @sha_list    = peer_info[:sha_list]
      @piece_index = peer_info[:piece_index]
      @buffer      = ''
      @block_map   = []
      @offset      = 0
      @file_list   = file_list
      @attempts    = 0
    end

    def connect
      if @attempts < 1
        puts "\nConnecting to IP: #{peer[:ip]} PORT: #{peer[:port]}"
        begin
          Timeout::timeout(2) { @socket = TCPSocket.new(peer[:ip], peer[:port]) }
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
          @socket.write(handshake)
          @status = true
        else
          @status = false
          @attempts += 1
        end
      end
    end

    def handshake
      "#{PROTOCOL}#{@info_hash}#{PEER_ID}"
    end

    def msg_num
      @buffer.slice!(0..3).unpack("N*").first
    end
  end
end
