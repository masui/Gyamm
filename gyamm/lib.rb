# -*- coding: utf-8 -*-
$LOAD_PATH << '..' unless $LOAD_PATH.include? '..'

require 'gyamm/config'
require 'gyamm/lock'
require 'time'

def disp_list(name)
  @name = name

  listfile = "#{ROOTDIR}/data/#{name}/deletefiles"
  d = DeleteFiles.new(listfile)

  path = "#{ROOTDIR}/data/#{@name}"
  if File.exists?(path) && File.directory?(path) then
    visited = {}
    @ids = Dir.open(path).find_all { |id|
      id =~ /^\d{14}$/ && ! d.deleted?(id)
    }.sort { |a,b|
      File.mtime("#{path}/#{b}") <=> File.mtime("#{path}/#{a}")
    }
    @from = {}
    @to = {}
    @subject = {}
    @date = {}
    @ids.each { |id|
      text = File.read("#{path}/#{id}")
      @mail = Mime.new
      @mail.read(text)
      @from[id] = @mail['From'].to_s.toutf8
      @to[id] = @mail['To'].to_s.toutf8
      @subject[id] = @mail['Subject'].to_s.toutf8
      id =~ /^(....)(..)(..)(..)(..)/
      y = $1
      m = $2
      d = $3
      h = $4
      min = $5
      @date[id] = "#{y}/#{m.sub(/^0+/,'')}/#{d.sub(/^0+/,'')} #{h.sub(/^0+/,'')}:#{min}"
#      time = Time.parse(@mail['Date'])
#      @date[id] = "#{time.year}/#{time.mon}/#{time.day}"
    }
    @id = id
    @lock = ''
    lock = Lock.new(name)
    if @locker = lock.locked_by then
      @lock = "このアーカイブは <b>#{@locker}</b> によりロックされています"
    end
    erb :list
  else
    'このURLは利用されていません'
  end
end

def disp_message(name,id)
  file = "#{ROOTDIR}/data/#{name}/#{id}"
  @text = (File.exists?(file) ? File.read(file) : '')
  @mail = Mime.new
  @mail.read(@text)
  @mail.prepare_aux_files("#{ROOTDIR}/public/tmp")
  @from = @mail['From'].to_s.toutf8
  @to = @mail['To'].to_s.toutf8
  @subject = @mail['Subject'].to_s.toutf8
  @html = @mail.dump
  @body = @mail.body.toutf8
  @id = id
  @name = name
  erb :message
end

