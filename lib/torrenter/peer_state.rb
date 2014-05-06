module Torrenter
  # The buffer state should be responsible ONLY for the handling of non-metadata bytes.
  # the messaging behavior should and ought to remain with the peer class, though
  # in truth, it may be better if I didnt do that. 

  # So, if the state of the buffer reaches a certain step in its process involving the piece
  # the buffer state should be fired off. 

  # instead of initialiazing it with the buffer, 

  class BufferState

    def intialize(socket)
      @socket = socket
      @buffer = ''
    end

    # include Torrenter

    def state(buffer, master_index)
      buffer_id = buffer[4]
      if buffer_id.nil?
        buffer.slice!(0..3)
      else
        @length = buffer[0..3].unpack("N>")
        case buffer_id
        when BITFIELD   then process_bitfield
        when HAVE       then process_have
        when INTERESTED then process_interested
        when PIECE      then process_piece
        when CHOKE      then choke_message
        when HANDSHAKE  then process_handshake
        end
      end
    end

    def process_bitfield
      
    end

    def process_have
      
    end

    def process_piece
      
    end

    def process_handshake
      
    end

    def recv_data
      
    end
  end
end