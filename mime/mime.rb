# -*- coding: utf-8 -*-
#
# qwikのmail-*.rbがワケがわからなくなってきたので、メールの
# 解析とMIMEデコードを自力でやってみることにする
#
# 2011/5/2 masui
#

class Mail
  def initialize
    @header = []     # @header = [['Date', 'Mon, 02 May 2011 07:44:13 +0900'], ...]
  end
  
  attr_accessor :bare    # メールの生テキスト
  attr_accessor :header  # ヘッダ配列
  attr_accessor :body    # body文字列

  attr_accessor :data    # MIMEの階層構造を扱うために導入
                         # Mailクラスの配列またはbody文字列

  def read(text)
    # 生テキスト
    @bare = text || ''
    
    #
    # ヘッダと中身は空行で区切られている
    # その他も空行は入ってるので「2」を引数に入れる
    #
    header, body = @bare.split(/\n\n/, 2)
    @body = body || ''
    
    #
    # ヘッダ解析
    # @header = [['Received', '...'], ['Received', '...'], ['Date', '...'], ...]
    #
    attr = nil
    header.split("\n").each { |line|
      line.chomp!
      if /^(\S+):\s*(.*)/ =~ line
        attr = $1
        @header.push([attr, $2])
      elsif attr
        @header.last[1] += ("\n" + line)
      end
    }
  end

  #
  # mail['Date'] => 'Mon, 02 May 2011 07:44:13 +0900', etc.
  # 
  def [](key)
    field = @header.find { |field|
      key.downcase == field.first.downcase
    }
    return nil if field.nil?
    return field.last
  end

  #
  # Content-Typeに指定されているバウンダリ文字列を取得
  # 古いqwikに不具合があったのを指摘されて直したものらしい
  #
  def boundary
    ct = self['Content-Type']
    return nil if ct.nil?
    #if /^multipart\/\w+;\s*boundary=("?)(.*)\1/i =~ ct
    if /^multipart\/\w+;/i =~ ct and /[\s;]boundary=("?)(.*)\1/i =~ ct
      return $2 
    end
    return nil
  end

  def multipart?
    return !!boundary
  end

  #
  # バウンダリ文字列でbodyを分割する。
  # 部分は "--バウンダリ文字列" で区切られており、
  # 最後だけ "--バウンダリ文字列--" がつくことになっているようだ
  # splitすると最初と最後が空文字列になるので捨てる
  #
  def split
    bdy = self.body
    bry = self.boundary
    return [bdy] if bry.nil? || bry.empty?
    parts = bdy.split(/^--#{Regexp.escape(bry)}-*\n/)
    parts.shift	# Remove the first empty string.
    parts.pop if /\A\s*\z/ =~ parts.last
    return parts
  end

  def make_tree(text)
    self.read(text)
    _make_tree(self)
  end

  def _make_tree(mail)
    if mail.multipart? then
      parts = mail.split
      mail.data = parts.collect { |text|
        child = Mail.new
        child.read(text)
        _make_tree(child)
      }
    else
      mail.data = mail.body
    end
    return mail
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
  TESTFILES = []
  TESTFILES << TESTFILE1
  TESTFILES << TESTFILE2
  TESTFILES << TESTFILE3

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

    def test_hash
      TESTFILES.each { |testfile|
        mail = Mail.new
        text = File.read(testfile)
        mail.read(text)
        assert mail['Date'] != nil
        assert mail['Date'].class == String
        assert mail['Date'].length > 0
        assert mail['Date'] =~ /(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) /
        assert mail['Date'] =~ /2\d\d\d /
        assert mail['date'] =~ /2\d\d\d /
      }
    end

    def test_boundary
      TESTFILES.each { |testfile|
        mail = Mail.new
        text = File.read(testfile)
        mail.read(text)
        assert mail.boundary != nil
        assert mail.boundary.class == String
        assert mail.boundary.length > 10      # それなりに長いはず
      }
    end

    def test_multipart
      TESTFILES.each { |testfile|
        mail = Mail.new
        text = File.read(testfile)
        mail.read(text)
        assert mail.multipart?
      }
    end

    def test_split
      TESTFILES.each { |testfile|
        mail = Mail.new
        text = File.read(testfile)
        mail.read(text)
        parts = mail.split
        assert parts != nil
        assert parts.class == Array
        assert parts[0].class == String
      }
    end

    def test_tree
      TESTFILES.each { |testfile|
        mail = Mail.new
        text = File.read(testfile)
        mail.make_tree(text)
        _test_tree(mail)
      }
    end

    def _test_tree(mail)
      return if mail.body.size == 0
      if mail.data.class == Array then
        mail.data.each { |child|
          _test_tree(child)
        }
        assert mail.header.class == Array
        assert mail.body.class == String
        assert mail.data.class == Array
        assert mail.data.length > 0
        # puts mail['Content-Type']
        assert mail['Content-Type'] =~ /multipart/
      else
        assert mail.header.class == Array
        assert mail.body.class == String
        assert mail.data.class == String
        assert mail.data.length > 0
        # puts mail['Content-Type']
        assert mail['Content-Type'] =~ /(text|image|application)/ # 他にもあるかも
        if mail['Content-Disposition'] then
          assert mail['Content-Disposition'] =~ /(inline|attachment)/
        end
      end
    end

#    #
#    # MIMEの入れ子構造をたどるテスト
#    #
#    def test_recursive
#      TESTFILES.each { |testfile|
#        text = File.read(testfile)
#        _test_recursive(text)
#      }
#    end
#
#    def _test_recursive(text)
#      mail = Mail.new
#      mail.read(text)
#      if mail.multipart? then
#        parts = mail.split
#        assert parts != nil
#        assert parts.class == Array
#        mail.data = parts.collect { |text|
#          assert text.class == String
#          assert text.length > 0
#          _test_recursive(text)
#        }
#      else
#        mail.data = mail.body
#      end
#      return mail
#    end


  end
end




