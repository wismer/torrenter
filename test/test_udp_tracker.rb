require 'bencode'
require 'pry'
require 'digest/sha1'
require 'net/http'
require 'minitest/autorun'
require '../lib/torrenter/message/message_types.rb'
require '../lib/torrenter/torrent_reader.rb'
require '../lib/torrenter/udp_tracker.rb'
require '../lib/torrenter/http_tracker.rb'

class TestUDPTracker < Minitest::Test
  def setup
    file = BEncode.load_file('../thrones.torrent')
    @udp = Torrenter::UDPTracker.new('udp://someudp.com:80', file)
  end

  def test_instance_values
    assert_kind_of Integer, @udp.instance_variable_get(:@port)
    assert_kind_of UDPSocket, @udp.instance_variable_get(:@socket)
    assert_equal @udp.instance_variable_get(:@connection_id), [0x41727101980].pack("Q>")
    assert_equal @udp.instance_variable_get(:@url), 'someudp.com'
  end

  def test_action_message
    assert_equal @udp.action(0), [0].pack("I>")
  end

  def test_connect_message
  end
end