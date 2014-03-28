module Message
  MESSAGE_INDEX = [:handshake, :interest, :choke, :unchoke, :have, :bitfield, :request, :keep_alive, :piece]

  class Messenger

    def initialize
      create_methods
    end

    def handshake(info_hash)
      "#{PROTOCOL}#{info_hash}#{PEER_ID}"
    end

    def receive_msg(opts={})
      begin
        Timeout::timeout(10) { opts[:socket].read(opts[:msg]) }
      rescue IO::EAGAINWaitReadable
      rescue Timeout::Error
      end
    end

    # send whatever message by passing in the options hash which, I'd assume, would have the
    # appropriate combination of bytes that make up the message

    def send_msg(opts={})
      Timeout::timeout(5) { opts[:socket].write(opts[:msg]) }
    end

    def create_index(msg, length)
      msg.unpack("B#{length}").join.split('').map { |n| n == '1' }
    end

    def modify_index(msg)
      msg.unpack("C*").last
    end

    def pack(msg)
      [msg].pack("I>")
    end

    def incomplete?(msg, type)
      
    end

    def nonblock_read(opts={})
      begin
        opts[:socket].read_nonblock(opts[:msg], opts[:buffer])
      rescue IO::EAGAINWaitReadable

      end
    end

    # EXPERIMENTAL
    # EXPERIMENTAL
    # EXPERIMENTAL

    def create_methods
      MESSAGE_INDEX.each do |msg|
        self.define_singleton_method(msg, ->(opts={}) { opts[:send] == true ? send_msg(opts) : receive_msg(opts) })
      end
    end
  end
end




