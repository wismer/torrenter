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
    end

    def modify_index
      IO.write($data_dump, '', 0) unless File.exists?($data_dump)
      file_size = File.size($data_dump)
      0.upto(@sha_list.size - 1) do |n|
        data = IO.read($data_dump, @piece_length, n * @piece_length) || ''
        @master_index[n] = :downloaded if Digest::SHA1.digest(data) == @sha_list[n]
      end
      $update = @master_index
      puts "#{@master_index.count(:downloaded)} pieces are downloaded already."
    end

    # sends the handshake messages.

    def message_reactor(opts={})
      modify_index
      if !@master_index.all? { |index| index == :downloaded }
        @peers.each { |peer| peer.connect }
        puts "You are now connected to #{active_peers} peers."
        loop do
          break if @master_index.all? { |piece| piece == :downloaded }
          @peers.each do |peer|
            piece_count = @master_index.count(:downloaded)
            if peer.status
              peer.state(@master_index, @blocks) # unless peer.piece_index.all? { |piece| piece == :downloaded }
              if @master_index.count(:downloaded) > piece_count
                send_post
                system("clear")
                puts download_bar + "Downloading from #{active_peers} active peers"
              end
            elsif Time.now.to_i % 60 == 0
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

    def send_post
      $update = @master_index
      # http = Net::HTTP.new("localhost", 4567)
      # http.post("/filer", JSON.generate({:index => @master_index}))
    end

    def active_peers
      @peers.select { |peer| peer.status }.size
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
        File.open("#{folder}/#{@file_list['name'].join}", 'w') { |data| data << File.read($data_dump) }
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