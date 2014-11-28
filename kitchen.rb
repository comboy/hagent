require_relative 'hagent'
require_relative '../komoku/komoku-core/lib/komoku/agent'


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

    sw_red: pcf2.pin(1),
    sw_green: pcf2.pin(2),
    sw_yellow: pcf2.pin(3),

    sw_hood1: pcf3.pin(0),
    sw_hood_light: pcf3.pin(1),
    sw_hood2: pcf3.pin(2),
    sw_hood3: pcf3.pin(3),
    nc35: pcf3.pin(4),
  },

  outputs: {
    notify_green: pcf.pin(6),
    notify_blue: pcf.pin(4),
    notify_red: pcf.pin(5),
    notify_buzz: pcf.pin(7),
 
    status_green: pcf2.pin(0),
    status_yellow: pcf2.pin(4),

    hood2: pcf2.pin(5),
    hood3: pcf2.pin(6),
    hood1: pcf2.pin(7),

    light_up: pcf3.pin(5),
    light_neon: pcf3.pin(6),
    light_hood: pcf3.pin(7),
  },

  sensors: {
    temp_internal: ds,
    temp_hood: ds2,
    temp_up: ds3,
    hum_hood: dht1,
    hum_up: dht2,
    light: light
  }
}

class Music
  def initialize
    @pid = nil
    #@thread = respawn_thread
    @stream_idx = 0
  end

  def playing?
    !! @pid
  end

  def start(no_thread = false)
    #@thread = respawn_thread unless no_thread
    @pid = fork do
      exec("mplayer '#{streams[@stream_idx]}' -really-quiet")
    end
  end

  def next
    @stream_idx += 1
    @stream_idx = 0 if @stream_idx >= streams.size
  end

  def stop
    puts "STAHP"
    pid = @pid
    @pid = nil
    #@thread.kill
    system("killall -9 mplayer") # TMP TODO FIXME
    #Process.kill "TERM", pid
    #Process.wait pid
  end

  def streams
    [
      'http://ant-kra-01.cdn.eurozet.pl:8606/'
      #'http://stream.polskieradio.pl/program3'
    ]
  end

  protected

  def respawn_thread
    Catcher.thread "mplayer respawning" do
      loop do
        sleep 2
        if playing? && @pid
          Process.wait @pid
          puts "MPLAYER DIED"
          start true
        end
      end
    end
  end
end

music = Music.new

ka = Komoku::Agent.new server: 'ws://10.7.0.10:7272/', reconnect: true, async: true
ka.connect
ka.logger = Logger.new STDOUT
ka.logger.level = Logger::INFO

ha = Hagent.new description, komoku_agent: ka

def prs(pcf)
  8.times do |i|
    puts "#{i}: #{pcf.pin(i).value}"
  end
end

prs pcf

# startup light
1.times do
  %w{notify_green notify_red notify_blue}.each do |pin|
    ha.set pin, true
    sleep 0.5 
    ha.set pin, false
  end
end

# Heartbeat light
Thread.new do loop do
  ha.set :status_green, true; sleep 0.1; ha.set :status_green, false; sleep 0.1
  ha.set :status_green, true; sleep 0.1; ha.set :status_green, false; sleep 0.5
end end

# connection lost light
Thread.new do loop do
  if !system("ping -c 1 192.168.1.1 > /dev/null")
    ha.set :status_yellow, false; sleep 0.5; ha.set :status_yellow, true; sleep 0.5
  else
    ha.set :status_yellow, false; sleep 2
  end
end end

puts "HA state:"
ap ha.state

ha.debug_inputs

# Komoku sensors
%i{temp_internal temp_up temp_hood light hum_hood hum_up}.each do |sensor|
  ha.on_change(sensor) do
    value = ha.read sensor, cache: false
    ka.put sensor, value
  end
end

# Buttons, switches
ha.direct_switch :sw_hood1, :hood1
ha.direct_switch :sw_hood2, :hood2
ha.direct_switch :sw_hood3, :hood3
ha.direct_switch :sw_hood_light, :light_hood

ha.toggle_switch :sw_green, :light_neon
ha.toggle_switch :sw_yellow, :light_up

# Komoku outputs
%i{light_up light_hood light_neon}.each do |output|
  # sync with komoku on boot
  ha.set(output, !!ka.get(output))

  # keep komoku up to date
  ha.on_set(output) {|value| ka.put output, value}

  # keep state from komoku
  ka.on_change(output) do |key, curr, prev|
    ha.set output, curr if ha.last_set(output) != curr
  end
end


ha.on_change :sw_red do
  if music.playing?
    #$last_sw_red = Time.now
    ka.put :radio_on, false
  else
    #if $last_sw_red && ((Time.now - $last_sw_red) < 1)
    #  puts "MPLAYER  NEXT"
    #end
    ka.put :radio_on, true
    ha.set :notify_buzz, true
    sleep 0.1
    ha.set :notify_buzz, false
  end
end

ka.on_change(:radio_on) do |key, curr, prev|
  if curr && !music.playing?
    music.start
  else
    music.stop
  end
end

ka.on_change(:radio_volume) do |key, curr, prev|
  system("amixer set PCM #{curr}%")
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

