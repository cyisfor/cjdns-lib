require 'rubygems'
require 'bencode'
require 'socket'
require 'digest'
require 'cjdns-lib/version'

module Cjdns
  class Lib

    def initialize(options = {})
      options = { 'host' => 'localhost', 'port' => 11234, 'password' => nil }.merge options

      @password = options['password']
      @socket = TCPSocket.open(options['host'], options['port'])
      raise "#{host}:#{port} doesn't appear to be a cjdns socket" unless ping_self
    end

    def ping_self
      return false unless auth_send('ping')['q'] == 'pong'
      true
    end

    def memory
      begin
        return auth_send('memory')['bytes']
      rescue RuntimeError
        return false
      end
    end

    def ping_node(path, timeout = 5000)
      begin
        response = auth_send('RouterModule_pingNode', { 'path' => path, 'timeout' => timeout } )
        rescue RuntimeError
        return false
      end

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
      begin
        response = auth_send('SwitchPinger_ping', { 'path' => path,
                                                    'data' => data,
                                                    'timeout' => timeout } )
      rescue RuntimeError
        return false
      end

      return response['ms'] if response['result'] == 'pong'
      false
    end

    def lookup(address)
      begin
        return auth_send('RouterModule_lookup', { 'address' => address } )['result']
      rescue RuntimeError
        return false
      end
    end

    def authorized_passwords_add(password, auth_type = 1)
      begin
        return auth_send('AuthorizedPasswords_add', { 'password' => password,
                                                      'authType' => auth_type } )
        rescue RuntimeError
        return false
      end
    end

    def authorized_passwords_flush
      begin
        return auth_send('AuthorizedPasswords_flush')
        rescue RuntimeError
        return false
      end
    end

    def scramble_keys(xor_value)
      begin
        return auth_send('UDPInterface_scrambleKeys', { 'xorValue' => xor_value } )
        rescue RuntimeError
        return false
      end
    end

    def begin_connection(public_key, address, password = nil)
      begin
        return auth_send('UDPInterface_beginConnection', { 'publicKey' => public_key,
                                                           'address' => address,
                                                           'password' => password } )
        rescue RuntimeError
        return false
      end
    end


    private

    def auth_send(funcname, args = nil)
      # setup authenticated request if password given
      if @password
        cookie = get_cookie

        request = {
          'q' => 'auth',
          'aq' => funcname,
          'hash' => Digest::SHA256.hexdigest(@password + cookie),
          'cookie' => cookie
        }

        request['args'] = args if args
        request['hash'] = Digest::SHA256.hexdigest(request.bencode)

      # if no password is given, try request without auth
      else
        request = { 'q' => funcname }
        request['args'] = args if args
      end

      send(request)
    end

    def get_cookie
      send('q' => 'cookie')['cookie']
    end

    def send(request)
      response = ''
      @socket.puts request.bencode

      while r = @socket.recv(1024)
        response << r
        break if r.length < 1024
      end

      response = response.bdecode
      raise response['error'] if response['error']
      response
    end
  end
end