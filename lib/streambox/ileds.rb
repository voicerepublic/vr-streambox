class Ileds

  COLORS = {
    red: 0,
    green: 1
  }

  LEDS = {
    logo:      [ 4,  5],
    network:   [ 3,  2],
    connected: [26, 21],
    audio:     [22, 23],
    #streaming: [],
    #recording: [],
    #uploading: [],
  }

  def initialize
    LEDS.each do |led|
      led.each do |pin| # colors
        %x[gpio mode #{pin} out]
      end
    end
  end

  def on(led, color)
    %x[gpio write #{pin(led, color)} 1]
  end

  def off(led, color)
    %x[gpio write #{pin(led, color)} 0]
  end

  private

  def pin(led, color)
    LEDS[led][COLORS[color]]
  end

end
