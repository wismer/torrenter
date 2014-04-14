module Torrenter
  class Reactor
    include Torrenter

    def initialize(peers, sha_list, piece_length, file_list)
      @peers        = peers
      @master_index = Array.new(sha_list.size) { :free }
      @blocks       = piece_length / BLOCK
      @file_list    = file_list
      @piece_length = piece_length
      @sha_list     = sha_list
    end

    def delayed_connect
      offset = 0
      @peers.map { |peer| [peer, Time.now + (offset+=100), ->(peer) { peer.connect }]}
    end

    # makes the peers connect


    # selects the peers that were able to connect

    def connected
      @peers.select { |peer| peer.socket }
    end

    def modify_index
      IO.write($data_dump, '', 0) unless File.exists?($data_dump)
      off = 0
      until off > total_file_size
        data = IO.read($data_dump, @piece_length, off) || ''
        index = off / @piece_length
        @master_index[index] = :downloaded if Digest::SHA1.digest(data) == @sha_list[index]
        off += @piece_length
      end
    end

    # sends the handshake messages.

    def message_reactor(opts={})
      modify_index
      @peers.each { |peer| peer.connect }
      loop do
        break if @master_index.all? { |piece| piece == :downloaded }
        @peers.each do |peer|

          if peer.status
            peer.state(@master_index, @blocks)
          elsif Time.now.to_i % 60 == 0
            peer.connect
          end
        end
      end

      seperate_data_dump_into_files
    end

    def seperate_data_dump_into_files
      offset = 0
      @file_list.each do |file|
        length = file['length']
        offset += file['length']
        data = File.open("#{file['path'].join}", 'a+')
        data << IO.read($data_dump, length, offset)
        data.close
      end
    end

    def total_file_size
      @file_list.map { |f| f['length'] }.inject { |x, y| x + y }
    end

    def keep_alive
      @connected.each { |peer| peer.send_data(KEEP_ALIVE) }
    end

    def parse_bitfields
      @connected.each do |peer|
        peer.parse_bitfield
        @connected.delete(peer) unless peer.bitfield
      end
    end

    def empty_buffers
      @connected.each { |peer| peer.buffer = '' }
    end
  end
end