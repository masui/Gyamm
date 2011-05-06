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
    @path = "#{ROOTDIR}/data/#{@name}"
  end

  def valid?
    File.exists?(@path) && File.directory?(@path)
  end

  def path(id)
    "#{@path}/#{id}"
  end

  def cachedir(id)
    id =~ /^(........)/
    dir = "#{ROOTDIR}/public/tmp/#{$1}"
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
    d = DeleteFiles.new("#{ROOTDIR}/data/#{@name}/deletefiles")
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

def message_html(name,id)
  gyamm = Gyamm.new(name)
  file = gyamm.path(id)
  text = (File.exists?(file) ? File.read(file) : '')
  mime = Mime.new
  cachedir = gyamm.cachedir(id)
  cacheurl = gyamm.cacheurl(id)
  mime.read(text)
  mime.prepare_aux_files(cachedir)
  @from = mime['From'].to_s.toutf8
  @to = mime['To'].to_s.toutf8
  @subject = mime['Subject'].to_s.toutf8
  @html = mime.dump(cacheurl)
  @body = mime.body.toutf8
  @id = id
  @name = name
  erb :message
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
    # @from = {}
    # @to = {}
    @subject = {}
    @date = {}
    @ids.each { |id|
      text = File.read(gyamm.path(id))
      @mail = Mime.new
      @mail.read(text)
      # @from[id] = @mail['From'].to_s.toutf8
      # @to[id] = @mail['To'].to_s.toutf8
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

# def disp_list(name)
#   @name = name
# 
#   listfile = "#{ROOTDIR}/data/#{name}/deletefiles"
#   d = DeleteFiles.new(listfile)
# 
#   path = "#{ROOTDIR}/data/#{@name}"
#   if File.exists?(path) && File.directory?(path) then
#     @ids = Dir.open(path).find_all { |id|
#       id =~ /^\d{14}$/ && ! d.deleted?(id)
#     }.sort { |a,b|
#       #
#       # ownerが異なるファイルに対してFile.touchはできるのにFile.utimeができないので、
#       # ファイルの更新時刻とファイルIDを連結したものを比較することによりファイルを新しい順に並べることにする。
#       #
#       File.mtime("#{path}/#{b}").strftime('%Y%m%d%H%M%S')+b <=> File.mtime("#{path}/#{a}").strftime('%Y%m%d%H%M%S')+a
#     }
#     @from = {}
#     @to = {}
#     @subject = {}
#     @date = {}
#     @ids.each { |id|
#       text = File.read("#{path}/#{id}")
#       @mail = Mime.new
#       @mail.read(text)
# #      @from[id] = @mail['From'].to_s.toutf8
# #      @to[id] = @mail['To'].to_s.toutf8
#       @subject[id] = @mail['Subject'].to_s.toutf8
#       @subject[id] = "(タイトルなし)" if @subject[id] == ""
#       (dummy, y, m, d, h, min) = id.match(/^(....)(..)(..)(..)(..)/).to_a
#       @date[id] = "#{y}/#{m.sub(/^0+/,'')}/#{d.sub(/^0+/,'')} #{h.sub(/^0+/,'')}:#{min}"
# #      time = Time.parse(@mail['Date'])
# #      @date[id] = "#{time.year}/#{time.mon}/#{time.day}"
#     }
#     @id = id
#     @lock = ''
#     lock = Lock.new(name)
#     if @locker = lock.locked_by then
#       @lock = "このアーカイブは <b>#{@locker}</b> によりロックされています"
#     end
#     erb :list
#   else
#     'このURLは利用されていません'
#   end
# end

# ファイルのDate:をmodtimeにしようとしたのだが、ownerが異なるファイルに
# 対してFile.utimeができないらしいため失敗。
# touchで我慢することにする。

def touch_all(name)
  gyamm = Gyamm.new(name)
  gyamm.each { |id|
    FileUtils.touch(gyamm.path(id))
  }
end

#def set_file_time(name)
#  @name = name
#  path = "#{ROOTDIR}/data/#{@name}"
#  if File.exists?(path) && File.directory?(path) then
#    @ids = Dir.open(path).each { |id|
#      if id =~ /^\d{14}$/ then
#        file = "#{path}/#{id}"
#        FileUtils.touch(file)
#      end
#    }
#  end
#end

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
      gyamm.each { |id|
        assert id =~ /^\d{14}$/
      }
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

