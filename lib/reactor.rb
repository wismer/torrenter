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
      @data_size    = if file_list.is_a?(Array)
                        file_list.map { |f| f['length'] }.inject { |x, y| x + y }
                      else
                        file_list['length']
                      end
      # @server       = TCPServer.new("127.0.0.1", 28561)
    end


    # makes the peers connect


    # selects the peers that were able to connect


    def modify_index
      IO.write($data_dump, '', 0) unless File.exists?($data_dump)
      file_size = File.size($data_dump)
      0.upto(@sha_list.size - 1) do |n|
        data = IO.read($data_dump, @piece_length, n * @piece_length) || ''
        @master_index[n] = :downloaded if Digest::SHA1.digest(data) == @sha_list[n]
      end
      puts "#{@master_index.count(:downloaded)} pieces are downloaded already."
    end

    # sends the handshake messages.

    def message_reactor(opts={})
      modify_index
      if !@master_index.all? { |index| index == :downloaded }
        @peers.each { |peer| peer.connect }
        loop do
          break if @master_index.all? { |piece| piece == :downloaded }
          @peers.each do |peer|
            if peer.status
              peer.state(@master_index, @blocks) # unless peer.piece_index.all? { |piece| piece == :downloaded }
            elsif Time.now.to_i % 500 == 0
              peer.connect
            end
          end
        end
        stop_downloading
        seperate_data_dump_into_files
      else
        upload_data
      end
    end

    def stop_downloading
      @peers.each { |peer| peer.piece_index.map { |piece| piece = :downloaded}}
    end

    def upload_data
      binding.pry
    end

    def display_state
      File.open('data.json', 'w') { |io| io << JSON.generate( { indices: @master_index } ) }
    end

    def seperate_data_dump_into_files
      binding.pry
      offset = 0
      @file_list.each do |file|
        length  = @piece_length
        offset += file['length']
        filename   = file['name'] || file['path'].join
        File.open(filename, 'a+') { |data| data << IO.read($data_dump, length, offset) }
      end
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