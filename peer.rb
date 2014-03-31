# contains the peer information
module Torrenter
  class Peer
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
      @interest  = false
      @block_map   = []
      @request_sent = false
      @current_piece = nil
      @block_count = 0
    end

    def pack_data
      data = @block_map.join
      if piece_verified?(data)
        puts "FILE CHUNK PASSED!!!"
        @piece_index[@current_piece] = false
        IO.write("data", data, @current_piece * @piece_len)
        if @piece_index.all?
          @status = :finished
          binding.pry
        end
      end
      @block_map = []
    end

    def connect
      puts "\nConnecting to IP: #{peer[:ip]} PORT: #{peer[:port]}"
      begin
        # Timeout::timeout(2) { @socket = TCPSocket.new("95.236.136.24", 34429) }
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

    def read_response(type)
      
    end

    def piece_verified?(data)
      Digest::SHA1.digest(data) == @sha_list[@current_piece]
    end

    def request_message(index, offset)
      pack_request(13) + "\x06" + pack_request(index) + pack_request(offset) + pack_request(BLOCK)
    end

    def interested?
    end

    def hash_match?
      buffer.unpack("A*").first[28..47] == @info_hash
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

    def get_length
      buffer.slice!(0..3).unpack("C*").last
    end

    def get_id
      buffer.slice!(0).unpack("C*").last
    end

    def payload(length, id)
      payload = buffer.slice!(0...length - 1)
      if id == 5
        @piece_index = payload.unpack("B#{sha_list.size}").join.split('').map { |bit| bit == '1' }
      else
        index = payload.unpack("C*").inject { |x,y| x + y }
        @piece_index[index] = true
      end
    end
  end
end
