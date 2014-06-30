require 'catcher'
require 'awesome_print'

$: << "."
require 'pcf8574'
require 'ds18b20'

class Hagent

  DEFAULT_OPTS = {
    cache_time: 5
  }

  def initialize(description, opts = {})
    @desc = {inputs: {}, outputs: {}, sensors: {}}.merge description
    @last_values = {}

    @opts = DEFAULT_OPTS.merge opts
    @desc[:inputs].each_pair do |name, pin|
      pin.mode = :input
    end

    # auto monitoring sensors
    @desc[:sensors].each_pair do |name, sensor|
      if sensor.kind_of? DS18B20
        Catcher.thread "ds18b20 reads" do
          loop do
            read(name, cache: false)
            sleep 2
          end
        end
      end
    end
  end

  def set(name, value = true)
    name = name.to_sym

    if @desc[:outputs].keys.include? name
      @desc[:outputs].set value
    end
  end

  def read(name, opts = {})
    name = name.to_sym

    if @desc[:inputs][name]
      # no caching for binary inptuts
    elsif @desc[:sensors][name]
      # TODO cache by default may be suboptimal uze #lazy_read or smthg?
      return @last_values[name][1] if opts[:cache] != false && @last_values[name] && (@last_values[name][0] < Time.now - @opts[:cache_time])
    else
      raise "no such output/sensor"
    end

    pin = @desc[:inputs][name] || @desc[:sensors][name]

    value = pin.read
    @last_values[name] ||= []
    @last_values[name][0] = Time.now
    @last_values[name][1] = value
    value
  end

  def state
    ret  = {}
    ret[:inputs] = Hash[*@desc[:inputs].map {|k,v| [k, read(k)]}.flatten ]
    ret[:sensors] = Hash[*@desc[:sensors].map {|k,v| [k, read(k)]}.flatten ]
    ret
  end

  def on_change(opts = {}, &block)
    if opts.kind_of? Symbol
      name = opts.to_sym
      if @desc[:inputs][name]
        @desc[:inputs][name].on_change do
          block.call
        end
      end
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

puts "HA state:"
ap ha.state
ha.on_change(:swo1) do
  ap ha.state
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

