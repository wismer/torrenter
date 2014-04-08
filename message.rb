module Torrenter
  KEEP_ALIVE = "\x00\x00\x00\x00"
  BLOCK = 2**14
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
    end
  end

  def recv_data(bytes=BLOCK, opts={})
    begin
      if opts[:peek]
        Timeout::timeout(10) { @socket.recv_nonblock(4, Socket::MSG_PEEK) }
      else
        Timeout::timeout(10) { buffer << @socket.recv_nonblock(bytes) }
      end
    rescue Timeout::Error
      ''
    rescue Errno::EADDRNOTAVAIL
      ''
    rescue Errno::ECONNREFUSED
      ''
    rescue Errno::ECONNRESET
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

  def bitfield_msg
    @piece_index = buffer[1...msg_len].unpack("B#{sha_list.size}").join.map { |bit| bit == '1' }
  end

  def parse_bitfield
    @buffer = buffer[68..-1]
    bitfield_msg
    if !buffer.empty?
      parse_have
    else
      @bitfield = true
    end
  end

  def parse_have
    binding.pry
    if buffer.bytesize % 9 == 0
      buffer.each_byte(9) do |byte|
        if byte.unpack("N*").first == 4
        end
      end
    end
  end
  
  # because ruby.

  def hash_match?
    recv_data if buffer.empty?
    @buffer.unpack("A*").first[28..47] == info_hash
  end

  # the negative 1 modifier is for factoring in the id

  def msg_len
    @buffer.slice!(0..3).unpack("N*").first - 1
  end

  # def msg_id(buff)
  #   buff[0].unpack("N").first
  # end

  def payload(buff)
  end

  def pack(i)
    [i].pack("I>")
  end
end