require 'bencode'

require 'cjdns-lib/interface'
require 'cjdns-lib/host'
require 'cjdns-lib/route'

module CJDNS
  class RoutingTable

    attr_reader :routes, :hosts

    # @param [CJDNS::Interface] cjdns
    # @param [Hash] options options for CJDNS::Interface
    def initialize(cjdns = nil, options = {})
      # connect to cjdns socket, unless given
      @cjdns = cjdns
      @cjdns = CJDNS::Interface.new(options) unless @cjdns

      # populate routes
      @routes = []
      @cjdns.dump_table.each do |route|
        @routes << Route.new(self, route['ip'], route['path'], route['link'])
      end

      # populate hosts
      @hosts = []
      @routes.each do |r|
        next unless r.link > 0
        next unless @hosts.select { |h| h.ip == r.ip }.length == 0
        @hosts << Host.new(r.ip, cjdns)
      end
    end

    # get all routes (for host)
    #
    # @param [String] host get routes to this host only
    # @param [Int] max_hops only get routes with up to max_hops hops
    def get_routes(host = nil, max_hops = nil)
      routes = {}
      @routes.each do |r|
        # skip if not requested (unshorten before test)
        next if host and IPAddress::IPv6.new(host).address != r.ip
        next unless r.link > 0 # skip dead links
        hops = r.get_hops

        # skip if not enough hops
        next if max_hops and hops.length > max_hops

        hops << r # add target as last hop
        routes[r.ip] ||= []
        routes[r.ip] << hops
      end

      routes
    end

    # get all hosts
    #
    # @param [Int] max_hops only get hosts with up to max_hops hops
    def get_hosts(max_hops = nil)
      hosts = []

      # get_routes takes a long time, only use it if max_hops is given
      if max_hops and max_hops < 9999
        routes = get_routes(nil, max_hops)
      else
        routes = {}
        @routes.each { |r| routes[r.ip] ||= [] }
      end

      routes.each do |ip, route|
        hosts << Host.new(ip, @cjdns) if hosts.select { |h| h.ip == ip }.empty?
      end
      hosts
    end
  end
end
