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
            piece_count = @master_index.count(:downloaded)
            if peer.status
              peer.state(@master_index, @blocks) # unless peer.piece_index.all? { |piece| piece == :downloaded }
              if @master_index.count(:downloaded) > piece_count
                system("clear")
                puts download_bar
              end
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

    def download_bar
      ("\u2588" * pieces(:downloaded)) + ("\u2593" * pieces(:downloading)) + (" " * pieces(:free)) + " %#{pieces(:downloaded)} downloaded"
    end

    def pieces(type)
      (@master_index.count(type).fdiv(@master_index.size) * 100).round
    end

    def free
      (@master_index.count(:free).fdiv(@master_index.size) * 100).round
    end

    def stop_downloading
      @peers.each { |peer| peer.piece_index.map { |piece| piece = :downloaded}}
    end

    def upload_data
      binding.pry
    end

    def seperate_data_dump_into_files
      if multiple_files?
        @file_list.each do |file|
          length  = @piece_length
          offset += file['length']
          filename   = file['name'] || file['path']
          File.open(filename, 'a+') { |data| data << IO.read($data_dump, length, offset) }
        end
      else
        File.open(@file_list['name'], 'w') { |data| data << File.read($data_dump) }
      end
    end

    def multiple_files?
      @file_list.is_a?(Array)
    end
  end
end