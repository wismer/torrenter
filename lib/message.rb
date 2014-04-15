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
        Timeout::timeout(2) { buffer << @socket.recv_nonblock(bytes) }
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
    len = msg_len
    buffer.slice!(0)
    @piece_index = buffer.slice!(0...len).unpack("B#{sha_list.size}")
      .first.split('')
      .map { |bit| bit == '1' ? :available : :unavailable }
  end

  def send_interested
    send_data("\x00\x00\x00\x01\x02")
  end

  def parse_have
    if buffer[5..8].bytesize == 4
      index = buffer[5..8].unpack("N*").first
      @piece_index[index] = :available
      buffer.slice!(0..8)
    else
      recv_data
    end
    send_interested if @buffer.empty?
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
    @requesting = 0
    if @piece_index.any? { |chunk| chunk == :available }
      @index = @piece_index.index(:available)
      if master[@index] == :free
        @piece_index[@index] = :downloading
        master[@index] = :downloading
      else
        @piece_index[@index] = :downloaded
        evaluate_index(master)
      end
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
    @buffer_state = @buffer[4]
    if buffer.bytesize <= 3 
      recv_data
    elsif buffer.bytesize == 4 && buffer[0..3] == KEEP_ALIVE
      buffer.slice!(0..3)
    else
      # p @buffer[0..3].unp@buack("C*")
      case @buffer[4]
      when INTERESTED
        buffer.slice!(0..4)
        modify_index(master)
        evaluate_index(master)
        request_message
      when HAVE
        parse_have
      when BITFIELD
        parse_bitfield
        send_interested if buffer.empty?
      when PIECE
        @length = buffer[0..3].unpack("N*").first + 4
        if buffer.bytesize >= @length

          buffer.slice!(0..12)
          # the metadata is slireced off.
          @offset += (@length - 13)
          # buffer is reduced
          pack_buffer
          # that means the bytes for that block have been collected entirely.
          # the buffer becomes empty
          puts "remaining blocks: #{data_remaining} index: #{@index + 1} peer: #{peer} current_piece: #{offset} count: #{@requesting}"
          if data_remaining > 0
            if piece_size == @piece_len
              pack_file(master)
              evaluate_index(master)
              request_message
            else
              request_message
            end
          elsif (File.size($data_dump) + piece_size) == total_file_size
            pack_file(master)
            File.open($data_dump, 'w') { |io| io << '' }
          else
            request_message(total_file_size - (File.size($data_dump) + piece_size))
          end
        else
          recv_data(@length - buffer.bytesize)
        end
        # piece
      when CHOKE
        buffer.slice!(0..3)
        send_interested
      when HANDSHAKE
        parse_handshake
      end
    end
  end

  def data_remaining
    ((total_file_size - (File.size($data_dump) + piece_size))) / BLOCK
  end

  def piece_size
    @block_map.join.bytesize
  end

  def pack_buffer
    @block_map << @buffer.slice!(0...(@length - 13))
  end

  def pack_file(master)
    data = @block_map.join
    if piece_verified?(data)
      p 'piece passed.'
      IO.write($data_dump, data, @index * @offset)
      master[@index] = :downloaded
      @piece_index[@index] = :downloaded
    else
      master[@index] = :free
      @piece_index[@index] = :downloaded

      # data not passed - clear block_map and revert changes to both master and piece indices
      # peer may also not be a good peer.
    end
    @block_map = []
    @offset = 0
  end

  def piece_verified?(data)
    Digest::SHA1.digest(data) == sha_list[@index]
  end

  def request_message(bytes=BLOCK)
    @requesting += 1
    send_data(pack(13) + "\x06" + pack(@index) + pack(@offset) + pack(bytes))
  end

  def pack(i)
    [i].pack("I>")
  end
end