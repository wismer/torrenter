module Torrenter
  # torrent reader should only read the torrent file and return either
  # a UDP tracker object or an HTTP tracker object
  class TorrentReader
    attr_reader :stream
    def initialize(stream)
      @stream = stream
    end

    def info_hash
      Digest::SHA1.digest(@stream['info'].bencode)
    end

    def sha_hashes
      @stream['info']['pieces']
    end

    def total_file_size
      file_list.is_a?(Array) ? multiple_file_size : file_list['length']
    end

    def multiple_file_size
      file_list.map { |file| file['length'] }.inject { |x,y| x + y }
    end

    def piece_length
      @stream['info']['piece length']
    end

    def file_list
      @stream['info']['files'] || @stream['info']
    end

    def announce_url
      @stream['announce']
    end

    def announce_list
      @stream['announce-list']
    end

    def url_list
      announce_list ? announce_list.flatten << announce_url : [announce_url]
    end

    def access_trackers
      url_list.map do |track|
        if track.include?("http://")
          HTTPTracker.new(track, @stream)
        else
          UDPTracker.new(track, @stream)
        end
      end
    end

    def peer_list(bytestring)
      bytestring.chars.each_slice(6).map do |peer_data|
        ip = peer_data[0..3].join('').bytes.join('.')
        port = peer_data[4..5].join('').unpack("S>").first
        Peer.new(ip, port, info_hash, piece_length)
      end
    end

    def unpack_data
      puts "ALL FINISHED! Transferring data into file(s)."
      @main_folder = $data_dump[/.+(?=\.torrent-data)/]
      create_folders

      if multiple_files?
        offset = 0
        file_list.each do |file|

          length = file['length']
          filename = file['path'].join("/")

          File.open("#{@main_folder}/#{filename}", 'a+') do |data|
            data << IO.read($data_dump, length, offset)
          end

          offset += length
        end
      else
        FileUtils.mkdir(@main_folder)
        File.open("#{@main_folder}/#{file_list['name']}", 'w') { |data| data << File.read($data_dump) }
      end
      File.delete($data_dump)
    end

    def create_folders
      if multiple_files?
        folders = sub_folders.map { |fold| fold['path'][0..-2].join("/") }.uniq
        folders.each { |folder| FileUtils.mkdir_p(@main_folder + "/#{folder}") }
      else
        FileUtils.mkdir(@main_folder)
      end
    end

    def sub_folders
      stream['info']['files'].select { |fold| fold['path'].length > 1 }
    end

    def multiple_sub_folders?(file)
      file['path'].length > 0
    end

    def multiple_files?
      file_list.is_a?(Array)
    end
  end
end
