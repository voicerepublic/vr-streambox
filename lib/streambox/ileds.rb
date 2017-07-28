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
    LEDS.each do |led, pins|
      pins.each do |pin|
        puts cmd = "gpio mode #{pin} out"
        system cmd
      end
    end
  end

  def on(led, color)
    write(pin(led, color), 1)
  end

  def off(led, color)
    write(pin(led, color), 0)
  end

  private

  def pin(led, color)
    LEDS[led][COLORS[color]]
  end

  def write(p1n, value)
    puts cmd = "gpio write #{p1n} #{value}"
    system cmd
  end

end

__END__

require './streambox-repo/lib/streambox/ileds.rb'
