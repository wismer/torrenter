module Torrenter
  class Reactor < Torrenter::TorrentReader
    # include Torrenter
    attr_accessor :master_index, :bytes_remaining
    def initialize(peers, stream)
      super(stream)
      @peers         = peers
      @master_index  = Array.new(sha_hashes.bytesize / 20) { :free }
    end

    def check_for_existing_data
      # if the torrent data file is not present, one will be created
      IO.write($data_dump, '', 0) unless File.exists?($data_dump)

      0.upto(@master_index.size - 1) do |n|
        data = IO.read($data_dump, piece_length, n * piece_length) || ''
        @master_index[n] = :downloaded if verified?(n, data)
      end

      @bytes_remaining = total_file_size - File.size($data_dump)
    end

    def verified?(loc, piece)
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
        @counter = 0
        @time = Time.now.to_i

        puts "You are now connected to #{active_peers.size} peers."
        loop do
          break if finished?

          if Time.now.to_i - @time == 1
            @counter = 0
          end

          @time = Time.now.to_i

          @peers.each do |peer|
            peer.remaining = remaining

            datasize = peer.current_size

            peer.state(@master_index) if peer.connected?

            current = peer.current_size - datasize

            if current > 0
              @counter += current
            end

            if peer.index
              if verified?(peer.index, peer.piece_data)
                # piece gets committed to the data dump
                pack_piece(peer)
                # pick new pieces
                index_select(peer)
                # request the next piece
                peer.request_piece(@master_index)
              end
            end
          end
          reattempt_disconnected_peers if Time.now.to_i % 300 == 0

          show_status
        end
      end
      seperate_data_dump_into_files
    end

    def show_status
      if (Time.now.to_i - @time) == 1
        system('clear')
        puts "#{download_bar} \n Downloading #{$data_dump[/(.+)(?=torrent-data)/]} at #{real} KB/sec with #{pieces_left} pieces left to download"
        puts "and #{data_remaining} MB remaining"
      end
    end

    def remaining
      total_file_size - File.size($data_dump)
    end

    def data_remaining
      (total_file_size - File.size($data_dump)).fdiv(1024).fdiv(1024).round(2)
    end

    def pieces_left
      @master_index.count(:free)
    end

    def real
      @counter.fdiv(1024).round(1)
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

    def seperate_data_dump_into_files
      folder = $data_dump[/.+(?=\.torrent-data)/]

      if multiple_files?
        offset = 0

        file_list.each do |file|

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
        FileUtils.mkdir("#{folder}")
        File.open("#{folder}/#{file_list['name']}", 'w') { |data| data << File.read($data_dump) }
      end
      File.delete($data_dump)
    end

    def multiple_sub_folders?(file)
      file['path'].size > 1
    end

    def multiple_files?
      file_list.is_a?(Array)
    end
  end
end