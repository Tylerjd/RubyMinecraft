class RCON
  class Packet
    # placeholder so ruby doesn't bitch
  end
  class Query

    def cvar(cvar_name)
      response = command(cvar_name)
      match = /^.+?\s(?:is|=)\s"([^"]+)".*$/.match response
      match = match[1]
      if /\D/.match match
        return match
      else
        return match.to_i
      end
    end
  end
end
  
  class RubyMinecraft::RCON::Packet::Source
    # execution command
    COMMAND_EXEC = 2
    # auth command
    COMMAND_AUTH = 3
    # auth response
    RESPONSE_AUTH = 2
    # normal response
    RESPONSE_NORM = 0
    # packet trailer
    TRAILER = "\x00\x00"
  
    # size of the packet (10 bytes for header + string1 length)
    attr_accessor :packet_size
    # Request Identifier, used in managing multiple requests at once
    attr_accessor :request_id
    # Type of command, normally COMMAND_AUTH or COMMAND_EXEC. In response packets, RESPONSE_AUTH or RESPONSE_NORM
    attr_accessor :command_type
    # First string, the only used one in the protocol, contains
    # commands and responses. Null terminated.
    attr_accessor :string1
    # Second string, unused by the protocol. Null terminated.
    attr_accessor :string2
  
    #
    # Generate a command packet to be sent to an already
    # authenticated RubyMinecraft::RCON connection. Takes the command as an
    # argument.
    # 
    def command(string)
      @request_id = rand(1000)
      @string1 = string
      @string2 = TRAILER
      @command_type = COMMAND_EXEC

      @packet_size = build_packet.length

      return self
    end
  
    #
    # Generate an authentication packet to be sent to a newly
    # started RubyMinecraft::RCON connection. Takes the RubyMinecraft::RCON password as an
    # argument.
    #
    def auth(string)
      @request_id = rand(1000)
      @string1 = string
      @string2 = TRAILER
      @command_type = COMMAND_AUTH
    
      @packet_size = build_packet.length
    
      return self
    end
  
    #
    # Builds a packet ready to deliver, without the size prepended.
    # Used to calculate the packet size, use #to_s to get the packet
    # that srcds actually needs.
    #
    def build_packet
      return [@request_id, @command_type, @string1, @string2].pack("VVa#{@string1.length}a2")
    end

    # Returns a string representation of the packet, useful for
    # sending and debugging. This include the packet size.
    def to_s
      packet = build_packet
      @packet_size = packet.length
      return [@packet_size].pack("V") + packet
    end

  end
  
  #
  # RubyMinecraft::RCON::Query::Source sends queries to a "Source" Engine server,
  # such as Half-Life 2: Deathmatch, Counter-Strike: Source, or Day
  # of Defeat: Source.
  #
  # Note that one authentication packet needs to be sent to send
  # multiple commands. Sending multiple authentication packets may
  # damage the current connection and require it to be reset.
  #
  # Note: If the attribute 'return_packets' is set to true, the full
  # RubyMinecraft::RCON::Packet::Source object is returned, instead of just a string
  # with the headers stripped. Useful for debugging.
  #

  class RubyMinecraft::RCON::Query::Source < RubyMinecraft::RCON::Query
    # RubyMinecraft::RCON::Packet::Source object that was sent as a result of the last query
    attr_reader :packet
    # TCPSocket object
    attr_reader :socket
    # Host of connection
    attr_reader :host
    # Port of connection
    attr_reader :port
    # Authentication Status
    attr_reader :authed
    # return full packet, or just data?
    attr_accessor :return_packets
  
    #
    # Given a host and a port (dotted-quad or hostname OK), creates
    # a RubyMinecraft::RCON::Query::Source object. Note that this will still
    # require an authentication packet (see the auth() method)
    # before commands can be sent.
    #

    def initialize(host, port)
      @host = host
      @port = port
      @socket = nil
      @packet = nil
      @authed = false
      @return_packets = false
    end
  
    #
    # See RubyMinecraft::RCON::Query#cvar.
    # 
  
    def cvar(cvar_name)
      return_packets = @return_packets
      @return_packets = false
      response = super
      @return_packets = return_packets
      return response
    end

    #
    # Sends a RubyMinecraft::RCON command to the server. May be used multiple times
    # after an authentication is successful. 
    #
    # See the class-level documentation on the 'return_packet' attribute
    # for return values. The default is to return a string containing
    # the response.
    #
  
    def command(command)
    
      if ! @authed
        raise RubyMinecraft::RCON::NetworkException.new("You must authenticate the connection successfully before sending commands.")
      end

      @packet = RubyMinecraft::RCON::Packet::Source.new
      @packet.command(command)

      @socket.print @packet.to_s
      rpacket = build_response_packet

      if rpacket.command_type != RubyMinecraft::RCON::Packet::Source::RESPONSE_NORM
        raise RubyMinecraft::RCON::NetworkException.new("error sending command: #{rpacket.command_type}")
      end

      if @return_packets
        return rpacket
      else
        return rpacket.string1
      end
    end
  
    #
    # Requests authentication from the RubyMinecraft::RCON server, given a
    # password. Is only expected to be used once.
    #
    # See the class-level documentation on the 'return_packet' attribute
    # for return values. The default is to return a true value if auth
    # succeeded.
    #
  
    def auth(password)
      establish_connection

      @packet = RubyMinecraft::RCON::Packet::Source.new
      @packet.auth(password)

      @socket.print @packet.to_s
      # on auth, one junk packet is sent
      rpacket = nil
      2.times { rpacket = build_response_packet }

      if rpacket.command_type != RubyMinecraft::RCON::Packet::Source::RESPONSE_AUTH
        raise RubyMinecraft::RCON::NetworkException.new("error authenticating: #{rpacket.command_type}")
      end

      @authed = true
      if @return_packets
        return rpacket
      else
        return true
      end
    end

    alias_method :authenticate, :auth
  
    #
    # Disconnects from the Source server.
    #
  
    def disconnect
      if @socket
        @socket.close
        @socket = nil
        @authed = false
      end
    end
  
    protected
  
    #
    # Builds a RubyMinecraft::RCON::Packet::Source packet based on the response
    # given by the server. 
    #
    def build_response_packet
      rpacket = RubyMinecraft::RCON::Packet::Source.new
      total_size = 0
      request_id = 0
      type = 0
      response = ""
      message = ""
    

      loop do
        break unless IO.select([@socket], nil, nil, 10)

        #
        # TODO: clean this up - read everything and then unpack.
        #

        tmp = @socket.recv(14)
        if tmp.nil?
          return nil
        end
        size, request_id, type, message = tmp.unpack("VVVa*")
        total_size += size
      
        # special case for authentication
        break if message.sub! /\x00\x00$/, ""

        response << message

        # the 'size - 10' here accounts for the fact that we've snarfed 14 bytes,
        # the size (which is 4 bytes) is not counted, yet represents the rest
        # of the packet (which we have already taken 10 bytes from)

        tmp = @socket.recv(size - 10)
        response << tmp
        response.sub! /\x00\x00$/, ""
      end
    
      rpacket.packet_size = total_size
      rpacket.request_id = request_id
      rpacket.command_type = type
    
      # strip nulls (this is actually the end of string1 and string2)
      rpacket.string1 = response.sub /\x00\x00$/, ""
      return rpacket
    end
  
    # establishes a connection to the server.
    def establish_connection
      if @socket.nil?
        @socket = TCPSocket.new(@host, @port)
      end
    end
  
  end


  class RubyMinecraft::RCON::Query::Minecraft < RubyMinecraft::RCON::Query
    # RubyMinecraft::RCON::Packet::Source object that was sent as a result of the last query
    attr_reader :packet
    # TCPSocket object
    attr_reader :socket
    # Host of connection
    attr_reader :host
    # Port of connection
    attr_reader :port
    # Authentication Status
    attr_reader :authed
    # return full packet, or just data?
    attr_accessor :return_packets
  
    #
    # Given a host and a port (dotted-quad or hostname OK), creates
    # a RubyMinecraft::RCON::Query::Minecraft object. Note that this will still
    # require an authentication packet (see the auth() method)
    # before commands can be sent.
    #

    def initialize(host, port)
      @host = host
      @port = port
      @socket = nil
      @packet = nil
      @authed = false
      @return_packets = false
    end
  
    #
    # See RubyMinecraft::RCON::Query#cvar.
    # 
  
    def cvar(cvar_name)
      return_packets = @return_packets
      @return_packets = false
      response = super
      @return_packets = return_packets
      return response
    end

    #
    # Sends a RubyMinecraft::RCON command to the server. May be used multiple times
    # after an authentication is successful. 
    #
    # See the class-level documentation on the 'return_packet' attribute
    # for return values. The default is to return a string containing
    # the response.
    #
  
    def command(command)
    
      if ! @authed
        raise RubyMinecraft::RCON::NetworkException.new("You must authenticate the connection successfully before sending commands.")
      end

      @packet = RubyMinecraft::RCON::Packet::Source.new
      @packet.command(command)

      @socket.print @packet.to_s
      rpacket = build_response_packet

      if rpacket.command_type != RubyMinecraft::RCON::Packet::Source::RESPONSE_NORM
        raise RubyMinecraft::RCON::NetworkException.new("error sending command: #{rpacket.command_type}")
      end

      if @return_packets
        return rpacket
      else
        return rpacket.string1
      end
    end
  
    #
    # Requests authentication from the RubyMinecraft::RCON server, given a
    # password. Is only expected to be used once.
    #
    # See the class-level documentation on the 'return_packet' attribute
    # for return values. The default is to return a true value if auth
    # succeeded.
    #
  
    def auth(password)
      establish_connection

      @packet = RubyMinecraft::RCON::Packet::Source.new
      @packet.auth(password)

      @socket.print @packet.to_s
      rpacket = nil
      rpacket = build_response_packet

      if rpacket.command_type != RubyMinecraft::RCON::Packet::Source::RESPONSE_AUTH
        raise RubyMinecraft::RCON::NetworkException.new("error authenticating: #{rpacket.command_type}")
      end

      @authed = true
      if @return_packets
        return rpacket
      else
        return true
      end
    end

    alias_method :authenticate, :auth
  
    #
    # Disconnects from the Minecraft server.
    #
  
    def disconnect
      if @socket
        @socket.close
        @socket = nil
        @authed = false
      end
    end
  
    protected
  
    #
    # Builds a RubyMinecraft::RCON::Packet::Source packet based on the response
    # given by the server. 
    #
    def build_response_packet
      rpacket = RubyMinecraft::RCON::Packet::Source.new
      total_size = 0
      request_id = 0
      type = 0
      response = ""
      message = ""
      message2 = ""

      tmp = @socket.recv(4)
      if tmp.nil?
        return nil
      end
      size = tmp.unpack("V1")
      tmp = @socket.recv(size[0])
      request_id, type, message, message2 = tmp.unpack("V1V1a*a*")
      total_size = size[0]
      
      #puts "size: "+size.to_s 
      #puts "type: "+type.to_s
      #puts "message: "+message
      #puts "message2: "+message2
    
      rpacket.packet_size = total_size
      rpacket.request_id = request_id
      rpacket.command_type = type
    
      # strip nulls (this is actually the end of string1 and string2)
      message.sub! /\x00\x00$/, ""
      message2.sub! /\x00\x00$/, ""
      rpacket.string1 = message
      rpacket.string2 = message2
      return rpacket
    end
  
    # establishes a connection to the server.
    def establish_connection
      if @socket.nil?
        @socket = TCPSocket.new(@host, @port)
      end
    end
  
  end

  # Exception class for network errors
  class RubyMinecraft::RCON::NetworkException < Exception
  end
end