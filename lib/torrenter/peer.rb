module Torrenter
  class Peer
    include Torrenter
    attr_reader :status, :peer_state, :info_hash, :piece_length, :blocks, :buffer, :index
    attr_accessor :piece_index

    # attr_reader :socket, :peer, :sha_list, :piece_len, :info_hash, :status, :index, :msg_length
    # attr_accessor :piece_index, :offset, :buffer, :block_map

    def initialize(ip, port, info_hash, piece_length)
      @ip           = ip
      @port         = port
      @info_hash    = info_hash
      @piece_length = piece_length
      @buffer       = ''
      @blocks       = []
    end

    def full_piece?
      piece_data.size == @piece_length
    end

    def piece_data
      @blocks.join('')
    end

    def connect
      puts "\nConnecting to IP: #{@ip} PORT: #{@port}"
      begin
        Timeout::timeout(1) { @socket = TCPSocket.new(@ip, @port) }
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
        puts "Connected!"
        @socket.write(handshake)
        @peer_state = true
      else
        @peer_state = false
      end
    end

    def handshake
      "#{PROTOCOL}#{@info_hash}#{PEER_ID}"
    end

    def connected?
      @peer_state
    end
  end
end
