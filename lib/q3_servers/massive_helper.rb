# frozen_string_literal: true

module Q3Servers
  class MassiveHelper
    attr_reader :sockets, :servers

    def initialize(servers, logger)
      @logger = logger
      self.servers = servers
    end

    def read_info_servers(max_retries, timeout, &block)
      read_info(servers.map { |_unique_index, server| server.socket }, max_retries, timeout, &block)
    end

    def read_info(sockets, max_retries, timeout, &block)
      servers_with_info = []
      sockets_completed = 0
      retries = 0
      sockets.size.times do |_i|
        break if (sockets_completed >= sockets.size) || (retries >= max_retries)

        ready_sockets = IO.select(sockets, nil, nil, timeout)
        if ready_sockets && (ready_sockets = ready_sockets[0])
          retries = 0
          ready_sockets.each do |socket|
            sockets_completed += 1
            server = servers[calculate_index(socket)]
            block.call(server)
            servers_with_info << server
          end
        else
          retries += 1
          @logger&.info "Retry n #{retries}"
        end
      end
      servers_with_info
    end

    def calculate_index(socket)
      # to determine which socket answered
      addr = socket.peeraddr(false)
      ServerConnection.new(addr.last, addr[1]).unique_index
    end

    def servers=(new_servers)
      @servers = new_servers.each_with_object({}) do |server, hsh|
        hsh[server.unique_index] = server
      end
    end
  end
end
