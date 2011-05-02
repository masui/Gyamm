# -*- coding: utf-8 -*-
# -*- ruby -*-

require 'rubygems'
require 'sinatra'
require 'nkf'

require 'lib/mail'
require 'lib/mail-parse'
require 'lib/mail-body'

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
  @from = @mail['From'].toutf8
  @to = @mail['To'].toutf8
  @subject = @mail['Subject'].toutf8
  if false && @mail.multipart? then
    content = ''
    @mail.each_part {|sub_mail|
      if sub_mail.plain_text_body?
        c = sub_mail.decoded_body.normalize_eol
        c = c.set_mail_charset.to_page_charset
        content << c
      else
        filename = sub_mail.filename
        decoded_body = sub_mail.decoded_body
        if filename && decoded_body
#          msg = GroupSite.attach(site, key, filename, decoded_body)
          msg = "<<<#{filename}>>>\n"
          content << msg
        else
          content << decoded_body
        end
      end
    }
    return content
  else
    @body = @mail.body.toutf8
    erb :plain
  end
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

