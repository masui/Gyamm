# Copyright (C) 2003-2006 Kouichirou Eto, All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
# You can redistribute it and/or modify it under the terms of the GNU GPL 2.

require 'optparse'

$LOAD_PATH << '..' unless $LOAD_PATH.include? '..'

class Config
  LIBDIR = File.dirname(__FILE__)
  DEBUG_BASEDIR = File.expand_path(LIBDIR+'/../../')

  DefaultConfig = {
    # For test and debug.
    :debug		=> false,
    :test		=> false,
    :verbose_mode	=> false,

    :timeout			=> 120,
    
    :max_threads		=> 10,		# Number of working threads.

    # Server setting.
    :user		=> 'daemon',  # daemon
    :group		=> 'daemon', # daemon
    :bind_address	=> '0.0.0.0',
#    :ml_port		=> 9195,
    :ml_port		=> 25,

    :logger => nil,
    :catalog => nil,
    
    # Setting for production mode.
#    :sites_dir	=> '/var/lib/qwik/data',
#    :grave_dir	=> '/var/lib/qwik/grave',
#    :cache_dir	=> '/var/cache/qwik',
#    :super_dir	=> '/usr/share/qwik/super',
#    :theme_dir	=> '/usr/share/qwik/theme',
#    :template_dir	=> '/usr/share/qwik/template',
    :qrcode_dir	=> '/usr/share/qwik/qrcode',
    :etc_dir		=> '/etc/gyamm',
    :config_file	=> '/etc/gyamm/config.txt',
    :log_dir		=> '/var/log/gyamm',
    :pid_file	=> '/var/run/gyamm.pid',

    :gyamm_datadir => '/Users/masui/Gyamm/public',

  }
  
  DebugConfig = {
    # Setting for debug mode.
    :super_dir	=> DEBUG_BASEDIR+'/share/super',
    :theme_dir	=> DEBUG_BASEDIR+'/share/theme',
    :template_dir	=> DEBUG_BASEDIR+'/share/template',
    :qrcode_dir	=> DEBUG_BASEDIR+'/share/qrcode',
  }
  
  TestConfig = {
    # Setting for test mode.
    :debug		=> true,
    :test		=> true,	# Do not send mail.
    #      :public_url	=> 'http://example.com/q/',
    #      :default_sitename	=> 'top',
    :ml_domain	=> 'q.example.com',
    :ml_postmaster	=> 'postmaster@q.example.com',
    :sites_dir	=> '.',
    :grave_dir	=> '.',
    :cache_dir	=> '.',
    :etc_dir		=> '.',
    :log_dir		=> '.',
#    :web_pid_file	=> 'qwikweb.pid',
#    :ml_pid_file	=> 'quickml.pid',
  }
  
  def initialize
    @config = {}
    @config.update(DefaultConfig)
    Config.make_accessor(Config, @config, @config[:debug])
  end
  
  def [](k)
    return @config[k]
  end
  
  def []=(k, v)
    @config[k] = v
  end
  
  def update(hash)
    @config.update(hash)
  end
  
  # class method
  
  def self.load_args_and_config(config, progname, args)
    args_conf = Config.parse_args(progname, args)
    config.update(args_conf)		# config file is specified by args
    file_conf = Config.load_config_file(config[:config_file])
    config.update(file_conf)
    config.update(args_conf)		# Set args again to override.
  end
  
  def self.load_config_file(file)
    raise "can not open #{file}" if ! FileTest.exist?(file)
    content = open(file) {|fh| fh.read }
    return parse_config(content)
  end
  
  def self.parse_config(str)
    config = {}
    str.each_line {|line|
      next unless /\A\:/ =~ line
      ar = line.chomp.split(':', 3)
      next if ar[1].empty?
      config[ar[1].intern] = parse_value(ar[2])
    }
    return config
  end
  
  def self.parse_value(v)
    v = $1 if /\A(.+?)\#.*\z/ =~ v	# remove comment
    v = v.strip
    case v
    when 'true';	return true
    when 'false';	return false
    when 'nil';	return nil
    when /\A\d+\z/;	return v.to_i
      # Only numbers, * and spaces are allowable.
      # It is allowable to use eval in this context.
    when /\A[\d\ \*]+\z/;	return eval(v)
    when /\A(\d+)m\z/;	return $1.to_i * 60
    when /\A(\d+)h\z/;	return $1.to_i * 60 * 60
    when /\A(\d+)d\z/;	return $1.to_i * 60 * 60 * 24
    when /\A(\d+)w\z/;	return $1.to_i * 60 * 60 * 24 * 7
    when /\A(\d+)KB\z/;	return $1.to_i * 1024
    when /\A(\d+)MB\z/;	return $1.to_i * 1024 * 1024
    end
    v.gsub!('$BASEDIR') { DEBUG_BASEDIR }
    return v
  end
  
  def self.make_accessor(klass, config, debug=false)
    config.each_key {|k|
      if ! klass.method_defined?(k)
        klass.class_eval "
            def #{k}
              return @config[:#{k}]
            end
	  "
      end
    }
  end

  def self.parse_args(myprog, args)
    config = {}
    optionparser = OptionParser.new {|opts|
      opts.banner = "Usage: #{myprog} [options]"
      opts.separator ''
      opts.separator 'Specific options:'
      opts.on('-c', '--config file', 'Specify config file.') {|a|
        config[:config_file] = a
      }
      opts.on('-d', '--[no-]debug', 'Run in debug mode') {|a|
        config[:debug] = a
      }
      opts.separator ''
      opts.separator 'Common options:'
      opts.on_tail('-h', '--help', 'Show this message') {
        puts opts
        exit
      }
      opts.on_tail('-v', '--version', 'Show version') {
        puts VERSION
        exit
      }
    }
    optionparser.parse!(args)
    return config
  end
end

if $0 == __FILE__
  require 'test/unit'
  $test = true
end

if defined?($test) && $test
  class TestConfig < Test::Unit::TestCase
    def test_class_method
      c = Config

      # test_parse_config
      assert_equal({}, c.parse_config('::'))
      assert_equal({}, c.parse_config('::v'))
      assert_equal({:k=>''}, c.parse_config(':k:'))
      assert_equal({:k=>''}, c.parse_config(':k:	'))

      assert_equal({:k=>'v'}, c.parse_config(':k:v'))
      assert_equal({:k=>'v:v'}, c.parse_config(':k:v:v'))
      assert_equal({:k=>'v'}, c.parse_config("\#c\n:k:v"))
      assert_equal({:k=>'v'}, c.parse_config(':k:v#comment'))
      assert_equal({:k=>'v'}, c.parse_config(':k:v #comment'))

      assert_equal({:k=>4}, c.parse_config(':k:	2 * 2'))
      assert_equal({:k=>'1.1'}, c.parse_config(':k:1.1'))

      assert_equal({:k=>Config::DEBUG_BASEDIR},
		   c.parse_config(':k:$BASEDIR'))

      # test_parse_value
      assert_equal  true, c.parse_value('true')
      assert_equal false, c.parse_value('false')
      assert_equal   nil, c.parse_value('nil')

      assert_equal 1, c.parse_value('1')
      assert_equal 4, c.parse_value('2*2')
      assert_equal 4, c.parse_value('2 * 2')

      assert_equal     60, c.parse_value('1m')
      assert_equal   3600, c.parse_value('1h')
      assert_equal  86400, c.parse_value('1d')
      assert_equal 604800, c.parse_value('1w')
      assert_equal   1024, c.parse_value('1KB')
      assert_equal 1048576, c.parse_value('1MB')

      # test_parse_args
      assert_equal({:debug=>true}, c.parse_args('myprog', ['-d']))
    end

    def test_all
      # test_new
      config = Config.new
      assert_equal false, config.debug
      assert_equal false, config.test
      config[:debug] = true
      assert_equal true, config.debug
    end
  end
end
