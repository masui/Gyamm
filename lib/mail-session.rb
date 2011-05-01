# -*- coding: utf-8 -*-
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
# require 'qwik/ml-gettext'
require 'lib/mail'
require 'lib/util-basic'
require 'lib/util-safe'
require 'lib/mail-header'
require 'lib/mail-parse'
require 'lib/mail-processor'

require 'kconv'
require 'net/smtp'
require 'socket'
require 'timeout'

class TCPSocket
  def address
    return peeraddr[3]
  end

  def hostname
    return peeraddr[2]
  end
end

class Session
  COMMAND_TABLE = [:helo, :ehlo, :noop, :quit, :rset, :rcpt, :mail, :data]
  
  def initialize (config, socket)
    @socket = socket
    @config = config
    @logger = @config.logger
    @catalog = @config.catalog
    
    @hello_host = 'hello.host.invalid'
    @protocol = nil
    @peer_hostname = @socket.hostname
    @peer_address = @socket.address
    @remote_host = (@peer_hostname or @peer_address)
    
    @data_finished = false
    @my_hostname = 'localhost'
    @my_hostname = Socket.gethostname if @config.ml_port == 25
    @message_charset = nil

#    # mail-server.rbでも定義してるのだが
#    # そういうのを「memory」に入れてるのか? ワカラン
#    log_file = (config[:log_dir].path + Logger::LOG_FILE).to_s
#    @logger = Logger.new(log_file, config[:verbose_mode])
  end
  
  def start
    elapsed = calc_time {
      _start
    }
    @logger.vlog "Session finished: #{elapsed} sec."
  end
  
  private
  
  def calc_time
    start_time = Time.now
    yield
    elapsed = Time.now - start_time
    return elapsed
  end
  
  def _start
    begin
      def_puts(@socket)
      connect
      timeout(@config.timeout) {
        process
      }
    rescue TimeoutError
      @logger.vlog "Timeout: #{@remote_host}"
    ensure
      close
    end
  end
  
  def def_puts(socket)
    def socket.puts(*objs)
      objs.each {|x|
        begin
          self.print x.xchomp, "\r\n"
        rescue Errno::EPIPE
        end
      }
    end
  end
  
  def connect
    @socket.puts "220 #{@my_hostname} ESMTP GYAMM"
    @logger.vlog "Connect: #{@remote_host}"
  end
  
  def process
    until @socket.closed?
      begin
        mail = Mail.new
        receive_mail(mail)
        if mail.valid?
          processor = Processor.new(@config, mail)
          processor.process
        end
#      rescue TooLargeMail
#        cleanup_connection
#        report_too_large_mail(mail) if mail.valid?
#        @logger.log "Too Large Mail: #{mail.from}"
      rescue TooLongLine
        cleanup_connection
        @logger.log "Too Long Line: #{mail.from}"
      end
    end
  end
  
  def receive_mail (mail)
    while line = @socket.safe_gets
      line = line.xchomp
      command, arg = line.split(/\s+/, 2)
      return if command.nil? || command.empty?
      command = command.downcase.intern  # 'HELO' => :helo
      if COMMAND_TABLE.include?(command)
        @logger.vlog "Command: #{line}"
        send(command, mail, arg)
      else
        @logger.vlog "Unknown SMTP Command: #{command} #{arg}"
        @socket.puts '502 Error: command not implemented'
      end
      break if command == :quit or command == :data
    end
  end
  
  def helo (mail, arg)
    return if arg.nil?
    @hello_host = arg.split.first
    @socket.puts "250 #{@my_hostname}"
    @protocol = 'SMTP'
  end
  
  def ehlo (mail, arg)
    @hello_host = arg.split.first
    @socket.puts "250-#{@my_hostname}"
    @socket.puts '250 PIPELINING'
    @protocol = 'ESMTP'
  end
  
  def noop (mail, arg)
    @socket.puts '250 ok'
  end
  
  def quit (mail, arg)
    @socket.puts '221 Bye'
    close
  end
  
  def rset (mail, arg)
    mail.mail_from = nil
    mail.clear_recipients
    @socket.puts '250 ok'
  end
  
  def rcpt (mail, arg)
    if mail.mail_from.nil?
      @socket.puts '503 Error: need MAIL command'
    elsif /^To:\s*<(.*)>/i =~ arg or /^To:\s*(.*)/i =~ arg
      address = $1
#      if Mail.address_of_domain?(address, @config.ml_domain)
        mail.add_recipient(address)
        @socket.puts '250 ok'
#      else
#        @socket.puts "554 <#{address}>: Recipient address rejected"
#        @logger.vlog "Unacceptable RCPT TO:<#{address}>"
#      end
    else
      @socket.puts "501 Syntax: RCPT TO: <address>"
    end
  end
  
  def mail (mail, arg)
    if @protocol.nil?
      @socket.puts '503 Error: send HELO/EHLO first'
    elsif /^From:\s*<(.*)>/i =~ arg or /^From:\s*(.*)/i =~ arg 
      mail.mail_from = $1
      @socket.puts '250 ok'
    else
      @socket.puts "501 Syntax: MAIL FROM: <address>"
    end
  end
  
  def data (mail, arg)
    if mail.recipients.empty?
      @socket.puts '503 Error: need RCPT command'
    else
      @socket.puts '354 send the mail data, end with .';
      begin
        read_mail(mail)
      ensure
        @message_charset = mail.charset
      end
      @socket.puts '250 ok'
    end
  end
  
  def read_mail (mail)
    len = 0
    lines = []
    while line = @socket.safe_gets
      break if end_of_data?(line)
      len += line.length
#      if @config.max_mail_length < len
#        mail.read(lines.join('')) # Generate a header for an error report.
#        raise TooLargeMail 
#      end
      line.sub!(/^\.\./, '.') # unescape
      line = line.normalize_eol
      lines << line
      # I do not know why but constructing mail_string with
      # String#<< here is very slow.
      # mail_string << line  
    end
    mail_string = lines.join('')
puts mail_string
    @data_finished = true
    mail.read(mail_string)
    mail.unshift_field('Received', received_field)
  end
  
  def end_of_data? (line)
    # line.xchomp == '.'
    return line == ".\r\n"
  end
  
  def received_field
    sprintf("from %s (%s [%s])\n" + 
            "	by %s (QuickML) with %s;\n" + 
            "	%s", 
            @hello_host,
            @peer_hostname, 
            @peer_address,
            @my_hostname,
            @protocol,
            Time.now.rfc2822)
  end
  
  def cleanup_connection
    unless @data_finished
      discard_data
    end
    @socket.puts '221 Bye'
    close
  end
  
  def discard_data
    begin
      while line = @socket.safe_gets
        break if end_of_data?(line)
      end
    rescue TooLongLine
      retry
    end
  end
  
  # FIXME: this is the same method of QuickML#content_type
  def content_type
    return Mail.content_type(@config.content_type, @message_charset)
  end
  
  def close
    return if @socket.closed?
    @socket.close
    @logger.vlog "Closed: #{@remote_host}"
  end
end

if $0 == __FILE__
  require 'test/unit'
  require 'lib/config'
  require 'lib/mock-logger'
  require 'lib/mock-socket'
  $test = true
end

if defined?($test) && $test
  class TestMLSession < Test::Unit::TestCase
    def test_all
#      return
      config = Config.new
      hash = {
	:logger		=> MockLogger.new,
	:sites_dir	=> '.',
      }
      config.update(hash)
#      QuickML::ServerMemory.init_mutex(config)
#      QuickML::ServerMemory.init_catalog(config)
#      old_test_memory = $test_memory
#      $test_memory = Qwik::ServerMemory.new(config)	# FIXME: Ugly.
      socket = MockSocket.new "HELO localhost
MAIL FROM: user@example.net
RCPT TO: test@example.com
DATA
To: test@example.com
From: user@example.net
Subject: create

create new ML.
.
QUIT
"
      session = Session.new(config, socket)
      session.start
#      $test_memory = old_test_memory
    end
  end
end
