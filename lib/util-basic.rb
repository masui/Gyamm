#
# Copyright (C) 2002-2004 Satoru Takabayashi <satoru@namazu.org> 
# Copyright (C) 2003-2006 Kouichirou Eto
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

$LOAD_PATH << '..' unless $LOAD_PATH.include? '..'
require 'lib/util-string'

class Integer
  # 12345.commify => '12,345'
  def commify
    numstr = self.to_s
    true while numstr.sub!(/^([-+]?\d+)(\d{3})/, '\1,\2')
    return numstr
  end
end

# It preserves case information. but it accepts an
# address case-insensitively for member management.
class IcaseArray < Array
  def include? (item)
    if self.find {|x| x.downcase == item.downcase } 
      return true
    else
      return false
    end
  end

  def delete (item)
    self.replace(self.find_all {|x| x.downcase != item.downcase })
  end
end

class IcaseHash < Hash
  def include? (key)
    super(key.downcase)
  end

  def delete (key)
    super(key.downcase)
  end

  def [] (key)
    super(key.downcase)
  end	

  def []= (key, value)
    super(key.downcase, value)
  end	
end

class Hash
  def to_query_string
    ar = []
    self.each {|k, v|
      if k && v
	ar << "#{k.to_s.escape}=#{v.to_s.escape}"
      end
    }
    return ar.sort.join('&')
  end
end

if $0 == __FILE__
  require 'test/unit'
  $test = true
end

if defined?($test) && $test
  class TestUtilBasic < Test::Unit::TestCase
    def test_integer
      assert_equal '12,345', 12345.commify
      assert_equal '123,456,789', 123456789.commify
    end

    def test_iscase_array
      iar = IcaseArray.new
      iar << 'T'
      assert_equal true, iar.include?('T')
      assert_equal true, iar.include?('t')
      iar.delete('t')
      assert_equal false, iar.include?('t')
    end

    def test_icase_hash
      ih = IcaseHash.new
      ih['T'] = 1
      assert_equal true, ih.include?('t')
      assert_equal 1, ih['t']
      ih.delete('t')
      assert_equal false, ih.include?('t')
    end

    def test_hash
      # test_hash_to_query_string
      assert_equal 'k=v', {:k=>'v'}.to_query_string
      assert_equal 'k1=v1&k2=v2', {:k1=>'v1', :k2=>'v2'}.to_query_string
    end
  end
end
