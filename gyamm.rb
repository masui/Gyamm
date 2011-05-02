# -*- coding: utf-8 -*-
# -*- ruby -*-

require 'rubygems'
require 'sinatra'
require 'nkf'

require 'gyamm/mime'
require 'gyamm/config'
require 'gyamm/delete'

get '/:name' do |name|
  @name = name
#  deleted_ids = {}
#  listfile = "#{ROOTDIR}/data/#{name}/deletefiles"
#  if File.exists?(listfile) then
#    File.open(listfile){ |f|
#      f.each { |line|
#        line.chomp!
#        deleted_ids[line] = true
#      }
#    }
#  end

  listfile = "#{ROOTDIR}/data/#{name}/deletefiles"
  d = DeleteFiles.new(listfile)
  

  path = "#{ROOTDIR}/data/#{@name}"
  if File.exists?(path) && File.directory?(path) then
    @ids = Dir.open(path).find_all { |e|
      # e =~ /^\d{14}$/ && ! deleted_ids[e]
      e =~ /^\d{14}$/ && ! d.deleted?(e)
    }.sort { |a,b|
      b <=> a
    }
    @from = {}
    @to = {}
    @subject = {}
    @date = {}
    @ids.each { |id|
      text = File.read("#{path}/#{id}")
      @mail = Mail.new
      @mail.read(text)
      @from[id] = @mail['From'].to_s.toutf8
      @to[id] = @mail['To'].to_s.toutf8
      @subject[id] = @mail['Subject'].to_s.toutf8
      id =~ /^(....)(..)(..)/
      y = $1
      m = $2
      d = $3
      @date[id] = "#{y}/#{m.sub(/^0+/,'')}/#{d.sub(/^0+/,'')}"
    }
    @id = id
    erb :list
  else
    ''
  end
end

get '/:name/' do |name|
  @name = name
  path = "#{ROOTDIR}/data/#{@name}"
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
    erb :list
  else
    ''
  end
end

get '/:name/recover' do |name|
  listfile = "#{ROOTDIR}/data/#{name}/deletefiles"
  d = DeleteFiles.new(listfile)
  d.recover

#  if File.exists?(listfile) then
#    ids = []
#    File.open(listfile){ |f|
#      f.each { |line|
#        line.chomp!
#        next if line !~ /\d{14}/
#        ids << line if line != id
#      }
#    }
#    ids.shift
#    File.open(listfile,"w"){ |f|
#      ids.each { |id|
#        f.puts id
#      }
#    }
#  end
  redirect "/#{name}"
end

get '/:name/:id' do |name,id|
  file = "#{ROOTDIR}/data/#{name}/#{id}"
  @text = (File.exists?(file) ? File.read(file) : '')
  @mail = Mail.new
  @mail.read(@text)
  @mail.prepare_aux_files("#{ROOTDIR}/public/tmp")
  @from = @mail['From'].to_s.toutf8
  @to = @mail['To'].to_s.toutf8
  @subject = @mail['Subject'].to_s.toutf8
  @html = @mail.dump
  @body = @mail.body.toutf8
  @id = id
  @name = name
  erb :plain
end

get '/:name/:id/' do |name,id|
  file = "#{ROOTDIR}/data/#{name}/#{id}"
  @text = (File.exists?(file) ? File.read(file) : '')
  @mail = Mail.new
  @mail.read(@text)
  @mail.prepare_aux_files("#{ROOTDIR}/public/tmp")
  @from = @mail['From'].to_s.toutf8
  @to = @mail['To'].to_s.toutf8
  @subject = @mail['Subject'].to_s.toutf8
  @html = @mail.dump
  @body = @mail.body.toutf8
  @id = id
  @name = name
  erb :plain
end

get '/:name/:id/delete' do |name,id|
  listfile = "#{ROOTDIR}/data/#{name}/deletefiles"
  d = DeleteFiles.new(listfile)
  d.delete(id)

#  if !File.exists?(listfile) then
#    File.open(listfile,"w"){ |f|
#      f.puts ""
#    }
#  end
#  ids = []
#  ids << id
#  File.open(listfile){ |f|
#    f.each { |line|
#      line.chomp!
#      next if line !~ /\d{14}/
#      ids << line if line != id
#    }
#  }
#  File.open(listfile,"w"){ |f|
#    ids.each { |id|
#      f.puts id
#    }
#  }

  redirect "/#{name}"
end

get '/:name/:id/text' do |name,id|
  file = "#{ROOTDIR}/data/#{name}/#{id}"
  @name = name
  @id = id
  @text = (File.exists?(file) ? File.read(file) : '')
  @text.gsub!(/</,'&lt;')
  erb :text
end
