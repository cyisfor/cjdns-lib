require 'socket'
require 'ipaddress'

module CJDNS
  class Host
    attr_reader :ip, :cjdns

    # @param [String] ip
    # @param [CJDNS::Interface] cjdns
    # @param [Hash] options options for CJDNS::Interface
    def initialize(ip, cjdns = nil, options = {})
      # unshort ip
      @ip = IPAddress::IPv6.new(ip).address

      # connect to cjdns socket, unless given
      cjdns = CJDNS::Interface.new(options) unless cjdns
      @cjdns = cjdns
    end

    # checks if TCP port is open
    #
    # @param [Int] port
    # @param [Int] timeout
    # @return [Hash] { 'ms' => [Int] response_time }
    # @return [Boolean] false if host is not responding or port is closed
    def is_port_open?(port, timeout = 5)
      response = {}
      start = Time.new

      begin
        s = connect(port, timeout)
        return false unless s

        # retrieve banner (up to 40 chars)
        banner = s.recv(40) if IO.select([s], nil, nil, 1)
        response['banner'] = banner.chomp if banner

        s.close
      rescue Errno::EHOSTUNREACH, Errno::ETIMEDOUT, Errno::ECONNREFUSED, Errno::ENOTCONN
        return false
      end

      response['ms'] = (Time.new - start) * 1000
      return response
    end

    # TCP pings host (port 7)
    #
    # @param [Int] timeout
    # @return [Hash] { 'ms' => [Int] response_time }
    # @return [Boolean] false if host is not responding
    def ping_tcp(timeout = 5)
      start = Time.new

      begin
        s = connect(7, timeout)
        return false unless s
        s.close
      rescue Errno::ECONNREFUSED
        # connection refused means host is alive
      rescue Errno::EHOSTUNREACH, Errno::ETIMEDOUT
        return false
      end

      return { 'ms' => (Time.new - start) * 1000 }
    end

    # HTTP ping (port 80)
    #
    # @param [Int] timeout
    # @return [Hash] { 'ms' => [Int] response_time, 'title' => [String] html_title (if found) }
    # @return [Boolean] false if host is not replying to http
    def ping_http(timeout = 5)
      response = {}
      start = Time.new

      begin
        s = connect(80, timeout)
        return false unless s

        s.write "GET / HTTP/1.1\r\nHost: [#{@ip}]\r\nUser-Agent: cjdns-tool-#{CJDNS::Lib::VERSION}\r\nConnection: close\r\n\r\n"

        s.read.each_line do |line|
          line.force_encoding 'utf-8' unless RUBY_VERSION < '1.9'
          if md = (/<title>\s*(.*)\s*<\/title>/iu).match(line)
            response['title'] = md[1]
          end
        end

        s.close
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ETIMEDOUT, Errno::EPIPE, Errno::EINVAL
        return false
      end

      response['ms'] = (Time.new - start) * 1000
      return response
    end

    # cjdns internal ping
    #
    # @param [Int] timeout
    # @return [Hash] { 'ms' => [Int] response_time, 'version' => [String] cjdns_version }
    # @return [Boolean] false if host is not replying
    def ping_cjdns(timeout = 1)
      lookup
      response = @cjdns.ping_node(@ip, timeout * 1000)
      return false unless response['result'] == 'pong'
      response
    end

    # cjdns lookup
    #
    # @param [String] address
    # return [Boolean]
    def lookup
      return true if @cjdns.lookup(@ip)['error'] == 'none'
      false
    end


    private

    # use nonblocking socket to connect to port, respecting timeout
    #
    # @param [Int] port
    # @param [Int] timeout
    # @return [Socket] on success, nil on failure
    def connect(port, timeout = 5)
      s = Socket.open(Socket::AF_INET6, Socket::SOCK_STREAM, 0)

      begin
        s.connect_nonblock(Socket.sockaddr_in(port, @ip))
      rescue Errno::EINPROGRESS
        # block until the socket is ready, then try again
        IO.select([s], [s], [s], timeout)

        begin
          s.connect_nonblock(Socket.sockaddr_in(port, @ip))
        rescue Errno::EISCONN
          # already connected, do nothing
        rescue Errno::EINPROGRESS, Errno::EALREADY
          # connection still in progress, this means we timed out given
          # our IO.select has returned.
          s.close
          return nil
        rescue Errno::EINVAL, Errno::EACCES
          # invalid argument errors or permission denied errors
          # rise once in a while on the second connect, ignore
        end
      end
      s
    end

  end
end
