# -*- coding: utf-8 -*-
#
# qwikのmail-*.rbがワケがわからなくなってきたので、メールの
# 解析とMIMEデコードを自力でやってみることにする
#
# 2011/5/2 masui
#
require 'nkf'
require 'base64'

class Mail
  def initialize
    @header = []     # @header = [['Date', 'Mon, 02 May 2011 07:44:13 +0900'], ...]
    @cid2file = {}
    @html = ''
  end
  
  attr_accessor :bare    # メールの生テキスト
  attr_accessor :header  # ヘッダ配列
  attr_accessor :body    # body文字列

  attr_accessor :data    # MIMEの階層構造を扱うために導入
                         # Mailクラスの配列またはbody文字列
  attr_accessor :cid2file
  attr_accessor :html

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

    make_tree(self)
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
    content_type = self['Content-Type']
    return nil if content_type.nil?
    #if /^multipart\/\w+;\s*boundary=("?)(.*)\1/i =~ ct
    if /^multipart\/\w+;/i =~ content_type and
        /[\s;]boundary=("?)(.*)\1/i =~ content_type
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

  def filename
    filename_from_content_disposition || filename_from_content_type
  end

  #
  # Content-Dispositionにはこういう文字列が入る
  # Content-Disposition: attachment;
  #  filename*0*=UTF-8''%32%2D%E2%91%A0%5F%E8%B3%87%E6%96%99%38%2D%31%5F%E9%80;
  #  filename*1*=%B2%E6%8D%97%E5%A0%B1%E5%91%8A%E6%9B%B8%5F%31%31%30%34%31%38;
  #  filename*2*=%5F%E6%9B%BE%E5%B7%9D%E9%87%8C%E7%94%B0%E7%89%87%E5%B1%B1%2E;
  #  filename*3*=%64%6F%63
  #
  # Content-Disposition:attachment;
  #  filename*=iso-2022-jp'ja'%1B%24B%21w%23I%23T%25m%254%25%5E%21%3C%25%2F%1B%28B%2Egif
  #
  # Content-Disposition:attachment;
  #  filename*0="51zJbcqaasL._SL110_PIsitb-sticker-arrow-sm,TopRight,10,-13_O";
  #  filename*1="U09_.jpg"
  #
  # これはRFC2231とかいうやつで、頑張ってデコードしなきゃ駄目らしい
  # http://www.atmarkit.co.jp/fnetwork/rensai/netpro04/netpro01.html
  # http://www.emaillab.org/win-mailer/exp-japanese.html
  #
  def filename_from_content_disposition
    s = self['Content-Disposition']
    return nil if s.nil?
    s = s.dup
    decode = false
    code = ''
    lang = ''
    name = ''
    if s =~ /filename\*=.*'.*'/ then # 1行HEX
      s =~ /filename\*=(\S*)'(\S*)'(.*)$/
      code = $1
      lang = $2
      name = $3
      decode = true
    elsif s =~ /filename\*0\*.*'.*'/ then # 複数行HEX
      num = 0
      while s =~ /filename/ do
        if s.sub!(/filename\*#{num}\*=(\S*)'(\S*)'([%0-9a-fA-F]+);?/,'') then
          code = $1
          lang = $2
          name += $3
        elsif s.sub!(/filename\*#{num}\*=([%0-9a-fA-F]+);?/,'') then
          name += $1
        end
        num += 1
      end
      decode = true
    elsif s =~ /filename="(.*)"/ then # 1行ノーマル
      name = $1
    elsif s =~ /filename\*0="(.*)"/ then
      num = 0
      while s =~ /filename/ do
        if s.sub!(/filename\*#{num}="(.*)"/,'') then
          name += $1
        elsif s.sub!(/filename\*#{num}=(.*)/,'') then
          name += $1
        end
        num += 1
      end
    end
    return decode ? NKF.nkf('-w',decode_percent_hex(name)) : name
  end

  #
  # RFC2047仕様になってるContent-Typeからファイル名を取り出す
  #
  # Content-Type: application/msword;
  #  name="=?UTF-8?B?Mi3ikaBf6LOH5paZOC0xX+mAsuaNl+WgseWRiuabuF8xMTA0MThf5pu+5bed6YeM?=
  #  =?UTF-8?B?55Sw54mH5bGxLmRvYw==?="
  #
  def filename_from_content_type
    self['Content-Type'] =~ /name="(.+)"/m
    s = $1
    return nil if s.nil?
    if s =~ /=\?.*\?=/ then
      name = ''
      method = 'B'
      code = ''
      while s.sub!(/=\?(\S+)\?([QB])\?(.*)\?=/,'') do
        code = $1
        method = $2
        name += (method == 'B' ? decode_base64($3) : decode_quoted_printable($3))
      end
      return name
    else
      return s
    end
  end

  def decode_base64(str)
    return Base64.decode64(str)
  end

  def decode_quoted_printable(str)
    str = str.gsub(/[ \t]+$/no, '')
    str.gsub!(/=\r?\n/no, '')
    str.gsub!(/=([0-9A-F][0-9A-F])/no) { $1.hex.chr }
    return str
  end

  def decode_percent_hex(str)
    str = str.gsub(/[ \t]+$/, '')
    str.gsub!(/%([0-9A-F][0-9A-F])/) { $1.hex.chr }
    return str
  end

  def decode_uuencode(str)
    uu = ''
    str.each {|line|
      next  if /\Abegin/ =~ line
      break if /\Aend/ =~ line
      uu << line
    }
    return uu.unpack('u').first
  end

  def decode_body
    enc = self['Content-Transfer-Encoding']
    return decode_base64(@body) if /base64/i =~ enc
    return decode_uuencode(@body) if /x-uuencode/i =~ enc
    return decode_quoted_printable(@body) if /quoted-printable/i =~ enc
    return body
  end

  def make_tree(mail)
    if mail.multipart? then
      parts = mail.split
      mail.data = parts.collect { |text|
        child = Mail.new
        child.read(text)
        make_tree(child)
      }
    else
      mail.data = mail.body
    end
    return mail
  end

  def prepare_aux_files(tmpdir)
    @cid2file = {}
    _prepare_aux_files(self,@cid2file,tmpdir)
  end

  def _prepare_aux_files(mail,cid2file,tmpdir)
    return if mail.body.size == 0
    if mail.data.class == Array then
      mail.data.each { |child|
        _prepare_aux_files(child,cid2file,tmpdir)
      }
    else
      cid = mail['Content-ID']
      filename = mail.filename
      if filename then
        File.open(tmpdir+"/"+filename,"w"){ |f|
          f.print mail.decode_body
        }
        if cid then
          cid.sub!(/^</,'')
          cid.sub!(/>$/,'')
          cid2file[cid] = filename
        end
      end
    end
  end

  def dump
    _dump(self)
  end

  def _dump(mail)
    return if mail.body.size == 0
    if mail.data.class == Array then
      if mail['Content-Type'] =~ /multipart\/alternative/ then  # プレーンテキストとHTML混在の場合など
        # 代表を決める
        rep = 0
        mail.data.each_with_index { |child,i|
          if child['Content-Type'] !~ /text\/plain/ then
            rep = i
          end
        }
        mail.html += _dump(mail.data[rep])
      elsif mail['Content-Type'] =~ /multipart\/mixed/ then # 添付ファイルなど
        mail.data.each { |child|
          if child['Content-Type'] =~ /multipart/ then
            mail.html += _dump(child)
          elsif child['Content-Type'] =~ /text\/plain/ then
            mail.html += ("<pre>" + child.decode_body + "</pre>\n")
          elsif child['Content-Type'] =~ /text\/html/ then
            mail.html += child.decode_body
          else
            mail.html += "<a href='/tmp/#{child.filename}'>#{child.filename}</a><br>"
          end
        }
      elsif mail['Content-Type'] =~ /multipart\/related/ then
        mail.data.each { |child|
          if child['Content-Disposition'] =~ /inline/ then
            # ファイルはインラインで表示される
          else
            html = child.decode_body
            while html =~ /"(cid:([^"]+))"/ do
              filename = "/tmp/#{@cid2file[$2]}"
              cidstr = $1
              html.gsub!(/#{Regexp.escape(cidstr)}/,"#{filename}")
            end
            mail.html += html
          end
        }
      end
    else
      mail.html += "<pre>" + mail.decode_body + "</pre>\n"
    end
    return mail.html
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
        mail.read(text)
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
          # puts mail['Content-Disposition']
          assert mail['Content-Disposition'] =~ /(inline|attachment)/
        end
      end
    end

    def test_filename
      TESTFILES.each { |testfile|
        mail = Mail.new
        text = File.read(testfile)
        mail.read(text)
        _test_filename(mail)
      }
    end

    def _test_filename(mail)
      return if mail.body.size == 0
      if mail.data.class == Array then
        mail.data.each { |child|
          _test_filename(child)
        }
      else
        # puts mail['Content-Disposition']
        # mail.filename
        # puts mail['Content-Type']
        assert_equal mail.filename_from_content_type, mail.filename_from_content_disposition
      end
    end

    def test_aux_files
      tmpdir = "/tmp/mime#{$$}"
      Dir.mkdir(tmpdir)
      mail = Mail.new
      text = File.read(TESTFILE1)
      mail.read(text)
      mail.prepare_aux_files(tmpdir)
      auxfiles = [
                  "25930913.jpg",
                  "56381097.jpg",
                  "66578592.jpg",
                  "69693880.jpg",
                  "7696614.jpg",
                  "9771903.jpg",
                  "facebook_16_16.png",
                  "su_16_16.png",
                  "twitter_16_16.png",
                 ]
      createdfiles = {}
      Dir.open(tmpdir).each { |file|
        createdfiles[file] = true
      }
      auxfiles.each { |auxfile|
        assert createdfiles[auxfile]
      }
      system "/bin/rm -r -f #{tmpdir}"
    end

  end
end




