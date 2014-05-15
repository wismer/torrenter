require 'bencode'
require 'pry'
require 'digest/sha1'
require 'net/http'
require 'minitest/autorun'
require '../lib/torrenter/message/message_types.rb'
require '../lib/torrenter/torrent_reader.rb'
require '../lib/torrenter/udp_tracker.rb'
require '../lib/torrenter/http_tracker.rb'

class TestTorrentReader < Minitest::Test

  def setup
    file = BEncode.load_file('../sky.torrent')
    @reader = Torrenter::TorrentReader.new(file)
  end

  def test_stream_is_a_hash
    assert_kind_of Hash, @reader.stream
  end

  def test_lists_are_array
    assert_kind_of Array, @reader.url_list
    assert_kind_of Array, @reader.sha_hash_list
    assert_kind_of Array, @reader.trackers
  end

  def test_info_hash_length
    assert @reader.info_hash.length == 20
  end

  def test_sha_hash_list_is_of_correct_length
    assert @reader.sha_hash_list.all? { |sha| sha.length == 20 }
  end
end
