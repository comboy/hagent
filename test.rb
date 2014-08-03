require 'catcher'
require 'awesome_print'

$: << "."
require 'hagent'



pcf = Hagent::PCF8574.new(addr: '0x38', int: 0)
ds = Hagent::Sensor::DS18B20.new(addr: '28-00000450de65')

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
    t1: ds
  }
}

ha = Hagent.new description

def prs(pcf)
  8.times do |i|
    puts "#{i}: #{pcf.pin(i).value}"
  end
end

prs pcf

puts "HA state:"
ap ha.state
ha.on_change(:t1) do
  puts "T1: #{ha.read :t1, cache: false}"
end
ha.on_change(:swo1) do
  puts "CHANGE!"
  ha.set :o2, ha.read(:swo1)
  ha.set :o1, ha.read(:swo1)
  sleep 2
  ha.set :o1, false
end

sleep
exit 0

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

20.times do
  %w{o1 o2 o3 o4}.each do |pin|
    ha.set pin, true
    sleep 0.02
    ha.set pin, false
  end
end

