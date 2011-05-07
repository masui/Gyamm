# -*- coding: utf-8 -*-
$LOAD_PATH << '..' unless $LOAD_PATH.include? '..'

require 'gyamm/config'
require 'gyamm/lock'
require 'gyamm/mime'
require 'gyamm/delete'
require 'time'

class Gyamm
  def initialize(name)
    @name = name
    @path = datadir(name)
  end

  def valid?
    File.exists?(@path) && File.directory?(@path)
  end

  def path(id)
    "#{@path}/#{id}"
  end

  def cachedir(id)
    id =~ /^(........)/
    dir = "#{tmpdir}/#{$1}"
    unless File.exists?(dir) then
      Dir.mkdir(dir)
    end
    return dir
  end

  def cacheurl(id)
    cachedir(id)
    id =~ /^(........)/
    return "/tmp/#{$1}"
  end

  def ids
    list = []
    if File.exists?(@path) && File.directory?(@path) then
      list = Dir.open(@path).find_all { |id|
        id =~ /^\d{14}$/
      }.sort
    end
    return list
  end

  def valid_ids
    d = DeleteFiles.new("#{@path}/deletefiles")
    list = ids.find_all { |id|
      ! d.deleted?(id)
    }
    return list
  end

  def each
    ids.each { |id|
      yield id
    }
  end

  def from(id)
    text = File.read(path(id))
    mime = Mime.new
    mime.read(text)
    s = mime['From']
    addr = (s =~ /<(.*@.*)>/ ? $1 :
            s =~ /\[mailto:(.*@.*)\]/ ? $1 : 
            s =~ /(\S+@\S+)/ ? $1 : s)
    return addr
  end

  def members
    members = {}
    ids.each { |id|
      members[from(id)] = true
    }
    return members.keys
  end
end

def message_html(name,id,link=false)
  File.open("/tmp/name","w"){ |f|
    f.puts name
    f.puts id
  }
  gyamm = Gyamm.new(name)
  file = gyamm.path(id)
  text = (File.exists?(file) ? File.read(file) : '')

  if !link then
    @link = linkname(text)
    if !File.exists?(linkfile(@link)) then
      File.symlink(file,linkfile(@link))
    end
  else
    @link = nil
  end

  mime = Mime.new
  cachedir = gyamm.cachedir(id)
  cacheurl = gyamm.cacheurl(id)
  mime.read(text)
  mime.prepare_aux_files(cachedir)
  @from = mime['From'].to_s.sub(/</,'&lt;').toutf8
  @to = mime['To'].to_s.sub(/</,'&lt;').toutf8
  @subject = mime['Subject'].to_s.toutf8
  @html = mime.dump(cacheurl)
  @body = mime.body.toutf8
  @id = id
  @name = name
  erb :message
end

#
# 単体でメールを表示したいとき(リストを見せたくないとき)利用
#
def link_html(link)
  file = File.readlink(linkfile(link))
  file =~ %r{/([^/]+)/([^/]+)$}
  name = $1
  id = $2
  message_html(name,id,link)
end

def list_html(name)
  @name = name
  gyamm = Gyamm.new(name)
  if gyamm.valid? then
    @ids = gyamm.valid_ids.sort { |a,b|
      #
      # ownerが異なるファイルに対してFile.touchはできるのにFile.utimeができないので、
      # ファイルの更新時刻とファイルIDを連結したものを比較することによりファイルを新しい順に並べることにする。
      #
      File.mtime(gyamm.path(b)).strftime('%Y%m%d%H%M%S')+b <=>
      File.mtime(gyamm.path(a)).strftime('%Y%m%d%H%M%S')+a
    }
    @subject = {}
    @date = {}
    @ids.each { |id|
      text = File.read(gyamm.path(id))
      @mail = Mime.new
      @mail.read(text)
      @subject[id] = @mail['Subject'].to_s.toutf8
      @subject[id] = "(タイトルなし)" if @subject[id] == ""
      (dummy, y, m, d, h, min) = id.match(/^(....)(..)(..)(..)(..)/).to_a
      @date[id] = "#{y}/#{m.to_i}/#{d.to_i} #{h.to_i}:#{min}"
    }
    @lock = ''
    lock = Lock.new(name)
    if @locker = lock.locked_by then
      @lock = "このアーカイブは <b>#{@locker}</b> によりロックされています"
    end
    erb :list
  else
    'このURLは利用されていません'
  end
end

# ファイルのDate:をmodtimeにしようとしたのだが、ownerが異なるファイルに
# 対してFile.utimeができないらしいため失敗。
# touchで我慢することにする。

def touch_all(name)
  gyamm = Gyamm.new(name)
  gyamm.each { |id|
    FileUtils.touch(gyamm.path(id))
  }
end

if $0 == __FILE__
  require 'test/unit'
  $test = true
end

if defined?($test) && $test
  class TestMime < Test::Unit::TestCase
    def test_members
      gyamm = Gyamm.new("ubi-programming")
      members = gyamm.members
      assert_equal members.class, Array
      assert members.length > 0
      assert members.include?("masui@pitecan.com")
    end

    def test_from
      gyamm = Gyamm.new("masui_test")
      gyamm.each { |id|
        from = gyamm.from(id)
        assert_equal from, "masui@pitecan.com"
      }
    end

    def test_ids
      gyamm = Gyamm.new("ubi-programming")
      gyamm.ids.each { |id|
        assert id =~ /^\d{14}$/
      }
    end

    def test_valid_ids
      gyamm = Gyamm.new("ubi-programming")
      valid_ids = gyamm.valid_ids
      assert_equal valid_ids.class, Array
      assert valid_ids.length > 0
      valid_ids.each { |id|
        assert id =~ /^\d{14}$/
      }
      assert gyamm.ids.length > valid_ids.length
    end

    def test_ids_sorted
      gyamm = Gyamm.new("ubi-programming")
      firstid = gyamm.ids[0]
      gyamm.each { |id|
        assert firstid <= id
      }
    end
  end
end

