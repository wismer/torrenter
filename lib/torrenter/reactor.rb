module Torrenter
  class Reactor < Torrenter::TorrentReader
    # include Torrenter
    attr_accessor :master_index
    def initialize(peers, stream)
      super(stream)
      @peers        = peers
      @master_index = Array.new(sha_hashes.bytesize / 20) { :free }
    end

    def check_for_existing_data
      # if the torrent data file is not present, one will be created
      IO.write($data_dump, '', 0) unless File.exists?($data_dump)
      file_size = File.size($data_dump)
      0.upto(@sha_list.size - 1) do |n|
        data = IO.read($data_dump, piece_length, n * piece_length) || ''
        @master_index[n] = :downloaded if hash_check?(n, data)
      end
      $update = { index: indices }
      puts "#{@master_index.count(:downloaded)} pieces are downloaded already."
    end

    def hash_check?(loc, piece)
      Digest::SHA1.digest(piece) == sha_hashes[loc * 20..(loc * 20) + 19]
    end

    # sends the handshake messages.

    def message_reactor
      modify_index
      if !@master_index.all? { |index| index == :downloaded }
        @peers.each { |peer| peer.connect if active_peers.size < 8 }
        puts "You are now connected to #{active_peers.size} peers."
        loop do
          break if @master_index.all? { |piece| piece == :downloaded }
          @peers.each do |peer|
            $update = { index: indices, peer_count: peer_data }
            piece_count = @master_index.count(:downloaded)

            if peer.status
              peer.state(@master_index, @blocks) # unless peer.piece_index.all? { |piece| piece == :downloaded }

              if @master_index.count(:downloaded) > piece_count
                system("clear")
                puts download_bar + "Downloading from #{active_peers.size} active peers"
              end
            else
              @peers.each { |peer| peer.connect if Time.now.to_i % 60 == 0 }
            end
          end
        end
      else
        # upload_data
      end
      seperate_data_dump_into_files
    end

    def piece_done?(peer)
      
    end

    def block_done?(peer)
      
    end

    def indices
      @master_index.map do |piece|
        if piece == :free
          0
        elsif piece == :downloaded
          1
        else
          get_status @master_index.index(piece)
        end
      end
    end

    def peer_data
      active_peers.map { |peer| "ip: #{peer.peer[:ip]} port:#{peer.peer[:port]}" }.join("\n")
    end

    def get_status(i)
      peer = @peers.find { |peer| peer.piece_index[i] == :downloading }
      (peer.buffer.bytesize + peer.piece_size).fdiv(@piece_length)
    end

    def active_peers
      @peers.select { |peer| peer.status }
    end

    def index_percentages
      active_peers.map do |peer|
        size = peer.buffer.bytesize + peer.piece_size
        [peer.index, (size.fdiv @piece_length) * 100]
      end
    end

    def download_bar
      ("\u2588" * pieces(:downloaded)) + ("\u2593" * pieces(:downloading)) + (" " * pieces(:free)) + " %#{pieces(:downloaded)} downloaded "
    end

    def pieces(type)
      (@master_index.count(type).fdiv(@master_index.size) * 100).round
    end

    def stop_downloading
      @peers.each { |peer| peer.piece_index.map { |piece| piece = :downloaded} }
    end

    def seperate_data_dump_into_files
      if multiple_files?
        offset = 0
        folder =  $data_dump[/.+(?=\.torrent-data)/] || FileUtils.mkdir($data_dump[/.+(?=\.torrent-data)/]).join
        @file_list.each do |file|

          length =  file['length']
          filename = file['path'].pop

          if multiple_sub_folders?(file)
            subfolders = file['path'].join("/")
            folder = folder + "/" + subfolders
            FileUtils.mkdir_p("#{folder}", force: true)
          end

          File.open("#{folder}/#{filename}", 'a+') { |data| data << IO.read($data_dump, length, offset) }
          
          offset += length
        end
      else
        File.open("#{folder}/#{@file_list['name']}", 'w') { |data| data << File.read($data_dump) }
      end
      File.delete($data_dump)
    end

    def multiple_sub_folders?(file)
      file['path'].size > 1
    end

    def multiple_files?
      @file_list.is_a?(Array)
    end
  end
end