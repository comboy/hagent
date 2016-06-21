require_relative 'hagent'
require_relative '../komoku/komoku-core/lib/komoku/agent'
require 'pp'


pcf = Hagent::PCF8574.new(addr: '0x20', int: 27) # TODO which INT, int: 0)
ds = Hagent::Sensor::DS18B20.new(addr: '28-00000450dbb9')
ds2 = Hagent::Sensor::DS18B20.new(addr: '28-0000054ff826')
ds3 = Hagent::Sensor::DS18B20.new(addr: '28-00000550443b')
pcf2 = Hagent::PCF8574.new(addr: '0x39', int: 27) # TODO which INT, int: 0)
pcf3 = Hagent::PCF8574.new(addr: '0x23', int: 27) # TODO which INT, int: 0)

dht1 = Hagent::Sensor::DHT22.new(pin: 22)
dht2 = Hagent::Sensor::DHT22.new(pin: 24)
light = Hagent::Sensor::Light.new pin: 23

pin_led_left = Hagent::Pin
pin_led_right = Hagent::Pin

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

    light_led_left: pin_led_left,
    light_led_right: pin_led_right,
  },

  sensors: {
    temp_internal: ds,
    temp_hood: ds2,
    temp_up: ds3,
    hum_hood: dht1,
    hum_up: dht1,
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
    station = $ka.get('radio_station')
    url = streams[station]
    puts "GONNA START #{station} = #{url}"
    #@thread = respawn_thread unless no_thread
    @pid = fork do
      exec("mplayer '#{url}' -really-quiet")
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
    {
      #nil => 'http://ant-kra-01.cdn.eurozet.pl:8606/', # dead
#      'antyradio' => 'http://94.23.89.48:7300/',
      'roxyfm' => 'http://lodz.radio.pionier.net.pl:8000/pl/roxyfm.ogg',
      'zloteprzeboje' => 'http://lodz.radio.pionier.net.pl:8000/pl/zloteprzeboje.ogg',
      'trojka' => 'http://stream.polskieradio.pl/program3',
      'eskarock' => 'http://s3.deb1.scdn.smcloud.net/t008-1.mp3',
      'eskaalt' => 'http://s3.deb1.scdn.smcloud.net/t015-1.mp3',
      'zetrock' => 'http://zetrok-02.cdn.eurozet.pl:8448/',
      'mpd' => 'http://bzium:8000/'
      #'http://stream.polskieradio.pl/program3'
    }
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


ka = Komoku::Agent.new server: 'wss://komoku:7273/', reconnect: true, async: true, timeout: 120, scope: 'kitchen'
ka.connect
ka.logger = Logger.new STDOUT
ka.logger.level = Logger::INFO
ka.define_keys('alive' => {type: 'uptime', max_time: 100})

$ka = ka # yeah yeah

music = Music.new

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
ha.direct_switch :sw_hood_light, :light_up

ha.toggle_switch :sw_green, :light_neon
ha.toggle_switch :sw_yellow, :light_hood

# Komoku outputs
%i{light_up light_hood}.each do |output|
  # sync with komoku on boot
  ha.set(output, !!ka.get(output))

  # keep komoku up to date
  ha.on_set(output) {|value| ka.put output, value}

  # keep state from komoku
  ka.on_change(output) do |c|
    pp c
    ha.without_callbacks do
      ha.set(output, c[:value]) if ha.last_set(output) != c[:value]
    end
  end
end

ka.on_change(:light_neon) do |c|
  if c[:value] == true
    `/root/tmp/rpi1/RF24/RPi/RF24/examples/remote -m 1`
  else
    `/root/tmp/rpi1/RF24/RPi/RF24/examples/remote -m 0`
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

ka.on_change(:radio_station) do
  ka.put :radio_on, false
  ka.put :radio_on, true
end

ka.on_change(:radio_on) do |c|
  if c[:value] && !music.playing?
    music.start
  else
    music.stop
  end
end
ka.on_change('.mol.internet', init: true) do |c|
  ha.set :notify_red, !c[:value]
end

ka.on_change(:radio_volume) do |c|
  system("amixer set PCM #{c[:value]}%")
end

# stayin alive
Catcher.thread_loop("stayin alive") do
  ka.put 'alive', true
  sleep 60
end


require 'input/rotenc'
require 'output/lcd'

require 'ard_panel'

class Panel

  attr_accessor :radio_items
  attr_accessor :on_radio_selected
  attr_accessor :on_volume_change
  attr_accessor :volume
  attr_accessor :on_button_press
  attr_accessor :on_lcd_line_2

  attr_accessor :temp
  attr_accessor :hum
  attr_accessor :ard_temp

  def initialize
    @ard = ard = Hagent::ArdPanel.new
    @ard_temp = @ard

    pcf = ard.pcf

    description = {
      inputs: {
        sw1: pcf.pin(7),
        sw2: pcf.pin(6),
        sw3: pcf.pin(5),
        sw4: pcf.pin(4),

        sw5: pcf.pin(0),
        knob_button: pcf.pin(1),
        sw_up: pcf.pin(2), # sw up
        sw_down: pcf.pin(3), #sw down
      },
      outputs: {},
      sensors: {}
    }

    100.downto(1) do |i|
      ard.tone(500 + i**2)
      sleep 0.01 / (i+1).to_f
    end
    100.times do |i|
      ard.tone(500 + i**2)
      sleep 0.01 / (i+1).to_f
    end
    ard.tone(200)
    sleep 0.3
    ard.tone(200)
    sleep 0.2
    ard.tone(900)
    sleep 0.1
    ard.tone 0

    @radio_items = []
    @current_radio_idx = 0

    @on_radio_selected = -> (station) {}
    @on_volume_change  = -> (volume) {}
    @on_button_press  = -> (buttons) {}
    @on_lcd_line_2  = -> () {nil} # what a shitty name

    @ha = Hagent.new description
    @lcd = Hagent::Output::Lcd.new engine: ard.lcd
    #@lcd = Hagent::Output::Lcd.new
    @temp = 0
    @hum = 0

    @lcd.push_line 0, "panel init"
    @lcd.set_led false
    sleep 1
    @lcd.set_led true

    200.times do |i|
      ard.send_data("a#{i}\n")
      sleep 0.01
    end

    50.times do |i|
      ard.send_data("a#{200 - i*4}\n")
      sleep 0.001
    end

    @mode = :volume
    @last_activity = Time.now
    @switch_state = :center # FIXME
    @volume = 70 # FIXME
    @brightness = 70 # FIXME

    @ha.on_change(:knob_button) do
      beat
      knob_click if @ha.read(:knob_button) == false
    end

    @ha.on_change(:sw_up) do
      beat
      val = @ha.read(:sw_up)
      @switch_state = val ? :up : :center
      switch_change
    end

    @ha.on_change(:sw_down) do
      beat
      val = @ha.read(:sw_down)
      @switch_state = val ? :down : :center
      switch_change
    end

    [:sw1, :sw2, :sw3, :sw4].each_with_index do |sw, i|
      num = i+1
      @ha.on_change(sw) do
        button_change(num, @ha.read(sw))
      end
    end

    Catcher.thread_loop("heartbeat") do
      sleep 1
      next if @keep_displayed_time && (@keep_displayed_time > Time.now)
      @mode = :volume if (Time.now - @last_activity) > 5
      if @mode == :volume
        @lcd.push_line 0, "T: #{(@temp || -1 ).round(1)}\xDF | H: #{(@hum || -1).round}%".center(16)
        @lcd.push_line 1, on_lcd_line_2.call || Time.now.strftime("%H:%M:%S").center(16)
      end
    end

    #@rotenc = Hagent::Input::Rotenc.new pins: [22,27]
    @rotenc = Hagent::Input::Rotenc.new engine: ard.rotenc

    @rotenc.on_change do |direction|
      beat
      knob_rotation(direction)
    end


    # TODO abstraction layer
    #`gpio -g mode 18 pwm`
    #`gpio pwmr 4000`
    #`gpio pwm-ms`
  end

  def button_change(num, value)
    #puts "B #{num} #{value}"
    @button_mutex ||= Mutex.new
    @ev_counter ||= 0
    @ev_counter += 1
    @pressed_buttons ||= []
    @button_mutex.synchronize do
      @press_fired = false if @press_fired.nil?
      if value
        @pressed_buttons << num unless @pressed_buttons.include? num
      else
        unless @press_fired
          button_press(@pressed_buttons)
          @press_fired = true
        end
        @pressed_buttons.delete num
        @press_fired = false if @pressed_buttons.empty?
      end
    end
  end

  def button_press(buttons)
    `gpio -g pwm 18 1000`
    sleep 0.01
    `gpio -g pwm 18 0`
    @on_button_press.call buttons
    @lcd.push_line 1, "E #{@ev_counter} B #{buttons.inspect}"
    keep_displayed(2)
  end

  def beat
    @last_activity = Time.now
  end

  def knob_click
    #@lcd.push_line 1, "knob click"

    if @mode == :volume
      @mode = :menu
      @lcd.push_line 0, " ..:: menu ::.. "
      @current_menu_idx = 0
      display_menu
    elsif @mode == :menu
      if @menu_items[@current_menu_idx] == 'RADIO STATION'
        @mode = :radio
        @lcd.push_line 0, " ..:: radio ::.. "
        display_radios
      end
      if @menu_items[@current_menu_idx] == 'LIGHT'
        @mode = :light
        @lcd.push_line 0, " ..:: light ::.. "
        @lcd.push_line 1, " set  brightness"
      end
    elsif @mode == :light
      @mode = :volume
    elsif @mode == :radio
      on_radio_selected.call @radio_items[@current_radio_idx]
      @mode = :volume
    end

  end

  def knob_rotation(direction)
    if @mode == :menu
      @current_menu_idx = (@rotenc.counter / 4) % @menu_items.size
      display_menu
    elsif @mode == :radio
      @current_radio_idx = (@rotenc.counter / 4) % @radio_items.size
      display_radios
    elsif @mode == :volume
      @volume += direction ? 2 : -2
      @volume = 0 if @volume < 0
      @volume = 100 if @volume > 100
      @on_volume_change.call @volume
      @lcd.push_line 0, "Volume: #{@volume}".center(16)
      @lcd.push_line 1, "  |#{'='*(@volume / 10)}"
      keep_displayed(2)
    elsif @mode == :light
      @brightness += direction ? 3 : -3
      @brightness = 0 if @brightness < 0
      @brightness = 100 if @brightness > 100
      #@on_volume_change.call @volume
      @lcd.push_line 0, "Light: #{@brightness}".center(16)
      @lcd.push_line 1, "  |#{'='*(@brightness / 10)}"
      @ard.light(1, (@brightness * 2.55).round)
      keep_displayed(2)
    else
      @lcd.push_line 1, "knob rot #{direction}"
    end
  end

  def keep_displayed(time)
    @keep_displayed_time = Time.now + time
  end

  def display_menu
    @menu_items = ['RADIO STATION','LIGHT','OPTIONS','VOLUME']
    @lcd.push_line 1, @menu_items[@current_menu_idx].center(16)
  end

  def display_radios
    #@radio_items = ['Zet Rock', 'Eska', 'MPD', 'Trójka']
    @lcd.push_line 1, @radio_items[@current_radio_idx].center(16)
  end

  def selected_radio_item=(radio_name)
    @current_radio_idx = @radio_items.index(radio_name) || 0
  end

  def switch_change
    if @switch_state == :down
      @lcd.set_led false
    else
      @lcd.set_led true
    end
    if @switch_state == :up
      @lcd.push_line 1, "switch up"
    end
  end

end

panel = Panel.new

panel.temp = ka.get :temp_up
panel.hum = ka.get :hum_up

ka.on_change(:temp_up) do |c|
  panel.temp = c[:value]
end

ka.on_change(:hum_up) do |c|
  panel.hum = c[:value]
end

panel.radio_items = music.streams.keys #['Zet Rock', 'Eska', 'MPD', 'Trójka', 'Whatever']
panel.selected_radio_item = ka.get(:radio_station)


panel.on_radio_selected = -> (name) do
  ka.put(:radio_station, name)
end

panel.on_lcd_line_2 = -> () do
  if music.playing?
    ka.lazy_get(:radio_station).to_s.center(16)
  end
end

panel.on_volume_change = -> (volume) do
  puts "volume: [#{volume}]"
  system("amixer set PCM #{volume}%")
end

panel.on_button_press = -> (buttons) do
  puts "buttons: [#{buttons.sort}]"
  if buttons == [4]
    if !music.playing?
      music.start
    else
      music.stop
    end
  end

  if buttons == [1,3]
    ha.set(:light_hood, !ha.last_set(:light_hood))
  end
  if buttons == [1,4]
    ka.put "table.light", !ka.get("table.light")
  end
  if buttons == [2]
    panel.ard_temp.light(3,0)
  end

  if buttons == [3] 
    ha.set :hood2, false
    ha.set :hood3, false
    ha.set :hood1, false
  end
  if buttons == [3,1] 
    ha.set :hood2, false
    ha.set :hood3, false
    ha.set :hood1, true
  end
  if buttons == [3,2] 
    ha.set :hood3, false
    ha.set :hood1, false
    ha.set :hood2, true
  end
  if buttons == [3,4] 
    ha.set :hood1, false
    ha.set :hood2, false
    ha.set :hood3, true
  end
  if buttons == [3]
  end
end

panel.ard_temp.light(1,0)
panel.ard_temp.light(2,0)
panel.ard_temp.light(3,0)

sleep

#exit 0

#pcf.on_change do |oldstate|
  #puts "change"
#end
#pcf.pin(6).on_change do
  #puts "pin 6 change [#{pcf.pin(6).value}]"
  #pcf.pin(0).set pcf.pin(6).value
#end

##loop do
##  puts ds.read
##end

#20.times do
  #%w{o1 o2 o3 o4}.each do |pin|
    #ha.set pin, true
    #sleep 0.02
    #ha.set pin, false
  #end
#end

