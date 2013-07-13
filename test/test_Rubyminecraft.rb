require 'test/unit'
require 'RubyMinecraft'

class RubyminecraftTest < Test::Unit::TestCase
  def test_rcon
    test = RCON::Minecraft.new('ftb.leonplay.com',25575)
    assert_not_nil(test)
    assert_nothing_raised(Exception){test}
    assert_nothing_thrown(){test}
  end
  
  def test_query
    test = Query.simpleQuery('ftb.leonplay.com',25565)
    assert_not_nil(test)
    assert_nothing_raised(Exception){test}
    assert_nothing_thrown(){test}
  end
end
