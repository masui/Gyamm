class DeleteFiles
  def initialize(listfile)
    @listfile = listfile
    @ids = []
    if File.exists?(listfile) then
      File.open(listfile){ |f|
        f.each { |line|
          line.chomp!
          @ids << line if valid?(line)
        }
      }
    end
  end

  def valid?(id)
    id =~ /^\d{14}$/
  end

  def save
    File.open(@listfile,"w"){ |f|
      @ids.each { |id|
        f.puts id
      }
    }
  end

  def delete(id)
    if valid?(id) then
      @ids.unshift(id)
      save
    end
  end

  def deleted?(id)
    return false if !valid?(id)
    return @ids.include?(id)
  end

  def recover
    if @ids.length > 0 then
      @ids.shift
      save
    end
  end
end

if $0 == __FILE__
  require 'test/unit'
  $test = true
end

if defined?($test) && $test
  class TestDelete < Test::Unit::TestCase
    def test_delete
      deletefile = "/tmp/deletefile"
      d = DeleteFiles.new(deletefile)
      d.delete('20110502123456')
      assert d.deleted?('20110502123456')
      File.unlink(deletefile)
    end

    def test_recover
      deletefile = "/tmp/deletefile"
      d = DeleteFiles.new(deletefile)
      d.delete('20110502123456')
      d.delete('20110502012345')
      assert d.deleted?('20110502123456')
      assert d.deleted?('20110502012345')
      d.recover
      assert ! d.deleted?('20110502012345')
      assert d.deleted?('20110502123456')
      d.recover
      assert ! d.deleted?('20110502012345')
      assert ! d.deleted?('20110502123456')
      d.recover
      assert ! d.deleted?('20110502012345')
      assert ! d.deleted?('20110502123456')
      d.delete('20110502123456')
      assert d.deleted?('20110502123456')
      File.unlink(deletefile)
    end
  end
end

