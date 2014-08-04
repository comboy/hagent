require_relative 'hagent'


pcf = Hagent::PCF8574.new(addr: '0x20', int: 27) # TODO which INT, int: 0)
ds = Hagent::Sensor::DS18B20.new(addr: '28-00000450dbb9')
ds2 = Hagent::Sensor::DS18B20.new(addr: '28-0000054ff826')
ds3 = Hagent::Sensor::DS18B20.new(addr: '28-00000550443b')
pcf2 = Hagent::PCF8574.new(addr: '0x39', int: 27) # TODO which INT, int: 0)
pcf3 = Hagent::PCF8574.new(addr: '0x23', int: 27) # TODO which INT, int: 0)

dht1 = Hagent::Sensor::DHT22.new(pin: 22)
dht2 = Hagent::Sensor::DHT22.new(pin: 24)
light = Hagent::Sensor::Light.new pin: 23


description = {
  inputs: {
    swo1: pcf.pin(0),
    swo2: pcf.pin(1),
    swo3: pcf.pin(2),
    nc1: pcf.pin(3),

    nc21: pcf2.pin(1),
    nc22: pcf2.pin(2),
    nc23: pcf2.pin(3),

    sw_okap1: pcf3.pin(0),
    sw_okap_light: pcf3.pin(1),
    sw_okap2: pcf3.pin(2),
    sw_okap3: pcf3.pin(3),
    nc35: pcf3.pin(4),
  },

  outputs: {
    notify_green: pcf.pin(6),
    notify_blue: pcf.pin(4),
    notify_red: pcf.pin(5),
    notify_buzz: pcf.pin(7),
 
    status_green: pcf2.pin(0),
    status_yellow: pcf2.pin(4),

    okap2: pcf2.pin(5),
    okap3: pcf2.pin(6),
    okap1: pcf2.pin(7),

    light_up: pcf3.pin(5),
    light_neon: pcf3.pin(6),
    light_okap: pcf3.pin(7),
  },

  sensors: {
    t1: ds,
    t_okap: ds2,
    t_up: ds3,
    h_okap: dht1,
    h_up: dht2,
    light: light
  }
}

ha = Hagent.new description

def prs(pcf)
  8.times do |i|
    puts "#{i}: #{pcf.pin(i).value}"
  end
end

prs pcf

Thread.new do
  loop do
    ha.set :status_green, true
    sleep 0.1
    ha.set :status_green, false
    sleep 0.1
    ha.set :status_green, true
    sleep 0.1
    ha.set :status_green, false
    sleep 0.5
  end
end
Thread.new do
  loop do
    if !system("ping -c 1 192.168.1.1 > /dev/null")
      ha.set :status_yellow, false
      sleep 0.5
      ha.set :status_yellow, true
      sleep 0.5
    else
      ha.set :status_yellow, false
      sleep 2
    end
  end
end

puts "pstryk"
1.times do
  %w{okap3 okap1 okap2}.each do |pin| #notify_buzz
    ha.set pin, true
    sleep 2 
    ha.set pin, false
  end
end if false
puts
1.times do
  %w{light1 light2 light3}.each do |pin| #notify_buzz
    puts "  #{pin}"
    ha.set pin, true
    sleep 5 
    ha.set pin, false
    sleep 0.1
  end
end if false

puts "done"


1.times do
  %w{notify_green notify_red notify_blue}.each do |pin| #notify_buzz
    ha.set pin, true
    sleep 0.5 
    ha.set pin, false
  end
end

puts "HA state:"
ap ha.state

ha.debug_inputs

ha.connect :sw_okap_light, :light_neon

ha.connect :sw_okap1, :okap1
ha.connect :sw_okap2, :okap2
ha.connect :sw_okap3, :okap3

ha.on_change(:t1) do
  puts "T1: #{ha.read :t1, cache: false}"
end
ha.on_change(:t_okap) do
  tup = ha.read :t_up, cache:false
  tokap = ha.read :t_okap, cache:false
  puts "T_UP: #{tup} \t T_OKAP: #{tokap}"
  #if tokap > tup
  #  ha.set :okap3, true
  #else
  #  ha.set :okap3, false
  #end
end
ha.on_change(:t_up) do
  tup = ha.read :t_up, cache:false
  tokap = ha.read :t_okap, cache:false
  puts "T_UP: #{tup} \t T_OKAP: #{tokap}"
  #if tokap > tup
  #  ha.set :okap3, true
  #else
  #  ha.set :okap3, false
  #end
end

ha.on_change(:h_up) do
  puts "H_UP: #{ha.read :h_up, cache: false} \t H_OKAP: #{ha.read :h_okap, cache: false}"
end

ha.on_change(:h_okap) do
  puts "H_UP: #{ha.read :h_up, cache: false} \t H_OKAP: #{ha.read :h_okap, cache: false}"
end

#ha.on_change(:light) do
#  puts "Light: #{ha.read :light, cache: false}"
#end
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

