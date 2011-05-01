# -*- coding: utf-8 -*-
# -*- ruby -*-

require 'rubygems'
require 'sinatra'
require 'nkf'

require 'lib/mail'
require 'lib/mail-parse'

# get /^\/[a-zA-Z0-9\._@]+$/ do |address|
#get '/:address'  do |address|
#  ''
#end
#
#get '/:address/'  do |address|
#end

get '/:name' do |name|
  @name = name
  path = "/Users/masui/Gyamm/data/#{@name}"
  if File.exists?(path) && File.directory?(path) then
    @ids = Dir.open(path).find_all { |e|
      e =~ /^\d{14}$/
    }
    @from = {}
    @to = {}
    @subject = {}
    @ids.each { |id|
      text = File.read("#{path}/#{id}")
      @mail = Mail.new
      @mail.read(text)
      @from[id] = @mail['From'].toutf8
      @to[id] = @mail['To'].toutf8
      @subject[id] = @mail['Subject'].toutf8
    }
    erb :folder
  else
    ''
  end
end

get '/:name/' do |name|
  @name = name
  path = "/Users/masui/Gyamm/data/#{@name}"
  if File.exists?(path) && File.directory?(path) then
    @ids = Dir.open(path).find_all { |e|
      e =~ /^\d{14}$/
    }
    @from = {}
    @to = {}
    @subject = {}
    @ids.each { |id|
      text = File.read("#{path}/#{id}")
      @mail = Mail.new
      @mail.read(text)
      @from[id] = @mail['From'].toutf8
      @to[id] = @mail['To'].toutf8
      @subject[id] = @mail['Subject'].toutf8
    }
    erb :folder
  else
    ''
  end
end

get '/:name/:id' do |name,id|
  file = "/Users/masui/Gyamm/data/#{name}/#{id}"
  @text = (File.exists?(file) ? File.read(file) : '')
  @mail = Mail.new
  @mail.read(@text)
  @body = @mail.body.toutf8
  @from = @mail['From'].toutf8
  @to = @mail['To'].toutf8
  @subject = @mail['Subject'].toutf8

  erb :plain
end

get '/:name/:id/' do |name,id|
  file = "/Users/masui/Gyamm/data/#{name}/#{id}"
  @text = (File.exists?(file) ? File.read(file) : '')
  @mail = Mail.new
  @mail.read(@text)
  @body = @mail.body.toutf8
  @from = @mail['From'].toutf8
  @to = @mail['To'].toutf8
  @subject = @mail['Subject'].toutf8

  erb :plain
end

