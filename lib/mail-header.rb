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
require 'lib/mailaddress'
require 'lib/mail-multipart'
require 'lib/util-charset'

class Mail
  # ==================== Basic header methods.
  def header
    return nil if ! $test	# Only for test.
    return @header
  end
  
  def []=(key, value)
    return nil if ! $test	# Only for test.
    field = @header.find {|field|
      key.downcase == field.first.downcase
    }
    if field
      field[1] = value
    else
      @header << [key, value]
    end
    return nil
  end
  
  def [] (key)
    field = @header.find {|field|
      key.downcase == field.first.downcase
    }
    return '' if field.nil?
    return field.last
  end
  
  # ml-session.rb:214:      mail.unshift_field('Received', received_field)
  def unshift_field (key, value)
    # Use Array for preserving order of the header
    @header.unshift([key, value])
  end
  
  # group.rb:265:      mail.each_field {|key, value|
  # mail-body.rb:18:      self.each_field {|key, value|
  def each_field
    @header.each {|field|
      yield(field.first, field.last)
    }
  end
  
  # ==================== Get value.
  def get_unified_subject
    return Mail.get_unified_subject(self['Subject'])
  end
  
  # ml-processor.rb:37:      if @mail.looping?
  def looping?
    return ! self['X-QuickML'].empty?
  end
  
  # ==================== Address methods.
  def from
    address = @mail_from
    address = Mail.collect_address(self['From'])[0] if ! self['From'].empty?
    address = 'unknown' if address.nil? || address.empty?
    address = MailAddress.normalize(address)
    return address
  end
  
  def valid?
puts "VALID?"
p @recipients
p @mail_from
    return (! @recipients.empty?) && !!@mail_from
  end
  
  def add_recipient (address)
    @recipients.push(MailAddress.normalize(address))
  end
  
  def clear_recipients
    @recipients = []
  end
  
  def collect_to
    return Mail.collect_address(self['To']) if self['To']
    return []
  end
  
  def collect_cc
    return Mail.collect_address(self['Cc']) if self['Cc']
    return []
  end
  
  # ==================== Class methods.
  def self.collect_address (field)
    address_regex = 
      /(("?)[-0-9a-zA-Z_.+?\/]+\2@[-0-9a-zA-Z]+\.[-0-9a-zA-Z.]+)/ #/
    addresses = []
    parts = Mail.remove_comment_in_field(field).split(',')
    parts.each {|part|
      if (/<(.*?)>/ =~ part) || (address_regex =~ part)
        addresses.push(MailAddress.normalize($1))
      end
    }
    return addresses.uniq
  end
  
  def self.get_unified_subject(s)
    s = Mail.clean_subject(s)
    s.sub!(/(?:Re:\s*)+/i, '')
    s.sub!(/\A\s+/, '')
    s.sub!(/\s+\z/, '')
    s.gsub!(/\s+/, ' ')	# Thanks to Mr. Atsushi SHICHI.
    return s
  end
  
  def self.remove_comment_in_field (field)
    field = field.tosjis
    true while field.sub!(/\([^()]*?\)/, '')
    return field
  end
  
  def self.get_charset(contenttype)
    return $2.downcase if /charset=("?)([-\w]+)\1/ =~ contenttype
    return nil
  end
  
  def self.get_content_type(contenttype)
    return $1.downcase if /([-\w]+\/[-\w]+)/ =~ contenttype
    return nil
  end
  
  def self.encode_field (field)
    field.gsub(Regexp.new("[\x81\x40-\xef\xf7]\\S*\\s*", nil, 's')) {|x|
      x.scan(Regexp.new('.{1,10}', nil, 's')).map {|y|
        '=?ISO-2022-JP?B?' + y.tojis.to_a.pack('m').chomp + '?='
      }.join("\n ")
    }
  end
  
  def self.decode_subject(s)
    s = s.gsub(/\n\s+/, ' ').gsub(/\n/, '')
    s = s.tosjis
    return s
  end
  
  def self.clean_subject(s)
    s = Mail.decode_subject(s)
    s.gsub!(/(?:\[[^\]]+:\d+\])/, '')
    s.sub!(/(?:Re:\s*)+/i, 'Re: ')
    return s
  end
  
  def self.rewrite_subject (s, name, count)
    s = Mail.clean_subject(s)
    s = "[#{name}:#{count}] " + s
    return Mail.encode_field(s)
  end
  
  def self.address_of_domain? (address, domain)
    re = '[.@]' + Regexp.quote(domain) + '$'
    domainpat = Regexp.new(re, Regexp::IGNORECASE)
    return true if domainpat =~ address
    return false
  end
  
  def self.content_type(default_content_type, charset)
    return default_content_type + "; charset=#{charset}" if charset
    return default_content_type
  end
  
end

if $0 == __FILE__
  require 'test/unit'
  $test = true
end

if defined?($test) && $test
  class TestMailHeader < Test::Unit::TestCase
    def test_all
      mail = Mail.new

      # test_header
      assert_equal([], mail.header)

      # test_[]=
      mail['k'] = 'v'

      # test_[]
      assert_equal('v', mail['k'])

      # test_unshift_field
      mail.unshift_field('k2', 'v2')
      assert_equal([['k2', 'v2'], ['k', 'v']], mail.header)

      # test_each_field
      mail.each_field {|k, v|
	# do nothing.
      }

      # test_get_unified_subject
      mail['Subject'] = 'Re: [t:1] s'
      assert_equal('s', mail.get_unified_subject)

      # test_looping?
      assert_equal(false, mail.looping?)
      mail['X-QuickML'] = 'true'
      assert_equal(true, mail.looping?)
    end

    def test_address
      mail = Mail.new

      # test_from
      assert_equal('unknown', mail.from)
      mail['From'] = 'a@e.com'
      assert_equal('a@e.com', mail.from)

      # test_valid?
      assert_equal(false, mail.valid?)

      # test_add_recipient
      mail.add_recipient('b@e.com')
      assert_equal(false, mail.valid?)
      
      # test_clear_recipients
      mail.clear_recipients

      # test_collect_to
      assert_equal([], mail.collect_to)
      mail['To'] = 't@e.com'
      assert_equal(['t@e.com'], mail.collect_to)

      # test_collect_cc
      assert_equal([], mail.collect_cc)
      mail['Cc'] = 'c@e.com'
      assert_equal(['c@e.com'], mail.collect_cc)
    end

    def test_class_method
      c = Mail

      # test_collect_address
      assert_equal(['a@example.net'], c.collect_address('a@example.net'))

      # test_get_unified_subject
      assert_equal('t', c.get_unified_subject('t'))
      assert_equal('t', c.get_unified_subject('Re: t'))
      assert_equal('t', c.get_unified_subject(' t'))
      assert_equal('t', c.get_unified_subject('t '))
      assert_equal('t t', c.get_unified_subject('t t'))
      assert_equal('t t', c.get_unified_subject('t  t'))
      assert_equal('t t t', c.get_unified_subject('t t t'))
      assert_equal('t t t', c.get_unified_subject('t  t  t'))
      assert_equal('Test Mail', c.get_unified_subject('Re: [test:1] Test Mail'))
      assert_equal('テスト', c.get_unified_subject('Re: [test:1] テスト '))

      # test_remove_comment_in_field
      assert_equal('', c.remove_comment_in_field(''))
      assert_equal('ac', c.remove_comment_in_field('a(b)c'))
      assert_equal('ace', c.remove_comment_in_field('a(b)c(d)e'))

      # test_get_charset
      assert_equal(nil, c.get_charset(''))
      assert_equal('ascii', c.get_charset('text/plain; charset="ascii"'))
      assert_equal('iso-2022-jp', c.get_charset('text/plain; charset=ISO-2022-JP'))
      assert_equal('shift_jis', c.get_charset('text/plain; charset=Shift_JIS'))

      # test_get_contenttype
      assert_equal(nil, c.get_content_type(''))
      assert_equal('text/plain',
	    c.get_content_type('text/plain; charset="ascii"'))
      assert_equal('multipart/mixed',
	    c.get_content_type("multipart/mixed; boundary='boundary'"))
      assert_equal('multipart/alternative',
	    c.get_content_type("multipart/alternative; boundary='b'"))

      # test_encode_field
      assert_equal("\201@", '　')
      assert_equal("\352\242", '瑤')
      assert_equal('t', c.encode_field('t'))
      assert_equal('=?ISO-2022-JP?B?GyRCJCIbKEI=?=', c.encode_field('あ'))
      assert_equal('=?ISO-2022-JP?B?GyRCJCIkJBsoQg==?=', c.encode_field('あい'))
      assert_equal('=?ISO-2022-JP?B?GyRCJCIkJCQmJCgkKiQrJC0kLyQxJDMbKEI=?=
 =?ISO-2022-JP?B?GyRCJDUkNyQ5JDskPRsoQg==?=',
	 c.encode_field('あいうえおかきくけこさしすせそ'))
      assert_equal('[test:1] Re: =?ISO-2022-JP?B?GyRCJUYlOSVIGyhCICA=?=',
	 c.encode_field('[test:1] Re: テスト  '))
      assert_equal('[test:1] Re: =?ISO-2022-JP?B?GyRCJUYlOSVIGyhCIA==?=',
	 c.encode_field('[test:1] Re: テスト '))
      assert_equal('[test:1] Re: =?ISO-2022-JP?B?GyRCJCIbKEI=?=',
	 c.encode_field('[test:1] Re: あ'))

      # test_decode_subject
      assert_equal('t', c.decode_subject('t'))
      assert_equal('st', c.decode_subject("s\nt"))
      assert_equal('s t', c.decode_subject("s\n t"))
      assert_equal("\202\240 ", c.decode_subject('=?iso-2022-jp?B?GyRCJCIbKEI=?= '))

      # test_clean_subject
      assert_equal('t', c.clean_subject('t'))
      assert_equal(' Re: Test ', c.clean_subject('[test:1] Re: Test '))
      assert_equal('Re: テスト ', c.clean_subject('Re: [test:1] テスト '))

      # test_rewrite_subject
      assert_equal('[n:2] t', c.rewrite_subject('t', 'n', '2'))
      assert_equal('[test:2] Re: Test Mail',
	    c.rewrite_subject('Re: [test:1] Test Mail', 'test', 2))
      assert_equal('[test:2] Re: =?ISO-2022-JP?B?GyRCJUYlOSVIGyhCIA==?=',
	    c.rewrite_subject('Re: [test:1] テスト ', 'test', 2))

      # test_address_of_domain?
      assert_equal(true,  c.address_of_domain?('user@example.net', 'example.net'))
      assert_equal(false, c.address_of_domain?('user@example.com', 'example.net'))
      assert_equal(false, c.address_of_domain?('user', 'example.net'))

      # test_content_type
      assert_equal('text/plain', c.content_type('text/plain', nil))
      assert_equal('text/plain; charset=iso-2022-jp',
	    c.content_type('text/plain', 'iso-2022-jp'))
    end
  end
end
