class Ileds

  def initialize(config)
    @config = config
    @config.each do |pin, _key|
      off(pin)
      init(pin)
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

  def init(p1n)
    puts cmd = "gpio mode #{pin} out"
    system cmd
  end

  def pin(key)
    @config.invert[key]
  end

  def write(p1n, value)
    puts cmd = "gpio write #{p1n} #{value}"
    system cmd
  end

end
