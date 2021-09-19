# frozen_string_literal: true

module Q3Servers
  class Server
    attr_accessor :connection, :info, :status

    STATUS = %i[request request_status response response_status destroyed].freeze
    GT = { '0' => 'FFA', '4' => 'TS', '7' => 'CTF', '9' => 'JMP' }.freeze

    def initialize(ip, port, info)
      @connection = ServerConnection.new(ip, port)
      @info = info || {}
    end

    def name_c_sanitized
      info['hostname'].gsub(/(\^[0-9]{1})/, '') if info.key?('hostname')
    end

    def gametype
      GT.fetch(info['gametype'], '')
    end

    def filter_info(filter)
      return false if info.empty?
      return true if filter.empty?

      info['hostname'] = name_c_sanitized if info.key?('hostname')
      f = filter.select { |k, v| info.key?(k.to_s) and (info[k.to_s].downcase =~ /#{v.to_s.downcase}/) }
      !f.empty?
    end

    def request_info
      self.status = :request
      puts "Requesting info to #{connection}"
      connection.request_info_server
    end

    def request_status
      self.status = :request_status
      puts "Requesting status to #{connection}"
      connection.request_status_server
    end

    def read_info
      self.status = :response
      self.info = connection.read_info_server
      touch!
      info
    end

    def read_status
      self.status = :response_status
      info['sv_status'] = connection.read_status_server
      status_touch!
      info['sv_status']
    end

    def request_and_get_status
      info['sv_status'] = connection.request_and_get_server_status # step 2 more info from server
      status_touch!
      info['sv_status']
    end

    def socket
      connection.socket
    end

    def unique_index
      connection.unique_index
    end

    def destroy_socket
      status = :destroyed
      connection.socket.close
    end

    def updated_at
      info['updated_at']
    end

    def status_updated_at
      info.dig('sv_status', 'updated_at')
    end

    def info_status
      info['sv_status'] || {}
    end

    STATUS.each do |status|
      define_method("#{status}_status?") { self.status == status }
    end

    def info?
      !info.empty?
    end

    def info_status?
      info? && !info_status.empty?
    end

    private

    def touch!
      info['updated_at'] = DateTime.now
    end

    def status_touch!
      info['sv_status']['updated_at'] = DateTime.now
    end
  end
end
