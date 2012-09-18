require 'test/unit'
require 'RubyMinecraft'

class RubyminecraftTest < Test::Unit::TestCase
  def test_rcon
    test = RCON::Minecraft.new('s.ecs-server.net',25575)
    assert_not_nil(test)
    assert_nothing_raised(Exception){test}
    assert_nothing_thrown(){test}
  end
  
  def test_query
    test = Query.simpleQuery('s.ecs-server.net',25565)
    assert_not_nil(test)
    assert_nothing_raised(Exception){test}
    assert_nothing_thrown(){test}
  end
end