module Torrenter
  class Server
    def initialize
      @server = TCPServer.new
    end
  end
end
