# -*- coding: utf-8 -*-
#
# qwikのmail-*.rbがワケがわからなくなってきたので、メールの
# 解析とMIMEデコードを自力でやってみることにする
#

class Mail
  def initialize
    @bare = nil      # メールの生テキスト
    @header = []     # @header['Date'] = 'Mon, 02 May 2011 07:44:13 +0900'
    @body = ''
  end
  
  attr_accessor :bare
  attr_accessor :header
  attr_accessor :body

  def read(text)
    @bare = text || ''
    
    header, body = @bare.split(/\n\n/, 2)
    @body = body || ''
    
    attr = nil
    header.split("\n").each {|line|
      line.chomp!
      if /^(\S+):\s*(.*)/ =~ line
        attr = $1
        @header.push([attr, $2])
      elsif attr
        @header.last[1] += ("\n" + line)
      end
    }
  end
end

if $0 == __FILE__
  require 'test/unit'
  $test = true
end

if defined?($test) && $test
  GYAMMDIR = "/Users/masui/Gyamm/data"
  TESTFILE1 = GYAMMDIR + "/masui_test/20110501212905" # StumbleUpon
  TESTFILE2 = GYAMMDIR + "/masui_test/20110502075633" # Amazon
  TESTFILE3 = GYAMMDIR + "/masui_test/20110502074413" # 未踏
  TESTFILES = [TESTFILE1, TESTFILE2, TESTFILE3]

  class TestMime < Test::Unit::TestCase
    def test_bare
      TESTFILES.each { |testfile|
        mail = Mail.new
        text = File.read(testfile)
        mail.read(text)
        assert mail.bare.size > 0
        assert mail.bare =~ /From/
        assert mail.bare =~ /Date/
      }
    end

    def test_body
      TESTFILES.each { |testfile|
        mail = Mail.new
        text = File.read(testfile)
        mail.read(text)
        assert mail.body.size > 0
        assert mail.body =~ /multi-part/
      }
    end

    def test_header
      TESTFILES.each { |testfile|
        mail = Mail.new
        text = File.read(testfile)
        mail.read(text)
        assert mail.header != nil
        assert mail.header.class == Array
        assert mail.header[0].class == Array
        e = {}
        mail.header.each { |entry|
          e[entry[0]] = true
        }
        assert e['Date']
        assert e['Received']
      }
    end
  end
end






