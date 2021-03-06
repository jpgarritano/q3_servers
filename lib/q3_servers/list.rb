# frozen_string_literal: true

require 'socket'
require 'date'
require 'logger'

module Q3Servers
  class List
    PROTOCOL = 68
    MAX_LENGTH = 65_536

    attr_reader :master_socket, :threads, :servers, :favorites
    attr_accessor :cache, :timeout, :master_updated_at, :debug, :logger, :master_cache_secs, :info_cache_secs, :only_favorites,
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
      @logger = Logger.new(STDOUT)
    end

    def fetch_servers(filter = {}, use_threads = false)
      servers_list_from_master if master_server_outdated? && !only_favorites?
      fetch_info_servers(filter, use_threads)
    end

    def cached_info?(server)
      cache? && server.info? && !server_info_outdated?(server)
    end

    def cached_status?(server)
      cache? && server.info_status? && !server_status_outdated?(server)
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

    def thread_server_info_status(server, filter)
      @threads << Thread.new { get_server_info_status_filter(server, filter) }
    rescue ThreadError => e
      p "Can't create thread! => #{e.inspect}"
    end

    def get_server_info_status_filter(server, filter)
      unless cached_info?(server)
        print_debug("INFO Server: Connecting to Server id => #{server.unique_index}")
        server.request_info
        server.read_info
      end
      server.request_and_get_status if server.filter_info(filter) && !cached_status?(server)
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
      if use_threads
        servers.each { |server| thread_server_info_status(server, filter) }
        @threads.each(&:join) # wait for threads
      else
        massive_read_info_status(servers, filter)
      end
      
      destroy_socket_servers
      servers.select { |server| server.filter_info(filter) }
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
      logger.info(info) if @debug
    end

    def to_ip(decimal)
      [decimal].pack('N').unpack('CCCC').join('.')
    end

    def master_server_outdated?
      !master_updated_at or (DateTime.now > (master_updated_at + Rational(master_cache_secs, 86_400)))
    end

    def server_info_outdated?(server)
      (!server.info? or (DateTime.now > (server.updated_at + Rational(info_cache_secs, 86_400))))
    end

    def server_status_outdated?(server)
      (!server.info_status? or (DateTime.now > (server.status_updated_at + Rational(info_cache_secs, 86_400))))
    end

    def massive_read_info_status(servers, filter)
      logger_object = debug ? logger : nil
      requested_servers = servers.reject { |server| cached_info?(server) }

      requested_servers.each do |not_cached_server|
        print_debug("INFO Server: Connecting to Server id => #{not_cached_server.unique_index}")
        not_cached_server.request_info
      end

      massive_helper = MassiveHelper.new(requested_servers, logger_object)
      print_debug('======== Read Info servers ========')
      massive_helper.read_info_servers(2, timeout) do |server|
        server.read_info unless cached_info?(server)
      end

      requested_servers = servers.reject { |server| cached_status?(server) }
      filtered_servers = requested_servers.select { |server| server.filter_info(filter) }
      filtered_servers.each { |server| server.request_status unless cached_status?(server) }

      massive_helper.servers = filtered_servers
      print_debug('======== Read Status servers ========')
      massive_helper.read_info_servers(2, timeout) do |server|
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
