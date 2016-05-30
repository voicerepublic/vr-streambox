require 'logger'
require 'json'
require 'ostruct'
require 'uri'

require 'faraday'
require 'eventmachine'
require 'faye'
require 'faye/authentication'

require "streambox/version"
require "streambox/banner"
require "streambox/client"
require "streambox/server"

module Streambox
  class Daemon

    ENDPOINTS = [
      'https://voicerepublic.com/api/devices',
      'https://staging:oph5lohb@staging.voicerepublic.com/api/devices'
    ]

    attr_accessor :server, :clients

    def initialize
      Thread.abort_on_exception = true

      # logger.info "Start Server..."
      # self.server = Server.new

      logger.info "Start Clients..."
      self.clients = ENDPOINTS.map do |endpoint|
        logger.info "Endpoint: #{endpoint}"
        config = OpenStruct.new(
          endpoint: endpoint,
          logger: logger,
          server: server
        )
        Client.new(config)
      end

      Banner.new
    end

    def run
      logger.info "Entering event machine loop..."
      EM.run {
        clients.each { |client| client.run }
      }
      logger.warn "Exiting."
    end

    def logger
      @logger ||= Logger.new(STDOUT).tap do |logger|
        # logger.level = ...
        logger.formatter = proc do |severity, datetime, progname, msg|
          "#{severity[0]} #{datetime.strftime('%H:%M:%S')} #{msg}\n"
        end
      end
    end

  end
end
