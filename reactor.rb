module Torrenter
  BLOCK = 2**14
  class Reactor
    def initialize(peers, list_size, piece_length, file_list)
      @peers        = peers
      @messager     = Message::Messenger.new
      @master_index = Array.new(list_size) { false }
      @blocks       = piece_length / BLOCK
      @data_file    = File.open('data', 'a+')
      @file_list    = file_list
    end

    # makes the peers connect

    def connect
      @peers.each { |peer| peer.connect }
    end

    # selects the peers that were able to connect

    def connected
      @peers.select { |peer| peer.socket }
    end

    def send_interested
      @connected.each do |peer|
        interested(peer)
        int = begin
                Timeout::timeout(5) { peer.socket.read(5) }
              rescue Timeout::Error
                ''
              end
        if int == "\x00\x00\x00\x01\x01"
          peer.interest = true
        else
          @connected.delete(peer)
        end
      end
    end

    def interested(peer)
      @messager.interest(:send => true, :msg => "\x00\x00\x00\x01\x02", :socket => peer.socket)
    end

    # sends the handshake messages. 

    def message_reactor(opts={})
      @connected = connected
      puts "Parsing Handshakes"
      parse_handshakes until @connected.all? { |peer| peer.shaken }
      puts "Parsing bitfields"
      parse_bitfields  until @connected.all? { |peer| peer.bitfield }
      puts "Sending interested messages"
      send_interested
      puts "Now finally I am at the request phase. #{@connected.size}"
      empty_buffers
      download_pieces if @connected.size > 0
      seperate_data_dump_into_files
    end

    def seperate_data_dump_into_files
      
    end

    def total_file_size
      @file_list.map { |f| f['length'] }.inject { |x, y| x + y }
    end

    def download_pieces
      loop do
        @connected.each { |peer| @connected.delete(peer) if peer.status == :finished }
        break if File.size('data') == total_file_size # this will break when a peer is downloading the last piece. BAD.
        @connected.each do |peer|
          # needs to be specific...
          if peer.buffer.bytesize == (BLOCK + 13)
            put_buffered_data_into_block_map(peer)
          end
      
          if peer.block_map.size == @blocks
            completed_piece(peer)
          end

          if peer.current_piece.nil?
            evaluate_index(peer)
          end

          if !peer.request_sent
            send_request_message(peer)
          end

          peek_for_keep_alive(peer)

          data = buffered_data(peer)

          if data != ''
            peer.buffer << data
          end
          # I have to save the point at which it does not have a full block
          # and also save the index point. When either of them have been fulfilled
          # actions are taken to reset.
          # so basically, everytime "peer" is reiterated, the following has to happen
          # first, the peer "checks" to see if the "block_map" still contains missing blocks
          # if that's true, then further requests have to be made.
          # second, if the peer's buffer is incomplete (meaning, not enough bytes to qualify as a complete block)
          # then another request for data needs to be made until that qualification is met.
          # finally, if the peer's block_map has been completely "filled", then the data is done and the next piece 
          # can be evaluated.
        end
      end  
    end

    def put_buffered_data_into_block_map(peer)
      peer.block_map << peer.buffer.byteslice(13..-1)
      peer.buffer = ''
      # puts "offset: #{peer.block_count * BLOCK} for #{peer.peer[:ip]} and the current piece is #{peer.current_piece} - file size is now at #{File.size('data') / 1024}"

      peer.block_count += 1
      peer.request_sent = false
    end

    def completed_piece(peer)
      peer.pack_data
      peer.request_sent = false
      peer.block_count = 0
      evaluate_index(peer)
      puts "#{peer.peer[:ip]} ---- current_piece: #{peer.current_piece}"
    end

    def send_request_message(peer)
      msg = if peer.block_count < @blocks
              request_msg(peer.current_piece, peer.block_count * BLOCK)
            else
              request_msg(peer.current_piece, 0)
            end
      peer.socket.sendmsg(msg)
      peer.request_sent = true
    end

    def peek_for_keep_alive(peer)
      if peer.buffer == ''
        peek  = begin 
                  peer.socket.recv_nonblock(4, Socket::MSG_PEEK)
                rescue IO::EAGAINWaitReadable
                  ''
                rescue Errno::ECONNRESET
                  ''
                end
        if peek == "\x00\x00\x00\x00"
          peer.socket.recv_nonblock(4)
        end
      end
    end

    def buffered_data(peer)
      begin
        peer.socket.recv_nonblock(BLOCK + 13)
      rescue IO::EAGAINWaitReadable
        ''
      rescue Errno::ECONNRESET
        ''
      rescue Errno::EPIPE
        @master_index[peer.current_piece] = false
        @connected.delete(peer)
        @connected.each do |p| 
          index = p.orig_index
          p.piece_index[peer.current_piece] = true if index[peer.current_piece]
        end
        ''
      end
    end

    def offset(peer)
      peer.block_map.size * BLOCK
    end

    def request_msg(piece, off)
      [13].pack("I>") + "\x06" + [piece].pack("I>") + [off].pack("I>") + [BLOCK].pack("I>")
    end

    def evaluate_index(peer)
      # NEEDS TO BE CHANGED
      # it won't be an accurate method
      piece = peer.piece_index.index(true)
      peer.current_piece = piece
      if @master_index[piece]
        # find a new one
        peer.piece_index[piece] = false
      else
        @master_index[piece] = true
      end
    end

    def keep_alive
      @connected.each { |peer| peer.socket.sendmsg_nonblock("\x00\x00\x00\x00") }
    end

    def parse_bitfields
      @connected.each do |peer|
        loop do
          break if peer.buffer.empty?
          length  = msg_payload(peer, (0..3))
          if length == 0
            break
            # keep alive
            # do nothing.
          else
            if length > peer.buffer.bytesize
              binding.pry
            end
            id = msg_payload(peer)
            peer.payload(length, id)
            puts "ID: #{id} LENGTH: #{length} for peer: #{peer.peer[:ip]}"
          end
        end
        peer.bitfield = true
      end
    end

    def empty_buffers
      @connected.each { |peer| peer.buffer = '' }
    end

    def msg_payload(peer, range=0)
      peer.buffer.slice!(range).unpack("C*").inject { |x,y| x + y }
    end

    def parse_handshakes
      @connected.each do |peer|
        @messager.nonblock_read(:msg => BLOCK, :socket => peer.socket, :buffer => peer.buffer)

        if peer.hash_match?
          peer.shaken = true
          peer.buffer = peer.buffer.byteslice(68..-1)
        else
          @connected.delete(peer)
        end
      end
    end
  end
end