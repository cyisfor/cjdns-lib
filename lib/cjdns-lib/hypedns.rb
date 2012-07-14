require 'resolv'
require 'ipaddress'

module CJDNS
  class HypeDNS

    # @param [String] nameserver (either ip, or 'via_internet' / 'via_cjdns' to use default)
    def initialize(nameserver = 'fc5d:baa5:61fc:6ffd:9554:67f0:e290:7535')
      @hypedns = Resolv::DNS.new(:nameserver => nameserver)
    end

    # get AAAA (ipv6) record of host
    #
    # @param [String] host
    # @return [String] ip, nil on failure
    def aaaa(host)
      return nil if @disabled

      begin
        @hypedns.getresource(host, Resolv::DNS::Resource::IN::AAAA).address.to_s.downcase
      rescue Resolv::ResolvError
        return nil
      end
    end

    # get PTR record for ip
    #
    # @param [String] ip
    # @return [String] host, nil on failure
    def ptr(ip)
      return nil if @disabled

      begin
        return @hypedns.getname(ip).to_s
      rescue Resolv::ResolvError
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
        return aaaa host
      end
    end

  end
end

