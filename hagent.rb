require 'catcher'
require 'awesome_print'

$: << "."
require 'pcf8574'
require 'sensor/ds18b20'
require 'sensor/dht22'
require 'sensor/light'

class Hagent

  DEFAULT_OPTS = {
    cache_time: 5
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
      @desc[:outputs][name].set value
      @last_set[name] = value

      if @on_set_blocks[name]
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
        puts "DS: #{name} = #{state}"
      end
    end
  end

end

