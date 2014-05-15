module Torrenter
  # KEEP_ALIVE = "\x00\x00\x00\x00"
  # BLOCK = 2**14
  # these methods get mixed in with the Peer class as a way to help 
  # organize and parse the byte-encoded data. The intention is to shorten
  # and shrink the complexity of the Peer class.
  # the following methods are responsible solely for data retrieval and data transmission
  def pick_piece(master)
    if @piece_index.any? { |chunk| chunk == :available }
      @index = @piece_index.index(:available)
      if master[@index] == :free
        @piece_index[@index] = :downloading
        master[@index] = :downloading
      else
        @piece_index[@index] = :downloaded
        pick_piece(master)
      end
    end
  end

  def state(master_index)
    recv_data if @buffer.size <= 3
    if @buffer[4].nil?
      @buffer.slice!(0..3) if @buffer[0..3] == KEEP_ALIVE
    else
      @length    = @buffer[0..3].unpack("N*").last
      @buffer_id = @buffer[4]
      case @buffer_id
      when BITFIELD
        process_bitfield(master_index.size, clear_msg)
      when HAVE
        process_have(clear_msg)
      when INTERESTED
        request_piece(master_index)
      when PIECE
        process_piece
      when CHOKE      
        choke_message
      when HANDSHAKE
        process_handshake
      end
    end
  end

  def choke_message
    @peer_state = false
  end

  def request_piece(master)
    @blocks = []
    @buffer = ''
    pick_piece(master)
    request_message
  end

  def clear_msg
    @buffer.slice!(0..@length + 3)  
  end

  def request_message(bytes=BLOCK)
    send_data(pack(13) + "\x06" + pack(@index) + pack(@blocks.size * bytes) + pack(bytes))
  end

  def pack(msg)
    [msg].pack("I>")
  end

  def process_bitfield(size, msg)
    index = msg[5..-1].unpack("B#{size}").join.split('')
    @piece_index = index.map { |bit| bit == '1' ? :available : :unavailable }
    send_interested if @buffer.empty?
  end

  def process_have(msg)
    @piece_index[msg[5..-1].unpack("C*").last] = :available
    send_interested if @buffer.empty?
  end

  def send_interested
    send_data("\x00\x00\x00\x01\x02")
  end

  def process_piece
    if @buffer.bytesize >= @length + 4
      pack_buffer if buffer_complete?
      # binding.pry if @blocks.size == 63
      if @blocks.join('').bytesize != @piece_length
        request_message
      else
        p "#{@ip} #{@port}"
      end
    else
      recv_data
    end
  end

  def piece_complete?
    piece_size == @piece_length
  end

  def buffer_size
    @buffer[13..-1].bytesize
  end

  def pack_buffer
    @blocks << @buffer.slice!(13..-1)
    @buffer.clear
  end

  def buffer_complete?
    @buffer.bytesize == @length + 4
  end

  # will need a last piece sort of thing inserted in here

  def piece_full?
    @blocks.join('').size == @piece_len
  end

  def piece_size
    @blocks.join('').bytesize + (@buffer.bytesize - 13)
  end

  def process_handshake
    @buffer.slice!(0..67) if hash_check?
  end

  def hash_check?
    @buffer[28..47] == @info_hash
  end

  def send_data(msg)
    begin
      Timeout::timeout(2) { @socket.sendmsg_nonblock(msg) }
    rescue Timeout::Error
      ''
    rescue *EXCEPTIONS
      ''
    end
  end

  def recv_data(bytes=BLOCK)
    begin
      Timeout::timeout(5) { @buffer << @socket.recv_nonblock(bytes) }
    rescue Timeout::Error
      ''
    rescue *EXCEPTIONS
      ''
    rescue IO::EAGAINWaitReadable
      ''
    end
  end
end