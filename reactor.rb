module Torrenter
  class Reactor
    def initialize(peers)
      @peers    = peers
      @messager = Message::Messenger.new
    end

    # makes the peers connect

    def connect
      @peers.each { |peer| peer.connect }
    end

    # selects the peers that were able to connect

    def connected
      @peers.select { |peer| peer.socket }
    end

    # sends the handshake messages. 

    def send_handshakes
      connected.each { |peer| @messager.handshake(:send => true, :msg => peer.handshake, :socket => peer.socket) }
    end

    def message_reactor(opts={})
      puts "Sending handshakes"
      send_handshakes
      puts "Parsing handshakes"
      parse_handshakes
      unless connected.empty?
        read_next until @connected.all? { |peer| peer.ready }
      end
    end

    def read_next
      # loop do
      #   connected.each do |peer|
      #     msg = @messager.bitfield(:msg => 4, :socket => peer.socket)
      #   end
      # end            

    end

    def parse_handshakes
      loop do 
        break if connected.all? { |peer| peer.shaken }
        connected.each do |peer|
          msg = @messager.handshake(:msg => 68, :socket => peer.socket)
          if msg 
            if peer.hash_match?(msg)
              peer.shaken = true
            else
              peer.socket.close
              connected.delete(peer)
            end
          end
        end
      end
    end
  end
end