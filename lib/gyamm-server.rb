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

#    if ! config.debug
#      GyammServer.be_daemon
#      GyammServer.be_secure(config)
#    end

    server  = MailServer.new(config)
#    sweeper = Sweeper.new(config)
    trap(:TERM) { server.shutdown; }
    trap(:INT)  { server.shutdown; }
    if Signal.list.key?("HUP")
      trap(:HUP)  { config.logger.reopen }
    end
    
#    if config.debug
#      require 'qwik/autoreload'
#      AutoReload.start(1, true, 'ML')	# auto reload every sec.
#    end

    if ! config.debug
      GyammServer.be_daemon
      GyammServer.be_secure(config)
    end

    server.start

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
    exit!(0) if fork
    Process::setsid
    exit!(0) if fork
    Dir::chdir('/')
    File::umask(022)
    STDIN.reopen('/dev/null',  'r+')
    STDOUT.reopen('/dev/null', 'r+')
    STDERR.reopen('/dev/null', 'r+')
  end
  
  def self.be_secure(config)
    return unless Process.uid == 0
    uid = Etc::getpwnam(config.user).uid 
    gid = Etc::getgrnam(config.group).gid
    FileUtils.touch(config.pid_file)
    log_file = (config[:log_dir].path + Logger::LOG_FILE).to_s
    FileUtils.touch(log_file)
#    File.chown(uid, gid, config.sites_dir)
    File.chown(uid, gid, config.pid_file)
    File.chown(uid, gid, log_file)
    Process.uid  = uid
    Process.gid  = gid
    Process.euid = uid
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
