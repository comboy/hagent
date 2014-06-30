class Hagent
  class DS18B20
    def initialize(opts = {})
      @addr = opts[:addr]
      @opts = opts
      @opts[:read_interval] ||= 1
      @last_read = nil
      @on_change_blocks = []
      @baz = "bar"

      Catcher.thread "ds18b20 reads" do
        loop do
          @baz = "moo"
          value = read_sensor
          if @last_read != value
            # make last_read assignment in case on change blocks want that value
            @last_read = value
            @on_change_blocks.each {|b| b.call }
          end
          @last_read = value
          sleep @opts[:read_interval]
        end
      end
    end

    def on_change(&block)
      @on_change_blocks << block
    end

    def read
      @last_read || read_sensor
    end

    protected
 
    def read_sensor
      lines = File.read("/sys/bus/w1/devices/#{@addr}/w1_slave").split("\n")
      raise "nope" unless lines[0].match /YES$/
      lines[1].match(/t=(\d+)/)[1].to_i / 1_000.0
    end
  end
end
