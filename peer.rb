# contains the peer information
module Torrenter
  class Peer
    include Torrenter
    PROTOCOL = "\x13BitTorrent protocol\x00\x00\x00\x00\x00\x00\x00\x00"
    # for non outside vars use the @ and remove them from

    attr_reader :socket, :peer, :sha_list, :piece_len, :info_hash, :orig_index
    attr_accessor :piece_index, :status, :buffer, :shaken, :ready, :bitfield, :block_map, :request_sent, :current_piece, :interest, :block_count


    def initialize(peer, peer_info={})
      @peer        = peer
      @info_hash   = peer_info[:info_hash]
      @piece_len   = peer_info[:piece_length]
      @sha_list    = peer_info[:sha_list]
      @piece_index = peer_info[:piece_index]
      @orig_index  = peer_info[:piece_index]
      @buffer      = ''
      @shaken      = false
      @status      = false
      @ready       = false
      @bitfield    = false
      @interest    = false
      @block_map   = []
      @request_sent = false
      @current_piece = nil
      @block_count = 0
    end

    def connect
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
      end
    end

    def block_retrieved?
      buffer[13..-1].bytesize == buffer[0..3].unpack("N*").first
    end

    def handshake
      "#{PROTOCOL}#{@info_hash}#{PEER_ID}"
    end

    def piece_verified?(data)
      Digest::SHA1.digest(data) == @sha_list[@current_piece]
    end

    def request_message(index, offset)
      pack(13) + "\x06" + pack(index) + pack(offset) + pack(BLOCK)
    end

    def pack(i)
      [i].pack("I>")
    end

    def parse_handshake
      
    end

    def parsed_bitfield?
      binding.pry
      until buffer.empty?
        if pack(4) == buffer
          have_meta
        else
          bitfield_meta
        end
      end
    end

    def msg_num
      @buffer.slice!(0..3).unpack("N*").first
    end

    def have_meta
      @piece_index[msg_num] = true
    end

    def bitfield_meta(length)
      payload = buffer.slice!(0...length - 1)
      @piece_index = payload.unpack("B#{@sha_list.size}").join.split('').map { |bit| bit == '1' }
    end

    def find_msg(opts={}, &block)
      if buffer[0..3] == pack
      end
    end

    def pack_data
      data = @block_map.join
      if piece_verified?(data)
        puts "FILE CHUNK PASSED!!!"
        @piece_index[@current_piece] = false
        IO.write("data", data, @current_piece * @piece_len)
        if @piece_index.all? { |x| x == false }
          @status = :finished
        end
      end
      @block_map = []
    end
  end
end
