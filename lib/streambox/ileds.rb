class Ileds

  def initialize(config)
    @config = config
    @config.each do |p1n, key|
      off(key)
      init(p1n)
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

  def all_off
    @config.each do |p1n, key|
      off(key)
    end
  end

  private

  def init(p1n)
    cmd = "gpio mode #{p1n} out"
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
