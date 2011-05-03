# -*- coding: utf-8 -*-
# -*- ruby -*-

require 'rubygems'
require 'sinatra'
require 'nkf'

require 'gyamm/mime'
require 'gyamm/config'
require 'gyamm/delete'
require 'gyamm/lib'
require 'gyamm/lock'

helpers do
  def protected!(name)
    unless authorized?(name)
      response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
      throw(:halt, [401, "Not authorized\n"])
    end
  end

  def authorized?(name)
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    lock = Lock.new(name)
    return true unless lock.locked?
    @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == [lock.addr, lock.password]
  end
end


get '/:name' do |name|
  protected!(name)
  disp_list(name)
end

get '/:name/' do |name|
  protected!(name)
  disp_list(name)
end

get '/:name/recover' do |name|
  protected!(name)
  listfile = "#{ROOTDIR}/data/#{name}/deletefiles"
  d = DeleteFiles.new(listfile)
  d.recover
  redirect "/#{name}"
end

get '/:name/:id' do |name,id|
  protected!(name)
  disp_message(name,id)
end

get '/:name/:id/' do |name,id|
  protected!(name)
  disp_message(name,id)
end

get '/:name/:id/delete' do |name,id|
  protected!(name)
  listfile = "#{ROOTDIR}/data/#{name}/deletefiles"
  d = DeleteFiles.new(listfile)
  d.delete(id)
  redirect "/#{name}"
end

get '/:name/:id/text' do |name,id|
  protected!(name)
  file = "#{ROOTDIR}/data/#{name}/#{id}"
  @name = name
  @id = id
  @text = (File.exists?(file) ? File.read(file) : '')
  @text.gsub!(/</,'&lt;')
  erb :text
end
