module Torrenter
  class UDPTracker < TorrentReader
    attr_reader :socket, :response

    def initialize(tracker, stream)
      super(stream)
      @url           = tracker[/(?<=udp\:\/\/).+(?=\:\d+)/]
      @port          = tracker[/\d+$/].to_i
      @socket        = UDPSocket.new
      @connection_id = [0x41727101980].pack("Q>")
    end

    def connect
      @transaction_id = [rand(1000)].pack("I>")
      @socket.connect(ip_addr, @port)
      begin
        send_msg(connect_msg)
        read_response
      rescue
        false
      end
    end

    def send_msg(msg)
      begin
        @socket.send(msg, 0)
      rescue
        false
      end
    end

    def connected?
      @response
    end

    def ip_addr
      Socket.getaddrinfo(@url, @port)[0][3]
    end

    def peers
      @connection_id = @response[-8..-1]
      @transaction_id = [rand(10000)].pack("I>")
      send_msg(announce_msg)

      read_response

      parse_announce if @response[0..3] == action(1)

      peer_list(@response)
    end

    def parse_announce
      if @response[4..7] == @transaction_id
        res = @response.slice!(0..11)
        leechers = @response.slice!(0..3).unpack("I>").first
        seeders  = @response.slice!(0..3).unpack("I>").first
      end
    end

    def send_message
      begin
        @socket.send(@msg, 0)
      rescue
      end
    end

    def read_response
      begin
        @response = @socket.recv(1028)
      rescue Exception => e
        e
      end
    end

    def connect_match?
      data[0] == (action(0) + @transaction_id + @connection_id)
    end

    def announce_input
      @connection_id + action(1) + @transaction_id + @sha + PEER_ID
    end

    def connect_msg
      @connection_id + action(0) + @transaction_id
    end

    def action(n)
      [n].pack("I>")
    end

    def announce_msg
      @connection_id + action(1) + @transaction_id + @sha + PEER_ID + [0].pack("Q>") + [0].pack("Q>") + [0].pack("Q>") + action(0) + action(0) + action(0) + action(-1) + [@socket.addr[1]].pack(">S")
    end
  end
end
