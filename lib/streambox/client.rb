require 'json'

require "streambox/player"

module Streambox
  class Client < Struct.new(:config)

    CHANNEL = '/admin/connections'

    attr_accessor :client, :players

    def run
      register
      subscribe
    end

    def register
      config.logger.info "Registering at #{config.endpoint}"
      uri = URI.parse(config.endpoint)
      faraday.basic_auth(uri.user, uri.password)
      response = faraday.post(config.endpoint, device: payload)
      details = JSON.parse(response.body)
      details.each { |key, value| config.send("#{key}=", value) }
    end

    def identifier
      md = File.read('/proc/cpuinfo').match(/Serial\s*:\s*(.*)/)
      md.nil? ? %x[hostname].chomp : md[1]
    end

    def payload
      {
        identifier: identifier,
        type: 'Streambox INGSOC',
        subtype: 'v0.1'
      }
    end

    def subscribe
      self.players = {}
      self.client = Faye::Client.new(config.faye_url)
      ext = Faye::Authentication::ClientExtension.new(config.faye_secret)
      client.add_extension(ext)

      config.logger.info "Subscribing to channel '#{CHANNEL}'..."
      client.subscribe(CHANNEL) { |message| dispatch(message) }
    end

    def dispatch(message)
      case event = message['event']
      when 'connected'
        logger.info "Subscribing to audio stream of #{message['name']}"
        player = Player.new(message['stream_url'])
        player.play!
        players[message['slug']] = player
      when 'disconnected'
        slug = message['slug']
        players[slug].stop!
        players.delete(slug)
      else
        config.logger.warn "Unknown event: #{event}"
      end
    end

    def faraday
      @faraday ||= Faraday.new(url: config.endpoint) do |f|
        f.request :url_encoded
        f.adapter Faraday.default_adapter
      end
    end

  end
end
