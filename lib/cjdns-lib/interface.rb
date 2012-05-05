require 'rubygems'
require 'bencode'
require 'socket'
require 'digest'

module CJDNS
  class Interface

    # @option options [String] host
    # @option options [Int] port
    # @option options [String] password
    # @option options [Boolean] debug
    # @raise [RuntimeError] if socket is not a valid cjdns socket
    def initialize(options = {})
      options = { 'host' => 'localhost', 'port' => 11234, 'password' => nil, 'debug' => false }.merge options

      @password = options['password']
      @debug = options['debug']

      puts "connecting to #{options['host']}:#{options['port']}" if @debug
      @socket = TCPSocket.open(options['host'], options['port'])
      raise "#{host}:#{port} doesn't appear to be a cjdns socket" unless ping_self
    end

    # @return [Boolean] true if cjdns socket replies
    def ping_self
      return false unless auth_send('ping')['q'] == 'pong'
      true
    end

    # @return [Int] bytes
    def memory
      return auth_send('memory')['bytes']
    end

    # @param [String] path to node
    # @param [Int] timeout
    def ping_node(path, timeout = 5000)
      response = auth_send('RouterModule_pingNode', { 'path' => path, 'timeout' => timeout } )
      return response['ms'] if response['result'] == 'pong'
      false
    end

    # @return [Hash] routing table
    def dump_table
      page = 0
      routing_table = []
      begin
        response = auth_send('NodeStore_dumpTable', 'page' => page)

        # add received routing table
        routing_table = routing_table + response['routingTable']

        # if 'more' is set, there's more data to come, request next page
        page += 1
      end while response['more']

      routing_table
    end

    # @param [String] path
    # @param [String] data
    # @param [Int] timeout
    # @return [Boolean] true if path socket replies
    def ping_switch(path, data = 'x', timeout = 5000)
      response = auth_send('SwitchPinger_ping', { 'path' => path,
                                                  'data' => data,
                                                  'timeout' => timeout } )

      return response['ms'] if response['result'] == 'pong'
      false
    end

    # @param [String] address
    # @return [Hash]
    def lookup(address)
      return auth_send('RouterModule_lookup', { 'address' => address } )
    end

    # @param [String] password
    # @param [Int] auth_type
    # @return [Hash]
    def authorized_passwords_add(password, auth_type = 1)
      return auth_send('AuthorizedPasswords_add', { 'password' => password,
                                                    'authType' => auth_type } )
    end

    # @return [Hash]
    def authorized_passwords_flush
      return auth_send('AuthorizedPasswords_flush')
    end

    # @param [String] xor_value
    # @return [Hash]
    def scramble_keys(xor_value)
      return auth_send('UDPInterface_scrambleKeys', { 'xorValue' => xor_value } )
    end

    # @param [String] publicKey
    # @param [String] address
    # @param [String] password
    # @return [Hash]
    def begin_connection(public_key, address, password = nil)
      return auth_send('UDPInterface_beginConnection', { 'publicKey' => public_key,
                                                         'address' => address,
                                                         'password' => password } )
    end


    private

    # send an authenticated 'funcname' request to the admin interface
    #
    # @param [String] funcname
    # @param [Hash] args
    # @return [Hash]
    def auth_send(funcname, args = nil)
      txid = rand(36**8).to_s(36)

      # setup authenticated request if password given
      if @password
        cookie = get_cookie

        request = {
          'q' => 'auth',
          'aq' => funcname,
          'hash' => Digest::SHA256.hexdigest(@password + cookie),
          'cookie' => cookie,
          'txid' => txid
        }

        request['args'] = args if args
        request['hash'] = Digest::SHA256.hexdigest(request.bencode)

      # if no password is given, try request without auth
      else
        request = { 'q' => funcname, 'txid' => txid }
        request['args'] = args if args
      end

      response = send request
      raise 'wrong txid in reply' if response['txid'] and response['txid'] != txid
      response
    end

    # get a cookie from server
    #
    # @return [String]
    def get_cookie
      txid = rand(36**8).to_s(36)
      response = send('q' => 'cookie', 'txid' => txid)
      raise 'wrong txid in reply' if response['txid'] and response['txid'] != txid
      response['cookie']
    end

    # send a request to the admin interface
    #
    # @param [Hash] request
    # @return [Hash]
    def send(request)
      # clear socket
      puts "flushing socket" if @debug
      @socket.flush

      puts "sending request: #{request.inspect}" if @debug
      response = ''
      @socket.puts request.bencode

      while r = @socket.recv(1024)
        response << r
        break if r.length < 1024
      end

      puts "bencoded reply: #{response.inspect}" if @debug
      response = response.bdecode

      puts "bdecoded reply: #{response.inspect}" if @debug
      response
    end
  end
end
