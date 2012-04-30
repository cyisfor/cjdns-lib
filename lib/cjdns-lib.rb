require 'rubygems'
require 'bencode'
require 'socket'
require 'digest'
require 'cjdns-lib/version'

module Cjdns
  class Lib

    def initialize(options = {})
      options = { 'host' => 'localhost', 'port' => 11234, 'password' => nil, 'debug' => false }.merge options

      @password = options['password']
      @debug = options['debug']

      puts "connecting to #{options['host']}:#{options['port']}" if @debug
      @socket = TCPSocket.open(options['host'], options['port'])
      raise "#{host}:#{port} doesn't appear to be a cjdns socket" unless ping_self
    end

    def ping_self
      return false unless auth_send('ping')['q'] == 'pong'
      true
    end

    def memory
      return auth_send('memory')['bytes']
    end

    def ping_node(path, timeout = 5000)
      response = auth_send('RouterModule_pingNode', { 'path' => path, 'timeout' => timeout } )
      return response['ms'] if response['result'] == 'pong'
      false
    end

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

    def ping_switch(path, data = 'x', timeout = 5000)
      response = auth_send('SwitchPinger_ping', { 'path' => path,
                                                  'data' => data,
                                                  'timeout' => timeout } )

      return response['ms'] if response['result'] == 'pong'
      false
    end

    def lookup(address)
      return auth_send('RouterModule_lookup', { 'address' => address } )
    end

    def authorized_passwords_add(password, auth_type = 1)
      return auth_send('AuthorizedPasswords_add', { 'password' => password,
                                                    'authType' => auth_type } )
    end

    def authorized_passwords_flush
      return auth_send('AuthorizedPasswords_flush')
    end

    def scramble_keys(xor_value)
      return auth_send('UDPInterface_scrambleKeys', { 'xorValue' => xor_value } )
    end

    def begin_connection(public_key, address, password = nil)
      return auth_send('UDPInterface_beginConnection', { 'publicKey' => public_key,
                                                         'address' => address,
                                                         'password' => password } )
    end


    private

    def auth_send(funcname, args = nil)
      txid = rand(10000000000).to_s

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
      raise 'wrong txid in reply' unless response['txid'] == txid
      response 
    end

    def get_cookie
      txid = rand(10000000000).to_s
      response = send('q' => 'cookie', 'txid' => txid)
      raise 'wrong txid in reply' unless response['txid'] == txid
      response['cookie']
    end

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
