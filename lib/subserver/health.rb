require 'socket'      # Sockets are in standard library

module Subserver
  class Health

    attr_accessor :server

    def initialize
      @server = TCPServer.new Subserver.options[:health_port] || 4081
    end

    def start
      begin
        logger.debug "Health check avalible on port #{@server.addr[1]}"
        while session = @server.accept
          request = session.gets

          session.print "HTTP/1.1 200\r\n" # 1
          session.print "Content-Type: text/html\r\n" # 2
          session.print "\r\n" # 3
          session.print "Subserver Online" #4
          session.close
        end
      rescue Errno::ECONNRESET, Errno::EPIPE => e
        puts e.message
        retry
      end
    end

    def stop
      @server.close
    end 

    def logger
      Subserver.logger
    end
  end
end 