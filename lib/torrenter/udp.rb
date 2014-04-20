module Torrenter
  class UDPConnection
    attr_reader :sender, :response
    def initialize(ip, port, info_hash)
      @ip             = ip
      @port           = port
      @sender         = UDPSocket.new
      @t              = rand(10000)
      @connection_id  = [0x41727101980].pack("Q>")
      @transaction_id = [@t].pack("I>")
      @info_hash      = info_hash
    end

    def connect_to_udp_host
      begin
        @sender.connect(@ip, @port)
        return self
      rescue
        false
      end
    end

    def message_relay
      @sender.send(connect_msg, 0)
      read_response
      if @response
        @connection_id = @response[-8..-1]
        @transaction_id = [rand(10000)].pack("I>")
        @sender.send(announce_msg, 0)
      end

      read_response
      
      if @response
        parse_announce if @response[0..3] == action(1)
        return @response
      end
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
        @sender.send(@msg, 0)
      rescue
      end
    end

    def read_response
      begin
        @response = @sender.recv(1028)
      rescue Exception => e
        e
      end
    end

    def connect_match?
      data[0] == (action(0) + @transaction_id + @connection_id)
    end

    def announce_input
      @connection_id + action(1) + @transaction_id + @info_hash + PEER_ID
    end

    def connect_msg
      @connection_id + action(0) + @transaction_id
    end

    def port
      @sender.addr[1]
    end

    def action(n)
      [n].pack("I>")
    end
    
    def announce_msg
      @connection_id + action(1) + @transaction_id + @info_hash + PEER_ID + [0].pack("Q>") + [0].pack("Q>") + [0].pack("Q>") + action(0) + action(0) + action(0) + action(-1) + [port].pack(">S")
    end
  end
end