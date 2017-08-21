#!/usr/bin/env ruby

require "i2c"

class LedDevice <  Struct.new(:i2c_address, :i2c_dev)

  attr_accessor :banks

  def init!
    self.banks = [[], []]
    blackout
    update!
    i2c.write(i2c_address, 0x21) # osci on
    i2c.write(i2c_address, 0xef) # make bright
    #i2c.write(i2c_address, 0xe0) # make dark
    i2c.write(i2c_address, 0x81) # display on
  end

  def shutdown!
    i2c.write(i2c_address, 0x20) # osci off
    i2c.write(i2c_address, 0x80) # display off
  end

  def blackout
    self.banks.each_with_index do |_, index|
      self.banks[index] = "0" * 8 * 8
    end
  end

  def probe!(address_range, value_range, delay)
    address_range.each do |address|
      value_range.each do |value|
        puts "Address: #{address} / Value: #{value}"
        i2c.write(i2c_address, address, value)
        sleep delay
      end
    end
  end

  private

  def i2c
    @i2c ||= I2C.create(self.i2c_dev || '/dev/i2c-1')
  end

end

class Bicolor24 < LedDevice

  def set(color, pattern)
    case color
    when :red    then
      self.banks[0] = pattern
      #self.banks[0] = (banks[0].to_i(2) | pattern.to_i(2)).to_s(2)
    when :green  then
      self.banks[1] = pattern
      #self.banks[1] = (banks[1].to_i(2) | pattern.to_i(2)).to_s(2)
    when :orange then
      self.banks[0] = self.banks[1] = pattern
      #set(:green, pattern)
      #set(:red, pattern)
    end
  end

  def update!
    self.banks[0].gsub!("\n", '')
    self.banks[0].gsub!(" ", '')
    3.times do |index|
      address = index * 2
      value = (self.banks[0][index * 4, 4] +
               self.banks[0][index * 4 + 12, 4]).reverse.to_i(2)
      i2c.write(i2c_address, address, value)
    end

    self.banks[1].gsub!("\n", '')
    self.banks[1].gsub!(" ", '')
    3.times do |index|
      address = index * 2 + 1
      value = (self.banks[1][index * 4, 4] +
               self.banks[1][index * 4 + 12, 4]).reverse.to_i(2)
      i2c.write(i2c_address, address, value)
    end
  end

end

class Bicolor8x8 < LedDevice

  def green=(pattern)
    self.banks[0] = pattern
  end

  def red=(pattern)
    self.banks[1] = pattern
  end

  def set_green(x, y)
    self.banks[0][x + 8 * y] = '1'
  end

  def set_red(x, y)
    self.banks[1][x + 8 * y] = '1'
  end

  def set_orange(x, y)
    self.banks[0][x + 8 * y] = '1'
    self.banks[1][x + 8 * y] = '1'
  end

  def update!
    self.banks[0].gsub!("\n", '')
    self.banks[0].gsub!(" ", '')
    self.banks[0].scan(/.{8}/).each_with_index do |row, index|
      address =  index * 2
      value = row.reverse.to_i(2)
      i2c.write(i2c_address, address, value)
    end

    self.banks[1].gsub!("\n", '')
    self.banks[1].gsub!(" ", '')
    self.banks[1].scan(/.{8}/).each_with_index do |row, index|
      address =  index * 2 + 1
      value = row.reverse.to_i(2)
      i2c.write(i2c_address, address, value)
    end
  end

end

#dr = Bicolor8x8.new(0x70)
#dl = Bicolor8x8.new(0x71)
#lb = Bicolor24.new(0x70)

#dr.init!
#dl.init!
#lb.init!

# require 'yaml'
#
# pattern = YAML.load(File.read('8x8bicolor.yml'))
#
# 1.times do
#
#   dr.blackout
#   dr.green = dr.red = pattern['smiley']
#   dl.green = dl.red = pattern['smiley']
#   dr.update!
#   dl.update!
#   sleep 1
#
#   dr.blackout
#   dr.red = '1' * 8 * 8
#   dr.update!
#   sleep 2
#   dr.green = '1' * 8 * 8
#   dr.update!
#   sleep 2
#   dr.red = '0' * 8 * 8
#   dr.update!
#   sleep 2
#
#   dr.blackout
#   5.times do
#     pattern['rotate'].each do |pat|
#       dr.green = pat
#       dr.update!
#       sleep 0.05
#     end
#   end
#
#   dr.blackout
#   dr.red = pattern['noob']
#   dr.update!
#   sleep 1
#
#   2.times do
#     24.times do |v|
#       lb.blackout
#       i = v
#       pattern = ('0' * 24)
#       pattern[i] = '1'
#       color = :green
#       color = :orange if i > 16
#       color = :red if i > 20
#       lb.set(color, pattern)
#       lb.update!
#       sleep 0.1
#     end
#     24.times do |v|
#       lb.blackout
#       i = 23 - v
#       pattern = ('0' * 24)
#       pattern[i] = '1'
#       color = :green
#       color = :orange if i > 16
#       color = :red if i > 20
#       lb.set(color, pattern)
#       lb.update!
#       sleep 0.1
#     end
#   end
#
#   sleep 1
#
#   [:green, :orange, :red].each do |color|
#     24.times do |i|
#       lb.blackout
#       lb.set(color, '1' * i + '0' * (24 - i))
#       lb.update!
#       sleep 0.05
#     end
#     24.times do |i|
#       lb.blackout
#       lb.set(color, '1' * (24 - i) + '0' * i)
#       lb.update!
#       sleep 0.05
#     end
#   end
#
#   100.times do
#     color = [:green, :orange, :red].shuffle.first
#     led = (['1'] + ['0'] * 23).shuffle.join
#     lb.set(color, led)
#     lb.update!
#     sleep 0.1
#   end
#
#   #lb.probe! 0..5, 1..255, 0.01
#   #sleep 1
#
# end
#
# dr.shutdown!
# dl.shutdown!
# lb.shutdown!
