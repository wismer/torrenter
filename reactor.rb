module Torrenter
  class Reactor
    include Torrenter
    def initialize(peers, list_size, piece_length, file_list)
      @peers        = peers
      @master_index = Array.new(list_size) { false }
      @blocks       = piece_length / BLOCK
      @data_file    = File.open('data', 'a+')
      @file_list    = file_list
      @dormant      = []
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
      offset = 0
      @file_list.each do |file|
        length = file['length']
        offset += file['length']
        data = File.open("#{file['path'].join}", 'a+')
        data << IO.read("data", length, offset)
        data.close
      end
    end

    def total_file_size
      @file_list.map { |f| f['length'] }.inject { |x, y| x + y }
    end

    def download_pieces
      loop do
        break if @connected.all? { |peer| peer.status == :finished } # this will break when a peer is downloading the last piece. BAD.
        @connected.each do |peer|
          # needs to be specific...
          if peer.buffer.bytesize == (BLOCK + 13)
            # parse messages by the piece message length (or for have msgs)
            peer.block_map << peer.buffer.byteslice(13..-1)
            peer.buffer = ''
            puts "offset: #{peer.block_count * BLOCK} for #{peer.peer[:ip]} and the current piece is #{peer.current_piece} - file size is now at #{File.size('data') / 1024}"

            peer.block_count += 1
            peer.request_sent = false
          end

          if peer.block_map.size == @blocks
            peer.pack_data
            peer.request_sent = false
            peer.block_count = 0
            evaluate_index(peer)
            puts "#{peer.peer[:ip]} ---- current_piece: #{peer.current_piece}"
          end

          unless peer.status == :finished
            if peer.current_piece.nil?
              evaluate_index(peer)
            end

            if !peer.request_sent
              msg = if peer.block_count < @blocks
                      request_msg(peer.current_piece, peer.block_count * BLOCK)
                    else
                      raise "Current Piece: #{peer.current_piece} offset: #{peer.block_count * BLOCK}"
                      request_msg(peer.current_piece, 0)
                    end
              peer.socket.sendmsg(msg)
              peer.request_sent = true
            end

            # peek for other messages that may come through the pipeline

            peek_for_keep_alive(peer)
            
            data = buffered_data(peer)
            if data != ''
              peer.buffer << data
            end
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

      # msg = msg || BLOCK
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
      # rewrite - confusing - 
      # NEEDS TO BE CHANGED
      # it won't be an accurate method
      piece = peer.piece_index.index(true)
      if piece
        peer.current_piece = piece
        if @master_index[piece] == true
          # find a new one
          peer.piece_index[piece] = false
          evaluate_index(peer)
        else
          @master_index[piece] = true
        end
      else
        peer.status = :finished
        binding.pry
      end
    end

    def keep_alive
      @connected.each { |peer| peer.send_data(KEEP_ALIVE) }
    end

    def parse_bitfields
      @connected.each do |peer|
        peer.parse_bitfield
        @connected.delete(peer) if !peer.bitfield_pass?
      end
    end

    def empty_buffers
      @connected.each { |peer| peer.buffer = '' }
    end

    def delete_peer(peer)
      @dormant << @connected.delete(peer)
    end

    def msg_payload(peer, range=0)
      peer.buffer.slice!(range).unpack("C*").inject { |x,y| x + y }
    end

    def parse_handshakes
      @connected.each do |peer| 
        peer.hash_match? ? peer.shaken = true : @dormant << @connected.delete(peer)
      end
    end

    def parse_have_msgs
      @connected.each do |peer|
        if peer.buffer.empty?
          
    end
  end
end