require 'bundler/setup'

require 'catcher'
require 'awesome_print'

$: << "."

require_relative 'hagent/generic_input'

require_relative 'pcf8574'
require_relative 'sensor/ds18b20'
require_relative 'sensor/dht22'
require_relative 'sensor/light'
require_relative 'ard_light'
require_relative 'ard_door'
require_relative 'rpi'


class Hagent

  DEFAULT_OPTS = {
    cache_time: 5,
    set_timeout: 120
  }

  def initialize(description, opts = {})
    @desc = {inputs: {}, outputs: {}, sensors: {}}.merge description
    @last_values = {}
    @last_set = {}

    @opts = DEFAULT_OPTS.merge opts
    @desc[:inputs].each_pair do |name, pin|
      pin.mode = :input
    end

    @on_set_blocks = {}
  end

  def set(name, value = true)
    name = name.to_sym

    if @desc[:outputs].keys.include? name

      Timeout.timeout(@opts[:set_timeout]) { @desc[:outputs][name].set value }
      @last_set[name] = value

      if !Thread.current[:hagent_without_callbacks] && @on_set_blocks[name]
        # probably should only be called when value is differnt
        @on_set_blocks[name].each do |block|
          Catcher.thread "hagent on set blocks" do
            block.call(value)
          end
        end
      end
    end
  end

  def report_sensors(pairing)
  end

  def last_set(name)
    name = name.to_sym
    return @desc[:outputs][name].read if @desc[:outputs][name].respond_to?(:read)
    @last_set[name]
  end

  def read(name, opts = {})
    name = name.to_sym

    if @desc[:inputs][name]
      # no caching for binary inptuts
    elsif @desc[:sensors][name]
      # TODO cache by default may be suboptimal uze #lazy_read or smthg?
      return @last_values[name][1] if opts[:cache] != false && @last_values[name] && (@last_values[name][0] > Time.now - @opts[:cache_time])
    else
      raise "no such input/output/sensor"
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

  def without_callbacks
    Thread.current[:hagent_without_callbacks] = true
    yield
    Thread.current[:hagent_without_callbacks] = false
  end

  # Position of the switch irrelevant, state toggles on change
  def toggle_switch(input, output)
    on_change input do
      sleep 0.01 # almost switch debounce ;)
      set output, !last_set(output)
    end
  end

  # Switch position decides the state
  def direct_switch(input, output)
    on_change input do
      state = read input
      set output, state
    end
  end

  def on_set(output, &block)
    output = output.to_sym
    @on_set_blocks[output] ||= []
    @on_set_blocks[output] << block
  end


  # Utils, move to some utils.rb
  #

  def debug_inputs
    puts "WHY"
    @desc[:inputs].each_pair do |name, pin|
      name = name.to_sym
      pin.on_change do
        state = read name
        puts "[#{Time.now}] DS: #{name} = #{state}"
      end
    end
  end

end

