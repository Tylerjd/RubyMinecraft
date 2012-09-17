class RubyMinecraft
  require 'socket'
  require 'timeout'
  
  def self.init
    @sock = UDPSocket.new
    @sock.connect(@addr,@port)
    @val = {}
    @buff = nil
    key
  end
  
  def self.key
    begin
      timeout(5) do
        start = @sock.send("\xFE\xFD\x09\x01\x02\x03\x04", 0)
        t = @sock.recvfrom(1460)[0]
        key = t[5...-1].to_i
        @key = Array(key).pack('N')
      end
    rescue Timeout::Error
      puts 'Timed Out!'
    end
  end
  
  def self.simpleQuery(addr, port)
    @addr = addr
    @port = port
    init
    begin
      timeout(5) do
        query = @sock.send("\xFE\xFD\x00\x01\x02\x03\x04" + @key, 0)
        data = @sock.recvfrom(1460)[0]
        buffer = data[5...-1]
        @val[:motd], @val[:gametype], @val[:map], @val[:numplayers], @val[:maxplayers], @buf = buffer.split("\x00", 6)
        if @sock != nil
          @sock.close
        end
      end
      return @val
    rescue Timeout::Error
      puts 'Timed Out!'
    end
  end
  
end