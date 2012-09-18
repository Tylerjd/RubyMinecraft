class RubyMinecraft::Query
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
  
  def self.fullQuery(addr, port)
    @addr = addr
    @port = port
    timeout(5) do
      query = @socket.send("\xFE\xFD\x00\x01\x02\x03\x04"+ @key + "\x00\x01\x02\x03\x04", 0)
      data = @socket.recvfrom(1460)[0]
      buffer = data[11...-1]
      items, players = buffer.split("\x00\x00\x01player_\x00\x00")
      if items[0...8] == 'hostname'
        items = 'motd' + items[8...-1]
      end
      @vals = {}
      items = items.split("\x00")
      items.each_with_index do |key, idx|
        next unless idx % 2 == 0
          @vals[key] = items[idx + 1]
        end

        @vals["motd"] = @vals["hostname"]
        @vals.delete("hostname")
        @vals.delete("um") if @vals["um"]

        players = players[0..-2]

        if players
          @vals[:players] = players.split("\x00")
        end
        @vals["raw_plugins"] = @vals["plugins"]
        parts = @vals["raw_plugins"].split(":")
        server = parts[0].strip()
        plugins = []
        if parts.size == 2
          plugins = parts[1].split(";").map {|value| value.strip() }
        end
        @vals["plugins"] = plugins
        @vals["server"] = server
      end
      return @vals
    end
  end
  
end