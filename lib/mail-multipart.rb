# -*- coding: cp932 -*-
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
require 'lib/mail'

class Mail
  # ==================== Multipart methods.
  def multipart?
    return !!boundary
  end
  
  def boundary
    return Mail.boundary(self['Content-Type'])
  end
  
  def filename
    return Mail.get_filename(self['Content-Disposition'])
  end
  
  def parts
    return Mail.split_body(self.body, self.boundary)
  end
  
  def nuparts
    boundary = self.boundary
    return [self.body] if boundary.nil? || boundary.empty?
    parts = @body.split(/^--#{Regexp.escape(boundary)}-*\n/)
    parts.shift	# Remove the first empty string.
    return parts
  end
  
  def each_part(&block)
    if multipart?
      self.parts.each {|str|
        submail = Mail.new
        submail.read(str)
        submail.each_part(&block)	# Recursive.
      }
    else
      yield(self)
    end
  end
  
  # ==================== class method
  def self.boundary(ct)
    #if /^multipart\/\w+;\s*boundary=("?)(.*)\1/i =~ ct
    if /^multipart\/\w+;/i =~ ct and /[\s;]boundary=("?)(.*)\1/i =~ ct
      return $2 
    end
    return nil
  end
  
  def self.split_body(body, boundary)
    return [body] if boundary.nil? || boundary.empty?
    parts = body.split(/^--#{Regexp.escape(boundary)}-*\n/)
    parts.shift	# Remove the first empty string.
    parts.pop if /\A\s*\z/ =~ parts.last
    return parts
  end
  
  def self.get_filename(disp)
    return nil if disp.nil?
    type, fdesc = disp.split(';', 2)
    return nil if fdesc.nil?
    fdesc = fdesc.strip
    if /\Afilename=/ =~ fdesc
      fdesc.sub!(/\Afilename=/, '')
      fdesc.sub!(/\A\"/, '')
      fdesc.sub!(/\"\z/, '')
      
      # FIXME: It is not sure that the filename is encoded in JIS.
      # FIXME: It is using nkf for decode MIME encode.
      str = fdesc.set_mail_charset.to_page_charset
      str = str.to_filename_charset
      
      return str
    end
    return nil
  end
  
end

if $0 == __FILE__
  require 'test/unit'
  $test = true
end

if defined?($test) && $test
  class TestMailMultipart < Test::Unit::TestCase
    def test_class_method
      c = Mail

      # test_boundary
      assert('b', c.boundary("multipart/mixed; boundary=\"b\""))
      # ref. https://www.codeblog.org/blog/ryu/?date=20060112#p01
      # Thanks to Mr. Sato.
      assert('b', c.boundary("multipart/signed; protocol=\"TYPE/STYPE\";
           micalg=\"MICALG\"; boundary=\"b\""))

      # test_split_body
      assert(['body'], c.split_body('body', ''))
      assert(["a\n", "b\n"], c.split_body('
--t
a
--t
b
', 't'))

      assert(["a\n", "b\n"], c.split_body('
--t
a
--t
b
--t--
', 't'))

      assert(["a\n", "b\n"], c.split_body('
--t
a
--t
b
--t--

', 't'))

      # example.
      assert(["a\n", "b\n"], c.split_body('
This is a multi-part message in MIME format.

------=_NextPart_000_006A_01C5C34A.53A389F0
a
------=_NextPart_000_006A_01C5C34A.53A389F0
b
------=_NextPart_000_006A_01C5C34A.53A389F0--

', '----=_NextPart_000_006A_01C5C34A.53A389F0'))

      # test_get_filename
      assert("\e$B$\"\e(B", 'あ'.set_sourcecode_charset.to_mail_charset)
      assert('t', c.get_filename("Content-Disposition: attachment; filename=\"t\""))
      assert("\343\201\202", c.get_filename("Content-Disposition: attachment; filename=\"\e$B$\"\e(B\""))
      assert('sounds.zip', c.get_filename("Content-Disposition: attachment;
	filename=sounds.zip"))
      # $KCODE = 's'
      assert('17fy予算コードの指定について.doc'.set_sourcecode_charset.to_filename_charset,
	    c.get_filename('Content-Disposition: attachment;
 filename="=?ISO-2022-JP?B?MTdmeRskQk09OzslMyE8JUkkTjtYRGokSxsoQg==?=
 =?ISO-2022-JP?B?GyRCJEQkJCRGGyhCLmRvYw==?="'))
      assert('情報流デザイングループ.xls'.set_sourcecode_charset.to_filename_charset,
	    c.get_filename('Content-Disposition: attachment;
 filename="=?ISO-2022-JP?B?GyRCPnBKc04uJUclNiUkJXMlMCVrITwlVxsoQg==?=
 =?ISO-2022-JP?B?Lnhscw==?="'))
    end

    def test_all
      mail = Mail.new

      # test_plain
      mail.body = 'body'
      assert_equal(['body'], mail.parts)	# test_parts
      assert_equal(false, mail.multipart?)	# test_multipart?

      # test_multi_part
      mail['Content-Type'] = "multipart/mixed; boundary=\"b\""
      assert_equal(true, mail.multipart?)	# test_multipart?
      assert_equal('b', mail.boundary)		# test_boundary
      assert_equal([], mail.parts)	# test_parts

      mail.body = '--b
1
--b
2
--b-
'
      assert_equal(["1\n", "2\n"], mail.parts)	# test_parts

      # test_each_part
      mail.each_part {|mail|
	assert_match(/\A\d\n\z/, mail.bare)
      }
    end
  end
end
