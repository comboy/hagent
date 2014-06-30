$: << "."
require 'pcf8574'
require 'ds18b20'

class Hagent

  def initialize(description)
    @desc = description
    @last_reads = {}

    @desc[:inputs].each_pair do |name, pin|
      pin.mode = :input
    end
  end

  def set(pin, value = true)
    pin = pin.to_sym

    if @desc[:outputs].keys.include? pin
      @desc[:outputs][pin.to_sym].set true
    end
  end

  def on_change(opts = {}, &block)
    if opts.kind_of? Symbol
      @desc[:outputs]
    end
  end
end



pcf = Hagent::PCF8574.new(addr: '0x38', int: 0)
ds = Hagent::DS18B20.new(addr: '28-00000450de65')

description = {
  inputs: {
    swo1: pcf.pin(6),
    swo2: pcf.pin(5),
    swo3: pcf.pin(4)
  },

  outputs: {
    o1: pcf.pin(0),
    o2: pcf.pin(1),
    o3: pcf.pin(2),
    o4: pcf.pin(3)
  },

  sensors: {
    temp: ds
  }
}

ha = Hagent.new description

def prs(pcf)
  8.times do |i|
    puts "#{i}: #{pcf.pin(i).value}"
  end
end

prs pcf


pcf.on_change do |oldstate|
  puts "change"
end
pcf.pin(6).on_change do
  puts "pin 6 change [#{pcf.pin(6).value}]"

  pcf.pin(0).set pcf.pin(6).value
end

#loop do
#  puts ds.read
#end
gets
loop do
  8.times do |i|
    pcf.pin(i).set false
    sleep 0.02
    pcf.pin(i).set true
  end
  #pcf.pin(1).set false
  #sleep 0.1
  #pcf.pin(1).set true
  #sleep 1
end


#sleep 5

