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

      0.upto(@master_index.size - 1) do |n|
        data = IO.read($data_dump, piece_length, n * piece_length) || ''
        @master_index[n] = :downloaded if piece_match?(n, data)
      end

      puts "#{@master_index.count(:downloaded)} pieces are downloaded already."
    end

    def piece_match?(loc, piece)
      Digest::SHA1.digest(piece) == sha_hashes[loc * 20..(loc * 20) + 19]
    end

    def finished?
      @master_index.all? { |index| index == :downloaded }
    end

    def connect_peers
      @peers.each { |peer| peer.connect if active_peers.size < 8 }
    end

    # sends the handshake messages.

    def message_reactor
      if !finished?

        connect_peers
        
        puts "You are now connected to #{active_peers.size} peers."
        loop do
          time = Time.now.to_i
          bench = download_data
          break if finished?
          @peers.each do |peer|
            peer.state(@master_index) if peer.connected?

            if peer.full_piece? && piece_match?(peer.index, peer.piece_data)
              # piece gets committed to the data dump
              pack_piece(peer)
              # pick new pieces
              index_select(peer)

              peer.request_piece(@master_index)

              # puts "#{@master_index.count(:downloaded)} pieces downloaded so far."
            end
          end


          reattempt_disconnected_peers if Time.now.to_i % 300 == 0
          if (Time.now.to_i - time) == 1
            rates = bench.map.with_index do |r,i|
              rate(r, i)
            end
            system('clear')
            puts "#{rates.inject { |x,y| x + y }.round(1)} KB/sec"
            # download_data.each_with_index do |r,i|
            #   p (r - rates[i]).fdiv(1000)
            # end
            # i = 0
            # rate = (download_data[i] - rates[i]).fdiv(1000)
          end
        end
      end
      seperate_data_dump_into_files
    end

    def rate(r, i)
      ((active_peers[i].piece_data.bytesize + active_peers[i].buffer.bytesize) - r).fdiv(1000)
    end

    def download_data
      active_peers.map { |peer| peer.blocks.join('').bytesize }
    end

    def reattempt_disconnected_peers
      disconnected_peers.each { |peer| peer.connect }
    end

    def disconnected_peers
      @peers.select { |peer| !peer.connected? }
    end

    def index_select(peer)
      @master_index[peer.index] = :downloaded
    end

    # def piece_match?(peer)
    #   Digest::SHA1.digest(peer.buffer_state) == sha_hashes[peer.index * 20..(peer.index * 20) + 19]
    # end

    def pack_piece(peer)
      IO.write($data_dump, peer.piece_data, piece_length * peer.index)
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

    def get_status(i)
      peer = @peers.find { |peer| peer.piece_index[i] == :downloading }
      (peer.buffer.bytesize + peer.piece_size).fdiv(@piece_length)
    end

    def active_peers
      @peers.select { |peer| peer.peer_state }
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