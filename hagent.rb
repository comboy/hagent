require 'catcher'
require 'awesome_print'

$: << "."
require 'pcf8574'
require 'sensor/ds18b20'
require 'sensor/dht22'

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
  end

  def set(name, value = true)
    name = name.to_sym

    if @desc[:outputs].keys.include? name
      @desc[:outputs][name].set value
    end
  end

  def read(name, opts = {})
    name = name.to_sym

    if @desc[:inputs][name]
      # no caching for binary inptuts
    elsif @desc[:sensors][name]
      # TODO cache by default may be suboptimal uze #lazy_read or smthg?
      return @last_values[name][1] if opts[:cache] != false && @last_values[name] && (@last_values[name][0] > Time.now - @opts[:cache_time])
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

      # TODO assumption thath all inputs and sensors implement on_change
      pin = @desc[:inputs][name] || @desc[:sensors][name]
      if pin
        pin.on_change do
          # TODO @last_values cache shit
          block.call
        end
      else
        raise "no such pin"
      end
    end
  end
end

