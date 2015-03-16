# TODO FIXME use FFI 
class Hagent
  class RF24
    def initialize(opts = {})
      @prog = "vendor/temp_rf24"
      # TODO pipes addresses go here from opts
    end

    def send(msg)
      self.class.lock.synchronize do
        print "RF Q #{msg}.."
        out = `#@prog -m #{msg}`
        if m = out.match(/response: (.*)$/)
          puts "OK"
          return m[1]
        else
          puts "NOPE"
          return nil
        end
      end
    end

    def self.lock
      @mutex ||= Mutex.new
    end
  end
end

#rf = Hagent::RF24.new

#puts "test rf: #{rf.send 10}"
