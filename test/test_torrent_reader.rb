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
    assert_kind_of Array, @reader.access_trackers
  end

  def test_info_hash_length
    assert @reader.info_hash.length == 20
  end

  def test_sha_hash_list_is_of_correct_length
    assert @reader.sha_hashes.bytesize % 20 == 0
  end

  def test_piece_length
    assert_kind_of Integer, @reader.piece_length
  end

  def test_url_list_contains_udp_or_http_protocols
    assert @reader.url_list.all? { |str| str.include?('http://') || str.include?("udp://") }
  end

  def test_tracker_creation
    @reader.access_trackers.each do |tracker|
      assert_kind_of Torrenter::HTTPTracker || Torrenter::UDPTracker, tracker
    end
  end
end
