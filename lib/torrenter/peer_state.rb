module Torrenter

  # The buffer state should be responsible ONLY for the handling of non-metadata bytes.
  # the messaging behavior should and ought to remain with the peer class, though
  # in truth, it may be better if I didnt do that. 

  # So, if the state of the buffer reaches a certain step in its process involving the piece
  # the buffer state should be fired off. 

  # instead of initialiazing it with the buffer, 

  class BufferState < Peer
    def examine(buffer, msg_length)
      binding.pry
    end
  end
end