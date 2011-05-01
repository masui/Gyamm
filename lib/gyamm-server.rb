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

require 'fileutils'

$LOAD_PATH << '..' unless $LOAD_PATH.include? '..'
require 'lib/config'
#require 'qwik/ml-memory'
require 'lib/mail-server'
require 'lib/mail-logger'

$ml_debug = false
# $ml_debug = true

class GyammServer
  def self.main(args)
    server = GyammServer.new

    config = Config.new
    Config.load_args_and_config(config, $0, args)
    config.update({:debug => true, :verbose_mode => true}) if $ml_debug

    log_file = (config[:log_dir].path + Logger::LOG_FILE).to_s
    @logger = config[:logger] = Logger.new(log_file, config[:verbose_mode])

#    ServerMemory.init_logger(config, config) 何故かこういう道を通って @loggerをセットしてるのだが
#    ServerMemory.init_mutex(config)
#    ServerMemory.init_catalog(config)

    server.run(config)
  end

  def initialize
    # Do nothing.
  end

  def run (config)
#    GyammServer.check_directory(config.sites_dir)

    if ! config.debug
      GyammServer.be_daemon
      GyammServer.be_secure(config)
    end
    File.open("/tmp/log7","w"){ |f|
f.puts 1
f.puts 11
f.puts config
    server  = Server.new(config)
f.puts 2
#    sweeper = Sweeper.new(config)
    trap(:TERM) { server.shutdown; }
    trap(:INT)  { server.shutdown; }
f.puts 3
    if Signal.list.key?("HUP")
      trap(:HUP)  { config.logger.reopen }
    end
f.puts 4
    
#    if config.debug
#      require 'qwik/autoreload'
#      AutoReload.start(1, true, 'ML')	# auto reload every sec.
#    end
f.puts 5    
    server.start
f.puts 6
    }
  end

  private

  def self.check_directory(dir)
    error("#{dir}: No such directory") if ! File.directory?(dir) 
    error("#{dir}: is not writable")   if ! File.writable?(dir) 
  end
  
  def self.error (msg)
    STDERR.puts "#{$0}: #{msg}"
    exit(1)
  end
  
  def self.be_daemon
    File.open("/tmp/log5","w"){ |f|
f.puts 1
    exit!(0) if fork
f.puts 2
    Process::setsid
f.puts 3
    exit!(0) if fork
f.puts 4
    Dir::chdir('/')
    File::umask(022)
    STDIN.reopen('/dev/null',  'r+')
    STDOUT.reopen('/dev/null', 'r+')
    STDERR.reopen('/dev/null', 'r+')
f.puts 5
    }
  end
  
  def self.be_secure(config)
    File.open("/tmp/log6","w"){ |f|
f.puts 1
    return unless Process.uid == 0
f.puts 2
    uid = Etc::getpwnam(config.user).uid 
    gid = Etc::getgrnam(config.group).gid
    FileUtils.touch(config.pid_file)
f.puts 3
    log_file = (config[:log_dir].path + Logger::LOG_FILE).to_s
f.puts 4
    FileUtils.touch(log_file)
#    File.chown(uid, gid, config.sites_dir)
    File.chown(uid, gid, config.pid_file)
    File.chown(uid, gid, log_file)
f.puts 5
    Process.uid  = uid
    Process.gid  = gid
    Process.euid = uid
f.puts 6
    }
  end
end

if $0 == __FILE__
  require 'test/unit'
  $test = true
end

if defined?($test) && $test
  class TestMLQuickMLServer < Test::Unit::TestCase
    def test_all
      # Just create it.
      gyamm_server = GyammServer.new
    end
  end
end
