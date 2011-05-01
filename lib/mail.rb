# -*- coding: utf-8 -*-
#
# Copyright (C) 2002-2004 Satoru Takabayashi <satoru@namazu.org> 
# Copyright (C) 2003-2006 Kouichirou Eto
# Modified by Toshiyuki Masui
#
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

$LOAD_PATH << '..' unless $LOAD_PATH.include? '..'

class Mail
  def initialize
    @mail_from = nil
    @recipients = []
    @header = []
    @body = ''
    @charset = nil
    @content_type = nil
    @bare = nil
  end
  
  attr_accessor :mail_from
  attr_reader :recipients
  attr_accessor :body
  attr_reader :charset
  attr_reader :content_type
  attr_accessor :bare
end

# TODO: Make special mode for Mr. Kaoru Misaki.
# Use the first line of the body as a subject.

if $0 == __FILE__
  require 'test/unit'
  $test = true
end

if defined?($test) && $test
  require 'lib/mail-parse'
  require 'lib/mail-header'
  require 'lib/mail-body'
  require 'lib/util-string'

  class TestMail < Test::Unit::TestCase
    def gen_mail(&b)
      return Mail.generate(&b)
    end

    def test_basic
      str = 'Date: Mon, 3 Feb 2001 12:34:56 +0900
From: "Test User" <user@e.com>
To: "Test Mailing List" <test@example.com>
Subject: Re: [test:1] Test Mail

This is a test.
'
      mail = gen_mail { str }

      # test_accessor
      assert_equal 'user@e.com', mail.mail_from
      assert_equal ['test@example.com'], mail.recipients
      assert_equal "This is a test.\n", mail.body
      assert_equal str, mail.bare

      # test_to_s
      assert_equal str, mail.to_s

      # test_looping?
      assert_equal false, mail.looping?

      # test_from
      assert_equal 'user@e.com', mail.from

      # test_collect
      assert_equal [], mail.collect_cc
      assert_equal ['test@example.com'], mail.collect_to

      # test_decoded_body
      assert_equal "This is a test.\n", mail.decoded_body

      # test_get_body
      assert_equal "This is a test.\n", mail.get_body

      # test_parts
      assert_equal ["This is a test.\n"], mail.parts

      assert_equal nil, mail.filename		# test_filename
      assert(['test@example.com'], mail.valid?)	# test_valid?
      assert_equal nil, mail.boundary		# test_boundary
      assert_equal false, mail.multipart?		# test_multipart?

      # test_each_part
      mail.each_part {|mail|
	assert_instance_of(Mail, mail)
      }
    end

    def test_multipart
      mail = gen_mail {
"Date: Mon, 3 Feb 2001 12:34:56 +0900
From: Test User <user@e.com>
To: test@example.com
Cc: guest@example.com
Subject: multipart test
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary=\"boundary\"
Content-Transfer-Encoding: 7bit

--boundary
Content-Type: text/plain; charset=\"ascii\"
Content-Transfer-Encoding: 7bit

body1

--boundary
Content-Type: text/plain; charset=\"ascii\"
Content-Transfer-Encoding: 7bit

body2

--boundary--
" }

      # test_accessor
      assert_equal ['test@example.com', 'guest@example.com'], mail.recipients

      # test_collect
      assert_equal ['guest@example.com'], mail.collect_cc

      # test_get_body
      assert_equal "body1\nbody2\n", mail.get_body

      # test_parts
      assert_equal ["Content-Type: text/plain; charset=\"ascii\"
Content-Transfer-Encoding: 7bit

body1

", "Content-Type: text/plain; charset=\"ascii\"
Content-Transfer-Encoding: 7bit

body2

"], mail.parts

      # test_parts
      mail0 = Mail.new
      mail0.read(mail.parts[0])
      assert_equal "body1\n\n", mail0.body

      mail1 = Mail.new
      mail1.read(mail.parts[1])
      assert_equal "body2\n\n", mail1.body

      # test_multipart
      assert_equal true, mail.multipart?		# test_multipart?
      assert_equal 'boundary', mail.boundary	# test_boundary

      # test_multipart_alternative
      mail['Content-Type'] = "multipart/alternative; boundary=\"b\""
      mail.instance_eval {
	@content_type = Mail.get_content_type(self['Content-Type'])
      }
      assert_equal 'multipart/alternative', mail.content_type
      assert_equal "multipart/alternative; boundary=\"b\"",
	    mail['Content-Type']
      assert_equal true, mail.multipart?		# test_multipart?
      assert_equal 'b', mail.boundary		# test_boundary
    end

    def test_mail_with_image
      mail = gen_mail {
"Date: Mon, 3 Feb 2001 12:34:56 +0900
From: Test User <user@e.com>
To: test@example.com
Cc: guest@example.com
Subject: Attach Test
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary=\"------_410DDC04C7AD046D3600_MULTIPART_MIXED_\"
Content-Transfer-Encoding: 7bit

--------_410DDC04C7AD046D3600_MULTIPART_MIXED_
Content-Type: text/plain; charset='ascii'
Content-Transfer-Encoding: 7bit

Test with image.

--------_410DDC04C7AD046D3600_MULTIPART_MIXED_
Content-Type: image/png; name=\"1x1.png\"
Content-Disposition: attachment;
 filename=\"1x1.png\"
Content-Transfer-Encoding: base64

iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR42mP4//8/AAX+Av4zEpUU
AAAAAElFTkSuQmCC

--------_410DDC04C7AD046D3600_MULTIPART_MIXED_--
" }

      # test_get_body
      assert_equal "Test with image.\n", mail.get_body

      # test_parts
      mail0 = Mail.new
      mail0.read(mail.parts[0])
      assert_equal 'text/plain', mail0.content_type
      assert_equal "Test with image.\n\n", mail0.body

      mail1 = Mail.new
      mail1.read(mail.parts[1])
      assert_equal 'image/png', mail1.content_type
      assert_equal "attachment;
 filename=\"1x1.png\"",
		 mail1['Content-Disposition']
      assert_equal '1x1.png', mail1.filename
      assert_equal 'base64', mail1['Content-Transfer-Encoding']
      assert_equal "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR42mP4//8/AAX+Av4zEpUU\nAAAAAElFTkSuQmCC\n\n", mail1.body
      assert_equal "\211PNG\r\n\032\n\000\000\000\rIHDR\000\000\000\001\000\000\000\001\010\002\000\000\000\220wS\336\000\000\000\fIDATx\332c\370\377\377?\000\005\376\002\3763\022\225\024\000\000\000\000IEND\256B`\202", mail1.decoded_body

      assert_equal nil, mail.parts[2]
    end

    def test_inline_disposition
      mail = gen_mail {
"Date: Mon, 3 Feb 2001 12:34:56 +0900
From: user@e.com
To: test@example.com
Subject: This is an inline test.
MIME-Version: 1.0 (generated by SEMI 1.14.4 - Hosorogi)
Content-Type: multipart/mixed;
 boundary=\"Multipart_Thu_Apr_14_21:22:30_2005-1\"

--Multipart_Thu_Apr_14_21:22:30_2005-1
Content-Type: text/plain; charset=ISO-2022-JP

I attached sample.jpg.
--Multipart_Thu_Apr_14_21:22:30_2005-1
Content-Type: image/jpeg
Content-Disposition: inline; filename=\"sample.jpg\"
Content-Transfer-Encoding: base64

iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR42mP4//8/AAX+Av4zEpUU
AAAAAElFTkSuQmCC

" }
      mail1 = Mail.new
      mail1.read(mail.parts[1])
      assert_equal "inline; filename=\"sample.jpg\"", mail1['Content-Disposition']
      assert_equal 'sample.jpg', mail1.filename
    end

    def test_apple_mail
      mail = gen_mail {
"Date: Mon, 3 Feb 2001 12:34:56 +0900
From: Test User <user@e.com>
To: test@example.com
Cc: guest@example.com
Subject: Apple Mail
Mime-Version: 1.0 (Apple Message framework v623)
Content-Type: multipart/mixed; boundary=Apple-Mail-1-134582006

--Apple-Mail-1-134582006
Content-Transfer-Encoding: 7bit
Content-Type: text/plain;
	charset=ISO-2022-JP;
	format=flowed

I attach a file using Apple Mail.
--Apple-Mail-1-134582006
Content-Transfer-Encoding: base64
Content-Type: application/zip;
	x-mac-type=5A495020;
	x-unix-mode=0755;
	x-mac-creator=53495421;
	name='sounds.zip'
Content-Disposition: attachment;
	filename=sounds.zip

iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR42mP4//8/AAX+Av4zEpUU
AAAAAElFTkSuQmCC

--Apple-Mail-1-134582006--
" }

      # test_get_body
      assert_equal "I attach a file using Apple Mail.\n", mail.get_body

      # test_parts
      mail0 = Mail.new
      mail0.read(mail.parts[0])
      assert_equal 'text/plain', mail0.content_type
      assert_equal "I attach a file using Apple Mail.\n", mail0.body

      mail1 = Mail.new
      mail1.read(mail.parts[1])
      assert_equal 'application/zip', mail1.content_type
      assert_equal "attachment;\n\tfilename=sounds.zip", mail1['Content-Disposition']
      assert_equal 'sounds.zip', mail1.filename
    end
  end

  class TestMLMailJapanese < Test::Unit::TestCase
    def gen_mail(&b)
      return Mail.generate(&b)
    end

    def test_jmail
      str =
'Date: Mon, 3 Feb 2001 12:34:56 +0900
From: "Test User" <user@e.com>
To: "Test Mailing List" <test@example.com>
Subject: Re: [test:1] テスト 

これはテストです。
'
      mail = gen_mail { str }
      assert_equal "これはテストです。\n".set_sourcecode_charset.to_mail_charset, mail.body
      assert_equal str.set_sourcecode_charset.to_mail_charset, mail.bare
      assert_equal "Re: [test:1] テスト ".set_sourcecode_charset.to_mail_charset, mail['Subject']
      assert_equal "これはテストです。\n".set_sourcecode_charset.to_mail_charset, mail.get_body
    end

    def test_for_confirm
      str = 'To: test@example.com
From: bob@example.net
Subject: test

test
'
      mail = gen_mail { str }

      # test_accessor
      assert_equal 'bob@example.net', mail.mail_from
      assert_equal ['test@example.com'], mail.recipients
      assert_equal "test\n", mail.body
    end
  end
end
