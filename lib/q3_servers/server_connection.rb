# frozen_string_literal: true

require 'digest'
module Q3Servers
  class ServerConnection
    attr_accessor :ip, :port, :socket, :timeout, :url_maps

    MAX_LENGTH = 65_536

    def initialize(ip, port, timeout = 1)
      @ip = ip
      @port = port
      @timeout = timeout
      @url_maps = 'https://www.urbanterror.info/files/static/images/levels/wide/'
    end

    def to_s
      "#{ip}:#{port}"
    end

    def unique_index
      Digest::MD5.hexdigest("#{ip}:#{port}")
    end

    def server_info_connect
      request_info_server
      read_info_server
    end

    def connect
      @socket&.close
      @socket = UDPSocket.new
      @socket.connect(ip, port)
      @socket
    end

    def request_info_server
      connect
      send_data("#{prepend_oob_data}getinfo xxx") # request step 1
    end

    # INFO 1/2
    def read_info_server
      sv_info = read_data
      sv_info ? parse_sv_info(sv_info) : {} # parse step 1 info
    end

    # INFO 2/2
    def request_and_get_server_status
      # sv_status = send_and_read(prepend_oob_data + 'getstatus')
      # sv_status ? parse_sv_status(sv_status) : {} # parse step 2
      request_status_server
      read_status_server
    end

    def request_status_server
      connect
      send_data("#{prepend_oob_data}getstatus") # request step 2
    end

    # INFO 2/2
    def read_status_server
      sv_status = read_data
      sv_status ? parse_sv_status(sv_status) : {} # parse step 2
    end

    private

    def send_and_read(data)
      send_data(data)
      read_data
    end

    def send_data(data)
      socket.send(data, 0)
    end

    def read_data
      IO.select([socket], nil, nil, timeout)
      response_info = socket.recvfrom_nonblock(MAX_LENGTH)
    rescue IO::WaitReadable, Errno::ECONNREFUSED, Errno::EHOSTUNREACH
      nil
    else
      response_info[0]
    end

    def parse_sv_info(sv_response)
      response = sv_response.unpack('CCCCA12CCa*') # infoResponse (len 12) string
      response = response[7].split('\\')
      result = Hash[*response]
      result['map_image_url'] = map_url(result['mapname'])
      result
    end

    def parse_sv_status(sv_response)
      response = sv_response.unpack('CCCCA14CCa*') # statusResponse (len 14) string
      response = response[7].split("\n")
      status = Hash[*response[0].split('\\')]
      players = parse_players(response[1..-1])
      status['players'] = players
      status
    end

    def parse_players(array_str)
      array_str.map do |player|
        kills, ping, player_name = player.split
        Player.new(player_name[1..-2], kills, ping)
      end
    end

    def prepend_oob_data
      "\xFF" * 4
    end

    def map_url(map_name)
      "#{url_maps}#{map_name}.jpg"
    end
  end
end
