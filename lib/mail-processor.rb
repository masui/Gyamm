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
#require 'lib/ml-exception'
require 'lib/mail'
require 'lib/mail-body'
require 'lib/util-charset'
require 'lib/util-pathname'
require 'lib/mailaddress'
require 'time'

require 'gyamm/lock'
require 'gyamm/lib'

class Processor

  def initialize (config, mail)
    @config = config
    @mail = mail
    @logger = @config.logger
    if mail.multipart?
      sub_mail = Mail.new
      sub_mail.read(mail.parts.first)
      @message_charset = sub_mail.charset
    else
      @message_charset = mail.charset
    end
  end
  
  def process
    mail_log

    @mail.recipients.each {|recipient|
      process_recipient(recipient)
    }
  end

  def process_recipient(recipient)
    path = @config[:gyamm_datadir] + "/" + MailAddress.name(recipient)
    Pathname.new(path).check_directory
    Pathname.new(path).chmod(0777) # Webから書き込みできるように

    datapath = path + "/" + Time.parse(@mail['Date']).strftime('%Y%m%d%H%M%S')

    # Lock/Unlock処理
    # Subject: lock password  ==> Basic認証設定
    # Subject: unlock         ==> 認証解除
    name = MailAddress.name(recipient)
    if @mail['Subject'] =~ /^(un)?lock(:)?\s*$/i then
      lock = Lock.new(name)
      lock.unlock(@mail.mail_from)
      return
    elsif @mail['Subject'] =~ /^lock:?\s*(\w+)/i then
      gyamm = Gyamm.new(name)
      # 最初にメールを送った人だけロックをかけられる
      if gyamm.from(gyamm.ids[0]) == @mail.mail_from then
        password = $1
        lock = Lock.new(name)
        lock.lock(@mail.mail_from, password)
      end
      return
    end

    File.open(datapath,"w"){ |f|
      f.print @mail.to_s
    }
    File.chmod(0666,datapath)
  end
  
  private
  
  def mail_log
    @logger.vlog "MAIL FROM:<#{@mail.mail_from}>"
    @mail.recipients.each {|recipient|
      @logger.vlog "RCPT TO:<#{recipient}>"
    }
    @logger.vlog 'From: ' + @mail.from
    @logger.vlog 'Cc: ' + @mail.collect_cc.join(', ')
    @logger.vlog 'bare From: ' + @mail['From']
    @logger.vlog 'bare Cc: ' + @mail['Cc']
  end
  
end

if $0 == __FILE__
  require 'qwik/testunit'
  require 'qwik/test-module-ml'
  require 'qwik/config'
  require 'qwik/mail'
  $test = true
end

if defined?($test) && $test
  class TestMLProcessor < Test::Unit::TestCase
    include TestModuleML

    def test_class_method
      c = QuickML::Processor
      eq true, c.unsubscribe_requested?('')
      eq false, c.unsubscribe_requested?('unsubscribe'+' '*489)
      eq false, c.unsubscribe_requested?(' '*499)
      eq false, c.unsubscribe_requested?(' '*500)
      eq true, c.unsubscribe_requested?(' ')
      eq true, c.unsubscribe_requested?("\n")
      eq true, c.unsubscribe_requested?('unsubscribe')
      eq true, c.unsubscribe_requested?(' unsubscribe')
      eq true, c.unsubscribe_requested?('bye')
      eq true, c.unsubscribe_requested?('#bye')
      eq true, c.unsubscribe_requested?('# bye')
      eq true, c.unsubscribe_requested?('退会')
      eq true, c.unsubscribe_requested?('unsubscribe'+' '*488)
      eq false, c.unsubscribe_requested?('unsubscribe desu.')
      eq false, c.unsubscribe_requested?('I want to unsubscribe.')
    end

    def ok_file(e, file)
      str = "test/#{file}".path.read
      ok_eq(e, str)
    end

    def ok_config(e)
      str = 'test/_GroupConfig.txt'.path.read
      hash = QuickML::GroupConfig.parse_hash(str)
      ok_eq(e, hash)
    end

    def test_all
      mail = QuickML::Mail.generate {
'From: "Test User" <user@e.com>
To: "Test Mailing List" <test@example.com>
Subject: Test Mail
Date: Mon, 3 Feb 2001 12:34:56 +0900

This is a test.
'
      }
      processor = QuickML::Processor.new(@ml_config, mail)
      processor.process

      ok_file("user@e.com\n", '_GroupMembers.txt')
      ok_config({
		  :auto_unsubscribe_count=>5,
		  :max_mail_length=>102400,
		  :max_members=>100,
		  :ml_alert_time=>2073600,
		  :ml_life_time=>2678400,
		  :forward=>false,
		  :permanent=>false,
		  :unlimited=>false,
		})
    end

    def test_with_confirm
      message = 'From: "Test User" <user@e.com>
To: "Test Mailing List" <test@example.com>
Subject: Test Mail
Date: Mon, 3 Feb 2001 12:34:56 +0900

This is a test.
'
      mail = QuickML::Mail.generate { message }
      org_confirm_ml_creation = @ml_config[:confirm_ml_creation]
      @ml_config[:confirm_ml_creation] = true
      processor = QuickML::Processor.new(@ml_config, mail)
      processor.process

      ok_file('', '_GroupMembers.txt')
      ok_file("user@e.com\n", '_GroupWaitingMembers.txt')
      ok_file(message, '_GroupWaitingMessage.txt')
      h = {
	:auto_unsubscribe_count=>5,
	:max_mail_length=>102400,
	:max_members=>100,
	:ml_alert_time=>2073600,
	:ml_life_time=>2678400,
	:forward=>false,
	:permanent=>false,
	:unlimited=>false,
      }
      ok_config(h)
      @ml_config[:confirm_ml_creation] = org_confirm_ml_creation
    end

    def test_invalid_mlname
      message = 'From: user@e.com
To: invalid_mlname@example.com
Subject: Test Mail
Date: Mon, 3 Feb 2001 12:34:56 +0900

This is a test.
'
      mail = QuickML::Mail.generate { message }
      processor = QuickML::Processor.new(@ml_config, mail)
      processor.process
    end
  end
end
