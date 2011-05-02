# -*- coding: utf-8 -*-
$LOAD_PATH << '..' unless $LOAD_PATH.include? '..'

require 'gyamm/config'

class Lock
  def initialize(addr, name, lockfile="#{ROOTDIR}/data/#{name}/lockfile")
    @addr = addr
    @name = name
    @lockfile = lockfile
    @password = ''
    if locked? then
      File.open(@lockfile){ |f|
        @lockaddr = f.gets.chomp
        @password = f.gets.chomp
      }
    end
  end

  def locked?
    File.exists?(@lockfile)
  end

  def lock(password)
    if @addr == @lockaddr || !locked? then
      File.open(@lockfile,"w"){ |f|
        f.puts @addr
        f.puts password
      }
      @lockaddr = @addr
      @password = password
      return true  # 成功
    end
    return false
  end

  def password
    @password
  end
end

if $0 == __FILE__
  require 'test/unit'
  $test = true
end

if defined?($test) && $test
  class TestLock < Test::Unit::TestCase
    def setup
      File.unlink("/tmp/locktest") if File.exists?("/tmp/locktest")
    end

    def test_lock
      lock = Lock.new('masui@pitecan.com', 'masui_test', "/tmp/locktest")
      assert ! lock.locked?
      assert lock.lock("secret")
      assert lock.locked?
      assert lock.lock("secret2")
      assert lock.locked?

      lock2 = Lock.new('masui@acm.org', 'masui_test', "/tmp/locktest")
      assert lock2.locked?
      assert ! lock2.lock("secret3")
    end

    def teardown
      File.unlink("/tmp/locktest")
    end
  end
end

