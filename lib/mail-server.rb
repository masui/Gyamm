#
# Copyright (C) 2002-2004 Satoru Takabayashi <satoru@namazu.org> 
# Copyright (C) 2003-2006 Kouichirou Eto
#     All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of 
# the GNU General Public License version 2.
#

require 'socket'
require 'etc'
require 'thread'
require 'thwait'
require 'timeout'
require 'time'
require 'net/smtp'	# FIXME: Which code uses smtp?

$LOAD_PATH << '..' unless $LOAD_PATH.include? '..'
require 'lib/mail-session'
require 'lib/util-safe'
require 'lib/util-pid'

class MailServer
  include PidModule
  
  def initialize (config)
    File.open("/tmp/log8","w"){ |f|
f.puts 1
f.puts 1.5
f.puts "abc"
f.puts @config
f.puts 111
f.puts config
    @config = config
f.puts 2
    $ml_debug = true if @config.debug
f.puts 3
    @status = :stop
f.puts 4
    @logger = @config.logger
f.puts 5
f.puts @config.bind_address
f.puts @config.ml_port
f.puts TCPServer
      begin
        @server = TCPServer.new(@config.bind_address, @config.ml_port)
      rescue => evar
        f.puts $!
        f.puts evar
      end

f.puts 6

    log_file = (config[:log_dir].path + Logger::LOG_FILE).to_s
f.puts 7
    @logger = Logger.new(log_file, config[:verbose_mode])
f.puts 8
    }
  end
  
  def start
    raise 'server already started' if @status != :stop
    write_pid_file(@config.pid_file)
    @logger.log sprintf('Server started at %s:%d [%d]',
                        'localhost', @config.ml_port, Process.pid)
    accept
    @logger.log "Server exited [#{Process.pid}]"
    remove_pid_file(@config.pid_file)
  end
  
  def shutdown
    begin
      @server.shutdown
    rescue Errno::ENOTCONN
      p 'Already disconnected.'
    end
    @status = :shutdown
  end
  
  private
  
  def accept
    running_sessions = []
    @status = :running
    while @status == :running
      begin 
        t = Thread.new(@server.accept) {|s|
          process_session(s)
        }
        t.abort_on_exception = true
        running_sessions.push(t)
      rescue Errno::ECONNABORTED # caused by @server.shutdown
      rescue Errno::EINVAL
      end
      running_sessions.delete_if {|t| t.status == false }
      if running_sessions.length >= @config.max_threads
        ThreadsWait.new(running_sessions).next_wait
      end
    end
    running_sessions.each {|t| t.join }
  end
  
  def process_session (socket)
    begin
      session = Session.new(@config, socket)
      session.start
    rescue Exception => e
      @logger.log "Unknown Session Error: #{e.class}: #{e.message}"
      @logger.log e.backtrace
    end
  end
  
end

if $0 == __FILE__
#  require 'qwik/test-module-ml'
#  require 'qwik/config'
  $test = true
end

if defined?($test) && $test
#  class TestMLServer < Test::Unit::TestCase
#    def test_all
#      #return
#      config = Qwik::Config.new
#      config[:ml_port] = 9195
#      server = QuickML::Server.new(config)
#    end
#  end
end
