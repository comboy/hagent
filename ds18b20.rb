class Hagent
  class DS18B20
    def initialize(opts)
      @addr = opts[:addr]
    end

    def read
      lines = File.read("/sys/bus/w1/devices/#{@addr}/w1_slave").split("\n")
      raise "nope" unless lines[0].match /YES$/
      lines[1].match(/t=(\d+)/)[1].to_i / 1_000.0
    end
  end
end
