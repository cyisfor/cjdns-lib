require 'resolv'
require 'ipaddress'

module CJDNS
  class HypeDNS
    class HypeDNSError < StandardError; end

    attr_reader :nameserver

    # @param [String] nameserver (either ip, or 'via_internet' / 'via_cjdns' to use default)
    def initialize(nameserver = 'fc5d:baa5:61fc:6ffd:9554:67f0:e290:7535')
      @nameserver = nameserver
      @hypedns = Resolv::DNS.new(:nameserver => @nameserver)
      raise HypeDNSError, "#{nameserver} is not a valid hypedns nameserver" unless try
    end

    # get AAAA (ipv6) record of host
    #
    # @param [String] host
    # @return [String] ip, nil on failure
    def aaaa(host)
      begin
        @hypedns.getresource(host, Resolv::DNS::Resource::IN::AAAA).address.to_s.downcase
      rescue Resolv::ResolvError, SocketError
        return nil
      end
    end

    # get PTR record for ip
    #
    # @param [String] ip
    # @return [String] host, nil on failure
    def ptr(ip)
      begin
        return @hypedns.getname(ip).to_s
      rescue Resolv::ResolvError, SocketErroir
        return nil
      end
    end

    # resolv host unless it already a valid ipv6 address
    #
    # @param [String] host
    # @return [String] ip|host, nil on failure or if host = nil
    def aaaa_unless_ip(host = nil)
      return nil unless host

      if IPAddress.valid_ipv6? host
        return host
      else
        return aaaa(host)
      end
    end

    # try if hypedns is responding by trying to resolv 'nodeinfo.hype'
    #
    # @return [Boolean] true if hypedns is working, false if not
    def try(host = 'nodeinfo.hype')
      begin
        Timeout::timeout(5) do
          return true if aaaa(host)
        end
      rescue Timeout::Error
        return false
      end
    end

  end
end

