require "q3_servers/version"

module Q3Servers
  class Error < StandardError; end
  
  require 'q3_servers/player'
  require 'q3_servers/server_connection'
  require 'q3_servers/server'
  require 'q3_servers/massive_helper'
  require 'q3_servers/list'
end
