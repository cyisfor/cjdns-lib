module CJDNS
  class Route
    attr_reader :path, :ip, :link, :quality, :routing_table

    # @param [CJDNS::RoutingTable] routing_table
    # @param [String] ip
    # @param [String] path
    # @param [String] link
    def initialize(routing_table, ip, path, link)
      @routing_table = routing_table
      @ip = ip
      @link = link

      # convert path to binary
      @path = path.gsub('.','').hex.to_s(2)

      # calculate quality using LINK_STATE_MULTIPLIER
      @quality = @link / 5366870.0
    end

    # get all possible routes to a host
    #
    # @return [Hash] routes
    def get_hops
      hops = []
      @routing_table.routes.each do |r|
        # for more information, read the switch section in the whitepaper
        next if self == r
        next unless @path.end_with? r.path[1..-1]
        hops << r
      end

      # puts hops in right order
      hops.sort_by { |h| h.path.to_i }
    end
  end
end
