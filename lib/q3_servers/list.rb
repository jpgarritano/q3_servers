# frozen_string_literal: true

require 'socket'
require 'date'

module Q3Servers
  class List
    PROTOCOL = 68
    MAX_LENGTH = 65_536

    attr_reader :master_socket, :threads, :servers, :favorites
    attr_accessor :cache, :timeout, :master_updated_at, :debug, :master_cache_secs, :info_cache_secs, :only_favorites,
                  :master_address, :master_port
    alias only_favorites? only_favorites
    alias cache? cache

    def initialize
      @master_socket = UDPSocket.new
      @servers = []
      @cache = true
      @timeout = 1
      @master_updated_at = nil
      @debug = false
      @master_cache_secs = 600
      @info_cache_secs = 60
      @favorites = []
      @master_port = 27_900
      @master_address = 'master.urbanterror.info' # 51.75.224.242
      @threads = []
    end

    def fetch_servers(filter = {}, use_threads: false)
      servers_list_from_master if master_server_outdated? && !only_favorites?
      fetch_info_servers(filter, use_threads)
    end

    def request_server_info(server, filter, use_threads)
      print_debug("INFO Server: Connecting to Server id => #{server.unique_index}")
      if use_threads
        thread_server_info(server, filter)
      else
        server.request_info
      end
    end

    def cached_info?(server)
      cache? && server_info?(server) && !server_info_outdated?(server)
    end

    def cached_status?(server)
      cache? && server_status?(server) && !server_status_outdated?(server)
    end

    def add_server(server)
      servers << server
    end

    def add_favorite(ip, port)
      favorites << new_favorite = Server.new(ip, port, {})
      add_server(new_favorite)
    end

    def favorite?(server)
      favorites.any? { |fav| server.unique_index == fav.unique_index }
    end

    private

    def thread_server_info(server, filter)
      @threads << Thread.new { get_server_info_status_filter(server, filter) }
    rescue ThreadError => e
      p "Can't create thread! => #{e.inspect}"
    end

    def get_server_info_status_filter(server, filter)
      server.get_info_connect
      server.request_and_get_status if server.filter_info(filter)
      server.info
    end

    def server_info?(server)
      !server.info.empty?
    end

    def server_status?(server)
      server_info?(server) && !server.info_status.empty?
    end

    def fill_list_favorites
      favorites.each do |fav|
        add_server(fav)
      end
    end

    def fill_list_master(response)
      response = response.unpack('CCCCA18Ca*')
      response = response[6]
      until response.empty?
        response = response.unpack('NnCa*')
        new_sv = Server.new(to_ip(response[0]), response[1], {}) # response[2] is \\ (EOT)
        add_server(new_sv)
        response = response[3] # prepare for next step
      end
      servers
    end

    def fetch_info_servers(filter, use_threads)
      servers.each do |server|
        cache_or_request_server_info(server, filter, use_threads)
      end
      # wait for "info servers"
      if use_threads
        @threads.each(&:join) # wait for threads
      else
        massive_read_info_status(servers, filter)
      end
      destroy_socket_servers
      servers.select { |server| server.filter_info(filter) }
    end

    def cache_or_request_server_info(server, filter, use_threads)
      if cached_info?(server)
        print_debug("INFO Server cached => #{server.unique_index}")
      else
        request_server_info(server, filter, use_threads)
      end
    end

    def servers_list_from_master
      servers.clear # #clean servers list
      print_debug("Connecting to master server: cache => #{cache} | timeout => #{timeout}")
      connect_request_master_socket
      response_all_servers = []
      loop do
        response_all_servers << master_socket.recvfrom(MAX_LENGTH).first
        size = response_all_servers.last.size
        print_debug(size)
        break if size < 1394
      end
      response_all_servers.each { |r_server| fill_list_master(r_server) } unless only_favorites?
      self.master_updated_at = DateTime.now
    end

    def print_debug(info)
      p info if @debug
    end

    def to_ip(decimal)
      [decimal].pack('N').unpack('CCCC').join('.')
    end

    def master_server_outdated?
      !master_updated_at or (DateTime.now > (master_updated_at + Rational(master_cache_secs, 86_400)))
    end

    def server_info_outdated?(server)
      (!server_info?(server) or (DateTime.now > (server.updated_at + Rational(info_cache_secs, 86_400))))
    end

    def server_status_outdated?(server)
      (!server_status?(server) or (DateTime.now > (server.status_updated_at + Rational(info_cache_secs, 86_400))))
    end

    def massive_read_info_status(servers, filter)
      massive_helper = MassiveHelper.new(servers.select(&:request_status?), self)
      alive_servers = massive_helper.read_info_servers(2, timeout) do |server|
        server.read_info unless cached_info?(server)
      end

      filtered_servers = alive_servers.select { |server| server.filter_info(filter) }
      filtered_servers.each(&:request_status)

      massive_helper.read_status_servers(filtered_servers, 2, timeout) do |server|
        server.read_status unless cached_status?(server)
      end
    end

    def destroy_socket_servers
      servers.each(&:destroy_socket)
    end

    def connect_request_master_socket
      master_socket.connect(master_address, master_port)
      master_socket.send("#{prepend_oob_data}getservers #{PROTOCOL} full empty", 0)
    end

    def prepend_oob_data
      "\xFF" * 4
    end
  end
end
