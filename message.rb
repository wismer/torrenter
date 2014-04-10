module Torrenter
  # KEEP_ALIVE = "\x00\x00\x00\x00"
  # BLOCK = 2**14
  # these methods get mixed in with the Peer class as a way to help 
  # organize and parse the byte-encoded data. The intention is to shorten
  # and shrink the complexity of the Peer class.

  # the following methods are responsible solely for data retrieval and data transmission

  def send_data(msg, opts={})
    begin
      Timeout::timeout(2) { @socket.sendmsg_nonblock(msg) }
    rescue Timeout::Error
      ''
    rescue Errno::EADDRNOTAVAIL
      ''
    rescue Errno::ECONNREFUSED
      ''
    rescue Errno::EPIPE
      ''
    end
  end

  def recv_data(bytes=BLOCK, opts={})
    begin
      if opts[:peek]
        Timeout::timeout(2) { @socket.recv_nonblock(4, Socket::MSG_PEEK) }
      else
        Timeout::timeout(2) { @buffer << @socket.recv_nonblock(bytes) }
      end
    rescue Timeout::Error
      ''
    rescue Errno::EADDRNOTAVAIL
      ''
    rescue Errno::ECONNREFUSED
      ''
    rescue Errno::ECONNRESET
      ''
    rescue IO::EAGAINWaitReadable
      ''
    end
  end

  # the next few methods responsibility is for parsing the buffer. 
  # They are responsible for the critical step of analyzing the buffer,
  # checking for message consistency from the peer (and if it fails a test
  # another message is sent out to attempt to fix the missing data)
  

  # parse message will be the gatekeeper. If the buffer is ever low in the READ part
  # of the torrent program, then it knows more data may be required.
  # It will also be responsble for EVERY new message that gets received, whether
  # its in the download sequence of messaging or in the actual handshake, it will
  # control it that way.

  # for now, I'm assuming that at least the bitfield will be sent in full

  def parse_bitfield
    buffer.slice!(0)
    @piece_index = buffer.slice!(0...msg_len).unpack("B#{sha_list.size}")
      .first.split('')
      .map { |bit| bit == '1' ? :available : :unavailable }
  end

  def send_interested
    send_data("\x00\x00\x00\x01\x02")
  end

  def parse_have
    until @buffer.empty?
      @buffer.slice!(0..4)
      index = @buffer.slice!(0..3).unpack("N*").first
      @piece_index[index] = :available
    end
    send_interested
  end
  
  # because ruby.

  def parse_handshake
    @buffer.slice!(0..67) if hash_match?
  end

  def hash_match?
    @buffer.unpack("A*").first[28..47] == info_hash
  end

  # the negative 1 modifier is for factoring in the id

  def msg_len
    @buffer.slice!(0..3).unpack("N*").first - 1
  end

  def evaluate_index(master)
    if @piece_index.any? { |chunk| chunk == :available }
      @index = @piece_index.index(:available)
      if master[@index] == :free
        @piece_index[@index] = :downloading
        master[@index] = :downloading
      else
        @piece_index[@index] = :downloaded
        evaluate_index(master)
      end
      request_message
    end
  end

  def modify_index(master)
    master.each_with_index do |v,i|
      if v == :downloaded
        @piece_index[i] = :downloaded
      end
    end
  end

  def total_file_size
    @file_list.map { |file| file['length'] }.inject { |x,y| x + y }
  end

  def state(master, blocks)
    if @buffer.empty?
      recv_data
    elsif @buffer[0..3] == KEEP_ALIVE
      @buffer.slice!(0..3)
    else
      if @buffer[4]
        binding.pry if @buffer[4].bytes.first == 0
      end
      # p @buffer[0..3].unp@buack("C*")
      case @buffer[4]
      when INTERESTED
        @buffer.slice!(0..4)
        modify_index(master)
        evaluate_index(master)
      when HAVE
        parse_have
      when BITFIELD
        parse_bitfield
        send_interested if @buffer.empty?
      when PIECE
        @length = @buffer[0..3].unpack("N*").first + 4

        if @buffer.bytesize >= @length
          @buffer.slice!(0..12)
          # the metadata is sliced off.
          pack_buffer
          # that means the bytes for that block have been collected entirely.
          # the buffer becomes empty
          @offset += (@length - 13)
          puts "remaining blocks: #{data_remaining} index: #{@index + 1} peer: #{peer} current_piece: #{piece_size}"
          if data_remaining > 0
            if piece_size == @piece_len
              pack_file(master)
              evaluate_index(master)
            end
            request_message
          elsif (File.size('data') + piece_size) == total_file_size
            pack_file(master)
            File.open('data', 'w') { |io| io << '' }
          else
            request_message(total_file_size - (File.size('data') + piece_size))
          end
        else
          recv_data(@length)
        end
        # piece
      when CHOKE
        binding.pry
      when HANDSHAKE
        parse_handshake
      else
        # 
      end
    end
  end

  def data_remaining
    ((total_file_size - (File.size('data') + piece_size))) / BLOCK
  end

  def piece_size
    @block_map.join.bytesize
  end

  def pack_buffer
    @block_map << @buffer.slice!(0...@length)
  end

  def pack_file(master)
    data = @block_map.join
    if piece_verified?(data)
      IO.write('data', data, @index * @offset)
      master[@index] = :downloaded
      @piece_index[@index] = :downloaded
      @block_map = []
      @offset = 0
    else
      binding.pry
      # data not passed - clear block_map and revert changes to both master and piece indices
      # peer may also not be a good peer.
    end
  end

  def piece_verified?(data)
    Digest::SHA1.digest(data) == sha_list[@index]
  end

  def request_message(bytes=BLOCK)
    send_data(pack(13) + "\x06" + pack(@index) + pack(@offset) + pack(bytes))
  end

  def pack(i)
    [i].pack("I>")
  end
end