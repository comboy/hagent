
require_relative 'hagent'
require_relative '../komoku/komoku-core/lib/komoku/agent'
require 'ard_vent'

ds_door = Hagent::Sensor::DS18B20.new(addr: '28-0000032ebf4f')
ds_rpi = Hagent::Sensor::DS18B20.new(addr: '28-00000550d6a2')
dht = Hagent::Sensor::DHT22.new(pin: 17)
pcf = Hagent::PCF8574.new(addr: '0x38') #TODO interrupt

ard_light = Hagent::ArdLight.new '/dev/ttyAMA0', 9600
ard_vent = Hagent::ArdVent.new
rpi = Hagent::RPI.new

description = {
  inputs: {
    #swo1: pcf.pin(0),
    light_switch: ard_light.switch(3),
    light_stairs_switch: ard_light.switch(2),
    light_hall_switch: ard_light.switch(1),
    pir: rpi.input(23)
  },

  outputs: {
    #light_hood: pcf.pin(1),
    buzzer: pcf.pin(6),
    light: ard_light.light(3),
    light_stairs: ard_light.light(2),
    light_hall: ard_light.light(1),
    status_green: pcf.pin(7),
    bath_vent: ard_vent.vent,
    bath_vent_shutter: ard_vent.shutter
  },

  sensors: {
    temp_internal: ds_rpi,
    temp_room: ds_door,
    bath_temp_out: ard_vent.temp_out,
    bath_temp_shower: ard_vent.temp_dht,
    bath_hum_shower: ard_vent.hum,
    hum: dht,
    bri: ard_light.photo_resistor
  }
}

ka = Komoku::Agent.new server: 'ws://bzium:7272/', reconnect: true, async: true, timeout: 120, scope: 'gab'
ka.connect
ka.logger = Logger.new STDOUT
ka.logger.level = Logger::INFO
$ka = ka # yeah yeah

ha = Hagent.new description, komoku_agent: ka

puts "HA state:"
ap ha.state
ha.debug_inputs

ha.set :bath_vent_shutter, false
ha.set :bath_vent, false
# Heartbeat light
Thread.new do loop do
  ha.set :status_green, true; sleep 0.1; ha.set :status_green, false; sleep 0.1
  ha.set :status_green, true; sleep 0.1; ha.set :status_green, false; sleep 0.5
end end


ha.toggle_switch :light_switch, :light
ha.toggle_switch :light_stairs_switch, :light_stairs
ha.toggle_switch :light_hall_switch, :light_hall

%i{light light_stairs light_hall}.each do |output|
  # keep komoku up to date
  ha.on_set(output) {|value| ka.put output, value}

  # keep state from komoku
  ka.on_change(output) do |key, curr, prev|
    ha.without_callbacks do
      ha.set(output, curr) if ha.last_set(output) != curr
    end
  end
end



%i{temp_internal temp_room hum bri}.each do |sensor|
  ha.on_change(sensor) do
    value = ha.read sensor, cache: false
    ka.put sensor, value
  end
end


ha.on_change(:bath_hum_shower) do
  hum = ha.read :bath_hum_shower
  puts "bath hum shower: #{hum}"
  next unless hum
  if hum > 90
    ha.set(:bath_vent, true) if ha.last_set(:bath_vent) != true
  elsif hum < 77
    ha.set(:bath_vent, false) if ha.last_set(:bath_vent) != false
  end
  if hum > 70
    ha.set(:bath_vent_shutter, true) if ha.last_set(:bath_vent_shutter) != true
  elsif hum < 55
    ha.set(:bath_vent_shutter, false) if ha.last_set(:bath_vent_shutter) != false
  end
end


last_away = Time.now
ha.on_change(:pir) do
  state = ha.read(:pir)
  #puts "pir: #{state}"
  if state
    puts "pir away: #{Time.now - last_away}"
    if ha.read(:bri) < 70 && !ha.last_set(:light)
      ha.set :light, true
    end
  else
    last_away = Time.now
  end
end

sleep
