class Hagent
  class DHT22
    def initialize(opts = {})
      @pin = opts[:pin]
      @opts = opts
      @opts[:read_interval] ||= 2
      @last_read = nil
      @on_change_blocks = []

      Catcher.thread "dht22 reads" do
        loop do
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
      # FIXME proper path
      response = `python vendor/AdafruitDHT.py 22 #{@pin}`
      response.split('Humidity=').last[0..-2].to_f
    end
  end
end
