# -*- coding: utf-8 -*-
#
# Gyammのパスワード処理
#
# ロックファイルにメールアドレスとパスワードを書いておき、
# 同じメールアドレスからの要求は受け付ける。
#
$LOAD_PATH << '..' unless $LOAD_PATH.include? '..'

require 'gyamm/config'

class Lock
  def initialize(name, lockfile="#{ROOTDIR}/data/#{name}/lockfile")
    @name = name
    @lockfile = lockfile
    getinfo
  end

  attr_reader :addr, :password

  def locked?
    File.exists?(@lockfile)
  end

  def getinfo
    @addr = ''
    @password = ''
    if locked? then
      File.open(@lockfile){ |f|
        @addr = f.gets.chomp
        @password = f.gets.chomp
      }
    end
  end

  def lock(addr, password)
    getinfo
    if addr == @addr || !locked? then
      File.open(@lockfile,"w"){ |f|
        f.puts addr
        f.puts password
      }
      File.chmod(0777,@lockfile)
      @addr = addr
      @password = password
      return true  # 成功
    end
    return false
  end

  def unlock(addr)
    return true if !locked?
    getinfo
    if addr == @addr then
      File.unlink(@lockfile)
      return true
    end
    return false
  end
end

if $0 == __FILE__
  require 'test/unit'
  $test = true
end

if defined?($test) && $test
  class TestLock < Test::Unit::TestCase
    TESTLOCK = "/tmp/locktest"
    
    def setup
      File.unlink(TESTLOCK) if File.exists?(TESTLOCK)
    end

    def test_lock
      lock = Lock.new('masui_test', TESTLOCK)
      assert ! lock.locked?
      assert lock.lock("masui@pitecan.com", "secret")
      assert lock.locked?
      assert lock.lock("masui@pitecan.com", "secret2")
      assert lock.locked?

      lock2 = Lock.new('masui_test', TESTLOCK)
      assert lock2.locked?
      assert ! lock2.lock("masui@acm.org", "secret3")
    end

    def test_unlock
      lock = Lock.new('masui_test', TESTLOCK)
      assert lock.unlock("masui@pitecan.com")
      assert lock.unlock("dummy")
      assert lock.lock("masui@pitecan.com", "secret")
      assert lock.locked?
      assert lock.unlock("masui@pitecan.com")
      assert ! lock.locked?
      assert lock.lock("masui@pitecan.com", "secret")
      assert ! lock.unlock("masui@acm.org")
      assert lock.locked?
      assert lock.unlock("masui@pitecan.com")
      assert ! lock.locked?
    end

    def teardown
      File.unlink(TESTLOCK) if File.exists?(TESTLOCK)
    end
  end
end
