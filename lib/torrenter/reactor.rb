module Torrenter
  class Reactor < Torrenter::TorrentReader

    attr_accessor :master_index
    def initialize(peers, stream)
      super(stream)
      @peers         = peers
      @master_index  = Array.new(sha_hashes.bytesize / 20) { :free }
      @time_counter  = 0
      @time          = Time.now.to_i
      @byte_counter  = 0
    end

    def check_for_existing_data
      # if the torrent data file is not present, one will be created
      IO.write($data_dump, '', 0) unless File.file?($data_dump)

      0.upto(@master_index.size - 1) do |n|
        # this needs to get changed in order to account for 
        # the last piece not being equal to the piece_length
        data = IO.read($data_dump, piece_length, n * piece_length) || ''
        # binding.pry
        if verified?(n, data)
          @master_index[n] = :downloaded
          @byte_counter += data.bytesize
        end
      end
      puts "#{@master_index.count(:downloaded)} pieces downloaded"
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
      connect_peers

      puts "You are now connected to #{active_peers.size} peers."
      loop do
        break if finished?

        if Time.now.to_i - @time == 1
          @time_counter = 0
        end

        @time = Time.now.to_i

        active_peers.each_with_index do |peer, i|

          datasize = peer.current_size

          state = peer.state(@master_index, remaining) do |data, i|
            if verified?(i, data)
              @master_index[peer.index] = :downloaded
              @byte_counter += peer.piece_data.bytesize
              pack_piece(peer)
              peer.mark_complete
              piece_select(peer)
            end
          end

          current = peer.current_size - datasize
          if state == :interested
            peer.update_indices(@master_index)
            piece_select(peer)
          end

          if current > 0
            @time_counter += current
          end
        end
        reattempt_disconnected_peer if Time.now.to_i % 30 == 0

        show_status
      end
    end

    def piece_indices
      active_peers.select { |peer| peer.piece_index }
        .map { |peer| peer.piece_index }
    end

    def tally
      @master_index.map.with_index do |p,i| 
        p == :free ? piece_indices.map { |x| x[i] } : []
      end
    end

    def piece_select(peer, limit=1)
      # binding.pry if @master_index.count(:free) == 1

      piece_index = peer.piece_index
      @tally = tally
      index = nil

      loop do
        if limit == active_peers.size + 1
          index = piece_index.index(:free)
          break
        elsif index.is_a?(Integer)
          break
        end
        i = 0
        loop do
          break if i > piece_index.size - 1|| !index.nil?
          if @tally[i].count(:free) == limit && piece_index[i] == :free
            index = i
          else
            i += 1
          end
        end

        limit += 1 if index.nil?
      end

      if index
        @master_index[index] = :downloading
        peer.request_piece(index)
        return index
      end
    end

    def show_status
      if (Time.now.to_i - @time) == 1
        system('clear')
        puts "#{download_bar} \n Downloading #{$data_dump[/(.+)(?=torrent-data)/]}"\
             "at #{real} KB/sec #{data_remaining} MB remaining"\
      end
    end

    def remaining
      total_file_size - @byte_counter
    end

    def select_index(index)
      poo = @master_index.map.with_index do |peer,index|
        active_peers.map { |x| x.piece_index[index] }
      end
    end

    def peer_indices
      active_peers.map { |peer| peer.piece_index }
    end

    def data_remaining
      (total_file_size - @byte_counter).fdiv(1024).fdiv(1024).round(2)
    end

    def real
      @time_counter.fdiv(1024).round(1)
    end

    def reattempt_disconnected_peer
      disconnected_peers.sample.connect
    end

    def disconnected_peers
      @peers.select { |peer| !peer.connected? }
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
  end
end