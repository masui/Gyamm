# Copyright (C) 2003-2006 Kouichirou Eto, All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
# You can redistribute it and/or modify it under the terms of the GNU GPL 2.

$LOAD_PATH << '..' unless $LOAD_PATH.include? '..'

class MockLogger
  def initialize
    clear
  end
  
  def clear
    @log = []
    @vlog = []
  end
  
  def log(str)
    @vlog << str
    @log << str
  end
  
  def vlog(str)
    @vlog << str
  end
  
  def get_log
    lo = @log
    clear
    return lo
  end
  
  def get_vlog
    lo = @vlog
    clear
    return lo
  end
end

if $0 == __FILE__
  require 'test/unit'
  $test = true
end

if defined?($test) && $test
  class TestMockLogger < Test::Unit::TestCase
    def test_all
      # test_initialize
      s = MockLogger.new

      # test_log
      s.log('t')

      # test_get_log
      assert_equal(['t'], s.get_log)

      # test_vlog
      s.vlog('v')

      # test_get_vlog
      assert_equal(['v'], s.get_vlog)
    end
  end
end
