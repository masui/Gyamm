require 'digest/md5'

ROOTDIR = "/Users/masui/Gyamm"

def datadir(name=nil)
  name ? "#{ROOTDIR}/data/#{name}" : "#{ROOTDIR}/data"
end

def datafile(name,id)
  file = "#{datadir(name)}/#{id}"
  File.symlink?(file) ? File.readlink(file) : file
end

def tmpdir
  "#{ROOTDIR}/public/tmp"
end

def linkdir
  "#{ROOTDIR}/links"
end

def linkname(data)
  Digest::MD5.hexdigest(data)
end

def linkfile(link)
  link =~ /^(.)(.)/
  return "#{linkdir}/#{$1}/#{$2}/#{link}"
end

if $0 == __FILE__
  require 'test/unit'
  $test = true
end

if defined?($test) && $test
  class TestConfig < Test::Unit::TestCase
    def test_linkfile
      s1 = linkfile('abc')
      s2 = linkfile('def')
      assert s1 =~ /[0-9a-f]{32}/
      assert s2 =~ /[0-9a-f]{32}/
      assert s1.length == s2.length
      assert s1 != s2
    end
  end
end
