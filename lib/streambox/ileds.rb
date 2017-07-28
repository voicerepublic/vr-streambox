class Ileds

  def initialize(config)
    @config = config
    @config.each do |led, pins|
      pins.each do |pin|
        cmd = "gpio mode #{pin} out"
        system cmd
      end
    end
  end

  def on(key)
    write(pin(key), 1)
    if block_given?
      yield
      off(key)
    end
  end

  def off(led)
    write(pin(led), 0)
  end

  private

  def pin(led)
    @config.invert[key]
  end

  def write(p1n, value)
    cmd = "gpio write #{p1n} #{value}"
    system cmd
  end

end
