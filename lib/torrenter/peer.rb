module Torrenter
  class Peer
    include Torrenter

    attr_reader :socket, :peer, :sha_list, :piece_len, :info_hash, :status, :index, :msg_length
    attr_accessor :piece_index, :offset, :buffer, :block_map

    def initialize(peer_data)
      @ip   = peer_data[0..3].join('.')
      @port = (peer_data[4] * 256) + peer_data[5]
    end

    def total_file_size
      if @file_list.is_a?(Array)
        @file_list.map { |f| f['length'] }.inject { |x, y| x + y }
      else
        @file_list['length']
      end
    end

    def connect
      puts "\nConnecting to IP: #{peer[:ip]} PORT: #{peer[:port]}"
      begin
        Timeout::timeout(1) { @socket = TCPSocket.new(peer[:ip], peer[:port]) }
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
        @status = true
      else
        @status = false
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
