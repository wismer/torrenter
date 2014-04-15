module Torrenter
  class UDPConnection
    def initialize(ip, port)
      @ip             = ip
      @port           = port.to_i
      @sender         = UDPSocket.new
      @connection_id  = [0x41727101980].pack("Q")
      @transaction_id = [29345].pack("N")
      binding.pry
    end

    def udp_server
      @sender.connect(addr, @port)
      @sender.send msg, 0
      @sender.recvfrom_nonblock(16)
      # Socket.udp_server_sockets(0) { |socket| 
      #   socket = socket.first
      #   sock_addr = socket.local_address
      #   binding.pry
      #   socket.bind(sock_addr)
      #   # socket is what I'll use to receive info?
      #   binding.pry
      # }
    end

    def addr
      Socket.getaddrinfo(@ip, @port)[0][3]
    end


    def connect
      @socket.connect(@ip, @port, 0)
    end

    def msg
      @connection_id + action(0) + @transaction_id
    end

    def action(n)
      [n].pack("I")
    end

    def send_message
      
    end
  end
end