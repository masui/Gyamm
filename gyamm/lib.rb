$LOAD_PATH << '..' unless $LOAD_PATH.include? '..'

require 'gyamm/config'

def disp_list(name)
  @name = name

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

def disp_message(name,id)
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

